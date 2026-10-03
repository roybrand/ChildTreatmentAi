using System.Text.RegularExpressions;

namespace ChildTreatment.Api.Llm;

/// <summary>
/// Replaces real names with placeholders before text goes to the LLM, and restores them in the reply.
/// It covers the names the app knows. Other names a parent types in free text are not detected.
/// </summary>
public sealed class Pseudonymizer
{
    public const string Child = "[CHILD]";
    public const string Parent = "[PARENT]";

    // Hebrew one-letter prefixes (and, that, to, in, from, the, as) attach to a name, up to three in a row.
    private const string HebrewPrefixes = "[ושלבמהכ]{0,3}";

    private readonly List<(Regex Pattern, string Placeholder, string Name)> _names = [];

    public Pseudonymizer(string? childName, string? parentName = null)
    {
        Add(childName, Child);
        Add(parentName, Parent);
    }

    private void Add(string? name, string placeholder)
    {
        name = name?.Trim();
        if (string.IsNullOrEmpty(name))
            return;

        // The name must stand as a word: letters may precede it only as Hebrew prefixes, and none may follow.
        var pattern = new Regex(
            $@"(?<!\p{{L}})({HebrewPrefixes}){Regex.Escape(name)}(?!\p{{L}})",
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        _names.Add((pattern, placeholder, name));
    }

    public string Hide(string? text)
    {
        if (string.IsNullOrEmpty(text))
            return text ?? "";

        foreach (var (pattern, placeholder, _) in _names)
            text = pattern.Replace(text, m => m.Groups[1].Value + placeholder);
        return text;
    }

    public string Restore(string? text)
    {
        if (string.IsNullOrEmpty(text))
            return text ?? "";

        foreach (var (_, placeholder, name) in _names)
            text = text.Replace(placeholder, name, StringComparison.Ordinal);
        return text;
    }
}
