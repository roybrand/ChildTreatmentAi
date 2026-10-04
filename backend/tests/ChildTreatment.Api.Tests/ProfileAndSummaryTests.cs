using ChildTreatment.Api.Data;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Onboarding;
using ChildTreatment.Api.Planning;
using ChildTreatment.Api.Safety;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace ChildTreatment.Api.Tests;

public class ProfileAgentTests
{
    private static readonly InterviewContext Context = new() { Age = 9 };

    private const string Turn = """
        {"reply":"תודה. מה מפחיד את [CHILD]?","items":[{"section":"StrengthsAndInterests","text":"[CHILD] אוהבת לצייר"}],"complete":false}
        """;

    [Fact]
    public async Task A_crisis_message_never_reaches_the_model_and_nothing_is_written_down()
    {
        var llm = new FakeLlm { CoachReply = Turn };

        var outcome = await TestSupport.ProfileAgent(llm).RespondAsync(Context, [], "היא אמרה שהיא רוצה למות");

        Assert.Equal(InterviewOutcomeKind.Crisis, outcome.Kind);
        Assert.Equal(SafetyTexts.Crisis, outcome.Text);
        Assert.Empty(outcome.Items);
        Assert.Empty(llm.Requests);
    }

    [Fact]
    public async Task The_question_and_the_notes_are_returned_after_review()
    {
        var llm = new FakeLlm { CoachReply = Turn };

        var outcome = await TestSupport.ProfileAgent(llm).RespondAsync(Context, [], "היא אוהבת לצייר");

        Assert.Equal(InterviewOutcomeKind.Reply, outcome.Kind);
        Assert.Equal("learner-profile/v1", outcome.PromptVersion);
        Assert.Equal(new ProposedItem(ProfileSection.StrengthsAndInterests, "[CHILD] אוהבת לצייר"), Assert.Single(outcome.Items));
        // The reviewer sees the notes too, since the parent is shown both.
        Assert.Contains("[CHILD] אוהבת לצייר", llm.ReviewRequests.Single().Messages[0].Text);
    }

    [Fact]
    public async Task A_turn_that_fails_review_writes_nothing_down()
    {
        var llm = new FakeLlm { CoachReply = Turn, Review = FakeLlm.ReviewBlock };

        var outcome = await TestSupport.ProfileAgent(llm).RespondAsync(Context, [], "היא אוהבת לצייר");

        Assert.Equal(InterviewOutcomeKind.Fallback, outcome.Kind);
        Assert.Equal(SafetyTexts.Fallback, outcome.Text);
        Assert.Empty(outcome.Items);
    }

    [Theory]
    [InlineData("not json")]
    [InlineData("""{"reply":"","items":[],"complete":false}""")]
    [InlineData("""{"items":[],"complete":false}""")]
    public async Task Output_that_cannot_be_read_gives_the_fallback(string output)
    {
        var llm = new FakeLlm { CoachReply = output };

        var outcome = await TestSupport.ProfileAgent(llm).RespondAsync(Context, [], "היא אוהבת לצייר");

        Assert.Equal(InterviewOutcomeKind.Fallback, outcome.Kind);
    }

    [Fact]
    public async Task Notes_outside_the_known_sections_or_too_long_are_dropped()
    {
        var tooLong = new string('א', ProfileAgent.MaxItemLength + 1);
        var llm = new FakeLlm
        {
            CoachReply = $$"""
                {"reply":"תודה","complete":false,"items":[
                  {"section":"Diagnosis","text":"משהו"},
                  {"section":"99","text":"משהו"},
                  {"section":"WhatCalms","text":"{{tooLong}}"},
                  {"section":"WhatCalms","text":"חיבוק"}]}
                """,
        };

        var outcome = await TestSupport.ProfileAgent(llm).RespondAsync(Context, [], "חיבוק עוזר לה");

        Assert.Equal(new ProposedItem(ProfileSection.WhatCalms, "חיבוק"), Assert.Single(outcome.Items));
    }
}

public class ProfileInterviewServiceTests
{
    private static readonly Guid FamilyId = Guid.NewGuid();

    private sealed record Arranged(ProfileInterviewService Service, AppDbContext Db, Guid ChildId, string Database);

    private static async Task<Arranged> Arrange(FakeLlm llm)
    {
        var database = Guid.NewGuid().ToString();
        var db = TestSupport.Db(database, FamilyId);
        var clock = TestSupport.Clock();

        var child = new ChildProfile { Id = Guid.NewGuid(), Nickname = "נועה", BirthYear = 2017, CreatedAt = clock.GetUtcNow() };
        db.Children.Add(child);
        db.ProfileItems.Add(new ProfileItem
        {
            ChildId = child.Id, Section = ProfileSection.WhatCalms, Text = "מוזיקה לפני השינה",
            Status = ProfileItemStatus.Rejected, CreatedAt = clock.GetUtcNow(),
        });
        await db.SaveChangesAsync();

        var service = new ProfileInterviewService(
            db, TestSupport.ProfileAgent(llm), TestSupport.Rules(), clock, Options.Create(new FeatureOptions()), NullLogger<ProfileInterviewService>.Instance);
        return new Arranged(service, db, child.Id, database);
    }

