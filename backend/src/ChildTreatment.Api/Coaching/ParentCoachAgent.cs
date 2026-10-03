using System.Text;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;

namespace ChildTreatment.Api.Coaching;

public sealed record CoachAccommodation(string Description, string Status, string? PlannedChange);

/// <summary>What the coach knows about a family. All text is already pseudonymized.</summary>
public sealed record CoachContext
{
    public required int Age { get; init; }
    public IReadOnlyList<string> Profile { get; init; } = [];
    public IReadOnlyList<CoachAccommodation> Accommodations { get; init; } = [];
    public IReadOnlyList<string> Log { get; init; } = [];
    /// <summary>Set when the crisis screen was shown recently, so the coach knows without seeing the text.</summary>
    public string? SafetyNote { get; init; }
}

public enum CoachOutcomeKind { Reply, Crisis, Fallback }

public sealed record CoachOutcome(
    CoachOutcomeKind Kind,
    string Text,
    string PromptVersion,
    string? CrisisCategory = null,
    string? BlockReason = null);

/// <summary>
/// The Parent Coach: one turn of coaching, with both safety layers around it.
/// It holds no database access, so the application and the evaluation tool run the same code.
/// </summary>
public sealed class ParentCoachAgent(
    ILlmClient llm,
    PromptStore prompts,
    CrisisRules crisisRules,
    SafetyReviewer reviewer)
{
    public const string AgentName = "parent-coach";

    public async Task<CoachOutcome> RespondAsync(
        CoachContext context,
        IReadOnlyList<LlmMessage> history,
        string parentMessage,
        CancellationToken ct = default)
    {
        var prompt = prompts.Get(AgentName);

        // Layer one: rules in code, before the model sees anything.
        if (crisisRules.Check(parentMessage) is { } hit)
            return new CoachOutcome(CoachOutcomeKind.Crisis, SafetyTexts.Crisis, prompt.Version, CrisisCategory: hit.Category);

        var familyContext = FormatContext(context);
        var result = await llm.CompleteAsync(new LlmRequest
        {
            System = prompt.Text,
            Context = familyContext,
            Messages = AsAlternatingTurns([.. history, new LlmMessage(LlmRole.User, parentMessage)]),
        }, ct);

        if (result.Refused || string.IsNullOrWhiteSpace(result.Text))
            return new CoachOutcome(CoachOutcomeKind.Fallback, SafetyTexts.Fallback, prompt.Version,
                BlockReason: "The model declined or returned nothing.");

        // Layer two: review of the reply before a person sees it.
        var review = await reviewer.ReviewAsync(familyContext, parentMessage, result.Text, ct);
        if (!review.Passed)
            return new CoachOutcome(CoachOutcomeKind.Fallback, SafetyTexts.Fallback, prompt.Version,
                BlockReason: review.Reason);

        return new CoachOutcome(CoachOutcomeKind.Reply, result.Text.Trim(), prompt.Version);
    }

    public static string FormatContext(CoachContext context)
    {
        var sb = new StringBuilder();
        sb.AppendLine("<family_context>");
        sb.AppendLine($"<child age=\"{context.Age}\" mode=\"{(context.Age >= Data.ChildProfile.TeenModeFromAge ? "teen" : "child")}\" />");

        sb.AppendLine("<profile>");
        AppendItems(sb, context.Profile, "The parent has not added anything yet.");
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

        sb.AppendLine("<recent_log>");
        AppendItems(sb, context.Log, "No log entries yet.");
        sb.AppendLine("</recent_log>");

        if (!string.IsNullOrWhiteSpace(context.SafetyNote))
            sb.AppendLine($"<safety_note>{context.SafetyNote}</safety_note>");

        sb.Append("</family_context>");
        return sb.ToString();
    }

    private static void AppendItems(StringBuilder sb, IReadOnlyList<string> items, string whenEmpty)
    {
        if (items.Count == 0)
            sb.AppendLine(whenEmpty);
        foreach (var item in items)
            sb.AppendLine($"- {item}");
    }

    // The API needs turns that start with the user and alternate. Stored history can have
    // two messages in a row from one side (a parent message whose reply failed, for example),
    // so neighbours from the same side are joined.
    private static List<LlmMessage> AsAlternatingTurns(IReadOnlyList<LlmMessage> history)
    {
        var turns = new List<LlmMessage>();
        foreach (var message in history)
        {
            if (turns.Count == 0 && message.Role != LlmRole.User)
                continue;

            if (turns.Count > 0 && turns[^1].Role == message.Role)
                turns[^1] = turns[^1] with { Text = turns[^1].Text + "\n\n" + message.Text };
            else
                turns.Add(message);
        }
        return turns;
    }
}
