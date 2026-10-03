using ChildTreatment.Api.Coaching;
using ChildTreatment.Api.Data;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace ChildTreatment.Api.Tests;

public class ParentCoachAgentTests
{
    private static readonly CoachContext Context = new() { Age = 9 };

    [Fact]
    public async Task A_crisis_message_never_reaches_the_model()
    {
        var llm = new FakeLlm();

        var outcome = await TestSupport.Agent(llm).RespondAsync(Context, [], "היא אמרה שהיא רוצה למות");

        Assert.Equal(CoachOutcomeKind.Crisis, outcome.Kind);
        Assert.Equal("self_harm", outcome.CrisisCategory);
        Assert.Equal(SafetyTexts.Crisis, outcome.Text);
        Assert.Empty(llm.Requests);
    }

    [Fact]
    public async Task A_reply_that_fails_review_is_replaced_by_the_fallback()
    {
        var llm = new FakeLlm { CoachReply = "אפשר להוריד את המינון בהדרגה", Review = FakeLlm.ReviewBlock };

        var outcome = await TestSupport.Agent(llm).RespondAsync(Context, [], "אפשר להפסיק את הכדורים?");

        Assert.Equal(CoachOutcomeKind.Fallback, outcome.Kind);
        Assert.Equal(SafetyTexts.Fallback, outcome.Text);
    }

    [Theory]
    [InlineData("not json")]
    [InlineData("""{"verdict":"maybe","rules":[],"reason":""}""")]
    [InlineData("""{"rules":[]}""")]
    public async Task A_review_that_cannot_be_read_as_a_pass_blocks_the_reply(string review)
    {
        var llm = new FakeLlm { Review = review };

        var outcome = await TestSupport.Agent(llm).RespondAsync(Context, [], "מה לעשות הערב?");

        Assert.Equal(CoachOutcomeKind.Fallback, outcome.Kind);
    }

    [Fact]
    public async Task A_refusal_from_the_model_gives_the_fallback()
    {
        var llm = new FakeLlm { Refuse = true };

        var outcome = await TestSupport.Agent(llm).RespondAsync(Context, [], "מה לעשות הערב?");

        Assert.Equal(CoachOutcomeKind.Fallback, outcome.Kind);
    }

    [Fact]
    public async Task A_reviewed_reply_is_returned_with_the_prompt_version()
    {
        var llm = new FakeLlm();

        var outcome = await TestSupport.Agent(llm).RespondAsync(Context, [], "מה לעשות הערב?");

        Assert.Equal(CoachOutcomeKind.Reply, outcome.Kind);
        Assert.Equal("parent-coach/v1", outcome.PromptVersion);
        Assert.Equal(2, llm.Requests.Count);
    }

    [Fact]
    public async Task Turns_sent_to_the_model_start_with_the_parent_and_alternate()
    {
        var llm = new FakeLlm();
        List<LlmMessage> history =
        [
            new(LlmRole.Assistant, "stray coach message"),
            new(LlmRole.User, "first"),
            new(LlmRole.Assistant, "answer"),
            new(LlmRole.User, "unanswered"),
        ];

        await TestSupport.Agent(llm).RespondAsync(Context, history, "new");

        var messages = llm.CoachRequests.Single().Messages;
        Assert.Equal([LlmRole.User, LlmRole.Assistant, LlmRole.User], messages.Select(m => m.Role));
        Assert.Contains("unanswered", messages[^1].Text);
        Assert.Contains("new", messages[^1].Text);
    }
}

public class ParentCoachServiceTests
{
    private static readonly Guid FamilyId = Guid.NewGuid();

    private sealed record Arranged(ParentCoachService Service, AppDbContext Db, Guid ChildId, string Database);

