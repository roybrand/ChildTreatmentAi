using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;

namespace ChildTreatment.Api.Learning;

/// <summary>Someone who lives in the learner's world, and greets and asks.</summary>
public sealed record GuidePerson(string Name, string Role, string Emoji);

/// <summary>An English word from the learner's world. Circle 1 is the heart of the world, 3 the wide world.</summary>
public sealed record GuideWord(string En, string He, string Emoji, string Sentence, int Circle);

/// <summary>The people of a learner's world, and its English words in three widening circles.</summary>
public sealed record WorldGuide(IReadOnlyList<GuidePerson> People, IReadOnlyList<GuideWord> Words)
{
    public const int Circles = 3;
    public const int WordsPerCircle = 6;

    /// <summary>Written by people. Used when the learner has no interests on file, or the model's guide cannot be used.</summary>
    public static readonly WorldGuide Default = new(
        [new("נועם", "הצייר של הסדנה", "🧑‍🎨"), new("רותי", "לקוחה קבועה", "👩"), new("יואב", "השליח", "🧑")],
        [
            new("paint", "צבע", "🎨", "The paint is on the table.", 1),
            new("brush", "מכחול", "🖌️", "I have a new brush.", 1),
            new("paper", "נייר", "📄", "The paper is white.", 1),
            new("pencil", "עיפרון", "✏️", "This is my pencil.", 1),
            new("picture", "תמונה", "🖼️", "The picture is on the wall.", 1),
            new("scissors", "מספריים", "✂️", "The scissors are in the box.", 1),
            new("shop", "חנות", "🏪", "The shop is open today.", 2),
            new("box", "קופסה", "📦", "The box is very big.", 2),
            new("money", "כסף", "💰", "I have some money.", 2),
            new("bag", "תיק", "👜", "My bag is on the chair.", 2),
            new("key", "מפתח", "🔑", "The key is in my bag.", 2),
            new("clock", "שעון", "🕒", "The clock is on the wall.", 2),
            new("friend", "חבר", "🤝", "My friend is at home.", 3),
            new("water", "מים", "💧", "I drink water every day.", 3),
            new("sun", "שמש", "☀️", "The sun is in the sky.", 3),
            new("house", "בית", "🏠", "This is my house.", 3),
            new("book", "ספר", "📖", "I read a book every week.", 3),
            new("music", "מוזיקה", "🎵", "I like this music.", 3),
        ]);
}

