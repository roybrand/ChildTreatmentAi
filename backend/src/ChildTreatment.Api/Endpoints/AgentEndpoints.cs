using ChildTreatment.Api.Data;
using ChildTreatment.Api.Learning;
using ChildTreatment.Api.Onboarding;
using ChildTreatment.Api.Planning;
using Microsoft.EntityFrameworkCore;

namespace ChildTreatment.Api.Endpoints;

public sealed record InterviewMessageResponse(
    Guid Id, CoachingRole Role, CoachingMessageKind Kind, string Text, DateTimeOffset CreatedAt);
public sealed record InterviewResponse(string Opening, bool Complete, IEnumerable<InterviewMessageResponse> Messages);
public sealed record SendInterviewMessageRequest(string Text);
public sealed record UpdateProfileItemRequest(ProfileItemStatus Status, string? Text);
public sealed record LessonProgressRequest(int Step, bool Completed);
public sealed record PracticeAnswer(string? QuestionId, string? Answer);
public sealed record PracticeOutcome(bool GotIt);

/// <summary>The Profile Agent's interview and the Planner's weekly summary.</summary>
public static class AgentEndpoints
{
    private const int MaxTextLength = 4000;

    public static void MapAgentEndpoints(this IEndpointRouteBuilder app)
    {
        // The skill map and practice questions. No model is involved: questions and checks are code.
        var learning = app.MapGroup("/api").RequireAuthorization().RequireFamily();

        learning.MapGet("/curriculum", (Curriculum curriculum) => curriculum.File);

        learning.MapGet("/practice/{subtopicId}", (string subtopicId, int? count, Curriculum curriculum) =>
        {
            var questions = curriculum.Questions(subtopicId, Math.Clamp(count ?? 5, 1, 10), Random.Shared);
            return questions is null ? Results.NotFound() : Results.Ok(questions);
        });

        learning.MapPost("/practice/check", (PracticeAnswer answer, Curriculum curriculum) =>
        {
            var check = curriculum.Check(answer.QuestionId ?? "", answer.Answer);
            return check is null ? Results.NotFound() : Results.Ok(check);
        });

        var child = app.MapGroup("/api/children/{childId:guid}").RequireAuthorization().RequireFamily();

        var coaching = child.MapGroup("").RequireFamilyCoaching();

        child.MapGet("/profile/interview", async (Guid childId, AppDbContext db) =>
        {
            var profile = await db.Children.FirstOrDefaultAsync(c => c.Id == childId);
            if (profile is null)
                return Results.NotFound();

            var messages = await db.InterviewMessages
                .Where(m => m.ChildId == childId)
                .OrderByDescending(m => m.CreatedAt)
                .Take(100)
                .ToListAsync();
            messages.Reverse();

            return Results.Ok(new InterviewResponse(
                ProfileInterviewService.Opening(profile.Nickname),
                messages.Any(m => m.Completes),
                messages.Select(m => new InterviewMessageResponse(m.Id, m.Role, m.Kind, m.Text, m.CreatedAt))));
        });

        child.MapPost("/profile/interview/messages", async (
            Guid childId, SendInterviewMessageRequest request, ProfileInterviewService interview, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.Text) || request.Text.Length > MaxTextLength)
                return Results.Problem($"Text is required and may be up to {MaxTextLength} characters.", statusCode: 400);

            var reply = await interview.SendAsync(childId, request.Text.Trim(), ct);
            return reply is null ? Results.NotFound() : Results.Ok(reply);
        });

        // The parent accepts, rejects, or rewords a profile item. Rejected items are kept, hidden,
        // so the Profile Agent does not propose them again.
        child.MapPatch("/profile-items/{id:guid}", async (Guid childId, Guid id, UpdateProfileItemRequest request, AppDbContext db) =>
        {
            if (request.Status == ProfileItemStatus.Suggested)
                return Results.Problem("A parent can confirm or reject an item.", statusCode: 400);
            if (request.Text is not null && (string.IsNullOrWhiteSpace(request.Text) || request.Text.Length > MaxTextLength))
                return Results.Problem($"Text may be up to {MaxTextLength} characters.", statusCode: 400);

            var item = await db.ProfileItems.FirstOrDefaultAsync(i => i.Id == id && i.ChildId == childId);
            if (item is null)
                return Results.NotFound();

            item.Status = request.Status;
            if (request.Text is not null)
                item.Text = request.Text.Trim();
            await db.SaveChangesAsync();
            return Results.Ok(new ProfileItemResponse(item.Id, item.Section, item.Text, item.Status));
        });

        // Practice questions told as stories from the learner's world, where a question has a story.
        child.MapGet("/practice/{subtopicId}", async (
            Guid childId, string subtopicId, int? count, bool? easy, Curriculum curriculum, LessonService lessons,
            CancellationToken ct) =>
        {
            var world = await lessons.WorldAsync(childId, ct);
            if (world is null)
                return Results.NotFound();
            var questions = curriculum.Questions(
                subtopicId, Math.Clamp(count ?? 5, 1, 10), Random.Shared, Story.From(world.World, world.Items), easy ?? false);
            return questions is null ? Results.NotFound() : Results.Ok(questions);
        });

        // How one question went. It is kept so a sub-topic that did not go well can be brought back.
        child.MapPost("/practice/{subtopicId}/result", async (
            Guid childId, string subtopicId, PracticeOutcome outcome, Curriculum curriculum, AppDbContext db, TimeProvider time) =>
        {
            if (!curriculum.HasQuestions(subtopicId) || !await db.Children.AnyAsync(c => c.Id == childId))
                return Results.NotFound();

            db.PracticeRecords.Add(new PracticeRecord
            {
                Id = Guid.NewGuid(),
                ChildId = childId,
                SubtopicId = subtopicId,
                GotIt = outcome.GotIt,
                CreatedAt = time.GetUtcNow(),
            });
            await db.SaveChangesAsync();
            return Results.NoContent();
        });

        child.MapGet("/practice-progress", async (Guid childId, AppDbContext db, TimeProvider time) =>
        {
            var records = await db.PracticeRecords
                .Where(p => p.ChildId == childId)
                .OrderByDescending(p => p.CreatedAt)
                .Take(3000)
                .ToListAsync();
            return PracticeProgress.Of(records, time.GetUtcNow());
        });

        // Opening a lesson for the first time asks the Tutor to set it in the child's world.
        child.MapGet("/lessons/{lessonId}", async (
            Guid childId, string lessonId, bool? newWorld, LessonService lessons, CancellationToken ct) =>
        {
            var lesson = await lessons.GetAsync(childId, lessonId, newWorld ?? false, ct);
            return lesson is null ? Results.NotFound() : Results.Ok(lesson);
        });

        child.MapPut("/lessons/{lessonId}/progress", async (
            Guid childId, string lessonId, LessonProgressRequest request, LessonService lessons, CancellationToken ct) =>
        {
            if (request.Step is < 0 or > 100)
                return Results.Problem("Step is out of range.", statusCode: 400);
            var lesson = await lessons.SaveProgressAsync(childId, lessonId, request.Step, request.Completed, ct);
            return lesson is null ? Results.NotFound() : Results.Ok(lesson);
        });

        coaching.MapGet("/summaries", async (Guid childId, WeeklySummaryService summaries, CancellationToken ct) =>
            await summaries.ListAsync(childId, ct));

        coaching.MapPost("/summaries", async (Guid childId, WeeklySummaryService summaries, CancellationToken ct) =>
        {
            var result = await summaries.CreateAsync(childId, ct);
            return result is null ? Results.NotFound() : Results.Ok(result);
        });
    }
}
