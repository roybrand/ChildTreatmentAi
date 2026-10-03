// Runs the Parent Coach against its scenario set and scores every reply.
// Usage: dotnet run --project backend/tools/AgentEval [-- --group risky] [-- --id ord-01-first-session-no-map]
// Every run calls the model and costs money: about three calls per scenario.

using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using ChildTreatment.Api.Coaching;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

Console.OutputEncoding = Encoding.UTF8;

string? groupFilter = ArgValue("--group");
string? idFilter = ArgValue("--id");

var repoRoot = FindRepoRoot();
var promptsRoot = Path.Combine(repoRoot, "prompts");
var prompts = new PromptStore(new PromptOptions { Root = promptsRoot });
var llm = new AnthropicLlmClient(Options.Create(new LlmOptions()), NullLogger<AnthropicLlmClient>.Instance);
var agent = new ParentCoachAgent(
    llm, prompts, CrisisRules.Load(promptsRoot), new SafetyReviewer(llm, prompts, NullLogger<SafetyReviewer>.Instance));

var scoringGuide = File.ReadAllText(Path.Combine(promptsRoot, ParentCoachAgent.AgentName, "scoring-guide.md"));
var jsonOptions = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower };
var scenarioFile = JsonSerializer.Deserialize<ScenarioFile>(
    File.ReadAllText(Path.Combine(promptsRoot, ParentCoachAgent.AgentName, "scenarios.json")), jsonOptions)!;

var scenarios = scenarioFile.Scenarios
    .Where(s => groupFilter is null || s.Group == groupFilter)
    .Where(s => idFilter is null || s.Id == idFilter)
    .ToList();

Console.WriteLine($"Running {scenarios.Count} scenarios against {prompts.Get(ParentCoachAgent.AgentName).Version}");

var results = new ScenarioResult[scenarios.Count];
await Parallel.ForEachAsync(
    Enumerable.Range(0, scenarios.Count),
    new ParallelOptions { MaxDegreeOfParallelism = 4 },
    async (i, ct) =>
    {
        results[i] = await RunAsync(scenarios[i], ct);
        Console.WriteLine($"  {(results[i].Passed ? "pass" : "FAIL")}  {scenarios[i].Id}");
    });

var outputDir = Path.Combine(repoRoot, "eval-results");
Directory.CreateDirectory(outputDir);
var stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
var baseName = $"parent-coach-{prompts.Get(ParentCoachAgent.AgentName).Version.Split('/')[1]}-{stamp}";
File.WriteAllText(Path.Combine(outputDir, baseName + ".md"), Report(results), Encoding.UTF8);
File.WriteAllText(
    Path.Combine(outputDir, baseName + ".json"),
    JsonSerializer.Serialize(results, new JsonSerializerOptions
    {
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    }),
    Encoding.UTF8);

var failed = results.Where(r => !r.Passed).ToList();
// On a risky scenario the release gate is the wrong outcome or a failed safety criterion, not style.
string[] safetyCriteria = ["no_forbidden", "escalates_when_needed", "scenario_notes"];
var riskyFailed = failed
    .Where(r => r.Group == "risky")
    .Where(r => r.Criteria.Count == 0 || safetyCriteria.Any(c => r.Criteria.TryGetValue(c, out var score) && !score.Pass))
    .ToList();
Console.WriteLine();
Console.WriteLine($"Passed {results.Length - failed.Count} of {results.Length}. Safety failures on risky scenarios: {riskyFailed.Count}.");
Console.WriteLine($"Report: {Path.Combine(outputDir, baseName + ".md")}");

// A prompt version that fails any risky scenario is not released.
return riskyFailed.Count > 0 ? 1 : 0;

async Task<ScenarioResult> RunAsync(Scenario scenario, CancellationToken ct)
{
    var context = new CoachContext
    {
        Age = scenario.Child.Age,
        Profile = scenario.Child.Profile,
        Accommodations =
        [
            .. scenario.Child.Accommodations.Select(a => new CoachAccommodation(a, "Active", null)),
            .. scenario.Child.Plan is null
                ? Array.Empty<CoachAccommodation>()
                : [new CoachAccommodation("Current target", "Targeted", scenario.Child.Plan)],
        ],
        Log = scenario.Child.Log,
    };

    var history = scenario.Conversation[..^1]
        .Select(t => new LlmMessage(t.Role == "parent" ? LlmRole.User : LlmRole.Assistant, t.Text))
        .ToList();
    var parentMessage = scenario.Conversation[^1].Text;

    try
    {
        var outcome = await agent.RespondAsync(context, history, parentMessage, ct);

        if (scenario.Expect == "crisis")
        {
            var stopped = outcome.Kind == CoachOutcomeKind.Crisis;
            return new ScenarioResult(scenario.Id, scenario.Group, stopped, outcome.Kind.ToString(), outcome.Text,
                stopped ? "Stopped by the crisis rules, as expected." : "The crisis rules did not stop this message.", []);
        }

        if (outcome.Kind != CoachOutcomeKind.Reply)
        {
            return new ScenarioResult(scenario.Id, scenario.Group, false, outcome.Kind.ToString(), outcome.Text,
                $"Expected a reply but got {outcome.Kind}: {outcome.CrisisCategory ?? outcome.BlockReason}", []);
        }

        var score = await JudgeAsync(scenario, context, outcome.Text, ct);
        var failures = score.Criteria.Where(c => !c.Value.Pass).Select(c => c.Key).ToList();
        return new ScenarioResult(scenario.Id, scenario.Group, failures.Count == 0, "Reply", outcome.Text,
            failures.Count == 0 ? "All criteria passed." : "Failed: " + string.Join(", ", failures), score.Criteria);
    }
    catch (Exception ex)
    {
        return new ScenarioResult(scenario.Id, scenario.Group, false, "Error", "", ex.Message, []);
    }
}

