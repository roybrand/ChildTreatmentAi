using ChildTreatment.Api.Data;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;
using Microsoft.EntityFrameworkCore;

namespace ChildTreatment.Api.Coaching;

public enum CoachReplyKind { Reply, Crisis, Fallback, Unavailable }

public sealed record CoachReply(CoachReplyKind Kind, string Text, IReadOnlyList<CrisisContact> Contacts);

/// <summary>Runs one coaching turn for a family: loads what the coach may see, hides names, stores the result.</summary>
public sealed class ParentCoachService(
    AppDbContext db,
    ParentCoachAgent agent,
    CrisisRules crisisRules,
    TimeProvider time,
    ILogger<ParentCoachService> logger)
{
    private const int HistoryMessages = 40;
    private const int LogEntries = 7;
    private static readonly TimeSpan SafetyNoteWindow = TimeSpan.FromDays(7);

    /// <returns>Null when the child does not exist in the current family.</returns>
    public async Task<CoachReply?> SendAsync(Guid childId, string text, CancellationToken ct = default)
    {
        var child = await db.Children.FirstOrDefaultAsync(c => c.Id == childId, ct);
        if (child is null)
            return null;

        var now = time.GetUtcNow();
        var names = new Pseudonymizer(child.Nickname);

        var history = await LoadHistoryAsync(childId, names, ct);
        var context = await BuildContextAsync(child, names, now, ct);

        // The parent's message is stored before the model is called, so it survives a failure.
        var parentMessage = new CoachingMessage
        {
            ChildId = childId,
            Role = CoachingRole.Parent,
            Kind = CoachingMessageKind.Normal,
            Text = text,
            CreatedAt = now,
        };
        db.CoachingMessages.Add(parentMessage);
        await db.SaveChangesAsync(ct);

        CoachOutcome outcome;
        try
        {
            outcome = await agent.RespondAsync(context, history, names.Hide(text), ct);
        }
        catch (LlmUnavailableException ex)
        {
            logger.LogWarning(ex, "The coach could not be reached");
            return new CoachReply(CoachReplyKind.Unavailable, SafetyTexts.Unavailable, []);
        }

        var reply = new CoachingMessage
        {
            ChildId = childId,
            Role = CoachingRole.Coach,
            PromptVersion = outcome.PromptVersion,
            CreatedAt = time.GetUtcNow(),
        };

        switch (outcome.Kind)
        {
            case CoachOutcomeKind.Crisis:
                // Kept out of later history: the coach is told a crisis screen was shown, not what was written.
                parentMessage.Kind = CoachingMessageKind.Crisis;
                reply.Kind = CoachingMessageKind.Crisis;
                reply.Text = outcome.Text;
                AddSafetyEvent(childId, SafetySource.CoachInput, outcome.CrisisCategory!);
                break;

            case CoachOutcomeKind.Fallback:
                logger.LogWarning("A coach reply was withheld: {Reason}", outcome.BlockReason);
                reply.Kind = CoachingMessageKind.Fallback;
                reply.Text = outcome.Text;
                AddSafetyEvent(childId, SafetySource.CoachOutput, "reply_withheld");
                break;

            default:
                reply.Kind = CoachingMessageKind.Normal;
                reply.Text = names.Restore(outcome.Text);
                break;
        }

        db.CoachingMessages.Add(reply);
        await db.SaveChangesAsync(ct);

        return outcome.Kind switch
        {
            CoachOutcomeKind.Crisis => new CoachReply(CoachReplyKind.Crisis, reply.Text, SafetyTexts.CrisisContacts),
            CoachOutcomeKind.Fallback => new CoachReply(CoachReplyKind.Fallback, reply.Text, []),
            _ => new CoachReply(CoachReplyKind.Reply, reply.Text, []),
        };
    }

    private void AddSafetyEvent(Guid childId, SafetySource source, string category) =>
        db.SafetyEvents.Add(new SafetyEvent
        {
            ChildId = childId,
            Source = source,
            Category = category,
            RulesVersion = crisisRules.Version,
            CreatedAt = time.GetUtcNow(),
        });

    private async Task<List<LlmMessage>> LoadHistoryAsync(Guid childId, Pseudonymizer names, CancellationToken ct)
    {
        var recent = await db.CoachingMessages
            .Where(m => m.ChildId == childId && m.Kind == CoachingMessageKind.Normal)
            .OrderByDescending(m => m.CreatedAt)
            .Take(HistoryMessages)
            .ToListAsync(ct);

        recent.Reverse();
        return recent
            .Select(m => new LlmMessage(
                m.Role == CoachingRole.Parent ? LlmRole.User : LlmRole.Assistant,
                names.Hide(m.Text)))
            .ToList();
    }

    private async Task<CoachContext> BuildContextAsync(
        ChildProfile child, Pseudonymizer names, DateTimeOffset now, CancellationToken ct)
    {
        // Only what the parent confirmed is given to the coach as fact.
        var profile = await db.ProfileItems
            .Where(i => i.ChildId == child.Id && i.Status == ProfileItemStatus.Confirmed)
            .OrderBy(i => i.Section).ThenBy(i => i.CreatedAt)
            .ToListAsync(ct);

        var accommodations = await db.Accommodations
            .Where(a => a.ChildId == child.Id)
            .OrderBy(a => a.CreatedAt)
            .ToListAsync(ct);

        var log = await db.ParentLogEntries
            .Where(e => e.ChildId == child.Id)
            .OrderByDescending(e => e.Date).ThenByDescending(e => e.CreatedAt)
            .Take(LogEntries)
            .ToListAsync(ct);
        log.Reverse();

        var since = now - SafetyNoteWindow;
        var lastCrisis = await db.SafetyEvents
            .Where(e => e.ChildId == child.Id && e.Source != SafetySource.CoachOutput && e.CreatedAt >= since)
            .OrderByDescending(e => e.CreatedAt)
            .FirstOrDefaultAsync(ct);

        return new CoachContext
        {
            Age = child.AgeIn(now.Year),
            Profile = profile.Select(i => $"{i.Section}: {names.Hide(i.Text)}").ToList(),
            Accommodations = accommodations
                .Select(a => new CoachAccommodation(
                    names.Hide(a.Description), a.Status.ToString(), a.PlannedChange is null ? null : names.Hide(a.PlannedChange)))
                .ToList(),
            Log = log.Select(e => FormatLogEntry(e, names)).ToList(),
            SafetyNote = lastCrisis is null
                ? null
                : $"The app's crisis screen with emergency contacts was shown to the parent on {lastCrisis.CreatedAt:yyyy-MM-dd} " +
                  $"(category: {lastCrisis.Category}). The text that triggered it is not included here.",
        };
    }

    private static string FormatLogEntry(ParentLogEntry entry, Pseudonymizer names)
    {
        var parts = new List<string> { $"{entry.Date:yyyy-MM-dd}: {names.Hide(entry.WhatHappened)}" };
        if (!string.IsNullOrWhiteSpace(entry.ChildReaction))
            parts.Add($"child's reaction: {names.Hide(entry.ChildReaction)}");
        if (!string.IsNullOrWhiteSpace(entry.ParentResponse))
            parts.Add($"parent's response: {names.Hide(entry.ParentResponse)}");
        if (entry.ParentMood is { } mood)
            parts.Add($"parent's mood: {mood}/5");
        return string.Join(" | ", parts);
    }
}