    [Fact]
    public async Task What_the_agent_writes_down_waits_for_the_parent_and_carries_the_real_name()
    {
        var llm = new FakeLlm
        {
            CoachReply = """
                {"reply":"מה מפחיד את [CHILD]?","items":[{"section":"StrengthsAndInterests","text":"[CHILD] אוהבת לצייר"}],"complete":false}
                """,
        };
        var arranged = await Arrange(llm);

        var reply = await arranged.Service.SendAsync(arranged.ChildId, "נועה אוהבת לצייר");

        Assert.All(llm.Requests, r => Assert.DoesNotContain("נועה", FakeLlm.AllText(r)));
        Assert.Equal(InterviewReplyKind.Reply, reply!.Kind);
        Assert.Equal("מה מפחיד את נועה?", reply.Text);

        var item = Assert.Single(reply.Items);
        Assert.Equal("נועה אוהבת לצייר", item.Text);
        Assert.Equal(ProfileItemStatus.Suggested, item.Status);
        var stored = await arranged.Db.ProfileItems.SingleAsync(i => i.Id == item.Id);
        Assert.Equal(ProfileItemStatus.Suggested, stored.Status);
    }

    [Fact]
    public async Task The_agent_is_told_what_the_parent_rejected()
    {
        var llm = new FakeLlm { CoachReply = """{"reply":"תודה","items":[],"complete":false}""" };
        var arranged = await Arrange(llm);

        await arranged.Service.SendAsync(arranged.ChildId, "היא אוהבת לצייר");

        Assert.Contains("[rejected by the parent] WhatCalms: מוזיקה לפני השינה", llm.CoachRequests.Single().Context);
    }

    [Fact]
    public async Task A_crisis_message_shows_contacts_records_an_event_and_writes_nothing_down()
    {
        var llm = new FakeLlm();
        var arranged = await Arrange(llm);

        var reply = await arranged.Service.SendAsync(arranged.ChildId, "נועה אמרה שהיא רוצה למות");

        Assert.Equal(InterviewReplyKind.Crisis, reply!.Kind);
        Assert.NotEmpty(reply.Contacts);
        Assert.Empty(reply.Items);
        Assert.Equal(SafetySource.ProfileInterviewInput, (await arranged.Db.SafetyEvents.SingleAsync()).Source);
        Assert.Empty(llm.Requests);
    }

    [Fact]
    public async Task The_closing_turn_marks_the_interview_complete()
    {
        var llm = new FakeLlm { CoachReply = """{"reply":"תודה רבה","items":[],"complete":true}""" };
        var arranged = await Arrange(llm);

        var reply = await arranged.Service.SendAsync(arranged.ChildId, "זה הכול");

        Assert.True(reply!.Complete);
        Assert.True(await arranged.Db.InterviewMessages.AnyAsync(m => m.Completes));
    }

    [Fact]
    public async Task A_child_from_another_family_is_not_found()
    {
        var llm = new FakeLlm();
        var arranged = await Arrange(llm);

        await using var otherDb = TestSupport.Db(arranged.Database, Guid.NewGuid());
        var otherService = new ProfileInterviewService(
            otherDb, TestSupport.ProfileAgent(llm), TestSupport.Rules(), TestSupport.Clock(),
            Options.Create(new FeatureOptions()), NullLogger<ProfileInterviewService>.Instance);

        Assert.Null(await otherService.SendAsync(arranged.ChildId, "שלום"));
        Assert.Empty(llm.Requests);
    }
}

public class WeeklySummaryTests
{
    private static readonly Guid FamilyId = Guid.NewGuid();

    private const string Summary = """
        {"what_happened":"[CHILD] נרדמה לבד פעמיים השבוע.",
         "patterns":[{"text":"הבכי התקצר","basis":"observed"},{"text":"אולי העייפות משפיעה","basis":"certain"}],
         "what_worked":["המשפט התומך לפני השינה"],
         "proposal":"אפשר להמשיך באותו צעד עוד שבוע."}
        """;

    private sealed record Arranged(WeeklySummaryService Service, AppDbContext Db, Guid ChildId, string Database);

    private static async Task<Arranged> Arrange(FakeLlm llm, int entriesThisWeek = 3)
    {
        var database = Guid.NewGuid().ToString();
        var db = TestSupport.Db(database, FamilyId);
        var clock = TestSupport.Clock();
        var now = clock.GetUtcNow();

        var child = new ChildProfile { Id = Guid.NewGuid(), Nickname = "נועה", BirthYear = 2017, CreatedAt = now };
        db.Children.Add(child);

        // The clock is at 3 October 2026, so the week runs from 27 September.
        (DateOnly Date, int? Mood)[] entries =
        [
            (new DateOnly(2026, 9, 22), 4), (new DateOnly(2026, 9, 24), 5),
            (new DateOnly(2026, 9, 28), 2), (new DateOnly(2026, 10, 1), 3), (new DateOnly(2026, 10, 3), null),
        ];
        foreach (var (date, mood) in entries.Take(2 + entriesThisWeek))
        {
            db.ParentLogEntries.Add(new ParentLogEntry
            {
                ChildId = child.Id, Date = date, WhatHappened = "נועה בכתה לפני השינה", ParentMood = mood, CreatedAt = now,
            });
        }
        await db.SaveChangesAsync();

        var service = new WeeklySummaryService(
            db, TestSupport.SummaryAgent(llm), TestSupport.Rules(), clock, NullLogger<WeeklySummaryService>.Instance);
        return new Arranged(service, db, child.Id, database);
    }

