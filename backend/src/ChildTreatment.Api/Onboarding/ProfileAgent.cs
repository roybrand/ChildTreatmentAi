using System.Text;
using System.Text.Json;
using ChildTreatment.Api.Data;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;

namespace ChildTreatment.Api.Onboarding;

/// <summary>A profile item as the agent sees it. Text is already pseudonymized.</summary>
public sealed record ProfileNote(ProfileSection Section, string Text, ProfileItemStatus Status);

public sealed record InterviewContext
{
    public required int Age { get; init; }
    /// <summary>Everything already in the profile, rejected items included, so nothing is proposed twice.</summary>
    public IReadOnlyList<ProfileNote> Items { get; init; } = [];
    /// <summary>Which interview to hold: the learner's profile for the tutor, or the family coaching one.</summary>
    public string Prompt { get; init; } = ProfileAgent.LearnerProfile;
    /// <summary>Sections the agent may write to. An item for any other section is dropped by code.</summary>
    public IReadOnlySet<ProfileSection> Sections { get; init; } = new FeatureOptions().ProfileSections;
}

public enum InterviewOutcomeKind { Reply, Crisis, Fallback }

/// <summary>Something the parent said, written down for the parent to confirm.</summary>
public sealed record ProposedItem(ProfileSection Section, string Text);

public sealed record InterviewOutcome(
    InterviewOutcomeKind Kind,
    string Text,
    string PromptVersion,
    IReadOnlyList<ProposedItem> Items,
    bool Complete = false,
    string? CrisisCategory = null,
    string? BlockReason = null);

