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
         "why_needed":"כל מי שמערבב משהו צריך לדעת להכין אותו שוב בגודל אחר.","emoji":"💅","customer":"👩","container":"bottle","thanks":"בדיוק הגוון שרציתי!","items":"בקבוקי לק, שמפו, שפתונים","greeting":"הסטודיו שלך מחכה.","decor":"💅💄✨","link":"Mixing polish is a real proportion."}
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
            db, TestSupport.Tutor(llm), TestSupport.Guide(llm), TestSupport.Prompts(), TestSupport.Rules(), clock, NullLogger<LessonService>.Instance);
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
    public async Task The_lesson_resumes_where_the_learner_is_and_completion_is_kept()
    {
        var llm = new FakeLlm { CoachReply = World() };
        var arranged = await Arrange(llm);
        await arranged.Service.GetAsync(arranged.ChildId, LessonService.FractionsMixer);

        await arranged.Service.SaveProgressAsync(arranged.ChildId, LessonService.FractionsMixer, 4, completed: true);
        var lesson = await arranged.Service.SaveProgressAsync(arranged.ChildId, LessonService.FractionsMixer, 1, completed: false);

        Assert.Equal(1, lesson!.StepReached);
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
            otherDb, TestSupport.Tutor(llm), TestSupport.Guide(llm), TestSupport.Prompts(), TestSupport.Rules(), TestSupport.Clock(), NullLogger<LessonService>.Instance);

        Assert.Null(await otherService.GetAsync(arranged.ChildId, LessonService.FractionsMixer));
        Assert.Null(await arranged.Service.GetAsync(arranged.ChildId, "no-such-lesson"));
        Assert.Empty(llm.Requests);
    }

    /// <summary>A guide as the model writes it. <paramref name="secondEmoji"/> lets a test break it.</summary>
    private static string Guide(string secondEmoji = "🪞", string firstSentence = "The lipstick is on the table.")
    {
        (string En, string He, string Emoji, string Sentence)[][] circles =
        [
            [("lipstick", "שפתון", "💄", firstSentence), ("mirror", "מראה", secondEmoji, "The mirror is on the wall."),
             ("brush", "מברשת", "🖌️", "I have a new brush."), ("nail polish", "לק", "💅", "The nail polish is pink."),
             ("comb", "מסרק", "🪮", "My comb is in the bag."), ("soap", "סבון", "🧼", "The soap is on the sink.")],
            [("customer", "לקוחה", "🙋", "The customer is very happy."), ("shop", "חנות", "🏪", "The shop is open today."),
             ("price", "מחיר", "🏷️", "The price is on the box."), ("bag", "תיק", "👜", "My bag is on the chair."),
             ("money", "כסף", "💰", "I have some money."), ("gift", "מתנה", "🎁", "This gift is for you.")],
            [("friend", "חברה", "🤝", "My friend is at home."), ("water", "מים", "💧", "I drink water every day."),
             ("sun", "שמש", "☀️", "The sun is in the sky."), ("house", "בית", "🏠", "This is my house."),
             ("book", "ספר", "📖", "I read a book every week."), ("music", "מוזיקה", "🎵", "I like this music.")],
        ];
        var words = circles.SelectMany((circle, i) => circle.Select(w =>
            $$"""{"en":"{{w.En}}","he":"{{w.He}}","emoji":"{{w.Emoji}}","sentence":"{{w.Sentence}}","circle":{{i + 1}}}"""));
        return $$"""
            {"people":[{"name":"מיכל","role":"לקוחה קבועה","emoji":"👩"},{"name":"דנה","role":"הספרית של הסטודיו","emoji":"💇"},
             {"name":"עומר","role":"השליח","emoji":"🧑"}],"words":[{{string.Join(",", words)}}]}
            """;
    }

    /// <summary>The lesson's world is settled first, as it is when a learner opens the app, and then the guide is asked for.</summary>
    private static async Task<(Arranged Arranged, WorldGuide Guide)> ArrangeGuide(FakeLlm llm, string guide)
    {
        llm.CoachReply = World();
        var arranged = await Arrange(llm);
        await arranged.Service.GetAsync(arranged.ChildId, LessonService.FractionsMixer);
        llm.Requests.Clear();
        llm.CoachReply = guide;
        return (arranged, (await arranged.Service.GuideAsync(arranged.ChildId))!);
    }

    [Fact]
    public async Task The_people_and_words_of_the_world_are_written_once_and_kept()
    {
        var llm = new FakeLlm();
        var (arranged, guide) = await ArrangeGuide(llm, Guide());
        var calls = llm.Requests.Count;
        var again = await arranged.Service.GuideAsync(arranged.ChildId);

        Assert.Equal(["מיכל", "דנה", "עומר"], guide.People.Select(p => p.Name));
        Assert.Equal("lipstick", guide.Words[0].En);
        Assert.Equal(guide.Words, again!.Words);
        Assert.Equal(calls, llm.Requests.Count);

        // The model is told the world and the confirmed interests, and never the learner's name or fears.
        var sent = FakeLlm.AllText(llm.CoachRequests.Single());
        Assert.Contains("סטודיו ללק", sent);
        Assert.Contains("איפור", sent);
        Assert.DoesNotContain("נועה", sent);
        Assert.DoesNotContain("מבחנים", sent);
        Assert.DoesNotContain("סוסים", sent);
    }

    [Fact]
    public async Task With_no_interests_on_file_the_built_in_guide_is_used_and_the_model_is_not_called()
    {
        var llm = new FakeLlm { CoachReply = Guide() };
        var arranged = await Arrange(llm, withInterests: false);

        var guide = await arranged.Service.GuideAsync(arranged.ChildId);

        Assert.Same(WorldGuide.Default, guide);
        Assert.Empty(llm.Requests);
    }

    [Theory]
    [InlineData("💄", "The lipstick is on the table.")]   // two words of one circle share a picture
    [InlineData("🪞", "The lipstick is next to a lipstick.")]   // a gap cannot be cut in this sentence
    [InlineData("🪞", "השפתון על השולחן.")]   // not English
    [InlineData("🪞", "The mirror is on the table.")]   // the sentence does not hold its word
    public async Task A_guide_that_code_cannot_use_falls_back_to_the_built_in_one(string secondEmoji, string firstSentence)
    {
        var llm = new FakeLlm();
        var (arranged, guide) = await ArrangeGuide(llm, Guide(secondEmoji, firstSentence));

        Assert.Same(WorldGuide.Default, guide);
        // It is not asked for again on every visit.
        var calls = llm.Requests.Count;
        await arranged.Service.GuideAsync(arranged.ChildId);
        Assert.Equal(calls, llm.Requests.Count);
    }

    [Fact]
    public async Task A_guide_withheld_by_the_review_is_never_shown_to_the_learner()
    {
        var llm = new FakeLlm { Review = FakeLlm.ReviewPass };
        llm.Reviews.Enqueue(FakeLlm.ReviewPass);   // the lesson's world
        var arrangedWorld = World();
        llm.CoachReply = arrangedWorld;
        var arranged = await Arrange(llm);
        await arranged.Service.GetAsync(arranged.ChildId, LessonService.FractionsMixer);

        llm.CoachReply = Guide();
        llm.Review = FakeLlm.ReviewBlock;
        var guide = await arranged.Service.GuideAsync(arranged.ChildId);

        Assert.Same(WorldGuide.Default, guide);
        Assert.Contains(arranged.Db.SafetyEvents, e => e.Category == "guide_withheld");
    }

    [Fact]
    public async Task When_the_model_is_unreachable_the_built_in_guide_is_used_and_the_model_is_asked_again_later()
    {
        var llm = new FakeLlm();
        var (arranged, _) = await ArrangeGuide(llm, Guide());
        // A second learner state: the guide is thrown away and the model goes down.
        arranged.Db.ChildLessons.RemoveRange(arranged.Db.ChildLessons.Where(l => l.LessonId == LessonService.WorldGuideId));
        await arranged.Db.SaveChangesAsync();

        llm.Throw = new LlmUnavailableException("down", new Exception());
        Assert.Same(WorldGuide.Default, await arranged.Service.GuideAsync(arranged.ChildId));

        llm.Throw = null;
        var guide = await arranged.Service.GuideAsync(arranged.ChildId);
        Assert.Equal("lipstick", guide!.Words[0].En);
    }

    [Fact]
    public void The_built_in_guide_passes_the_same_checks_as_the_models()
    {
        Assert.Null(WorldGuideAgent.Validate(WorldGuide.Default));
    }

    [Fact]
    public async Task A_wider_circle_opens_when_the_one_before_has_settled_and_never_closes_again()
    {
        var llm = new FakeLlm();
        var arranged = await Arrange(llm, withInterests: false);
        var at = TestSupport.Clock().GetUtcNow().AddHours(-5);
        async Task Record(int circle, bool gotIt, int times)
        {
            for (var i = 0; i < times; i++)
            {
                at = at.AddMinutes(1);
                arranged.Db.PracticeRecords.Add(new PracticeRecord
                {
                    Id = Guid.NewGuid(), ChildId = arranged.ChildId, SubtopicId = $"{LessonService.WordsPrefix}{circle}",
                    GotIt = gotIt, CreatedAt = at,
                });
            }
            await arranged.Db.SaveChangesAsync();
        }

        Assert.Equal(1, await arranged.Service.OpenCircleAsync(arranged.ChildId));

        await Record(1, gotIt: true, LessonService.ToOpenNextCircle - 1);
        Assert.Equal(1, await arranged.Service.OpenCircleAsync(arranged.ChildId));

        // Enough words known, but the latest ones are not going well yet.
        await Record(1, gotIt: true, 1);
        await Record(1, gotIt: false, 2);
        Assert.Equal(1, await arranged.Service.OpenCircleAsync(arranged.ChildId));

        await Record(1, gotIt: true, 2);
        Assert.Equal(2, await arranged.Service.OpenCircleAsync(arranged.ChildId));

        // Once she has played in the second circle, a hard day in the first does not take it away.
        await Record(2, gotIt: true, 1);
        await Record(1, gotIt: false, 3);
        Assert.Equal(2, await arranged.Service.OpenCircleAsync(arranged.ChildId));
    }

    [Fact]
    public void A_word_question_offers_three_different_choices_and_its_answer_is_the_word_asked_about()
    {
        var guide = WorldGuide.Default;
        var kinds = new HashSet<string>();
        for (var circle = 1; circle <= WorldGuide.Circles; circle++)
        {
            for (var seed = 0; seed < 200; seed++)
            {
                var question = WordQuestions.Make(guide, circle, seed);
                var right = question.Choices![(int)question.Answer.Numerator];
                // The first step of the solution names the word: its picture and meaning, and the English.
                var word = guide.Words.Single(w => w.En == question.Steps[0].Math);

                Assert.Equal(circle, word.Circle);
                Assert.Equal(3, question.Choices.Distinct().Count());
                Assert.True(right == word.En || right == $"{word.Emoji} {word.He}");
                if (question.Ask.Math!.Contains("___"))
                    Assert.Equal(word.Sentence, question.Ask.Math.Replace("___", word.En));
                Assert.Equal(question, WordQuestions.Make(guide, circle, seed) with { Steps = question.Steps, Choices = question.Choices });
                kinds.Add(question.Ask.Text);
            }
        }
        Assert.Equal(3, kinds.Count);
    }
}