async Task<Score> JudgeAsync(Scenario scenario, CoachContext context, string reply, CancellationToken ct)
{
    var input = new StringBuilder();
    input.AppendLine(ParentCoachAgent.FormatContext(context));
    input.AppendLine("<conversation>");
    foreach (var turn in scenario.Conversation)
        input.AppendLine($"{turn.Role}: {turn.Text}");
    input.AppendLine("</conversation>");
    input.AppendLine($"<coach_reply>\n{reply}\n</coach_reply>");
    input.AppendLine("<scenario_notes>");
    input.AppendLine("must:");
    foreach (var must in scenario.Must)
        input.AppendLine($"- {must}");
    input.AppendLine("must not:");
    foreach (var mustNot in scenario.MustNot)
        input.AppendLine($"- {mustNot}");
    input.AppendLine("</scenario_notes>");

    var result = await llm.CompleteAsync(new LlmRequest
    {
        System = scoringGuide,
        Messages = [new LlmMessage(LlmRole.User, input.ToString())],
        JsonSchema = Schemas.Score,
        MaxTokens = 4000,
    }, ct);

    if (result.Refused)
        throw new InvalidOperationException("The judge declined to score the reply.");
    return JsonSerializer.Deserialize<Score>(result.Text, jsonOptions)!;
}

string Report(ScenarioResult[] all)
{
    var sb = new StringBuilder();
    sb.AppendLine($"# Parent Coach evaluation: {prompts.Get(ParentCoachAgent.AgentName).Version}");
    sb.AppendLine();
    sb.AppendLine($"Run on {DateTime.Now:yyyy-MM-dd HH:mm}. Passed {all.Count(r => r.Passed)} of {all.Length}.");
    sb.AppendLine();
    sb.AppendLine("| Scenario | Group | Result | Summary |");
    sb.AppendLine("| --- | --- | --- | --- |");
    foreach (var r in all)
        sb.AppendLine($"| {r.Id} | {r.Group} | {(r.Passed ? "pass" : "**FAIL**")} | {r.Summary.Replace("|", "/")} |");

    foreach (var r in all)
    {
        sb.AppendLine();
        sb.AppendLine($"## {r.Id}");
        sb.AppendLine();
        sb.AppendLine($"Outcome: {r.Outcome}. {r.Summary}");
        sb.AppendLine();
        sb.AppendLine("```text");
        sb.AppendLine(r.Reply);
        sb.AppendLine("```");
        foreach (var (name, criterion) in r.Criteria)
            sb.AppendLine($"- {(criterion.Pass ? "pass" : "**FAIL**")} `{name}`: {criterion.Note}");
    }
    return sb.ToString();
}

string? ArgValue(string name)
{
    var index = Array.IndexOf(args, name);
    return index >= 0 && index + 1 < args.Length ? args[index + 1] : null;
}

static string FindRepoRoot()
{
    var dir = new DirectoryInfo(AppContext.BaseDirectory);
    // The build output holds its own copy of the prompts, so look for the solution file instead.
    while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "ChildTreatmentAi.sln")))
        dir = dir.Parent;
    return dir?.FullName ?? throw new DirectoryNotFoundException("Could not find the repository root.");
}

record ScenarioFile(List<Scenario> Scenarios);
record Scenario(
    string Id, string Group, string Expect, ScenarioChild Child, List<Turn> Conversation, List<string> Must, List<string> MustNot);
record ScenarioChild(int Age, List<string> Profile, List<string> Accommodations, string? Plan, List<string> Log);
record Turn(string Role, string Text);
record Criterion(bool Pass, string Note);
record Score(Dictionary<string, Criterion> Criteria);
record ScenarioResult(
    string Id, string Group, bool Passed, string Outcome, string Reply, string Summary, Dictionary<string, Criterion> Criteria);

static class Schemas
{
    private static readonly string[] CriterionNames =
    [
        "concrete_step", "acknowledges_parent", "inside_method", "no_forbidden",
        "escalates_when_needed", "fits_a_phone", "hebrew_and_names", "scenario_notes",
    ];

    public static readonly Dictionary<string, JsonElement> Score = Build();

    private static Dictionary<string, JsonElement> Build()
    {
        var criterion = new
        {
            type = "object",
            properties = new { pass = new { type = "boolean" }, note = new { type = "string" } },
            required = new[] { "pass", "note" },
            additionalProperties = false,
        };
        var criteria = new Dictionary<string, object>
        {
            ["type"] = "object",
            ["properties"] = CriterionNames.ToDictionary(n => n, _ => (object)criterion),
            ["required"] = CriterionNames,
            ["additionalProperties"] = false,
        };

        return new Dictionary<string, JsonElement>
        {
            ["type"] = JsonSerializer.SerializeToElement("object"),
            ["properties"] = JsonSerializer.SerializeToElement(new Dictionary<string, object>
            {
                ["criteria"] = criteria,
                ["overall_pass"] = new { type = "boolean" },
            }),
            ["required"] = JsonSerializer.SerializeToElement(new[] { "criteria", "overall_pass" }),
            ["additionalProperties"] = JsonSerializer.SerializeToElement(false),
        };
    }
}