/// <summary>
/// The Profile Agent: one turn of the onboarding interview, with both safety layers around it.
/// It asks the next question and writes down what the parent just said. It holds no database
/// access, so the application and the evaluation tool run the same code.
/// </summary>
public sealed class ProfileAgent(
    ILlmClient llm,
    PromptStore prompts,
    CrisisRules crisisRules,
    SafetyReviewer reviewer,
    ILogger<ProfileAgent> logger)
{
    /// <summary>The interview for the family coaching module: it also asks about anxiety and reported diagnoses.</summary>
    public const string AgentName = "profile-agent";
    /// <summary>The interview for the tutor: what the learner loves, what is hard in learning, what helps.</summary>
    public const string LearnerProfile = "learner-profile";

    public const int MaxItemsPerTurn = 6;
    public const int MaxItemLength = 300;

    private static readonly Dictionary<string, JsonElement> Schema = new()
    {
        ["type"] = JsonSerializer.SerializeToElement("object"),
        ["properties"] = JsonSerializer.SerializeToElement(new
        {
            reply = new { type = "string" },
            items = new
            {
                type = "array",
                items = new
                {
                    type = "object",
                    properties = new
                    {
                        section = new { type = "string", @enum = Enum.GetNames<ProfileSection>() },
                        text = new { type = "string" },
                    },
                    required = new[] { "section", "text" },
                    additionalProperties = false,
                },
            },
            complete = new { type = "boolean" },
        }),
        ["required"] = JsonSerializer.SerializeToElement(new[] { "reply", "items", "complete" }),
        ["additionalProperties"] = JsonSerializer.SerializeToElement(false),
    };

    public async Task<InterviewOutcome> RespondAsync(
        InterviewContext context,
        IReadOnlyList<LlmMessage> history,
        string parentMessage,
        CancellationToken ct = default)
    {
        var prompt = prompts.Get(context.Prompt);

        // Layer one: rules in code, before the model sees anything. Nothing from this message is written down.
        if (crisisRules.Check(parentMessage) is { } hit)
            return new InterviewOutcome(InterviewOutcomeKind.Crisis, SafetyTexts.Crisis, prompt.Version, [],
                CrisisCategory: hit.Category);

        var profileContext = FormatContext(context);
        var messages = LlmMessage.AsAlternatingTurns([.. history, new LlmMessage(LlmRole.User, parentMessage)]);
        var blockReason = "";

        for (var attempt = 1; attempt <= SafetyReviewer.MaxAttempts; attempt++)
        {
            var result = await llm.CompleteAsync(new LlmRequest
            {
                System = prompt.Text,
                Context = profileContext,
                Messages = messages,
                JsonSchema = Schema,
                MaxTokens = 4000,
            }, ct);

            if (result.Refused || string.IsNullOrWhiteSpace(result.Text))
                return Fallback(prompt, "The model declined or returned nothing.");

            if (Parse(result.Text, context.Sections) is not { } turn)
                return Fallback(prompt, "The model's output could not be read.");

            // Layer two: the reviewer sees the question and the notes, since both are shown to the parent.
            var review = await reviewer.ReviewAsync(profileContext, parentMessage, FormatForReview(turn.Reply, turn.Items), ct);
            if (review.Passed)
                return new InterviewOutcome(InterviewOutcomeKind.Reply, turn.Reply, prompt.Version, turn.Items, turn.Complete);

            // One more try, with the reviewer's reason in hand.
            blockReason = review.Reason;
            messages = [.. messages, new LlmMessage(LlmRole.Assistant, result.Text), reviewer.RetryMessage(review)];
        }

        return Fallback(prompt, blockReason);
    }

    private static InterviewOutcome Fallback(Prompt prompt, string reason) =>
        new(InterviewOutcomeKind.Fallback, SafetyTexts.Fallback, prompt.Version, [], BlockReason: reason);

    private (string Reply, List<ProposedItem> Items, bool Complete)? Parse(string json, IReadOnlySet<ProfileSection> sections)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            var reply = root.GetProperty("reply").GetString()?.Trim();
            if (string.IsNullOrEmpty(reply))
                return null;

            var items = new List<ProposedItem>();
            foreach (var item in root.GetProperty("items").EnumerateArray())
            {
                var text = item.GetProperty("text").GetString()?.Trim();
                // Anything outside the known sections or the size limits is dropped, not stored.
                if (!Enum.TryParse<ProfileSection>(item.GetProperty("section").GetString(), out var section) ||
                    !sections.Contains(section) ||
                    string.IsNullOrEmpty(text) || text.Length > MaxItemLength)
                    continue;
                if (items.Count < MaxItemsPerTurn)
                    items.Add(new ProposedItem(section, text));
            }

            return (reply, items, root.GetProperty("complete").GetBoolean());
        }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException)
        {
            logger.LogWarning(ex, "The Profile Agent returned output that could not be read");
            return null;
        }
    }

    public static string FormatForReview(string reply, IReadOnlyList<ProposedItem> items)
    {
        if (items.Count == 0)
            return reply;

        var sb = new StringBuilder(reply);
        sb.AppendLine().AppendLine().AppendLine("Notes written down from the parent's message, shown to the parent to confirm:");
        foreach (var item in items)
            sb.AppendLine($"- {item.Section}: {item.Text}");
        return sb.ToString().TrimEnd();
    }

    public static string FormatContext(InterviewContext context)
    {
        var sb = new StringBuilder();
        sb.AppendLine("<family_context>");
        sb.AppendLine($"<child age=\"{context.Age}\" mode=\"{(context.Age >= ChildProfile.TeenModeFromAge ? "teen" : "child")}\" />");
        sb.AppendLine("<profile_so_far>");
        if (context.Items.Count == 0)
            sb.AppendLine("Nothing yet.");
        foreach (var item in context.Items)
            sb.AppendLine($"- [{Describe(item.Status)}] {item.Section}: {item.Text}");
        sb.AppendLine("</profile_so_far>");
        sb.Append("</family_context>");
        return sb.ToString();
    }

    private static string Describe(ProfileItemStatus status) => status switch
    {
        ProfileItemStatus.Confirmed => "confirmed by the parent",
        ProfileItemStatus.Suggested => "waiting for the parent to confirm",
        _ => "rejected by the parent",
    };
}
