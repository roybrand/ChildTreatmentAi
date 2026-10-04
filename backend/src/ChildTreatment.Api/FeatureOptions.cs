using ChildTreatment.Api.Data;
using Microsoft.Extensions.Options;

namespace ChildTreatment.Api;

/// <summary>Which parts of the product are switched on. Read from the "Features" settings section.</summary>
public sealed class FeatureOptions
{
    /// <summary>
    /// The parent coaching side: the Parent Coach, the accommodation map, the daily log, and the
    /// weekly summary. Off by default: the product is a tutor (see docs/DECISIONS.md). The code stays
    /// so the module can return later, built with a child mental-health professional.
    /// </summary>
    public bool FamilyCoaching { get; set; }

    private static readonly IReadOnlySet<ProfileSection> LearnerSections = new HashSet<ProfileSection>
    {
        ProfileSection.StrengthsAndInterests,
        ProfileSection.LearningPicture,
        ProfileSection.WhatCalms,
        ProfileSection.WhatHasWorked,
    };

    private static readonly IReadOnlySet<ProfileSection> AllSections = Enum.GetValues<ProfileSection>().ToHashSet();

    /// <summary>
    /// The profile sections in use. The tutor keeps what a learner loves, what is hard in learning,
    /// and what helps. It holds nothing about anxiety, diagnoses, or the family.
    /// </summary>
    public IReadOnlySet<ProfileSection> ProfileSections => FamilyCoaching ? AllSections : LearnerSections;
}

public static class FeatureEndpointExtensions
{
    /// <summary>Makes a group of routes exist only while the family coaching module is switched on.</summary>
    public static RouteGroupBuilder RequireFamilyCoaching(this RouteGroupBuilder group)
    {
        group.AddEndpointFilter(async (context, next) =>
            context.HttpContext.RequestServices.GetRequiredService<IOptions<FeatureOptions>>().Value.FamilyCoaching
                ? await next(context)
                : Results.NotFound());
        return group;
    }
}
