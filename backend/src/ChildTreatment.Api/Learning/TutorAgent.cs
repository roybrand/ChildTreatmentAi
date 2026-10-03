using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using ChildTreatment.Api.Data;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;

namespace ChildTreatment.Api.Learning;

public sealed record Ingredient(string Name, string Color);

/// <summary>
/// The world a lesson is set in: the words and colours around the game. It holds no numbers.
/// The game, the numbers, and every check of an answer are code.
/// </summary>
public sealed record LessonWorld(
    string World,
    string Scene,
    string Request,
    Ingredient IngredientA,
    Ingredient IngredientB,
    string SmallLabel,
    string BigLabel,
    string ResultWord,
    string WhyNeeded)
{
    /// <summary>Written by people. Used when the child has no interests on file, or the Tutor's world cannot be used.</summary>
    public static readonly LessonWorld Default = new(
        "סדנת הצבע",
        "ערבבת צבע משלך בסדנה שלך.",
        "מישהי ראתה את הצבע ורוצה כמות גדולה יותר, בדיוק באותו צבע.",
        new Ingredient("כחול", "#2F6FDE"),
        new Ingredient("לבן", "#F4F4F4"),
        "הכלי הקטן",
        "הכלי הגדול",
        "הצבע",
        "כל מי שמערבב משהו, צבע, מתכון או משקה, צריך לדעת להכין את אותו דבר שוב בכמות אחרת. " +
        "שבר הוא הדרך לכתוב כמה מתוך השלם, כך שזה יעבוד בכל גודל.");
}

/// <summary>What the Tutor knows about the child. All text is already pseudonymized.</summary>
public sealed record TutorContext
{
    public required int Age { get; init; }
    public IReadOnlyList<string> Interests { get; init; } = [];
    public IReadOnlyList<string> Learning { get; init; } = [];
}

public sealed record TutorOutcome(LessonWorld? World, string PromptVersion, string? Link = null, string? BlockReason = null);

