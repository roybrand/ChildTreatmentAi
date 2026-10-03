namespace ChildTreatment.Api.Llm;

public sealed record Prompt(string Version, string Text);

public sealed class PromptOptions
{
    /// <summary>Folder that holds the prompt files. Relative paths resolve from the application folder.</summary>
    public string Root { get; set; } = "prompts";
    /// <summary>Agent name to the version in use, for example "parent-coach": "v1".</summary>
    public Dictionary<string, string> Versions { get; set; } = new()
    {
        ["parent-coach"] = "v2",
        ["profile-agent"] = "v1",
        ["planner"] = "v2",
        ["safety-review"] = "v2",
        ["summary-review"] = "v1",
        ["review-retry"] = "v1",
        ["tutor"] = "v1",
        ["lesson-review"] = "v1",
    };
}

/// <summary>
/// Loads agent prompts from versioned files, so every model output can be traced to the prompt that produced it.
/// </summary>
public sealed class PromptStore
{
    private readonly Dictionary<string, Prompt> _prompts = [];

    public string Root { get; }

    public PromptStore(PromptOptions options)
    {
        Root = Path.IsPathRooted(options.Root)
            ? options.Root
            : Path.Combine(AppContext.BaseDirectory, options.Root);

        foreach (var (agent, version) in options.Versions)
        {
            var path = Path.Combine(Root, agent, $"{version}.md");
            _prompts[agent] = new Prompt($"{agent}/{version}", File.ReadAllText(path));
        }
    }

    public Prompt Get(string agent) =>
        _prompts.TryGetValue(agent, out var prompt)
            ? prompt
            : throw new InvalidOperationException($"No prompt version is configured for agent '{agent}'.");
}
