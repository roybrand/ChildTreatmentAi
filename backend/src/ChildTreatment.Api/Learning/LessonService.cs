using System.Text.Json;
using ChildTreatment.Api.Data;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;
using Microsoft.EntityFrameworkCore;

namespace ChildTreatment.Api.Learning;

public sealed record LessonView(
    string LessonId, LessonWorld World, bool FromTutor, int StepReached, bool Completed);

/// <summary>Gives a child their lesson: the world it is set in, made once and kept, and their progress.</summary>
public sealed class LessonService(
    AppDbContext db,
    TutorAgent tutor,
    WorldGuideAgent guideAgent,
    PromptStore prompts,
    CrisisRules crisisRules,
    TimeProvider time,
    ILogger<LessonService> logger)
{
    /// <summary>Fractions with the Mixer: the first lesson. See docs/TUTOR_LESSONS.md.</summary>
    public const string FractionsMixer = "fractions-mixer-1";

    public static readonly IReadOnlySet<string> Lessons = new HashSet<string> { FractionsMixer };

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    /// <param name="newWorld">Ask the Tutor for a world again, for example after the profile changed.</param>
    /// <returns>Null when the child or the lesson does not exist.</returns>
    public async Task<LessonView?> GetAsync(Guid childId, string lessonId, bool newWorld = false, CancellationToken ct = default)
    {
        if (!Lessons.Contains(lessonId))
            return null;
        var child = await db.Children.FirstOrDefaultAsync(c => c.Id == childId, ct);
        if (child is null)
            return null;

        var lesson = await db.ChildLessons.FirstOrDefaultAsync(l => l.ChildId == childId && l.LessonId == lessonId, ct);
        // A lesson that opened in the built-in world before the Tutor was ever asked, because the profile
        // had no interests yet, gets its own world once there is something to build one from.
        var neverAsked = lesson is { FromTutor: false, PromptVersion: null } && await HasInterestsAsync(childId, ct);
        // A world written by an earlier version of the Tutor's prompt is written once more by the current
        // one. Only once: the new world carries the current version, whether or not the Tutor's text was used.
        var incomplete = lesson is { FromTutor: true } && lesson.PromptVersion != prompts.Get(TutorAgent.AgentName).Version;
        if (lesson is not null && !newWorld && !neverAsked && !incomplete)
            return ToView(lesson);

        var now = time.GetUtcNow();
        var (world, fromTutor, promptVersion) = await BuildWorldAsync(child, now, ct);

        if (lesson is null)
        {
            lesson = new ChildLesson { Id = Guid.NewGuid(), ChildId = childId, LessonId = lessonId, CreatedAt = now };
            db.ChildLessons.Add(lesson);
        }
        lesson.World = JsonSerializer.Serialize(world, Json);
        lesson.FromTutor = fromTutor;
        lesson.PromptVersion = promptVersion;
        // A new world is a new story, so the lesson starts from its first step.
        lesson.StepReached = 0;
        lesson.CompletedAt = null;
        await db.SaveChangesAsync(ct);
        return ToView(lesson);
    }

    /// <summary>
    /// The world the learner's lessons are set in, for the welcome page and for practice questions.
    /// It never calls the model: before a lesson has been opened it is the built-in world.
    /// </summary>
    /// <returns>Null when the child does not exist in the current family.</returns>
    public async Task<LessonWorld?> WorldAsync(Guid childId, CancellationToken ct = default)
    {
        if (!await db.Children.AnyAsync(c => c.Id == childId, ct))
            return null;
        var lesson = await db.ChildLessons.FirstOrDefaultAsync(l => l.ChildId == childId && l.LessonId == FractionsMixer, ct);
        return lesson is null ? LessonWorld.Default : ToView(lesson).World;
    }

    /// <summary>Where the people and the English words of a learner's world are kept, beside their lessons.</summary>
    public const string WorldGuideId = "world-guide";

    /// <summary>The practice records of a circle of words are kept under this name and the circle's number.</summary>
    public const string WordsPrefix = "en-words-";

    /// <summary>How many words of a circle a learner gets on their own before the next circle opens.</summary>
    public const int ToOpenNextCircle = 8;

    /// <summary>
    /// The people and the English words of the learner's world. Written once and kept; the first time, for
    /// a learner with interests on file, this asks the model. Otherwise the built-in guide is used.
    /// </summary>
    /// <returns>Null when the child does not exist in the current family.</returns>
    public async Task<WorldGuide?> GuideAsync(Guid childId, CancellationToken ct = default)
    {
        var child = await db.Children.FirstOrDefaultAsync(c => c.Id == childId, ct);
        if (child is null)
            return null;

        var version = prompts.Get(WorldGuideAgent.AgentName).Version;
        var stored = await db.ChildLessons.FirstOrDefaultAsync(l => l.ChildId == childId && l.LessonId == WorldGuideId, ct);
        var hasInterests = await HasInterestsAsync(childId, ct);
        // Written again only when it was never asked for and now can be, or when the prompt has a new version.
        var stale = stored is null ||
                    (stored.FromTutor && stored.PromptVersion != version) ||
                    (stored is { FromTutor: false, PromptVersion: null } && hasInterests);
        if (!stale)
            return stored!.FromTutor ? JsonSerializer.Deserialize<WorldGuide>(stored.World, Json)! : WorldGuide.Default;

        var now = time.GetUtcNow();
        WorldGuide guide = WorldGuide.Default;
        var fromModel = false;
        string? promptVersion = null;
        if (hasInterests)
        {
            promptVersion = version;
            var names = new Pseudonymizer(child.Nickname);
            var interests = await db.ProfileItems
                .Where(i => i.ChildId == childId && i.Status == ProfileItemStatus.Confirmed &&
                            i.Section == ProfileSection.StrengthsAndInterests)
                .OrderBy(i => i.CreatedAt).ToListAsync(ct);
            var context = new TutorContext
            {
                Age = child.AgeIn(now.Year),
                Interests = interests.Select(i => names.Hide(i.Text)).ToList(),
            };
            try
            {
                // The people and the words belong to the world of the lessons, so that world is settled first.
                var world = (await GetAsync(childId, FractionsMixer, ct: ct))!.World;
                var (written, reason) = await guideAgent.BuildAsync(context, world, ct);
                if (written is not null)
                {
                    (guide, fromModel) = (written, true);
                }
                else
                {
                    logger.LogWarning("The world guide was not used: {Reason}", reason);
                    db.SafetyEvents.Add(new SafetyEvent
                    {
                        ChildId = childId,
                        Source = SafetySource.LessonOutput,
                        Category = "guide_withheld",
                        RulesVersion = crisisRules.Version,
                        CreatedAt = now,
                    });
                }
            }
            catch (LlmUnavailableException ex)
            {
                // The built-in guide is used now, and the model is asked again next time.
                logger.LogWarning(ex, "The world guide could not be written");
                promptVersion = null;
            }
        }

        if (stored is null)
        {
            stored = new ChildLesson { Id = Guid.NewGuid(), ChildId = childId, LessonId = WorldGuideId, CreatedAt = now };
            db.ChildLessons.Add(stored);
        }
        stored.World = JsonSerializer.Serialize(guide, Json);
        stored.FromTutor = fromModel;
        stored.PromptVersion = promptVersion;
        await db.SaveChangesAsync(ct);
        return guide;
    }

    /// <summary>
    /// The widest circle of words open to the learner. A circle opens when the one before it has settled:
    /// enough words got without help, and the latest ones going well. A circle the learner has already
    /// played in stays open whatever happens later, and none of this is shown to the learner as a score.
    /// </summary>
    public async Task<int> OpenCircleAsync(Guid childId, CancellationToken ct = default)
    {
        var records = await db.PracticeRecords
            .Where(p => p.ChildId == childId && p.SubtopicId.StartsWith(WordsPrefix))
            .ToListAsync(ct);
        var progress = PracticeProgress.Of(records, time.GetUtcNow()).ToDictionary(p => p.SubtopicId);
        var open = 1;
        while (open < WorldGuide.Circles &&
               progress.TryGetValue($"{WordsPrefix}{open}", out var circle) &&
               circle.GotIt >= ToOpenNextCircle && !circle.ComeBack)
            open++;
        // Nothing that was opened is closed again.
        while (open < WorldGuide.Circles && progress.ContainsKey($"{WordsPrefix}{open + 1}"))
            open++;
        return open;
    }

    private Task<bool> HasInterestsAsync(Guid childId, CancellationToken ct) =>
        db.ProfileItems.AnyAsync(i => i.ChildId == childId && i.Status == ProfileItemStatus.Confirmed &&
                                      i.Section == ProfileSection.StrengthsAndInterests, ct);

    /// <returns>Null when the lesson has not been opened for this child.</returns>
    public async Task<LessonView?> SaveProgressAsync(
        Guid childId, string lessonId, int step, bool completed, CancellationToken ct = default)
    {
        var lesson = await db.ChildLessons.FirstOrDefaultAsync(l => l.ChildId == childId && l.LessonId == lessonId, ct);
        if (lesson is null)
            return null;

        // The step is where the learner is now, so the lesson resumes there, also after going back or starting again.
        lesson.StepReached = step;
        if (completed)
            lesson.CompletedAt ??= time.GetUtcNow();
        await db.SaveChangesAsync(ct);
        return ToView(lesson);
    }

    private async Task<(LessonWorld World, bool FromTutor, string? PromptVersion)> BuildWorldAsync(
        ChildProfile child, DateTimeOffset now, CancellationToken ct)
    {
        // Only what the parent confirmed is given to the Tutor.
        var items = await db.ProfileItems
            .Where(i => i.ChildId == child.Id && i.Status == ProfileItemStatus.Confirmed &&
                        (i.Section == ProfileSection.StrengthsAndInterests || i.Section == ProfileSection.LearningPicture))
            .OrderBy(i => i.CreatedAt)
            .ToListAsync(ct);

        var names = new Pseudonymizer(child.Nickname);
        var interests = items.Where(i => i.Section == ProfileSection.StrengthsAndInterests).Select(i => names.Hide(i.Text)).ToList();

        // With nothing to build a world from, the built-in one is used and the model is not called.
        if (interests.Count == 0)
            return (LessonWorld.Default, false, null);

        var context = new TutorContext
        {
            Age = child.AgeIn(now.Year),
            Interests = interests,
            Learning = items.Where(i => i.Section == ProfileSection.LearningPicture).Select(i => names.Hide(i.Text)).ToList(),
        };

        try
        {
            var outcome = await tutor.BuildWorldAsync(context, ct);
            if (outcome.World is not null)
            {
                logger.LogInformation("The Tutor set the lesson in a world. Link: {Link}", outcome.Link);
                return (outcome.World, true, outcome.PromptVersion);
            }

            logger.LogWarning("The Tutor's world was not used: {Reason}", outcome.BlockReason);
            db.SafetyEvents.Add(new SafetyEvent
            {
                ChildId = child.Id,
                Source = SafetySource.LessonOutput,
                Category = "world_withheld",
                RulesVersion = crisisRules.Version,
                CreatedAt = now,
            });
            return (LessonWorld.Default, false, outcome.PromptVersion);
        }
        catch (LlmUnavailableException ex)
        {
            // The lesson still runs: a child should never meet an error screen because a model is down.
            logger.LogWarning(ex, "The Tutor could not be reached");
            return (LessonWorld.Default, false, null);
        }
    }

    private static LessonView ToView(ChildLesson lesson) => new(
        lesson.LessonId,
        // The built-in world is read from code, so an improvement to it reaches lessons already opened.
        lesson.FromTutor ? JsonSerializer.Deserialize<LessonWorld>(lesson.World, Json)!.Complete() : LessonWorld.Default,
        lesson.FromTutor,
        lesson.StepReached,
        lesson.CompletedAt is not null);
}