/// <summary>
/// The Tutor: sets a hand-built game in the child's own world. It writes words and colours only.
/// Its output is checked by code and by the safety review before a child sees it, and when either
/// check fails the lesson runs in the built-in world. It holds no database access, so the
/// application and the evaluation tool run the same code.
/// </summary>
public sealed partial class TutorAgent(
    ILlmClient llm,
    PromptStore prompts,
    SafetyReviewer reviewer,
    ILogger<TutorAgent> logger)
{
    public const string AgentName = "tutor";

    private const int MaxSentence = 220;
    private const int MaxName = 30;
    // Two ingredients this close in colour would make a mix the child cannot see change.
    private const int MinColorDistance = 90;

    private static readonly Dictionary<string, JsonElement> Schema = BuildSchema();

    public async Task<TutorOutcome> BuildWorldAsync(TutorContext context, CancellationToken ct = default)
    {
        var prompt = prompts.Get(AgentName);
        var childContext = FormatContext(context);
        List<LlmMessage> messages = [new LlmMessage(LlmRole.User, "Set the Mixer lesson in this child's world.")];
        var blockReason = "";

        for (var attempt = 1; attempt <= SafetyReviewer.MaxAttempts; attempt++)
        {
            var result = await llm.CompleteAsync(new LlmRequest
            {
                System = prompt.Text,
                Context = childContext,
                Messages = messages,
                JsonSchema = Schema,
                MaxTokens = 3000,
            }, ct);

            if (result.Refused || string.IsNullOrWhiteSpace(result.Text))
                return new TutorOutcome(null, prompt.Version, BlockReason: "The model declined or returned nothing.");

            var (world, link, problem) = Parse(result.Text);
            if (world is null)
                return new TutorOutcome(null, prompt.Version, BlockReason: problem);

            // Every word a child reads passes the Safety Guard first.
            var review = await reviewer.ReviewAsync(childContext, "", FormatForReview(world), ct, SafetyReviewer.LessonRules);
            if (review.Passed)
                return new TutorOutcome(world, prompt.Version, link);

            blockReason = review.Reason;
            messages = [.. messages, new LlmMessage(LlmRole.Assistant, result.Text), reviewer.RetryMessage(review)];
        }

        return new TutorOutcome(null, prompt.Version, BlockReason: blockReason);
    }

    private (LessonWorld? World, string? Link, string? Problem) Parse(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            string Text(string name) => root.GetProperty(name).GetString()?.Trim() ?? "";
            Ingredient Mix(string name)
            {
                var element = root.GetProperty(name);
                return new Ingredient(
                    element.GetProperty("name").GetString()?.Trim() ?? "",
                    element.GetProperty("color").GetString()?.Trim().ToUpperInvariant() ?? "");
            }

            var world = new LessonWorld(
                Text("world"), Text("scene"), Text("request"), Mix("ingredient_a"), Mix("ingredient_b"),
                Text("small_label"), Text("big_label"), Text("result_word"), Text("why_needed"));

            return Validate(world) is { } problem ? (null, null, problem) : (world, Text("link"), null);
        }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException)
        {
            logger.LogWarning(ex, "The Tutor returned a world that could not be read");
            return (null, null, "The model's output could not be read.");
        }
    }

    /// <returns>What is wrong with the world, or null when code can use it.</returns>
    public static string? Validate(LessonWorld world)
    {
        string[] sentences = [world.Scene, world.Request, world.WhyNeeded];
        string[] names =
        [
            world.World, world.IngredientA.Name, world.IngredientB.Name,
            world.SmallLabel, world.BigLabel, world.ResultWord,
        ];

        if (sentences.Any(s => s.Length is 0 or > MaxSentence) || names.Any(n => n.Length is 0 or > MaxName))
            return "A text is missing or too long.";
        // The game shows every number itself, so a digit in the wording could contradict it.
        if (sentences.Concat(names).Any(t => t.Any(char.IsDigit)))
            return "The wording contains a digit.";
        if (!HexColor().IsMatch(world.IngredientA.Color) || !HexColor().IsMatch(world.IngredientB.Color))
            return "A colour is not a hex code.";
        if (ColorDistance(world.IngredientA.Color, world.IngredientB.Color) < MinColorDistance)
            return "The two colours are too close to tell apart.";
        if (string.Equals(world.IngredientA.Name, world.IngredientB.Name, StringComparison.Ordinal))
            return "The two ingredients have the same name.";
        return null;
    }

    private static double ColorDistance(string a, string b)
    {
        static int Channel(string hex, int index) => Convert.ToInt32(hex.Substring(1 + index * 2, 2), 16);
        double sum = 0;
        for (var i = 0; i < 3; i++)
            sum += Math.Pow(Channel(a, i) - Channel(b, i), 2);
        return Math.Sqrt(sum);
    }

    public static string FormatForReview(LessonWorld world) =>
        $"""
        World: {world.World}
        Scene: {world.Scene}
        Request: {world.Request}
        Ingredients: {world.IngredientA.Name}, {world.IngredientB.Name}
        Containers: {world.SmallLabel}, {world.BigLabel}
        The mix is called: {world.ResultWord}
        Why the idea is needed: {world.WhyNeeded}
        """;

    public static string FormatContext(TutorContext context)
    {
        var sb = new StringBuilder();
        sb.AppendLine("<family_context>");
        sb.AppendLine($"<child age=\"{context.Age}\" mode=\"{(context.Age >= ChildProfile.TeenModeFromAge ? "teen" : "child")}\" />");
        sb.AppendLine("<loves_and_is_good_at>");
        if (context.Interests.Count == 0)
            sb.AppendLine("Nothing on file.");
        foreach (var item in context.Interests)
            sb.AppendLine($"- {item}");
        sb.AppendLine("</loves_and_is_good_at>");
        sb.AppendLine("<how_they_learn>");
        if (context.Learning.Count == 0)
            sb.AppendLine("Nothing on file.");
        foreach (var item in context.Learning)
            sb.AppendLine($"- {item}");
        sb.AppendLine("</how_they_learn>");
        sb.Append("</family_context>");
        return sb.ToString();
    }

    private static Dictionary<string, JsonElement> BuildSchema()
    {
        var text = new { type = "string" };
        var ingredient = new
        {
            type = "object",
            properties = new { name = text, color = text },
            required = new[] { "name", "color" },
            additionalProperties = false,
        };
        string[] fields =
        [
            "world", "scene", "request", "ingredient_a", "ingredient_b",
            "small_label", "big_label", "result_word", "why_needed", "link",
        ];
        return new Dictionary<string, JsonElement>
        {
            ["type"] = JsonSerializer.SerializeToElement("object"),
            ["properties"] = JsonSerializer.SerializeToElement(fields.ToDictionary(
                f => f, f => f.StartsWith("ingredient_", StringComparison.Ordinal) ? (object)ingredient : text)),
            ["required"] = JsonSerializer.SerializeToElement(fields),
            ["additionalProperties"] = JsonSerializer.SerializeToElement(false),
        };
    }

    [GeneratedRegex("^#[0-9A-Fa-f]{6}$")]
    private static partial Regex HexColor();
}
