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
        Assert.Equal([7, 8, 9], Curriculum.File.Grades.Select(g => g.Grade));
        foreach (var grade in Curriculum.File.Grades)
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
