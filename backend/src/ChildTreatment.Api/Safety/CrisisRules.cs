using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace ChildTreatment.Api.Safety;

public sealed record CrisisHit(string Category);

/// <summary>
/// Rule-based crisis detection. Runs in code on every message from a person, before any agent sees it.
/// The phrase list lives in prompts/safety/crisis-rules.json so a clinician can review it.
/// </summary>
public sealed class CrisisRules
{
    private readonly List<(string Category, List<Regex> Patterns)> _categories = [];

    public string Version { get; }

    public CrisisRules(string json)
    {
        using var doc = JsonDocument.Parse(json);
        Version = doc.RootElement.GetProperty("version").GetString()!;

        foreach (var category in doc.RootElement.GetProperty("categories").EnumerateArray())
        {
            var patterns = category.GetProperty("phrases").EnumerateArray()
                .Select(p => ToPattern(Normalize(p.GetString()!)))
                .ToList();
            _categories.Add((category.GetProperty("id").GetString()!, patterns));
        }
    }

    public static CrisisRules Load(string promptsRoot) =>
        new(File.ReadAllText(Path.Combine(promptsRoot, "safety", "crisis-rules.json")));

    public CrisisHit? Check(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return null;

        var normalized = Normalize(text);
        foreach (var (category, patterns) in _categories)
        {
            if (patterns.Any(p => p.IsMatch(normalized)))
                return new CrisisHit(category);
        }
        return null;
    }

    // English phrases match whole words, so "stab" does not match "stable".
    // Hebrew phrases match anywhere, because prefixes and suffixes attach to the word.
    private static Regex ToPattern(string phrase)
    {
        var escaped = Regex.Escape(phrase);
        var isLatin = phrase.Any(c => c is >= 'a' and <= 'z');
        var pattern = isLatin ? $"(?<![a-z]){escaped}(?![a-z])" : escaped;
        return new Regex(pattern, RegexOptions.Compiled | RegexOptions.CultureInvariant);
    }

    /// <summary>Lower case, Hebrew vowel marks removed, apostrophe variants unified, whitespace collapsed.</summary>
    public static string Normalize(string text)
    {
        var sb = new StringBuilder(text.Length);
        var lastWasSpace = false;

        foreach (var raw in text)
        {
            // Hebrew cantillation and vowel marks.
            if (raw is >= '֑' and <= 'ׇ')
                continue;

            var c = raw switch
            {
                '’' or '‘' or '׳' or '`' => '\'',
                _ => char.ToLowerInvariant(raw),
            };

            if (char.IsWhiteSpace(c))
            {
                if (!lastWasSpace)
                    sb.Append(' ');
                lastWasSpace = true;
            }
            else
            {
                sb.Append(c);
                lastWasSpace = false;
            }
        }

        return sb.ToString().Trim();
    }
}