    private static async Task<Arranged> Arrange(FakeLlm llm)
    {
        var database = Guid.NewGuid().ToString();
        var db = TestSupport.Db(database, FamilyId);
        var clock = TestSupport.Clock();
        var now = clock.GetUtcNow();

        var child = new ChildProfile { Id = Guid.NewGuid(), Nickname = "נועה", BirthYear = 2017, CreatedAt = now };
        db.Children.Add(child);
        db.ProfileItems.Add(new ProfileItem
        {
            ChildId = child.Id, Section = ProfileSection.AnxietyPicture, Text = "נועה מפחדת לישון לבד",
            Status = ProfileItemStatus.Confirmed, CreatedAt = now,
        });
        db.ProfileItems.Add(new ProfileItem
        {
            ChildId = child.Id, Section = ProfileSection.OtherConditions, Text = "אולי יש קושי בקשב",
            Status = ProfileItemStatus.Suggested, CreatedAt = now,
        });
        db.ParentLogEntries.Add(new ParentLogEntry
        {
            ChildId = child.Id, Date = new DateOnly(2026, 10, 2), WhatHappened = "נועה בכתה שעה", CreatedAt = now,
        });
        await db.SaveChangesAsync();

        var service = new ParentCoachService(
            db, TestSupport.Agent(llm), TestSupport.Rules(), clock, NullLogger<ParentCoachService>.Instance);
        return new Arranged(service, db, child.Id, database);
    }

    [Fact]
    public async Task The_childs_name_never_reaches_the_model_and_is_restored_in_the_reply()
    {
        var llm = new FakeLlm { CoachReply = "אפשר לומר ל[CHILD] שאת סומכת עליה" };
        var arranged = await Arrange(llm);

        var reply = await arranged.Service.SendAsync(arranged.ChildId, "נועה שוב ביקשה שאשכב לידה");

        Assert.All(llm.Requests, r => Assert.DoesNotContain("נועה", FakeLlm.AllText(r)));
        Assert.Contains("[CHILD] שוב ביקשה", llm.CoachRequests.Single().Messages[^1].Text);
        Assert.Equal(CoachReplyKind.Reply, reply!.Kind);
        Assert.Equal("אפשר לומר לנועה שאת סומכת עליה", reply.Text);
    }

    [Fact]
    public async Task The_coach_sees_confirmed_profile_items_and_the_log_but_not_suggestions()
    {
        var llm = new FakeLlm();
        var arranged = await Arrange(llm);

        await arranged.Service.SendAsync(arranged.ChildId, "מה עושים הערב?");

        var context = llm.CoachRequests.Single().Context!;
        Assert.Contains("[CHILD] מפחדת לישון לבד", context);
        Assert.Contains("[CHILD] בכתה שעה", context);
        Assert.DoesNotContain("קושי בקשב", context);
    }

    [Fact]
    public async Task A_crisis_message_shows_contacts_records_an_event_and_stays_out_of_later_history()
    {
        var llm = new FakeLlm();
        var arranged = await Arrange(llm);

        var crisis = await arranged.Service.SendAsync(arranged.ChildId, "נועה אמרה שהיא רוצה למות");
        await arranged.Service.SendAsync(arranged.ChildId, "היא נרגעה, מה עכשיו?");

        Assert.Equal(CoachReplyKind.Crisis, crisis!.Kind);
        Assert.NotEmpty(crisis.Contacts);

        var safetyEvent = await arranged.Db.SafetyEvents.SingleAsync();
        Assert.Equal("self_harm", safetyEvent.Category);
        Assert.Equal(SafetySource.CoachInput, safetyEvent.Source);

        var request = llm.CoachRequests.Single();
        Assert.DoesNotContain("רוצה למות", FakeLlm.AllText(request));
        Assert.Contains("crisis screen", request.Context);
    }

    [Fact]
    public async Task When_the_model_is_unreachable_the_parents_message_is_kept()
    {
        var llm = new FakeLlm { Throw = new LlmUnavailableException("down", new Exception()) };
        var arranged = await Arrange(llm);

        var reply = await arranged.Service.SendAsync(arranged.ChildId, "מה עושים הערב?");

        Assert.Equal(CoachReplyKind.Unavailable, reply!.Kind);
        var stored = await arranged.Db.CoachingMessages.SingleAsync();
        Assert.Equal(CoachingRole.Parent, stored.Role);
    }

    [Fact]
    public async Task A_child_from_another_family_is_not_found()
    {
        var llm = new FakeLlm();
        var arranged = await Arrange(llm);

        await using var otherDb = TestSupport.Db(arranged.Database, Guid.NewGuid());
        var otherService = new ParentCoachService(
            otherDb, TestSupport.Agent(llm), TestSupport.Rules(), TestSupport.Clock(), NullLogger<ParentCoachService>.Instance);

        Assert.Null(await otherService.SendAsync(arranged.ChildId, "מה עושים הערב?"));
        Assert.Empty(llm.Requests);
    }
}