/// <summary>
/// Writes the people and the first English words of a learner's world. Its output is checked by code
/// and by the safety review before a learner sees it; when either fails, the built-in guide is used.
/// </summary>
public sealed partial class WorldGuideAgent(
    ILlmClient llm,
    PromptStore prompts,
    SafetyReviewer reviewer,
    ILogger<WorldGuideAgent> logger)
{
    public const string AgentName = "world-guide";

    private static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower };
    private static readonly Dictionary<string, JsonElement> Schema = BuildSchema();

    /// <returns>The guide, or null with the reason it cannot be used.</returns>
    public async Task<(WorldGuide? Guide, string? Reason)> BuildAsync(
        TutorContext context, LessonWorld world, CancellationToken ct = default)
    {
        var childContext = TutorAgent.FormatContext(context) +
                           $"\n<world name=\"{world.World}\" things=\"{world.Items}\" />";
        List<LlmMessage> messages = [new LlmMessage(LlmRole.User, "Write the people and the English words of this learner's world.")];
        var reason = "";

        for (var attempt = 1; attempt <= SafetyReviewer.MaxAttempts; attempt++)
        {
            var result = await llm.CompleteAsync(new LlmRequest
            {
                System = prompts.Get(AgentName).Text,
                Context = childContext,
                Messages = messages,
                JsonSchema = Schema,
                MaxTokens = 4000,
            }, ct);

            if (result.Refused || string.IsNullOrWhiteSpace(result.Text))
                return (null, "The model declined or returned nothing.");

            WorldGuide? guide;
            try
            {
                guide = JsonSerializer.Deserialize<WorldGuide>(result.Text, Json);
            }
            catch (JsonException ex)
            {
                logger.LogWarning(ex, "The world guide could not be read");
                return (null, "The model's output could not be read.");
            }
            if (guide is null)
                return (null, "The model's output was empty.");
            if (Validate(guide) is { } problem)
                return (null, problem);

            // Every word a learner reads passes the Safety Guard first.
            var review = await reviewer.ReviewAsync(childContext, "", FormatForReview(guide), ct, SafetyReviewer.LessonRules);
            if (review.Passed)
                return (guide, null);

            reason = review.Reason;
            messages = [.. messages, new LlmMessage(LlmRole.Assistant, result.Text), reviewer.RetryMessage(review)];
        }
        return (null, reason);
    }

    /// <returns>What is wrong with the guide, or null when code can use it.</returns>
    public static string? Validate(WorldGuide guide)
    {
        if (guide.People is not { Count: 3 } || guide.Words is null)
            return "There must be three people.";
        foreach (var person in guide.People)
        {
            if (person.Name is not { Length: >= 2 and <= 12 } || person.Name.Any(c => !IsHebrew(c)) ||
                person.Role is not { Length: >= 2 and <= 30 } || person.Role.Any(char.IsDigit) ||
                !IsSymbol(person.Emoji))
                return "A person's name, role, or symbol is not usable.";
        }

        for (var circle = 1; circle <= WorldGuide.Circles; circle++)
        {
            var words = guide.Words.Where(w => w.Circle == circle).ToList();
            if (words.Count != WorldGuide.WordsPerCircle)
                return $"Circle {circle} must hold {WorldGuide.WordsPerCircle} words.";
            // Within a circle a word is told apart by its picture and by its meaning.
            if (words.Select(w => w.Emoji).Distinct().Count() != words.Count ||
                words.Select(w => w.He).Distinct().Count() != words.Count)
                return $"Two words in circle {circle} share a picture or a meaning.";
        }
        if (guide.Words.Count != WorldGuide.Circles * WorldGuide.WordsPerCircle ||
            guide.Words.Select(w => w.En).Distinct().Count() != guide.Words.Count)
            return "A word appears twice, or is outside the three circles.";

        foreach (var word in guide.Words)
        {
            if (word.En is null || !EnglishWord().IsMatch(word.En))
                return "An English word is not plain lower-case letters.";
            if (word.He is not { Length: >= 1 and <= 25 } || !word.He.Any(IsHebrew) || word.He.Any(char.IsAsciiLetter))
                return "A Hebrew meaning is missing or not Hebrew.";
            if (!IsSymbol(word.Emoji))
                return "A word's picture is missing or is not a picture.";
            // The sentence is plain English that holds the word exactly once, so a gap can be cut in it.
            if (word.Sentence is null || !EnglishSentence().IsMatch(word.Sentence) ||
                Regex.Matches(word.Sentence, $@"\b{Regex.Escape(word.En)}\b", RegexOptions.IgnoreCase).Count != 1)
                return "A sentence is not plain English or does not hold its word exactly once.";
        }
        return null;
    }

    private static bool IsHebrew(char c) => c is (>= 'א' and <= 'ת') or ' ' or '\'' or '"' or '-';
    private static bool IsSymbol(string? s) => s is { Length: > 0 and <= 16 } && !s.Any(char.IsLetterOrDigit);

    public static string FormatForReview(WorldGuide guide)
    {
        var sb = new StringBuilder("People of the learner's world, and its first English words.\n");
        foreach (var p in guide.People)
            sb.AppendLine($"Person: {p.Name}, {p.Role} {p.Emoji}");
        foreach (var w in guide.Words)
            sb.AppendLine($"Word (circle {w.Circle}): {w.En} = {w.He} {w.Emoji} | {w.Sentence}");
        return sb.ToString().TrimEnd();
    }

    private static Dictionary<string, JsonElement> BuildSchema()
    {
        var text = new { type = "string" };
        object Item(object properties, string[] required) =>
            new { type = "array", items = new { type = "object", properties, required, additionalProperties = false } };
        return new Dictionary<string, JsonElement>
        {
            ["type"] = JsonSerializer.SerializeToElement("object"),
            ["properties"] = JsonSerializer.SerializeToElement(new
            {
                people = Item(new { name = text, role = text, emoji = text }, ["name", "role", "emoji"]),
                words = Item(
                    new { en = text, he = text, emoji = text, sentence = text, circle = new { type = "integer" } },
                    ["en", "he", "emoji", "sentence", "circle"]),
            }),
            ["required"] = JsonSerializer.SerializeToElement(new[] { "people", "words" }),
            ["additionalProperties"] = JsonSerializer.SerializeToElement(false),
        };
    }

    [GeneratedRegex("^[a-z]{2,14}( [a-z]{2,14})?$")]
    private static partial Regex EnglishWord();

    [GeneratedRegex(@"^[A-Za-z][A-Za-z ,']{6,70}[.!?]$")]
    private static partial Regex EnglishSentence();
}

/// <summary>
/// Questions about the words of a learner's world, made by code from the guide. Every one is a choice,
/// and the answer is the place of the right choice, so it is checked the same way as any other question.
/// </summary>
public static class WordQuestions
{
    public static Question Make(WorldGuide guide, int circle, int seed)
    {
        var r = new Random(seed);
        var words = guide.Words.Where(w => w.Circle == circle).ToList();
        var word = words[r.Next(words.Count)];
        // Two other words of the same circle to choose among, so the choice is between things met together.
        var others = words.Where(w => w != word).OrderBy(_ => r.Next()).Take(2).ToList();
        List<GuideWord> shown = [word, .. others];
        shown = [.. shown.OrderBy(_ => r.Next())];
        var place = shown.IndexOf(word);
        Line[] steps = [new Line($"{word.Emoji}  {word.He}", word.En), new Line("במשפט:", word.Sentence)];

        return r.Next(3) switch
        {
            // A picture, and its English word.
            0 => new Question(new Line("איך אומרים את זה באנגלית?", word.Emoji), place, steps,
                Choices: [.. shown.Select(w => w.En)]),
            // An English word, and its meaning.
            1 => new Question(new Line("מה פירוש המילה?", word.En), place, steps,
                Choices: [.. shown.Select(w => $"{w.Emoji} {w.He}")]),
            // A sentence with the word taken out.
            _ => new Question(
                new Line("בחרו את המילה שמשלימה את המשפט.",
                    Regex.Replace(word.Sentence, $@"\b{Regex.Escape(word.En)}\b", "___", RegexOptions.IgnoreCase)),
                place, steps, Choices: [.. shown.Select(w => w.En)]),
        };
    }
}
