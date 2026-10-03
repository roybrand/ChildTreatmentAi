using System.Text.Json;
using ChildTreatment.Api.Llm;

namespace ChildTreatment.Api.Safety;

public sealed record ReviewResult(bool Passed, string Reason);

/// <summary>
/// The second safety layer: an LLM check of an agent's reply before a person sees it.
/// It can only add a block. Anything it cannot read as a clear pass is treated as a block.
/// </summary>
public sealed class SafetyReviewer(ILlmClient llm, PromptStore prompts, ILogger<SafetyReviewer> logger)
{
    private static readonly Dictionary<string, JsonElement> Schema = new()
    {
        ["type"] = JsonSerializer.SerializeToElement("object"),
        ["properties"] = JsonSerializer.SerializeToElement(new
        {
            verdict = new { type = "string", @enum = new[] { "pass", "block" } },
            rules = new { type = "array", items = new { type = "integer" } },
            reason = new { type = "string" },
        }),
        ["required"] = JsonSerializer.SerializeToElement(new[] { "verdict", "rules", "reason" }),
        ["additionalProperties"] = JsonSerializer.SerializeToElement(false),
    };

    public const string ConversationRules = "safety-review";
    /// <summary>Rules for a weekly summary, where the parent's words are a week of log entries.</summary>
    public const string SummaryRules = "summary-review";

    /// <param name="context">What the agent was told about the family, so a reported condition is not mistaken for a diagnosis.</param>
    /// <param name="rules">Which review prompt to apply.</param>
    public async Task<ReviewResult> ReviewAsync(
        string context, string parentMessage, string reply, CancellationToken ct = default,
        string rules = ConversationRules)
    {
        var result = await llm.CompleteAsync(new LlmRequest
        {
            Tier = LlmTier.Review,
            System = prompts.Get(rules).Text,
            Messages =
            [
                new LlmMessage(LlmRole.User,
                    $"{context}\n\n<parent_message>\n{parentMessage}\n</parent_message>\n\n<coach_reply>\n{reply}\n</coach_reply>"),
            ],
            JsonSchema = Schema,
            MaxTokens = 2000,
        }, ct);

        if (result.Refused)
            return new ReviewResult(false, "The reviewer declined to assess the reply.");

        try
        {
            using var doc = JsonDocument.Parse(result.Text);
            var verdict = doc.RootElement.GetProperty("verdict").GetString();
            var reason = doc.RootElement.GetProperty("reason").GetString() ?? "";
            return verdict == "pass" ? new ReviewResult(true, "") : new ReviewResult(false, reason);
        }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException)
        {
            logger.LogWarning(ex, "The safety review returned output that could not be read");
            return new ReviewResult(false, "The review output could not be read.");
        }
    }
}
