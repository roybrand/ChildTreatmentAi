using ChildTreatment.Api.Data;
using ChildTreatment.Api.Onboarding;
using ChildTreatment.Api.Planning;
using Microsoft.EntityFrameworkCore;

namespace ChildTreatment.Api.Endpoints;

public sealed record InterviewMessageResponse(
    Guid Id, CoachingRole Role, CoachingMessageKind Kind, string Text, DateTimeOffset CreatedAt);
public sealed record InterviewResponse(string Opening, bool Complete, IEnumerable<InterviewMessageResponse> Messages);
public sealed record SendInterviewMessageRequest(string Text);
public sealed record UpdateProfileItemRequest(ProfileItemStatus Status, string? Text);

/// <summary>The Profile Agent's interview and the Planner's weekly summary.</summary>
public static class AgentEndpoints
{
    private const int MaxTextLength = 4000;

    public static void MapAgentEndpoints(this IEndpointRouteBuilder app)
    {
        var child = app.MapGroup("/api/children/{childId:guid}").RequireAuthorization().RequireFamily();

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

        child.MapGet("/summaries", async (Guid childId, WeeklySummaryService summaries, CancellationToken ct) =>
            await summaries.ListAsync(childId, ct));

        child.MapPost("/summaries", async (Guid childId, WeeklySummaryService summaries, CancellationToken ct) =>
        {
            var result = await summaries.CreateAsync(childId, ct);
            return result is null ? Results.NotFound() : Results.Ok(result);
        });
    }
}
