using System.Text.Json;

namespace ChildTreatment.Api.Llm;

public enum LlmRole { User, Assistant }

public sealed record LlmMessage(LlmRole Role, string Text);

public sealed record LlmRequest
{
    /// <summary>The agent's prompt. Stable across calls, so it can be cached.</summary>
    public required string System { get; init; }
    /// <summary>Per-family context, sent as a second system block after the stable prompt.</summary>
    public string? Context { get; init; }
    public required IReadOnlyList<LlmMessage> Messages { get; init; }
    /// <summary>When set, the reply is constrained to this JSON schema.</summary>
    public Dictionary<string, JsonElement>? JsonSchema { get; init; }
    public int MaxTokens { get; init; } = 16000;
}

public sealed record LlmResult(string Text, bool Refused);

/// <summary>The model is temporarily unreachable or overloaded. Safe to retry later.</summary>
public sealed class LlmUnavailableException(string message, Exception inner) : Exception(message, inner);

/// <summary>The only way the application reaches the LLM.</summary>
public interface ILlmClient
{
    Task<LlmResult> CompleteAsync(LlmRequest request, CancellationToken ct = default);
}
