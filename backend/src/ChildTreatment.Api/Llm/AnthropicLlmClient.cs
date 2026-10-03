using Anthropic;
using Anthropic.Exceptions;
using Anthropic.Models.Messages;
using Microsoft.Extensions.Options;

namespace ChildTreatment.Api.Llm;

public sealed class LlmOptions
{
    /// <summary>The model that writes what a person reads.</summary>
    public string Model { get; set; } = "claude-opus-5-5";
    /// <summary>low, medium, high, xhigh or max. Empty sends none, for models that do not accept it.</summary>
    public string Effort { get; set; } = "medium";
    /// <summary>The model that reviews a reply before it is shown.</summary>
    public string ReviewModel { get; set; } = "claude-opus-5-5";
    public string ReviewEffort { get; set; } = "medium";
}

public sealed class AnthropicLlmClient(IOptions<LlmOptions> options, ILogger<AnthropicLlmClient> logger) : ILlmClient
{
    // Reads ANTHROPIC_API_KEY from the environment. The key never leaves the server.
    private readonly AnthropicClient _client = new();
    private readonly LlmOptions _options = options.Value;

    public async Task<LlmResult> CompleteAsync(LlmRequest request, CancellationToken ct = default)
    {
        var (model, effort) = request.Tier == LlmTier.Review
            ? (_options.ReviewModel, ParseEffort(_options.ReviewEffort))
            : (_options.Model, ParseEffort(_options.Effort));

        var system = new List<TextBlockParam>
        {
            new() { Text = request.System, CacheControl = new CacheControlEphemeral() },
        };
        if (!string.IsNullOrWhiteSpace(request.Context))
            system.Add(new() { Text = request.Context });

        var format = request.JsonSchema is null ? null : new JsonOutputFormat { Schema = request.JsonSchema };

        var parameters = new MessageCreateParams
        {
            Model = model,
            MaxTokens = request.MaxTokens,
            System = system,
            Messages = request.Messages
                .Select(m => new MessageParam
                {
                    Role = m.Role == LlmRole.User ? Role.User : Role.Assistant,
                    Content = m.Text,
                })
                .ToList(),
            OutputConfig = effort is null && format is null
                ? null
                : new OutputConfig { Effort = effort, Format = format },
        };

        try
        {
            var response = await _client.Messages.Create(parameters, cancellationToken: ct);

            // Cached prompt tokens are reported separately; count them all as input so cost is not understated.
            var inputTokens = response.Usage.InputTokens
                + (response.Usage.CacheCreationInputTokens ?? 0)
                + (response.Usage.CacheReadInputTokens ?? 0);

            // One line per call, so spend can be added up from the log.
            logger.LogInformation(
                "LLM call: model {Model}, input tokens {InputTokens}, output tokens {OutputTokens}",
                model, inputTokens, response.Usage.OutputTokens);

            if (response.StopReason == "refusal")
            {
                logger.LogWarning("The model declined a request (category: {Category})",
                    response.StopDetails?.Category);
                return new LlmResult("", Refused: true, model, inputTokens, response.Usage.OutputTokens);
            }

            var text = string.Concat(response.Content.Select(b => b.Value).OfType<TextBlock>().Select(t => t.Text));
            return new LlmResult(text, Refused: false, model, inputTokens, response.Usage.OutputTokens);
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

    private static Effort? ParseEffort(string? value) => value?.Trim().ToLowerInvariant() switch
    {
        null or "" => null,
        "low" => Effort.Low,
        "medium" => Effort.Medium,
        "high" => Effort.High,
        "xhigh" => Effort.Xhigh,
        "max" => Effort.Max,
        _ => throw new InvalidOperationException($"Unknown effort value '{value}'."),
    };
}
