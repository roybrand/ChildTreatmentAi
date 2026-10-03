using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;

namespace ChildTreatment.Api.Tests;

public class CrisisRulesTests
{
    private readonly CrisisRules _rules = TestSupport.Rules();

    [Theory]
    [InlineData("מצאתי אתמול שהיא חותכת את עצמה ביד", "self_harm")]
    [InlineData("הוא אמר לי שהוא לא רוצה לחיות יותר", "self_harm")]
    [InlineData("היא אמרה שהיא מעדיפה למות ולא ללכת לבית הספר", "self_harm")]
    [InlineData("הוּא רוֹצֶה לָמוּת", "self_harm")]
    [InlineData("She said she wants to die", "self_harm")]
    [InlineData("I think he is SUICIDAL", "self_harm")]
    [InlineData("הוא איים להרוג את אחיו", "harm_to_others")]
    [InlineData("אבא שלה מרביץ לה", "abuse")]
    [InlineData("היא לא יוצאת מהמיטה כבר ארבעה ימים", "severe_decline")]
    [InlineData("He has stopped eating", "severe_decline")]
    public void Flags_crisis_language(string text, string category)
    {
        Assert.Equal(category, _rules.Check(text)?.Category);
    }

    [Theory]
    [InlineData("היא מפחדת לישון לבד ובוכה כל לילה")]
    [InlineData("הוא שאל אותי עשר פעמים אם אני אחזור הביתה")]
    [InlineData("She is in a stable mood and well established at school")]
    [InlineData("We want to establish a routine")]
    [InlineData("")]
    [InlineData(null)]
    public void Leaves_ordinary_messages_alone(string? text)
    {
        Assert.Null(_rules.Check(text));
    }

    [Theory]
    [InlineData("parent-coach")]
    [InlineData("profile-agent")]
    public void The_rules_stop_exactly_the_scenarios_marked_as_crisis(string agent)
    {
        var scenarios = TestSupport.Scenarios(agent);
        Assert.Contains(scenarios, s => s.Expect == "crisis");

        foreach (var scenario in scenarios)
        {
            var hit = _rules.Check(scenario.LastParentMessage);
            if (scenario.Expect == "crisis")
                Assert.True(hit is not null, $"{scenario.Id} should be stopped by the rules");
            else
                Assert.True(hit is null, $"{scenario.Id} should reach the coach but matched '{hit?.Category}'");
        }
    }
}

public class FieldProtectorTests
{
    [Fact]
    public void Round_trips_text_and_does_not_store_it_readable()
    {
        const string text = "נועה פחדה ללכת לבית הספר";
        var stored = TestSupport.Protector.Protect(text);

        Assert.StartsWith("enc1:", stored);
        Assert.DoesNotContain("נועה", stored);
        Assert.Equal(text, TestSupport.Protector.Unprotect(stored));
    }

    [Fact]
    public void The_same_text_is_stored_differently_each_time()
    {
        Assert.NotEqual(TestSupport.Protector.Protect("abc"), TestSupport.Protector.Protect("abc"));
    }
}

public class PseudonymizerTests
{
    [Theory]
    [InlineData("נועה בכתה בבוקר", "[CHILD] בכתה בבוקר")]
    [InlineData("אמרתי לנועה שאני סומך עליה", "אמרתי ל[CHILD] שאני סומך עליה")]
    [InlineData("כשנועה ואני יצאנו", "כש[CHILD] ואני יצאנו")]
    [InlineData("זה היה קשה, נועה.", "זה היה קשה, [CHILD].")]
    public void Hides_the_name_with_hebrew_prefixes(string text, string expected)
    {
        Assert.Equal(expected, new Pseudonymizer("נועה").Hide(text));
    }

    [Fact]
    public void Does_not_touch_a_longer_word_that_contains_the_name()
    {
        // "טל" is a name; "מוטלת" is an unrelated word that contains it.
        Assert.Equal("המשימה מוטלת עליי", new Pseudonymizer("טל").Hide("המשימה מוטלת עליי"));
    }

    [Fact]
    public void Restores_the_name_in_a_reply()
    {
        var names = new Pseudonymizer("נועה");
        Assert.Equal("אפשר לומר לנועה: אני יודע שזה מפחיד", names.Restore("אפשר לומר ל[CHILD]: אני יודע שזה מפחיד"));
    }

    [Fact]
    public void Works_for_latin_names_in_any_case()
    {
        Assert.Equal("[CHILD] cried, and [CHILD] slept", new Pseudonymizer("Noa").Hide("Noa cried, and noa slept"));
    }
}
