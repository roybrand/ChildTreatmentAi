using System.Text.Json;

namespace ChildTreatment.Api.Learning;

public sealed record CurriculumSource(string Title, string Publisher, string Url, string ReadOn);

/// <param name="Lesson">A hand-built lesson that teaches this sub-topic, when there is one.</param>
public sealed record Subtopic(string Id, string Title, string TitleEn, string? Generator, string? Lesson = null);

public sealed record Topic(
    string Id, string Domain, int Round, int Hours, string Title, string TitleEn, IReadOnlyList<Subtopic> Subtopics);

public sealed record GradeCurriculum(int Grade, string Name, int Hours, IReadOnlyList<Topic> Topics);

public sealed record CurriculumFile(string Subject, string Country, CurriculumSource Source, IReadOnlyList<GradeCurriculum> Grades);

/// <summary>A practice question as the app receives it. The id is enough to rebuild the question and check an answer.</summary>
/// <param name="Choices">When given, the learner picks one of these and sends back its place in the list, from 0.</param>
public sealed record PracticeQuestion(string Id, string Text, string? Math, IReadOnlyList<string>? Choices = null);

public sealed record PracticeCheck(
    bool Same, string Answer, IReadOnlyList<Line> Steps, Visual? Visual, IReadOnlyList<Line>? More);

/// <summary>
/// The skill map: the curriculum by grade, topic, and sub-topic, read from curriculum/math-il.json.
/// Each sub-topic names the code that makes its questions, so what is taught and what is checked
/// come from one record.
/// </summary>
public sealed class Curriculum
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower };

    private readonly Dictionary<string, Subtopic> _subtopics;

    /// <summary>One file per subject, mathematics first.</summary>
    public IReadOnlyList<CurriculumFile> Files { get; }

    /// <summary>The mathematics curriculum.</summary>
    public CurriculumFile File => Files[0];

    /// <param name="folder">The folder that holds the curriculum files, one per subject.</param>
    public Curriculum(string folder)
    {
        Files = Directory.GetFiles(folder, "*.json")
            .Select(path => JsonSerializer.Deserialize<CurriculumFile>(System.IO.File.ReadAllText(path), Json)
                            ?? throw new InvalidOperationException($"The curriculum file {path} is empty."))
            .OrderBy(file => file.Subject == "mathematics" ? 0 : 1).ThenBy(file => file.Subject)
            .ToList();
        _subtopics = Files.SelectMany(f => f.Grades).SelectMany(g => g.Topics).SelectMany(t => t.Subtopics)
            .ToDictionary(s => s.Id);
    }

    /// <summary>The curriculum files shipped with the application.</summary>
    public static Curriculum Load() => new(Path.Combine(AppContext.BaseDirectory, "curriculum"));

    /// <returns>Null when the sub-topic does not exist or has no questions yet.</returns>
    public IReadOnlyList<PracticeQuestion>? Questions(
        string subtopicId, int count, Random random, Story? story = null, bool easy = false)
    {
        if (!_subtopics.TryGetValue(subtopicId, out var subtopic) || subtopic.Generator is null)
            return null;

        var questions = new List<PracticeQuestion>();
        var seen = new HashSet<string>();
        // A few extra tries, so the same question is not handed out twice in one set.
        for (var attempt = 0; questions.Count < count && attempt < count * 5; attempt++)
        {
            var seed = random.Next();
            var question = QuestionBank.Make(subtopic.Generator, seed, story, easy);
            // An easy question says so in its id, so it is rebuilt as an easy one when its answer is checked.
            if (seen.Add(question.Ask.Text + question.Ask.Math))
                questions.Add(new PracticeQuestion($"{subtopicId}:{seed}{(easy ? ":e" : "")}", question.Ask.Text, question.Ask.Math, question.Choices));
        }
        return questions;
    }

    public bool HasQuestions(string subtopicId) =>
        _subtopics.TryGetValue(subtopicId, out var subtopic) && subtopic.Generator is not null;

    /// <summary>Checks an answer by rebuilding the question. The comparison is exact arithmetic, done by code.</summary>
    /// <returns>Null when the question id is not one this curriculum handed out.</returns>
    public PracticeCheck? Check(string questionId, string? answer)
    {
        var parts = questionId.Split(':');
        var easy = parts.Length == 3 && parts[2] == "e";
        if ((parts.Length != 2 && !easy) || !int.TryParse(parts[1], out var seed) ||
            !_subtopics.TryGetValue(parts[0], out var subtopic) || subtopic.Generator is null)
            return null;

        var question = QuestionBank.Make(subtopic.Generator, seed, easy: easy);
        var same = Rational.TryParse(answer, out var given) && given == question.Answer;
        return new PracticeCheck(same, question.Answer.ToString(), question.Steps, question.Visual, question.More);
    }
}
