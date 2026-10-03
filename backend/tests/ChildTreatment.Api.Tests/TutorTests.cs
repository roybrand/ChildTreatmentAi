using ChildTreatment.Api.Data;
using ChildTreatment.Api.Learning;
using ChildTreatment.Api.Llm;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace ChildTreatment.Api.Tests;

public class TutorTests
{
    private static readonly Guid FamilyId = Guid.NewGuid();

    private static string World(string scene = "יצרת גוון משלך בסטודיו ללק שלך.", string colorB = "#FFFFFF") => $$"""
        {"world":"סטודיו ללק","scene":"{{scene}}","request":"לקוחה רוצה בקבוק גדול, בדיוק באותו גוון.",
         "ingredient_a":{"name":"ורוד","color":"#e85d9a"},"ingredient_b":{"name":"לבן","color":"{{colorB}}"},
         "small_label":"הבקבוק הקטן","big_label":"הבקבוק הגדול","result_word":"הגוון",
         "why_needed":"כל מי שמערבב משהו צריך לדעת להכין אותו שוב בגודל אחר.","link":"Mixing polish is a real proportion."}
        """;

    private sealed record Arranged(LessonService Service, AppDbContext Db, Guid ChildId, string Database);

    private static async Task<Arranged> Arrange(FakeLlm llm, bool withInterests = true)
    {
        var database = Guid.NewGuid().ToString();
        var db = TestSupport.Db(database, FamilyId);
        var clock = TestSupport.Clock();
        var now = clock.GetUtcNow();

        var child = new ChildProfile { Id = Guid.NewGuid(), Nickname = "נועה", BirthYear = 2012, CreatedAt = now };
        db.Children.Add(child);
        if (withInterests)
        {
            db.ProfileItems.Add(new ProfileItem
            {
                ChildId = child.Id, Section = ProfileSection.StrengthsAndInterests, Text = "נועה אוהבת איפור ולק",
                Status = ProfileItemStatus.Confirmed, CreatedAt = now,
            });
            db.ProfileItems.Add(new ProfileItem
            {
                ChildId = child.Id, Section = ProfileSection.StrengthsAndInterests, Text = "אוהבת סוסים",
                Status = ProfileItemStatus.Suggested, CreatedAt = now,
            });
            db.ProfileItems.Add(new ProfileItem
            {
                ChildId = child.Id, Section = ProfileSection.AnxietyPicture, Text = "מפחדת ממבחנים",
                Status = ProfileItemStatus.Confirmed, CreatedAt = now,
            });
        }
        await db.SaveChangesAsync();

        var service = new LessonService(
            db, TestSupport.Tutor(llm), TestSupport.Rules(), clock, NullLogger<LessonService>.Instance);
        return new Arranged(service, db, child.Id, database);
    }

    [Fact]
    public async Task The_lesson_is_set_in_the_childs_world_once_and_kept()
    {
        var llm = new FakeLlm { CoachReply = World() };
        var arranged = await Arrange(llm);

        var first = await arranged.Service.GetAsync(arranged.ChildId, LessonService.FractionsMixer);
        var calls = llm.Requests.Count;
        var second = await arranged.Service.GetAsync(arranged.ChildId, LessonService.FractionsMixer);

        Assert.True(first!.FromTutor);
        Assert.Equal("סטודיו ללק", first.World.World);
        Assert.Equal("#E85D9A", first.World.IngredientA.Color);
        Assert.Equal(first.World, second!.World);
        Assert.Equal(calls, llm.Requests.Count);
    }

    [Fact]
    public async Task The_tutor_sees_confirmed_interests_only_and_never_the_childs_name_or_fears()
    {
        var llm = new FakeLlm { CoachReply = World() };
        var arranged = await Arrange(llm);

        await arranged.Service.GetAsync(arranged.ChildId, LessonService.FractionsMixer);

        var context = llm.CoachRequests.Single().Context!;
        Assert.Contains("[CHILD] אוהבת איפור ולק", context);
        Assert.DoesNotContain("סוסים", context);
        Assert.DoesNotContain("מבחנים", context);
        Assert.All(llm.Requests, r => Assert.DoesNotContain("נועה", FakeLlm.AllText(r)));
    }

