using Microsoft.AspNetCore.Identity;

namespace ChildTreatment.Api.Data;

/// <summary>Marks a string property that is encrypted at field level before it is stored.</summary>
[AttributeUsage(AttributeTargets.Property)]
public sealed class EncryptedAttribute : Attribute;

/// <summary>Every row that belongs to a family carries its id, so one query filter can isolate families.</summary>
public interface IFamilyOwned
{
    Guid FamilyId { get; set; }
}

public class AppUser : IdentityUser<Guid>
{
    public Guid? FamilyId { get; set; }
}

public class Family
{
    public Guid Id { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset ConsentGivenAt { get; set; }
    public string ConsentVersion { get; set; } = "";
}

public enum ChildMode { Child, Teen }

public class ChildProfile : IFamilyOwned
{
    public const int TeenModeFromAge = 12;

    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    [Encrypted] public string Nickname { get; set; } = "";
    // Birth year only: enough to choose the mode, and less identifying than a birth date.
    public int BirthYear { get; set; }
    public DateTimeOffset CreatedAt { get; set; }

    public int AgeIn(int year) => year - BirthYear;
    public ChildMode ModeIn(int year) => AgeIn(year) >= TeenModeFromAge ? ChildMode.Teen : ChildMode.Child;
}

public enum ProfileSection
{
    StrengthsAndInterests,
    AnxietyPicture,
    WhatCalms,
    LearningPicture,
    OtherConditions,
    FamilyContext,
    WhatHasWorked,
}

public enum ProfileItemStatus { Confirmed, Suggested, Rejected }

public class ProfileItem : IFamilyOwned
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid ChildId { get; set; }
    public ProfileSection Section { get; set; }
    [Encrypted] public string Text { get; set; } = "";
    public ProfileItemStatus Status { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public enum AccommodationStatus { Active, Targeted, Reduced }

public class Accommodation : IFamilyOwned
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid ChildId { get; set; }
    [Encrypted] public string Description { get; set; } = "";
    public AccommodationStatus Status { get; set; }
    // What the parent will do differently. Set when the accommodation becomes the target.
    [Encrypted] public string? PlannedChange { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public class ParentLogEntry : IFamilyOwned
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid ChildId { get; set; }
    public DateOnly Date { get; set; }
    [Encrypted] public string WhatHappened { get; set; } = "";
    [Encrypted] public string? ChildReaction { get; set; }
    [Encrypted] public string? ParentResponse { get; set; }
    /// <summary>How the parent was feeling, 1 (very hard) to 5 (good). Optional.</summary>
    public int? ParentMood { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public enum CoachingRole { Parent, Coach }

public enum CoachingMessageKind
{
    Normal,
    /// <summary>The Safety Guard stopped the exchange and the crisis screen was shown.</summary>
    Crisis,
    /// <summary>The coach's reply was withheld and a safe fallback was shown.</summary>
    Fallback,
}

public class CoachingMessage : IFamilyOwned
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid ChildId { get; set; }
    public CoachingRole Role { get; set; }
    public CoachingMessageKind Kind { get; set; }
    [Encrypted] public string Text { get; set; } = "";
    /// <summary>The prompt version that produced a coach message, for tracing.</summary>
    public string? PromptVersion { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>One turn of the onboarding interview between the parent and the Profile Agent.</summary>
public class InterviewMessage : IFamilyOwned
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid ChildId { get; set; }
    /// <summary>Coach here means the Profile Agent's side of the interview.</summary>
    public CoachingRole Role { get; set; }
    public CoachingMessageKind Kind { get; set; }
    [Encrypted] public string Text { get; set; } = "";
    /// <summary>True on the agent message that closed the interview.</summary>
    public bool Completes { get; set; }
    public string? PromptVersion { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>The Planner's summary of one week, as shown to the parent.</summary>
public class WeeklySummary : IFamilyOwned
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid ChildId { get; set; }
    public DateOnly WeekStart { get; set; }
    public DateOnly WeekEnd { get; set; }
    /// <summary>The written summary, as JSON (see WeeklySummaryContent).</summary>
    [Encrypted] public string Content { get; set; } = "";
    // Counted by code from the log, never by the model, so a decline cannot be written away.
    public int LogEntries { get; set; }
    public double? MoodAverage { get; set; }
    public double? PreviousMoodAverage { get; set; }
    public string PromptVersion { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>One lesson for one child: the world it is set in, and how far the child has got.</summary>
public class ChildLesson : IFamilyOwned
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid ChildId { get; set; }
    /// <summary>Which hand-built lesson this is, for example "fractions-mixer-1".</summary>
    public string LessonId { get; set; } = "";
    /// <summary>The world, as JSON (see LessonWorld). It is drawn from the child's interests.</summary>
    [Encrypted] public string World { get; set; } = "";
    /// <summary>False when the built-in world is in use.</summary>
    public bool FromTutor { get; set; }
    /// <summary>The furthest step reached, from 0. Kept so a lesson can stop anywhere and resume.</summary>
    public int StepReached { get; set; }
    public DateTimeOffset? CompletedAt { get; set; }
    public string? PromptVersion { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>
/// How one practice question went for a learner. It holds no question and no answer: only which
/// sub-topic, and whether the learner got it without being shown the solution.
/// </summary>
public class PracticeRecord : IFamilyOwned
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid ChildId { get; set; }
    public string SubtopicId { get; set; } = "";
    /// <summary>True when the answer fitted and the solution had not been shown.</summary>
    public bool GotIt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

// Stored as numbers: add new values at the end only.
public enum SafetySource
{
    CoachInput,
    CoachOutput,
    ParentLog,
    ProfileInterviewInput,
    ProfileInterviewOutput,
    WeeklySummaryOutput,
    LessonOutput,
}

/// <summary>A record that the Safety Guard acted. It holds the category only, never the text.</summary>
public class SafetyEvent : IFamilyOwned
{
    /// <summary>Sources where a person's own words matched the crisis rules and the crisis screen was shown.</summary>
    public static readonly SafetySource[] CrisisSources =
        [SafetySource.CoachInput, SafetySource.ParentLog, SafetySource.ProfileInterviewInput];

    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid? ChildId { get; set; }
    public SafetySource Source { get; set; }
    public string Category { get; set; } = "";
    public string RulesVersion { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; }
}
