using System.Globalization;
using System.Text;
using System.Text.Json;
using ChildTreatment.Api.Coaching;
using ChildTreatment.Api.Data;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;

namespace ChildTreatment.Api.Planning;

/// <summary>Numbers about the week, counted by code from the log.</summary>
public sealed record WeekFacts(int LogEntries, double? MoodAverage, double? PreviousMoodAverage);

/// <summary>What the Planner knows about the week. All text is already pseudonymized.</summary>
public sealed record SummaryContext
{
    public required int Age { get; init; }
    public IReadOnlyList<string> Profile { get; init; } = [];
    public IReadOnlyList<CoachAccommodation> Accommodations { get; init; } = [];
    public IReadOnlyList<string> Log { get; init; } = [];
    public required WeekFacts Facts { get; init; }
    /// <summary>Set when the crisis screen was shown during the week.</summary>
    public string? SafetyNote { get; init; }
}

/// <summary>A pattern is either seen in the log ("observed") or the Planner's reading of it ("guess").</summary>
public sealed record SummaryPattern(string Text, string Basis)
{
    public const string Observed = "observed";
    public const string Guess = "guess";
}

public sealed record WeeklySummaryContent(
    string WhatHappened,
    IReadOnlyList<SummaryPattern> Patterns,
    IReadOnlyList<string> WhatWorked,
    string Proposal);

public enum SummaryOutcomeKind { Summary, Fallback }

public sealed record SummaryOutcome(
    SummaryOutcomeKind Kind,
    WeeklySummaryContent? Content,
    string PromptVersion,
    string? BlockReason = null);

