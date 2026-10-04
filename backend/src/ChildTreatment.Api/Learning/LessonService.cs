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
        // A world written before the welcome page and the story questions existed lacks what they need,
        // so it is written once more.
        var incomplete = lesson is { FromTutor: true } && !lesson.World.Contains("\"items\"", StringComparison.Ordinal);
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
