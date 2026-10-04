using ChildTreatment.Api.Coaching;
using ChildTreatment.Api.Data;
using ChildTreatment.Api.Safety;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace ChildTreatment.Api.Endpoints;

public sealed record CreateChildRequest(string Nickname, int BirthYear);
public sealed record ChildResponse(Guid Id, string Nickname, int BirthYear, int Age, ChildMode Mode);

public sealed record CreateProfileItemRequest(ProfileSection Section, string Text);
public sealed record ProfileItemResponse(Guid Id, ProfileSection Section, string Text, ProfileItemStatus Status);

public sealed record CreateAccommodationRequest(string Description);
public sealed record UpdateAccommodationRequest(AccommodationStatus Status, string? PlannedChange);
public sealed record AccommodationResponse(Guid Id, string Description, AccommodationStatus Status, string? PlannedChange);

public sealed record CreateLogEntryRequest(
    DateOnly Date, string WhatHappened, string? ChildReaction, string? ParentResponse, int? ParentMood);
public sealed record LogEntryResponse(
    Guid Id, DateOnly Date, string WhatHappened, string? ChildReaction, string? ParentResponse, int? ParentMood);
public sealed record LogEntryCreated(LogEntryResponse Entry, CrisisNotice? Crisis);
public sealed record CrisisNotice(string Text, IReadOnlyList<CrisisContact> Contacts);

public sealed record SendCoachMessageRequest(string Text);
public sealed record CoachMessageResponse(
    Guid Id, CoachingRole Role, CoachingMessageKind Kind, string Text, DateTimeOffset CreatedAt);

public static class ChildEndpoints
{
    private const int MaxTextLength = 4000;
    private const int MinSchoolAge = 6;
    private const int MaxSchoolAge = 18;

