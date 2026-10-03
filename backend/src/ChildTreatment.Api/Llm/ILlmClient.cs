using System.Text.Json;

namespace ChildTreatment.Api.Llm;

public enum LlmRole { User, Assistant }

public sealed record LlmMessage(LlmRole Role, string Text)
{
    /// <summary>
    /// The API needs turns that start with the user and alternate. Stored history can have
    /// two messages in a row from one side (a parent message whose reply failed, for example),
    /// so neighbours from the same side are joined.
    /// </summary>
    public static List<LlmMessage> AsAlternatingTurns(IReadOnlyList<LlmMessage> history)
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

/// <summary>Which configured model a call uses. Review calls can run on a cheaper model than the main agent.</summary>
public enum LlmTier { Main, Review }

public sealed record LlmRequest
{
    public LlmTier Tier { get; init; } = LlmTier.Main;
    /// <summary>The agent's prompt. Stable across calls, so it can be cached.</summary>
    public required string System { get; init; }
    /// <summary>Per-family context, sent as a second system block after the stable prompt.</summary>
    public string? Context { get; init; }
    public required IReadOnlyList<LlmMessage> Messages { get; init; }
    /// <summary>When set, the reply is constrained to this JSON schema.</summary>
    public Dictionary<string, JsonElement>? JsonSchema { get; init; }
    public int MaxTokens { get; init; } = 16000;
}

public sealed record LlmResult(
    string Text, bool Refused, string Model = "", long InputTokens = 0, long OutputTokens = 0);

/// <summary>The model is temporarily unreachable or overloaded. Safe to retry later.</summary>
public sealed class LlmUnavailableException(string message, Exception inner) : Exception(message, inner);

/// <summary>The only way the application reaches the LLM.</summary>
public interface ILlmClient
{
    Task<LlmResult> CompleteAsync(LlmRequest request, CancellationToken ct = default);
}
