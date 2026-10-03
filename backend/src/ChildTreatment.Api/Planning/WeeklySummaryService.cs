using System.Text.Json;
using ChildTreatment.Api.Coaching;
using ChildTreatment.Api.Data;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;
using Microsoft.EntityFrameworkCore;

namespace ChildTreatment.Api.Planning;

public enum SummaryResultKind
{
    Created,
    /// <summary>A summary was already written today; it is returned and the model is not called again.</summary>
    Existing,
    /// <summary>Too few log entries this week to say anything honest.</summary>
    NotEnoughLog,
    /// <summary>The summary was withheld by the safety review.</summary>
    Fallback,
    Unavailable,
}

public sealed record WeeklySummaryView(
    Guid Id,
    DateOnly WeekStart,
    DateOnly WeekEnd,
    WeeklySummaryContent Content,
    int LogEntries,
    double? MoodAverage,
    double? PreviousMoodAverage,
    DateTimeOffset CreatedAt);

public sealed record SummaryResult(SummaryResultKind Kind, string? Text, WeeklySummaryView? Summary);

/// <summary>Writes the weekly summary for one child from the last seven days of the parent's log.</summary>
public sealed class WeeklySummaryService(
    AppDbContext db,
    WeeklySummaryAgent agent,
    CrisisRules crisisRules,
    TimeProvider time,
    ILogger<WeeklySummaryService> logger)
{
    public const int MinLogEntries = 2;
    private const int WeekDays = 7;

    public const string NotEnoughLogText =
        "אין עדיין מספיק רשומות ביומן כדי לסכם את השבוע. שתי רשומות קצרות מספיקות.";
    public const string WithheldText =
        "לא הצלחנו להכין סיכום טוב לשבוע הזה. אפשר לנסות שוב מחר, ובינתיים היומן והמאמן זמינים כרגיל.";

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    /// <returns>Null when the child does not exist in the current family.</returns>
    public async Task<SummaryResult?> CreateAsync(Guid childId, CancellationToken ct = default)
    {
        var child = await db.Children.FirstOrDefaultAsync(c => c.Id == childId, ct);
        if (child is null)
            return null;

        var now = time.GetUtcNow();
        var weekEnd = DateOnly.FromDateTime(now.UtcDateTime);
        var weekStart = weekEnd.AddDays(-(WeekDays - 1));

        // One summary a day at most: each one is two model calls.
        var latest = await db.WeeklySummaries
            .Where(s => s.ChildId == childId)
            .OrderByDescending(s => s.CreatedAt)
            .FirstOrDefaultAsync(ct);
        if (latest is not null && latest.WeekEnd == weekEnd)
            return new SummaryResult(SummaryResultKind.Existing, null, ToView(latest));

        var previousStart = weekStart.AddDays(-WeekDays);
        var entries = await db.ParentLogEntries
            .Where(e => e.ChildId == childId && e.Date >= previousStart && e.Date <= weekEnd)
            .OrderBy(e => e.Date).ThenBy(e => e.CreatedAt)
            .ToListAsync(ct);
        var thisWeek = entries.Where(e => e.Date >= weekStart).ToList();
        if (thisWeek.Count < MinLogEntries)
            return new SummaryResult(SummaryResultKind.NotEnoughLog, NotEnoughLogText, null);

        var facts = new WeekFacts(
            thisWeek.Count,
            Average(thisWeek),
            Average(entries.Where(e => e.Date < weekStart).ToList()));

        var names = new Pseudonymizer(child.Nickname);
        var context = await BuildContextAsync(child, names, thisWeek, facts, now, ct);

        SummaryOutcome outcome;
        try
        {
            outcome = await agent.SummarizeAsync(context, ct);
        }
        catch (LlmUnavailableException ex)
        {
            logger.LogWarning(ex, "The Planner could not be reached");
            return new SummaryResult(SummaryResultKind.Unavailable, SafetyTexts.Unavailable, null);
        }

        if (outcome.Kind == SummaryOutcomeKind.Fallback)
        {
            logger.LogWarning("A weekly summary was withheld: {Reason}", outcome.BlockReason);
            db.SafetyEvents.Add(new SafetyEvent
            {
                ChildId = childId,
                Source = SafetySource.WeeklySummaryOutput,
                Category = "summary_withheld",
                RulesVersion = crisisRules.Version,
                CreatedAt = now,
            });
            await db.SaveChangesAsync(ct);
            return new SummaryResult(SummaryResultKind.Fallback, WithheldText, null);
        }

        var written = outcome.Content!;
        var content = new WeeklySummaryContent(
            names.Restore(written.WhatHappened),
            written.Patterns.Select(p => p with { Text = names.Restore(p.Text) }).ToList(),
            written.WhatWorked.Select(names.Restore).ToList(),
            names.Restore(written.Proposal));

        var summary = new WeeklySummary
        {
            Id = Guid.NewGuid(),
            ChildId = childId,
            WeekStart = weekStart,
            WeekEnd = weekEnd,
            Content = JsonSerializer.Serialize(content, Json),
            LogEntries = facts.LogEntries,
            MoodAverage = facts.MoodAverage,
            PreviousMoodAverage = facts.PreviousMoodAverage,
            PromptVersion = outcome.PromptVersion,
            CreatedAt = now,
        };
        db.WeeklySummaries.Add(summary);
        await db.SaveChangesAsync(ct);

        return new SummaryResult(SummaryResultKind.Created, null, ToView(summary));
    }

    public async Task<List<WeeklySummaryView>> ListAsync(Guid childId, CancellationToken ct = default)
    {
        var summaries = await db.WeeklySummaries
            .Where(s => s.ChildId == childId)
            .OrderByDescending(s => s.CreatedAt)
            .Take(12)
            .ToListAsync(ct);
        return summaries.Select(ToView).ToList();
    }

    private static WeeklySummaryView ToView(WeeklySummary s) => new(
        s.Id, s.WeekStart, s.WeekEnd,
        JsonSerializer.Deserialize<WeeklySummaryContent>(s.Content, Json)!,
        s.LogEntries, s.MoodAverage, s.PreviousMoodAverage, s.CreatedAt);

    private static double? Average(List<ParentLogEntry> entries)
    {
        var moods = entries.Where(e => e.ParentMood is not null).Select(e => (double)e.ParentMood!.Value).ToList();
        return moods.Count == 0 ? null : Math.Round(moods.Average(), 1);
    }

    private async Task<SummaryContext> BuildContextAsync(
        ChildProfile child, Pseudonymizer names, List<ParentLogEntry> thisWeek, WeekFacts facts,
        DateTimeOffset now, CancellationToken ct)
    {
        // Only what the parent confirmed is given to the Planner as fact.
        var profile = await db.ProfileItems
            .Where(i => i.ChildId == child.Id && i.Status == ProfileItemStatus.Confirmed)
            .OrderBy(i => i.Section).ThenBy(i => i.CreatedAt)
            .ToListAsync(ct);

        var accommodations = await db.Accommodations
            .Where(a => a.ChildId == child.Id)
            .OrderBy(a => a.CreatedAt)
            .ToListAsync(ct);

        var since = now.AddDays(-WeekDays);
        var lastCrisis = await db.SafetyEvents
            .Where(e => e.ChildId == child.Id && SafetyEvent.CrisisSources.Contains(e.Source) && e.CreatedAt >= since)
            .OrderByDescending(e => e.CreatedAt)
            .FirstOrDefaultAsync(ct);

        return new SummaryContext
        {
            Age = child.AgeIn(now.Year),
            Profile = profile.Select(i => $"{i.Section}: {names.Hide(i.Text)}").ToList(),
            Accommodations = accommodations
                .Select(a => new CoachAccommodation(
                    names.Hide(a.Description), a.Status.ToString(), a.PlannedChange is null ? null : names.Hide(a.PlannedChange)))
                .ToList(),
            Log = thisWeek.Select(e => ParentCoachService.FormatLogEntry(e, names)).ToList(),
            Facts = facts,
            SafetyNote = lastCrisis is null
                ? null
                : $"The app's crisis screen with emergency contacts was shown to the parent on {lastCrisis.CreatedAt:yyyy-MM-dd} " +
                  $"(category: {lastCrisis.Category}).",
        };
    }
}
