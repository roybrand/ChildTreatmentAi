using ChildTreatment.Api.Learning;

namespace ChildTreatment.Api.Tests;

public class CurriculumTests
{
    private static readonly Curriculum Curriculum =
        new(Path.Combine(Path.GetDirectoryName(TestSupport.PromptsRoot)!, "curriculum", "math-il.json"));

    private static IEnumerable<Subtopic> Subtopics =>
        Curriculum.File.Grades.SelectMany(g => g.Topics).SelectMany(t => t.Subtopics);

    [Fact]
    public void Each_grade_adds_up_to_the_hours_the_ministry_gives_it()
    {
        Assert.Equal([5, 6, 7, 8, 9], Curriculum.File.Grades.Select(g => g.Grade));
        // Grades 7 to 9 were read from the Ministry's document with their hours. Grades 5 and 6 hold topic names only.
        foreach (var grade in Curriculum.File.Grades.Where(g => g.Grade >= 7))
        {
            Assert.Equal(150, grade.Hours);
            Assert.Equal(grade.Hours, grade.Topics.Sum(t => t.Hours));
        }
    }

    [Fact]
    public void Hours_by_domain_match_the_ministrys_split()
    {
        int Hours(int grade, string domain) =>
            Curriculum.File.Grades.Single(g => g.Grade == grade).Topics.Where(t => t.Domain == domain).Sum(t => t.Hours);

        Assert.Equal((68, 30, 52), (Hours(7, "algebra"), Hours(7, "number"), Hours(7, "geometry")));
        Assert.Equal((58, 54, 38), (Hours(8, "algebra"), Hours(8, "number"), Hours(8, "geometry")));
        Assert.Equal((90, 60), (Hours(9, "algebra"), Hours(9, "geometry")));
    }

    [Fact]
    public void A_lesson_named_by_a_sub_topic_is_one_that_exists()
    {
        var lessons = Subtopics.Where(s => s.Lesson is not null).Select(s => s.Lesson!).ToList();
        Assert.NotEmpty(lessons);
        Assert.All(lessons, lesson => Assert.Contains(lesson, LessonService.Lessons));
    }

    [Fact]
    public void Every_id_is_unique_and_every_named_generator_exists()
    {
        var ids = Subtopics.Select(s => s.Id).Concat(Curriculum.File.Grades.SelectMany(g => g.Topics).Select(t => t.Id)).ToList();
        Assert.Equal(ids.Count, ids.Distinct().Count());

        foreach (var subtopic in Subtopics.Where(s => s.Generator is not null))
            Assert.Contains(subtopic.Generator, QuestionBank.Generators);
        // No generator is left without a place in the curriculum.
        Assert.Empty(QuestionBank.Generators.Except(Subtopics.Select(s => s.Generator)));
    }

    [Fact]
    public void Every_generator_makes_questions_that_its_own_answer_solves()
    {
        foreach (var generator in QuestionBank.Generators)
        {
            for (var seed = 0; seed < 300; seed++)
            {
                var question = QuestionBank.Make(generator, seed);
                Assert.False(string.IsNullOrWhiteSpace(question.Ask.Text), generator);
                Assert.NotEmpty(question.Steps);
                Assert.True(question.Answer.Denominator > 0, generator);

                // The same seed gives the same question, so an answer can be checked later.
                var again = QuestionBank.Make(generator, seed);
                Assert.Equal(question.Ask, again.Ask);
                Assert.Equal(question.Answer, again.Answer);

                // The answer as the app would show it reads back as the same number.
                Assert.True(Rational.TryParse(question.Answer.ToString(), out var parsed), generator);
                Assert.Equal(question.Answer, parsed);
            }
        }
    }

