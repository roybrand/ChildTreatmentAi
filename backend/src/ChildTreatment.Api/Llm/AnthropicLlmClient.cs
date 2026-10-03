using Anthropic;
using Anthropic.Exceptions;
using Anthropic.Models.Messages;
using Microsoft.Extensions.Options;

namespace ChildTreatment.Api.Llm;

public sealed class LlmOptions
{
    public string Model { get; set; } = "claude-opus-5-5";
    /// <summary>low, medium, high, xhigh or max.</summary>
    public string Effort { get; set; } = "medium";
}

public sealed class AnthropicLlmClient(IOptions<LlmOptions> options, ILogger<AnthropicLlmClient> logger) : ILlmClient
{
    // Reads ANTHROPIC_API_KEY from the environment. The key never leaves the server.
    private readonly AnthropicClient _client = new();
    private readonly LlmOptions _options = options.Value;

    public async Task<LlmResult> CompleteAsync(LlmRequest request, CancellationToken ct = default)
    {
        var system = new List<TextBlockParam>
        {
            new() { Text = request.System, CacheControl = new CacheControlEphemeral() },
        };
        if (!string.IsNullOrWhiteSpace(request.Context))
            system.Add(new() { Text = request.Context });

        var parameters = new MessageCreateParams
        {
            Model = _options.Model,
            MaxTokens = request.MaxTokens,
            System = system,
            Messages = request.Messages
                .Select(m => new MessageParam
                {
                    Role = m.Role == LlmRole.User ? Role.User : Role.Assistant,
                    Content = m.Text,
                })
                .ToList(),
            OutputConfig = new OutputConfig
            {
                Effort = ParseEffort(_options.Effort),
                Format = request.JsonSchema is null ? null : new JsonOutputFormat { Schema = request.JsonSchema },
            },
        };

        try
        {
            var response = await _client.Messages.Create(parameters, cancellationToken: ct);

            if (response.StopReason == "refusal")
            {
                logger.LogWarning("The model declined a request (category: {Category})",
                    response.StopDetails?.Category);
                return new LlmResult("", Refused: true);
            }

            var text = string.Concat(response.Content.Select(b => b.Value).OfType<TextBlock>().Select(t => t.Text));
            return new LlmResult(text, Refused: false);
        }
        catch (AnthropicRateLimitException ex)
        {
            throw new LlmUnavailableException("The model is rate limited.", ex);
        }
        catch (Anthropic5xxException ex)
        {
            throw new LlmUnavailableException("The model service returned a server error.", ex);
        }
        catch (AnthropicIOException ex)
        {
            throw new LlmUnavailableException("The model service could not be reached.", ex);
        }
    }

    private static Effort ParseEffort(string value) => value.ToLowerInvariant() switch
    {
        "low" => Effort.Low,
        "medium" => Effort.Medium,
        "high" => Effort.High,
        "xhigh" => Effort.Xhigh,
        "max" => Effort.Max,
        _ => throw new InvalidOperationException($"Unknown Llm:Effort value '{value}'."),
    };
}