/// <summary>
/// The Planner's weekly summary: what happened, what patterns appear, what worked, and a proposal
/// for next week. It proposes and never changes the plan; stepping up needs the parent (docs/SAFETY.md).
/// It holds no database access, so the application and the evaluation tool run the same code.
/// </summary>
public sealed class WeeklySummaryAgent(
    ILlmClient llm,
    PromptStore prompts,
    SafetyReviewer reviewer,
    ILogger<WeeklySummaryAgent> logger)
{
    public const string AgentName = "planner";

    private const int MaxListItems = 5;

    private static readonly Dictionary<string, JsonElement> Schema = new()
    {
        ["type"] = JsonSerializer.SerializeToElement("object"),
        ["properties"] = JsonSerializer.SerializeToElement(new
        {
            what_happened = new { type = "string" },
            patterns = new
            {
                type = "array",
                items = new
                {
                    type = "object",
                    properties = new
                    {
                        text = new { type = "string" },
                        basis = new { type = "string", @enum = new[] { SummaryPattern.Observed, SummaryPattern.Guess } },
                    },
                    required = new[] { "text", "basis" },
                    additionalProperties = false,
                },
            },
            what_worked = new { type = "array", items = new { type = "string" } },
            proposal = new { type = "string" },
        }),
        ["required"] = JsonSerializer.SerializeToElement(new[] { "what_happened", "patterns", "what_worked", "proposal" }),
        ["additionalProperties"] = JsonSerializer.SerializeToElement(false),
    };

    public async Task<SummaryOutcome> SummarizeAsync(SummaryContext context, CancellationToken ct = default)
    {
        var prompt = prompts.Get(AgentName);
        var weekContext = FormatContext(context);

        var result = await llm.CompleteAsync(new LlmRequest
        {
            System = prompt.Text,
            Context = weekContext,
            Messages = [new LlmMessage(LlmRole.User, "Write the summary of this week for the parent.")],
            JsonSchema = Schema,
            MaxTokens = 4000,
        }, ct);

        if (result.Refused || string.IsNullOrWhiteSpace(result.Text))
            return new SummaryOutcome(SummaryOutcomeKind.Fallback, null, prompt.Version, "The model declined or returned nothing.");

        if (Parse(result.Text) is not { } content)
            return new SummaryOutcome(SummaryOutcomeKind.Fallback, null, prompt.Version, "The model's output could not be read.");

        // The reviewer reads the week's log as the parent's words, so a missed sign of danger is caught.
        var review = await reviewer.ReviewAsync(
            weekContext, string.Join("\n", context.Log), FormatForReview(content), ct, SafetyReviewer.SummaryRules);
        if (!review.Passed)
            return new SummaryOutcome(SummaryOutcomeKind.Fallback, null, prompt.Version, review.Reason);

        return new SummaryOutcome(SummaryOutcomeKind.Summary, content, prompt.Version);
    }

    private WeeklySummaryContent? Parse(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            var whatHappened = root.GetProperty("what_happened").GetString()?.Trim();
            var proposal = root.GetProperty("proposal").GetString()?.Trim();
            if (string.IsNullOrEmpty(whatHappened) || string.IsNullOrEmpty(proposal))
                return null;

            var patterns = root.GetProperty("patterns").EnumerateArray()
                .Select(p => new SummaryPattern(
                    p.GetProperty("text").GetString()?.Trim() ?? "",
                    // Anything not clearly marked as observed is shown as a guess.
                    p.GetProperty("basis").GetString() == SummaryPattern.Observed ? SummaryPattern.Observed : SummaryPattern.Guess))
                .Where(p => p.Text.Length > 0)
                .Take(MaxListItems)
                .ToList();
            var whatWorked = root.GetProperty("what_worked").EnumerateArray()
                .Select(w => w.GetString()?.Trim() ?? "")
                .Where(w => w.Length > 0)
                .Take(MaxListItems)
                .ToList();

            return new WeeklySummaryContent(whatHappened, patterns, whatWorked, proposal);
        }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException)
        {
            logger.LogWarning(ex, "The Planner returned a summary that could not be read");
            return null;
        }
    }

    public static string FormatForReview(WeeklySummaryContent content)
    {
        var sb = new StringBuilder();
        sb.AppendLine("Weekly summary shown to the parent.");
        sb.AppendLine($"What happened: {content.WhatHappened}");
        foreach (var pattern in content.Patterns)
            sb.AppendLine($"Pattern ({pattern.Basis}): {pattern.Text}");
        foreach (var worked in content.WhatWorked)
            sb.AppendLine($"What worked: {worked}");
        sb.Append($"Proposal for next week: {content.Proposal}");
        return sb.ToString();
    }

    public static string FormatContext(SummaryContext context)
    {
        var sb = new StringBuilder();
        sb.AppendLine("<family_context>");
        sb.AppendLine($"<child age=\"{context.Age}\" mode=\"{(context.Age >= ChildProfile.TeenModeFromAge ? "teen" : "child")}\" />");

        sb.AppendLine("<profile>");
        if (context.Profile.Count == 0)
            sb.AppendLine("The parent has not added anything yet.");
        foreach (var item in context.Profile)
            sb.AppendLine($"- {item}");
        sb.AppendLine("</profile>");

        sb.AppendLine("<accommodations>");
        if (context.Accommodations.Count == 0)
            sb.AppendLine("None mapped yet.");
        foreach (var a in context.Accommodations)
        {
            sb.Append($"- [{a.Status}] {a.Description}");
            if (!string.IsNullOrWhiteSpace(a.PlannedChange))
                sb.Append($" | planned change: {a.PlannedChange}");
            sb.AppendLine();
        }
        sb.AppendLine("</accommodations>");

        sb.AppendLine("<week_log>");
        foreach (var entry in context.Log)
            sb.AppendLine($"- {entry}");
        sb.AppendLine("</week_log>");

        sb.AppendLine("<week_facts>");
        sb.AppendLine($"Log entries this week: {context.Facts.LogEntries}");
        sb.AppendLine($"Parent's average mood this week (1 very hard to 5 good): {Number(context.Facts.MoodAverage)}");
        sb.AppendLine($"Parent's average mood the week before: {Number(context.Facts.PreviousMoodAverage)}");
        sb.AppendLine("</week_facts>");

        if (!string.IsNullOrWhiteSpace(context.SafetyNote))
            sb.AppendLine($"<safety_note>{context.SafetyNote}</safety_note>");

        sb.Append("</family_context>");
        return sb.ToString();
    }

    private static string Number(double? value) =>
        value is { } v ? v.ToString("0.0", CultureInfo.InvariantCulture) : "not recorded";
}