    public static void MapChildEndpoints(this IEndpointRouteBuilder app)
    {
        var children = app.MapGroup("/api/children").RequireAuthorization().RequireFamily();

        children.MapPost("", async (CreateChildRequest request, AppDbContext db, TimeProvider time) =>
        {
            var now = time.GetUtcNow();
            var age = now.Year - request.BirthYear;
            if (string.IsNullOrWhiteSpace(request.Nickname) || request.Nickname.Length > 50)
                return Results.Problem("A nickname of up to 50 characters is required.", statusCode: 400);
            // The year alone leaves a year of slack either side of the school-age range.
            if (age < MinSchoolAge - 1 || age > MaxSchoolAge + 1)
                return Results.Problem("The app supports school-age children, 6 to 18.", statusCode: 400);

            var child = new ChildProfile
            {
                Id = Guid.NewGuid(),
                Nickname = request.Nickname.Trim(),
                BirthYear = request.BirthYear,
                CreatedAt = now,
            };
            db.Children.Add(child);
            await db.SaveChangesAsync();
            return Results.Created($"/api/children/{child.Id}", ToResponse(child, now.Year));
        });

        children.MapGet("", async (AppDbContext db, TimeProvider time) =>
        {
            var year = time.GetUtcNow().Year;
            var all = await db.Children.OrderBy(c => c.CreatedAt).ToListAsync();
            return all.Select(c => ToResponse(c, year));
        });

        var child = children.MapGroup("/{childId:guid}");
        // The parent coaching side exists only while that module is switched on.
        var coaching = child.MapGroup("").RequireFamilyCoaching();

        child.MapPost("/profile-items", async (
            Guid childId, CreateProfileItemRequest request, AppDbContext db, TimeProvider time, IOptions<FeatureOptions> features) =>
        {
            if (!IsValidText(request.Text))
                return TextProblem();
            // The tutor keeps no section about anxiety, diagnoses, or the family.
            if (!features.Value.ProfileSections.Contains(request.Section))
                return Results.Problem("This profile section is not in use.", statusCode: 400);
            if (!await ChildExists(db, childId))
                return Results.NotFound();

            // What a parent enters is confirmed. Only an agent's own observation starts as a suggestion.
            var item = new ProfileItem
            {
                Id = Guid.NewGuid(),
                ChildId = childId,
                Section = request.Section,
                Text = request.Text.Trim(),
                Status = ProfileItemStatus.Confirmed,
                CreatedAt = time.GetUtcNow(),
            };
            db.ProfileItems.Add(item);
            await db.SaveChangesAsync();
            return Results.Ok(new ProfileItemResponse(item.Id, item.Section, item.Text, item.Status));
        });

        child.MapGet("/profile-items", async (Guid childId, AppDbContext db, IOptions<FeatureOptions> features) =>
        {
            var items = await db.ProfileItems
                .Where(i => i.ChildId == childId && i.Status != ProfileItemStatus.Rejected)
                .OrderBy(i => i.Section).ThenBy(i => i.CreatedAt)
                .ToListAsync();
            return items
                .Where(i => features.Value.ProfileSections.Contains(i.Section))
                .Select(i => new ProfileItemResponse(i.Id, i.Section, i.Text, i.Status));
        });

        coaching.MapPost("/accommodations", async (Guid childId, CreateAccommodationRequest request, AppDbContext db, TimeProvider time) =>
        {
            if (!IsValidText(request.Description))
                return TextProblem();
            if (!await ChildExists(db, childId))
                return Results.NotFound();

            var accommodation = new Accommodation
            {
                Id = Guid.NewGuid(),
                ChildId = childId,
                Description = request.Description.Trim(),
                Status = AccommodationStatus.Active,
                CreatedAt = time.GetUtcNow(),
            };
            db.Accommodations.Add(accommodation);
            await db.SaveChangesAsync();
            return Results.Ok(ToResponse(accommodation));
        });

        coaching.MapGet("/accommodations", async (Guid childId, AppDbContext db) =>
        {
            var all = await db.Accommodations.Where(a => a.ChildId == childId).OrderBy(a => a.CreatedAt).ToListAsync();
            return all.Select(ToResponse);
        });

        coaching.MapPatch("/accommodations/{id:guid}", async (Guid childId, Guid id, UpdateAccommodationRequest request, AppDbContext db) =>
        {
            if (request.PlannedChange is { Length: > MaxTextLength })
                return TextProblem();

            var accommodation = await db.Accommodations.FirstOrDefaultAsync(a => a.Id == id && a.ChildId == childId);
            if (accommodation is null)
                return Results.NotFound();

            // One accommodation at a time: that is the method.
            if (request.Status == AccommodationStatus.Targeted &&
                await db.Accommodations.AnyAsync(a => a.ChildId == childId && a.Id != id && a.Status == AccommodationStatus.Targeted))
                return Results.Problem("Another accommodation is already the current target.", statusCode: 409);

            accommodation.Status = request.Status;
            accommodation.PlannedChange = request.PlannedChange?.Trim();
            await db.SaveChangesAsync();
            return Results.Ok(ToResponse(accommodation));
        });

        coaching.MapPost("/log", async (Guid childId, CreateLogEntryRequest request, AppDbContext db, CrisisRules rules, TimeProvider time) =>
        {
            if (!IsValidText(request.WhatHappened) ||
                request.ChildReaction is { Length: > MaxTextLength } ||
                request.ParentResponse is { Length: > MaxTextLength })
                return TextProblem();
            if (request.ParentMood is < 1 or > 5)
                return Results.Problem("Parent mood is a number from 1 to 5.", statusCode: 400);
            if (!await ChildExists(db, childId))
                return Results.NotFound();

            var now = time.GetUtcNow();
            var entry = new ParentLogEntry
            {
                Id = Guid.NewGuid(),
                ChildId = childId,
                Date = request.Date,
                WhatHappened = request.WhatHappened.Trim(),
                ChildReaction = request.ChildReaction?.Trim(),
                ParentResponse = request.ParentResponse?.Trim(),
                ParentMood = request.ParentMood,
                CreatedAt = now,
            };
            db.ParentLogEntries.Add(entry);

            // A log entry is free text from a person, so it gets the same rule check as a chat message.
            var hit = rules.Check(string.Join('\n', entry.WhatHappened, entry.ChildReaction, entry.ParentResponse));
            if (hit is not null)
            {
                db.SafetyEvents.Add(new SafetyEvent
                {
                    ChildId = childId,
                    Source = SafetySource.ParentLog,
                    Category = hit.Category,
                    RulesVersion = rules.Version,
                    CreatedAt = now,
                });
            }

            await db.SaveChangesAsync();
            return Results.Ok(new LogEntryCreated(
                ToResponse(entry),
                hit is null ? null : new CrisisNotice(SafetyTexts.Crisis, SafetyTexts.CrisisContacts)));
        });

        coaching.MapGet("/log", async (Guid childId, AppDbContext db) =>
        {
            var entries = await db.ParentLogEntries
                .Where(e => e.ChildId == childId)
                .OrderByDescending(e => e.Date).ThenByDescending(e => e.CreatedAt)
                .Take(60)
                .ToListAsync();
            return entries.Select(ToResponse);
        });

        coaching.MapPost("/coach/messages", async (Guid childId, SendCoachMessageRequest request, ParentCoachService coach, CancellationToken ct) =>
        {
            if (!IsValidText(request.Text))
                return TextProblem();

            var reply = await coach.SendAsync(childId, request.Text.Trim(), ct);
            return reply is null ? Results.NotFound() : Results.Ok(reply);
        });

        coaching.MapGet("/coach/messages", async (Guid childId, AppDbContext db) =>
        {
            var messages = await db.CoachingMessages
                .Where(m => m.ChildId == childId)
                .OrderByDescending(m => m.CreatedAt)
                .Take(100)
                .ToListAsync();
            messages.Reverse();
            return messages.Select(m => new CoachMessageResponse(m.Id, m.Role, m.Kind, m.Text, m.CreatedAt));
        });
    }

    private static bool IsValidText(string? text) =>
        !string.IsNullOrWhiteSpace(text) && text.Length <= MaxTextLength;

    private static IResult TextProblem() =>
        Results.Problem($"Text is required and may be up to {MaxTextLength} characters.", statusCode: 400);

    private static Task<bool> ChildExists(AppDbContext db, Guid childId) =>
        db.Children.AnyAsync(c => c.Id == childId);

    private static ChildResponse ToResponse(ChildProfile c, int year) =>
        new(c.Id, c.Nickname, c.BirthYear, c.AgeIn(year), c.ModeIn(year));

    private static AccommodationResponse ToResponse(Accommodation a) =>
        new(a.Id, a.Description, a.Status, a.PlannedChange);

    private static LogEntryResponse ToResponse(ParentLogEntry e) =>
        new(e.Id, e.Date, e.WhatHappened, e.ChildReaction, e.ParentResponse, e.ParentMood);
}
