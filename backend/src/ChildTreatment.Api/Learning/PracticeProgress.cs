using ChildTreatment.Api.Data;

namespace ChildTreatment.Api.Learning;

/// <summary>How a learner is doing on one sub-topic.</summary>
/// <param name="Tried">How many questions were tried.</param>
/// <param name="GotIt">How many of them the learner got without being shown the solution.</param>
/// <param name="ComeBack">True when the latest questions did not go well, so the sub-topic is worth returning to.</param>
/// <param name="LastAt">When the sub-topic was last practised.</param>
/// <param name="TriedThisWeek">How many questions were tried in the last seven days.</param>
/// <param name="GotItThisWeek">How many of those the learner got on their own.</param>
public sealed record SubtopicProgress(
    string SubtopicId, int Tried, int GotIt, bool ComeBack, DateTimeOffset LastAt, int TriedThisWeek, int GotItThisWeek);

public static class PracticeProgress
{
    /// <summary>Only the latest few questions decide whether to come back: what matters is how it goes now.</summary>
    private const int Latest = 3;

    public static List<SubtopicProgress> Of(IEnumerable<PracticeRecord> records, DateTimeOffset now)
    {
        var weekAgo = now.AddDays(-7);
        return records
            .GroupBy(r => r.SubtopicId)
            .Select(group =>
            {
                var newestFirst = group.OrderByDescending(r => r.CreatedAt).ToList();
                var latest = newestFirst.Take(Latest).ToList();
                var thisWeek = newestFirst.Where(r => r.CreatedAt >= weekAgo).ToList();
                // Two of the latest three, or all of them when there are fewer than two.
                var enough = Math.Min(2, latest.Count);
                return new SubtopicProgress(
                    group.Key,
                    newestFirst.Count,
                    newestFirst.Count(r => r.GotIt),
                    latest.Count(r => r.GotIt) < enough,
                    newestFirst[0].CreatedAt,
                    thisWeek.Count,
                    thisWeek.Count(r => r.GotIt));
            })
            .OrderByDescending(p => p.LastAt)
            .ToList();
    }
}