    [Fact]
    public void The_arithmetic_of_a_few_generators_is_right_by_an_independent_check()
    {
        for (var seed = 0; seed < 200; seed++)
        {
            // Pythagoras: the answer squared is the sum of the squares in the question.
            var q = QuestionBank.Make("pythagoras", seed);
            var numbers = System.Text.RegularExpressions.Regex.Matches(q.Ask.Text, @"\d+").Select(m => int.Parse(m.Value)).ToList();
            Assert.Equal(numbers[0] * numbers[0] + numbers[1] * numbers[1], (int)(q.Answer.Numerator * q.Answer.Numerator));

            // A linear equation: putting the answer back into a·x + b gives the right-hand side.
            var e = QuestionBank.Make("linear-equation", seed);
            var parts = System.Text.RegularExpressions.Regex.Matches(e.Ask.Math!, @"\d+").Select(m => int.Parse(m.Value)).ToList();
            Assert.Equal(parts[2], parts[0] * (int)e.Answer.Numerator + parts[1]);

            // A quadratic: the answer is a root of x² − s·x + p.
            var d = QuestionBank.Make("quadratic-root", seed);
            var coefficients = System.Text.RegularExpressions.Regex.Matches(d.Ask.Math!.Replace("²", ""), @"\d+").Select(m => int.Parse(m.Value)).ToList();
            var root = (int)d.Answer.Numerator;
            Assert.Equal(0, root * root - coefficients[0] * root + coefficients[1]);
        }
    }

    [Fact]
    public void A_question_told_as_a_story_has_the_same_numbers_answer_and_steps_as_the_plain_one()
    {
        var story = new Story("סטודיו לק ג'ל", "בקבוקי לק");
        foreach (var generator in QuestionBank.Generators)
        {
            for (var seed = 0; seed < 100; seed++)
            {
                var plain = QuestionBank.Make(generator, seed);
                var told = QuestionBank.Make(generator, seed, story);
                Assert.Equal(plain.Answer, told.Answer);
                Assert.Equal(plain.Steps, told.Steps);
                Assert.Equal(plain.Ask.Math, told.Ask.Math);
                // A generator with a story names the place; one without is unchanged.
                Assert.Equal(QuestionBank.WithStory.Contains(generator), told.Ask.Text.Contains(story.Place));
                Assert.Equal(!QuestionBank.WithStory.Contains(generator), plain.Ask.Text == told.Ask.Text);
            }
        }
    }

    [Theory]
    [InlineData("3/8", 3, 8)]
    [InlineData("0.375", 3, 8)]
    [InlineData(" 6 / 16 ", 3, 8)]
    [InlineData("-5", -5, 1)]
    [InlineData("−5", -5, 1)]
    [InlineData("2,5", 5, 2)]
    public void An_answer_can_be_typed_as_a_whole_number_a_fraction_or_a_decimal(string text, int top, int bottom)
    {
        Assert.True(Rational.TryParse(text, out var value));
        Assert.Equal(new Rational(top, bottom), value);
    }

    [Theory]
    [InlineData("")]
    [InlineData("abc")]
    [InlineData("1/0")]
    [InlineData(null)]
    public void Text_that_is_not_a_number_is_not_an_answer(string? text)
    {
        Assert.False(Rational.TryParse(text, out _));
    }

    [Fact]
    public void The_picture_of_a_solution_shows_the_same_numbers_as_the_answer()
    {
        for (var seed = 0; seed < 200; seed++)
        {
            // Shelves: the first shelf holds the answer, and both shelves together hold everything.
            var share = QuestionBank.Make("ratio-share", seed);
            var s = share.Visual!.Numbers;
            Assert.Equal("shelves", share.Visual.Kind);
            Assert.Equal(share.Answer, (Rational)(s[0] * s[2]));
            var total = int.Parse(System.Text.RegularExpressions.Regex.Match(share.Ask.Text, @"\d+").Value);
            Assert.Equal(total, (s[0] + s[1]) * s[2]);

            // The second explanation deals out round by round and ends on the whole amount and the answer.
            var rounds = share.More!.Where(l => l.Text.StartsWith("סיבוב")).ToList();
            Assert.Equal(s[2], rounds.Count);
            Assert.EndsWith($"= {total}", rounds[^1].Math);
            Assert.Equal(share.Answer.ToString(), share.More![^1].Math);

            // Percent: the part drawn is the percent of the whole.
            var percent = QuestionBank.Make("percent-of", seed);
            var p = percent.Visual!.Numbers;
            Assert.Equal(percent.Answer, (Rational)p[2]);
            Assert.Equal(p[2] * 100, p[0] * p[1]);
        }
    }

