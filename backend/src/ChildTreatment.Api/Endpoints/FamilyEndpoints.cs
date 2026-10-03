using System.Security.Claims;
using ChildTreatment.Api.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace ChildTreatment.Api.Endpoints;

public sealed record ConsentRequest(bool Accepted, string ConsentVersion);
public sealed record FamilyResponse(Guid Id, DateTimeOffset ConsentGivenAt, string ConsentVersion);

public static class FamilyEndpoints
{
    public static void MapFamilyEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/family").RequireAuthorization();

        // Nothing about a child is stored until a parent has given explicit consent.
        group.MapPost("/consent", async (
            ConsentRequest request, ClaimsPrincipal principal, UserManager<AppUser> users,
            AppDbContext db, CurrentFamily current, TimeProvider time) =>
        {
            if (!request.Accepted || string.IsNullOrWhiteSpace(request.ConsentVersion))
                return Results.Problem("Consent must be accepted to continue.", statusCode: 400);

            var user = await users.GetUserAsync(principal);
            if (user is null)
                return Results.Unauthorized();

            if (user.FamilyId is { } existingId)
            {
                var existing = await db.Families.FirstAsync(f => f.Id == existingId);
                return Results.Ok(new FamilyResponse(existing.Id, existing.ConsentGivenAt, existing.ConsentVersion));
            }

            var now = time.GetUtcNow();
            var family = new Family
            {
                Id = Guid.NewGuid(),
                CreatedAt = now,
                ConsentGivenAt = now,
                ConsentVersion = request.ConsentVersion,
            };
            db.Families.Add(family);
            await db.SaveChangesAsync();

            user.FamilyId = family.Id;
            await users.UpdateAsync(user);
            current.FamilyId = family.Id;

            return Results.Ok(new FamilyResponse(family.Id, family.ConsentGivenAt, family.ConsentVersion));
        });

        var owned = group.MapGroup("").RequireFamily();

        // A family can take everything the app holds about it.
        owned.MapGet("/export", async (AppDbContext db, CurrentFamily current) =>
        {
            var family = await db.Families.FirstAsync(f => f.Id == current.FamilyId);
            return Results.Ok(new
            {
                family = new FamilyResponse(family.Id, family.ConsentGivenAt, family.ConsentVersion),
                children = await db.Children.ToListAsync(),
                profileItems = await db.ProfileItems.ToListAsync(),
                accommodations = await db.Accommodations.ToListAsync(),
                log = await db.ParentLogEntries.ToListAsync(),
                coaching = await db.CoachingMessages.OrderBy(m => m.CreatedAt).ToListAsync(),
                interview = await db.InterviewMessages.OrderBy(m => m.CreatedAt).ToListAsync(),
                weeklySummaries = await db.WeeklySummaries.OrderBy(s => s.CreatedAt).ToListAsync(),
                safetyEvents = await db.SafetyEvents.ToListAsync(),
            });
        });

        // A family can leave. Deleting the family row removes every row that belongs to it.
        owned.MapDelete("", async (AppDbContext db, CurrentFamily current, UserManager<AppUser> users) =>
        {
            var familyId = current.FamilyId!.Value;
            foreach (var member in await db.Users.Where(u => u.FamilyId == familyId).ToListAsync())
                await users.DeleteAsync(member);

            await db.Families.Where(f => f.Id == familyId).ExecuteDeleteAsync();
            return Results.NoContent();
        });
    }

    /// <summary>Refuses the request unless the signed-in parent has a family, which exists only after consent.</summary>
    public static RouteGroupBuilder RequireFamily(this RouteGroupBuilder group)
    {
        group.AddEndpointFilter(async (context, next) =>
        {
            var current = context.HttpContext.RequestServices.GetRequiredService<CurrentFamily>();
            if (current.FamilyId is null)
                return Results.Problem("Consent is required before using the app.", statusCode: 409, title: "consent_required");
            return await next(context);
        });
        return group;
    }
}
