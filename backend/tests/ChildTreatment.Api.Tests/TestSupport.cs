using System.Text.Json;
using ChildTreatment.Api.Coaching;
using ChildTreatment.Api.Data;
using ChildTreatment.Api.Learning;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Onboarding;
using ChildTreatment.Api.Planning;
using ChildTreatment.Api.Safety;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Time.Testing;

namespace ChildTreatment.Api.Tests;

/// <summary>Stands in for the model. Records every request and answers from a script.</summary>
public sealed class FakeLlm : ILlmClient
{
    public const string ReviewPass = """{"verdict":"pass","rules":[],"reason":""}""";
    public const string ReviewBlock = """{"verdict":"block","rules":[2],"reason":"Medication advice."}""";

    public List<LlmRequest> Requests { get; } = [];
    /// <summary>What the agent under test answers: plain text for the coach, JSON for the other agents.</summary>
    public string CoachReply { get; set; } = "תשובה של המאמן ל[CHILD]";
    public string Review { get; set; } = ReviewPass;
    /// <summary>Verdicts for the next reviews, in order. When empty, every review gets <see cref="Review"/>.</summary>
    public Queue<string> Reviews { get; } = new();
    public bool Refuse { get; set; }
    public Exception? Throw { get; set; }

    public Task<LlmResult> CompleteAsync(LlmRequest request, CancellationToken ct = default)
    {
        Requests.Add(request);
        if (Throw is not null)
            throw Throw;

        if (request.Tier == LlmTier.Review)
            return Task.FromResult(new LlmResult(Reviews.Count > 0 ? Reviews.Dequeue() : Review, false));
        return Task.FromResult(Refuse ? new LlmResult("", true) : new LlmResult(CoachReply, false));
    }

    public IEnumerable<LlmRequest> CoachRequests => Requests.Where(r => r.Tier == LlmTier.Main);
    public IEnumerable<LlmRequest> ReviewRequests => Requests.Where(r => r.Tier == LlmTier.Review);

    /// <summary>Everything a request carried, joined, for asserting on what reached the model.</summary>
    public static string AllText(LlmRequest request) =>
        string.Join("\n", [request.System, request.Context ?? "", .. request.Messages.Select(m => m.Text)]);
}

public sealed record ScenarioSummary(string Id, string Expect, string LastParentMessage);

public static class TestSupport
{
    public static readonly string PromptsRoot = FindPromptsRoot();

    private static string FindPromptsRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "prompts", "parent-coach")))
            dir = dir.Parent;
        return Path.Combine(dir?.FullName ?? throw new DirectoryNotFoundException("prompts folder not found"), "prompts");
    }

    public static PromptStore Prompts() => new(new PromptOptions { Root = PromptsRoot });

    public static CrisisRules Rules() => CrisisRules.Load(PromptsRoot);

    public static ParentCoachAgent Agent(FakeLlm llm)
    {
        var prompts = Prompts();
        return new ParentCoachAgent(llm, prompts, Rules(), new SafetyReviewer(llm, prompts, NullLogger<SafetyReviewer>.Instance));
    }

    public static ProfileAgent ProfileAgent(FakeLlm llm)
    {
        var prompts = Prompts();
        return new ProfileAgent(llm, prompts, Rules(),
            new SafetyReviewer(llm, prompts, NullLogger<SafetyReviewer>.Instance), NullLogger<ProfileAgent>.Instance);
    }

    public static WeeklySummaryAgent SummaryAgent(FakeLlm llm)
    {
        var prompts = Prompts();
        return new WeeklySummaryAgent(llm, prompts,
            new SafetyReviewer(llm, prompts, NullLogger<SafetyReviewer>.Instance), NullLogger<WeeklySummaryAgent>.Instance);
    }

    public static TutorAgent Tutor(FakeLlm llm)
    {
        var prompts = Prompts();
        return new TutorAgent(llm, prompts,
            new SafetyReviewer(llm, prompts, NullLogger<SafetyReviewer>.Instance), NullLogger<TutorAgent>.Instance);
    }

    public static WorldGuideAgent Guide(FakeLlm llm)
    {
        var prompts = Prompts();
        return new WorldGuideAgent(llm, prompts,
            new SafetyReviewer(llm, prompts, NullLogger<SafetyReviewer>.Instance), NullLogger<WorldGuideAgent>.Instance);
    }

    public static readonly FieldProtector Protector = new(new byte[32]);

    /// <summary>A context on a named in-memory database, acting for the given family.</summary>
    public static AppDbContext Db(string databaseName, Guid? familyId)
    {
        var options = new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(databaseName).Options;
        return new AppDbContext(options, new CurrentFamily { FamilyId = familyId }, Protector);
    }

    public static FakeTimeProvider Clock() => new(new DateTimeOffset(2026, 10, 3, 9, 0, 0, TimeSpan.Zero));

    /// <summary>The scenarios of an agent that holds a conversation with the parent.</summary>
    public static List<ScenarioSummary> Scenarios(string agent = "parent-coach")
    {
        var path = Path.Combine(PromptsRoot, agent, "scenarios.json");
        using var doc = JsonDocument.Parse(File.ReadAllText(path));
        return doc.RootElement.GetProperty("scenarios").EnumerateArray()
            .Select(s => new ScenarioSummary(
                s.GetProperty("id").GetString()!,
                s.GetProperty("expect").GetString()!,
                s.GetProperty("conversation").EnumerateArray().Last().GetProperty("text").GetString()!))
            .ToList();
    }
}