    [Fact]
    public async Task A_week_with_too_little_in_the_log_is_not_summarised()
    {
        var llm = new FakeLlm { CoachReply = Summary };
        var arranged = await Arrange(llm, entriesThisWeek: 1);

        var result = await arranged.Service.CreateAsync(arranged.ChildId);

        Assert.Equal(SummaryResultKind.NotEnoughLog, result!.Kind);
        Assert.Empty(llm.Requests);
    }

    [Fact]
    public async Task The_summary_carries_numbers_counted_by_code_and_the_real_name()
    {
        var llm = new FakeLlm { CoachReply = Summary };
        var arranged = await Arrange(llm);

        var result = await arranged.Service.CreateAsync(arranged.ChildId);

        Assert.Equal(SummaryResultKind.Created, result!.Kind);
        var summary = result.Summary!;
        Assert.Equal(new DateOnly(2026, 9, 27), summary.WeekStart);
        Assert.Equal(3, summary.LogEntries);
        Assert.Equal(2.5, summary.MoodAverage);
        Assert.Equal(4.5, summary.PreviousMoodAverage);
        Assert.Equal("נועה נרדמה לבד פעמיים השבוע.", summary.Content.WhatHappened);

        Assert.All(llm.Requests, r => Assert.DoesNotContain("נועה", FakeLlm.AllText(r)));
        var context = llm.CoachRequests.Single().Context!;
        Assert.Contains("Parent's average mood this week (1 very hard to 5 good): 2.5", context);
        // Last week's entries are counted, not sent.
        Assert.DoesNotContain("2026-09-22", context);
    }

    [Fact]
    public async Task A_pattern_not_clearly_marked_as_observed_is_shown_as_a_guess()
    {
        var llm = new FakeLlm { CoachReply = Summary };
        var arranged = await Arrange(llm);

        var result = await arranged.Service.CreateAsync(arranged.ChildId);

        Assert.Equal(
            [SummaryPattern.Observed, SummaryPattern.Guess],
            result!.Summary!.Content.Patterns.Select(p => p.Basis));
    }

    [Fact]
    public async Task A_second_request_on_the_same_day_returns_the_summary_without_calling_the_model()
    {
        var llm = new FakeLlm { CoachReply = Summary };
        var arranged = await Arrange(llm);

        var first = await arranged.Service.CreateAsync(arranged.ChildId);
        var calls = llm.Requests.Count;
        var second = await arranged.Service.CreateAsync(arranged.ChildId);

        Assert.Equal(SummaryResultKind.Existing, second!.Kind);
        Assert.Equal(first!.Summary!.Id, second.Summary!.Id);
        Assert.Equal(calls, llm.Requests.Count);
        Assert.Single(await arranged.Service.ListAsync(arranged.ChildId));
    }

    [Fact]
    public async Task A_summary_that_fails_review_is_not_stored_or_shown()
    {
        var llm = new FakeLlm { CoachReply = Summary, Review = FakeLlm.ReviewBlock };
        var arranged = await Arrange(llm);

        var result = await arranged.Service.CreateAsync(arranged.ChildId);

        Assert.Equal(SummaryResultKind.Fallback, result!.Kind);
        Assert.Null(result.Summary);
        Assert.Empty(await arranged.Db.WeeklySummaries.ToListAsync());
        Assert.Equal(SafetySource.WeeklySummaryOutput, (await arranged.Db.SafetyEvents.SingleAsync()).Source);
    }

    [Fact]
    public async Task The_reviewer_reads_the_weeks_log_so_a_missed_danger_can_be_caught()
    {
        var llm = new FakeLlm { CoachReply = Summary };
        var arranged = await Arrange(llm);

        await arranged.Service.CreateAsync(arranged.ChildId);

        Assert.Contains("[CHILD] בכתה לפני השינה", llm.ReviewRequests.Single().Messages[0].Text);
    }

    [Fact]
    public async Task A_child_from_another_family_is_not_found()
    {
        var llm = new FakeLlm { CoachReply = Summary };
        var arranged = await Arrange(llm);

        await using var otherDb = TestSupport.Db(arranged.Database, Guid.NewGuid());
        var otherService = new WeeklySummaryService(
            otherDb, TestSupport.SummaryAgent(llm), TestSupport.Rules(), TestSupport.Clock(),
            NullLogger<WeeklySummaryService>.Instance);

        Assert.Null(await otherService.CreateAsync(arranged.ChildId));
        Assert.Empty(llm.Requests);
    }
}