    [Fact]
    public async Task With_no_interests_on_file_the_built_in_world_is_used_and_the_model_is_not_called()
    {
        var llm = new FakeLlm { CoachReply = World() };
        var arranged = await Arrange(llm, withInterests: false);

        var lesson = await arranged.Service.GetAsync(arranged.ChildId, LessonService.FractionsMixer);

        Assert.False(lesson!.FromTutor);
        Assert.Equal(LessonWorld.Default, lesson.World);
        Assert.Empty(llm.Requests);
    }

    [Theory]
    [InlineData("יצרת גוון משלך ב-3 דקות.", "#FFFFFF")] // a digit in the wording
    [InlineData("יצרת גוון משלך.", "#E8609A")] // two colours too close to tell apart
    [InlineData("יצרת גוון משלך.", "pink")] // not a colour code
    public async Task A_world_that_code_cannot_use_falls_back_to_the_built_in_one(string scene, string colorB)
    {
        var llm = new FakeLlm { CoachReply = World(scene, colorB) };
        var arranged = await Arrange(llm);

        var lesson = await arranged.Service.GetAsync(arranged.ChildId, LessonService.FractionsMixer);

        Assert.False(lesson!.FromTutor);
        Assert.Equal(LessonWorld.Default, lesson.World);
        Assert.Empty(llm.ReviewRequests);
    }

    [Fact]
    public async Task A_world_withheld_by_the_review_is_never_shown_to_the_child()
    {
        var llm = new FakeLlm { CoachReply = World(), Review = FakeLlm.ReviewBlock };
        var arranged = await Arrange(llm);

        var lesson = await arranged.Service.GetAsync(arranged.ChildId, LessonService.FractionsMixer);

        Assert.Equal(LessonWorld.Default, lesson!.World);
        Assert.Equal(SafetySource.LessonOutput, (await arranged.Db.SafetyEvents.SingleAsync()).Source);
    }

    [Fact]
    public async Task When_the_model_is_unreachable_the_lesson_still_opens()
    {
        var llm = new FakeLlm { Throw = new LlmUnavailableException("down", new Exception()) };
        var arranged = await Arrange(llm);

        var lesson = await arranged.Service.GetAsync(arranged.ChildId, LessonService.FractionsMixer);

        Assert.Equal(LessonWorld.Default, lesson!.World);
    }

    [Fact]
    public async Task Progress_only_moves_forward_and_completion_is_kept()
    {
        var llm = new FakeLlm { CoachReply = World() };
        var arranged = await Arrange(llm);
        await arranged.Service.GetAsync(arranged.ChildId, LessonService.FractionsMixer);

        await arranged.Service.SaveProgressAsync(arranged.ChildId, LessonService.FractionsMixer, 4, completed: true);
        var lesson = await arranged.Service.SaveProgressAsync(arranged.ChildId, LessonService.FractionsMixer, 1, completed: false);

        Assert.Equal(4, lesson!.StepReached);
        Assert.True(lesson.Completed);
    }

    [Fact]
    public void The_built_in_world_passes_the_same_checks_as_the_tutors()
    {
        Assert.Null(TutorAgent.Validate(LessonWorld.Default));
    }

    [Fact]
    public async Task A_child_from_another_family_or_an_unknown_lesson_is_not_found()
    {
        var llm = new FakeLlm { CoachReply = World() };
        var arranged = await Arrange(llm);

        await using var otherDb = TestSupport.Db(arranged.Database, Guid.NewGuid());
        var otherService = new LessonService(
            otherDb, TestSupport.Tutor(llm), TestSupport.Rules(), TestSupport.Clock(), NullLogger<LessonService>.Instance);

        Assert.Null(await otherService.GetAsync(arranged.ChildId, LessonService.FractionsMixer));
        Assert.Null(await arranged.Service.GetAsync(arranged.ChildId, "no-such-lesson"));
        Assert.Empty(llm.Requests);
    }
}