    [Fact]
    public void An_easy_question_is_the_same_kind_with_smaller_numbers_and_is_still_solved_by_its_answer()
    {
        static long Largest(Question q) => System.Text.RegularExpressions.Regex
            .Matches(q.Ask.Text + " " + q.Ask.Math, @"\d+").Select(m => long.Parse(m.Value)).DefaultIfEmpty(0).Max();

        foreach (var generator in QuestionBank.Generators)
        {
            long usual = 0, easy = 0;
            for (var seed = 0; seed < 200; seed++)
            {
                var question = QuestionBank.Make(generator, seed, easy: true);
                Assert.NotEmpty(question.Steps);
                Assert.Equal(question.Answer, QuestionBank.Make(generator, seed, easy: true).Answer);
                usual += Largest(QuestionBank.Make(generator, seed));
                easy += Largest(question);
            }
            // Over many questions the numbers are no larger, and for nearly every kind they are smaller.
            Assert.True(easy <= usual, generator);
        }

        // An easy question is checked as an easy one: its id carries the mark.
        var handed = Curriculum.Questions("g8-ratio-share", 3, new Random(5), easy: true)!;
        Assert.All(handed, q => Assert.EndsWith(":e", q.Id));
        var shown = Curriculum.Check(handed[0].Id, "")!;
        Assert.True(Curriculum.Check(handed[0].Id, shown.Answer)!.Same);
    }

    [Fact]
    public void A_sub_topic_comes_back_when_the_latest_questions_did_not_go_well()
    {
        var start = new DateTimeOffset(2026, 10, 4, 9, 0, 0, TimeSpan.Zero);
        List<ChildTreatment.Api.Data.PracticeRecord> Records(string subtopic, params bool[] gotIt) =>
            gotIt.Select((g, i) => new ChildTreatment.Api.Data.PracticeRecord
            {
                SubtopicId = subtopic, GotIt = g, CreatedAt = start.AddMinutes(i),
            }).ToList();

        var progress = PracticeProgress.Of([
            .. Records("one-miss", false),
            .. Records("one-hit", true),
            .. Records("got-better", false, false, true, true),
            .. Records("got-worse", true, true, true, false, false),
            // Practised long ago: it counts in the total and not in this week.
            new ChildTreatment.Api.Data.PracticeRecord { SubtopicId = "long-ago", GotIt = true, CreatedAt = start.AddDays(-30) },
        ], start.AddHours(1)).ToDictionary(p => p.SubtopicId);

        Assert.Equal((1, 0), (progress["long-ago"].Tried, progress["long-ago"].TriedThisWeek));
        Assert.Equal((5, 3), (progress["got-worse"].TriedThisWeek, progress["got-worse"].GotItThisWeek));
        Assert.Equal(start.AddMinutes(4), progress["got-worse"].LastAt);

        Assert.True(progress["one-miss"].ComeBack);
        Assert.False(progress["one-hit"].ComeBack);
        // Only the latest three count: early misses are forgotten once it goes well.
        Assert.False(progress["got-better"].ComeBack);
        Assert.True(progress["got-worse"].ComeBack);
        Assert.Equal((5, 3), (progress["got-worse"].Tried, progress["got-worse"].GotIt));
    }

    [Fact]
    public void A_question_handed_out_can_be_checked_later_by_its_id()
    {
        var questions = Curriculum.Questions("g8-probability", 5, new Random(1))!;
        Assert.Equal(5, questions.Count);
        Assert.Equal(5, questions.Select(q => q.Text).Distinct().Count());

        var question = questions[0];
        var shown = Curriculum.Check(question.Id, "not a number")!;
        Assert.False(shown.Same);
        Assert.NotEmpty(shown.Steps);
        Assert.True(Curriculum.Check(question.Id, shown.Answer)!.Same);
    }

    [Fact]
    public void A_sub_topic_without_questions_and_an_unknown_question_are_not_found()
    {
        Assert.Null(Curriculum.Questions("g9-contradiction-proofs", 5, new Random(1)));
        Assert.Null(Curriculum.Questions("no-such-topic", 5, new Random(1)));
        Assert.Null(Curriculum.Check("no-such-topic:1", "1"));
        Assert.Null(Curriculum.Check("garbage", "1"));
    }
}
