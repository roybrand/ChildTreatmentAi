namespace ChildTreatment.Api.Learning;

/// <summary>
/// Makes English grammar questions: a sentence with a gap, and a few words to choose from.
/// The sentences are put together by code from small word lists whose forms are written out by hand,
/// so every sentence is correct English and every answer is known. No model is involved.
/// </summary>
public static class EnglishBank
{
    private const string Choose = "בחרו את המילה שמשלימה את המשפט.";

    /// <summary>A verb with its forms written out, and something that can follow it.</summary>
    private sealed record Verb(string Base, string S, string Ing, string Past, string Participle, string After);

    private static readonly Verb[] Verbs =
    [
        new("play", "plays", "playing", "played", "played", "football"),
        new("eat", "eats", "eating", "ate", "eaten", "an apple"),
        new("make", "makes", "making", "made", "made", "a cake"),
        new("write", "writes", "writing", "wrote", "written", "a letter"),
        new("buy", "buys", "buying", "bought", "bought", "a new bag"),
        new("see", "sees", "seeing", "saw", "seen", "the film"),
        new("take", "takes", "taking", "took", "taken", "the bus"),
        new("clean", "cleans", "cleaning", "cleaned", "cleaned", "the room"),
        new("watch", "watches", "watching", "watched", "watched", "a film"),
        new("paint", "paints", "painting", "painted", "painted", "the door"),
        new("open", "opens", "opening", "opened", "opened", "the window"),
        new("wash", "washes", "washing", "washed", "washed", "the car"),
        new("cook", "cooks", "cooking", "cooked", "cooked", "dinner"),
        new("read", "reads", "reading", "read", "read", "a book"),
    ];

    // Verbs whose object can be the subject of a passive sentence: "The room is cleaned."
    private static readonly (string Thing, Verb Verb)[] Passives =
    [
        ("The room", Verbs[7]), ("The door", Verbs[9]), ("The window", Verbs[10]), ("The car", Verbs[11]),
        ("The cake", Verbs[2]), ("The letter", Verbs[3]), ("Dinner", Verbs[12]),
    ];

    private static readonly (string Word, bool Third, bool Plural)[] Subjects =
    [
        ("I", false, false), ("You", false, true), ("He", true, false), ("She", true, false),
        ("We", false, true), ("They", false, true), ("Dana", true, false), ("My brother", true, false),
        ("The children", false, true),
    ];

    /// <summary>An adjective with its comparative and superlative.</summary>
    private static readonly (string Base, string Comparative, string Superlative)[] Adjectives =
    [
        ("tall", "taller", "tallest"), ("fast", "faster", "fastest"), ("old", "older", "oldest"),
        ("big", "bigger", "biggest"), ("easy", "easier", "easiest"), ("happy", "happier", "happiest"),
        ("expensive", "more expensive", "most expensive"), ("beautiful", "more beautiful", "most beautiful"),
        ("interesting", "more interesting", "most interesting"), ("good", "better", "best"),
    ];

    public static readonly IReadOnlyDictionary<string, Func<Random, Question>> Makers =
        new Dictionary<string, Func<Random, Question>>
        {
            // ---- Grades 5 and 6 ----
            ["en-to-be"] = r =>
            {
                var (subject, third, plural) = Pick(r, Subjects);
                var after = Pick(r, "happy", "at home", "tired", "in the garden", "ready");
                var right = subject == "I" ? "am" : third && !plural ? "is" : "are";
                return Gap(r, $"{subject} ___ {after}.", right, ["am", "is", "are"],
                    "אחרי I בא am. אחרי he, she, it או שם של אחד בא is. אחרי you, we, they או רבים בא are.");
            },
            ["en-there-is"] = r =>
            {
                var (thing, plural) = Pick(r, ("a book", false), ("two books", true), ("a cat", false), ("three cats", true),
                    ("an apple", false), ("many apples", true), ("a bag", false), ("some bags", true));
                var place = Pick(r, "on the table", "in the room", "in the garden", "under the chair");
                return Gap(r, $"There ___ {thing} {place}.", plural ? "are" : "is", ["is", "are", "am"],
                    "There is לדבר אחד. There are לכמה דברים.");
            },
            ["en-articles"] = r =>
            {
                var (noun, an) = Pick(r, ("apple", true), ("book", false), ("orange", true), ("dog", false),
                    ("egg", true), ("car", false), ("umbrella", true), ("house", false), ("ice cream", true), ("pen", false));
                var start = Pick(r, "I have", "This is", "Dana has", "We need", "I can see", "He wants");
                return Gap(r, $"{start} ___ {noun}.", an ? "an" : "a", ["a", "an"],
                    "לפני מילה שמתחילה בצליל של תנועה (a, e, i, o, u) בא an. לפני כל צליל אחר בא a.");
            },
            ["en-present-simple"] = r =>
            {
                var (subject, third, _) = Pick(r, Subjects);
                var verb = Pick(r, Verbs);
                return Gap(r, $"{subject} ___ {verb.After} every day.", third ? verb.S : verb.Base, [verb.Base, verb.S, verb.Ing],
                    "ב-Present Simple מוסיפים s לפועל רק אחרי he, she, it או שם של אחד. המילים every day מראות שזה קורה תמיד.");
            },
            ["en-can"] = r =>
            {
                var (subject, _, _) = Pick(r, Subjects);
                var verb = Pick(r, Verbs);
                return Gap(r, $"{subject} can ___ {verb.After}.", verb.Base, [verb.Base, verb.S, verb.Ing],
                    "אחרי can הפועל תמיד בצורת הבסיס: בלי s, בלי ing, ולא משנה מי עושה.");
            },
            ["en-present-progressive"] = r =>
            {
                var (subject, third, plural) = Pick(r, Subjects);
                var verb = Pick(r, Verbs);
                var be = subject == "I" ? "am" : third && !plural ? "is" : "are";
                return Gap(r, $"Look! {subject} ___ {verb.After} now.", $"{be} {verb.Ing}", [$"{be} {verb.Ing}", verb.S, verb.Base],
                    "כשמשהו קורה ממש עכשיו משתמשים ב-Present Progressive: am, is או are, ואחריו פועל עם ing. המילה now מראה את זה.");
            },
            ["en-was-were"] = r =>
            {
                var (subject, third, plural) = Pick(r, Subjects);
                var after = Pick(r, "at home", "at school", "happy", "in the park", "tired");
                var right = subject == "I" || (third && !plural) ? "was" : "were";
                return Gap(r, $"{subject} ___ {after} yesterday.", right, ["was", "were", "is"],
                    "בעבר: was אחרי I, he, she, it או שם של אחד. were אחרי you, we, they או רבים. המילה yesterday מראה שזה עבר.");
            },
            ["en-past-simple"] = r =>
            {
                var (subject, _, _) = Pick(r, Subjects);
                var verb = Pick(r, Verbs.Where(v => v.Past != v.Base).ToArray());
                return Gap(r, $"Yesterday {Lower(subject)} ___ {verb.After}.", verb.Past, [verb.Past, verb.Base, verb.S],
                    verb.Past.EndsWith("ed", StringComparison.Ordinal)
                        ? "בעבר (Past Simple) מוסיפים ed לפועל רגיל. הצורה זהה לכל הגופים."
                        : $"בעבר (Past Simple) לחלק מהפעלים יש צורה מיוחדת שצריך לזכור. העבר של {verb.Base} הוא {verb.Past}.");
            },
            ["en-possessive"] = r =>
            {
                var (owner, right, others) = Pick(r,
                    ("I have a dog.", "my", new[] { "me", "I" }), ("She has a dog.", "her", new[] { "she", "hers" }),
                    ("He has a dog.", "his", new[] { "he", "him" }), ("We have a dog.", "our", new[] { "we", "us" }),
                    ("They have a dog.", "their", new[] { "they", "them" }), ("You have a dog.", "your", new[] { "you", "yours" }));
                return Gap(r, $"{owner} It is ___ dog.", right, [right, .. others],
                    "לפני שם עצם באה מילת שייכות: my, your, his, her, our, their.");
            },

            // ---- Grade 7 ----
            ["en-simple-or-progressive"] = r =>
            {
                var verb = Pick(r, Verbs);
                var now = r.Next(2) == 0;
                var who = Pick(r, "She", "He", "Dana", "My brother", "My friend");
                var when = now ? Pick(r, "at the moment", "right now", "now") : Pick(r, "every week", "every day", "on Sundays");
                return Gap(r, $"{who} ___ {verb.After} {when}.",
                    now ? $"is {verb.Ing}" : verb.S, [$"is {verb.Ing}", verb.S],
                    $"דבר שקורה תמיד או שוב ושוב: Present Simple. דבר שקורה עכשיו: Present Progressive. כאן המילים {when} מראות מה מתאים.");
            },
            ["en-past-negative"] = r =>
            {
                var (subject, _, _) = Pick(r, Subjects);
                var verb = Pick(r, Verbs);
                return Gap(r, $"{subject} ___ {verb.Base} {verb.After} yesterday.", "didn't", ["didn't", "doesn't", "wasn't"],
                    "שלילה בעבר: didn't ואחריו הפועל בצורת הבסיס, לכל הגופים.");
            },
            ["en-going-to"] = r =>
            {
                var verb = Pick(r, Verbs);
                var start = Pick(r, "Tomorrow we are going", "Next week I am going", "Tonight Dana is going",
                    "On Friday they are going", "After school he is going", "This evening my friends are going");
                return Gap(r, $"{start} ___ {verb.After}.", $"to {verb.Base}", [$"to {verb.Base}", verb.Ing, verb.Base],
                    "תוכנית לעתיד: am, is או are, אחריו going to, ואחריו הפועל בצורת הבסיס.");
            },
            ["en-comparative"] = r =>
            {
                // Each pair is compared only by adjectives that make sense for it.
                var (a, b, fitting) = Pick(r,
                    ("This bag", "that bag", new[] { "expensive", "big", "old", "beautiful", "good" }),
                    ("My brother", "my sister", new[] { "tall", "old", "fast", "happy" }),
                    ("The red car", "the blue car", new[] { "fast", "old", "big", "expensive", "good" }),
                    ("This book", "that book", new[] { "interesting", "old", "big", "good", "easy" }));
                var chosen = Pick(r, fitting);
                var adjective = Adjectives.First(x => x.Base == chosen);
                return Gap(r, $"{a} is ___ than {b}.", adjective.Comparative, [adjective.Base, adjective.Comparative, adjective.Superlative],
                    "כשמשווים בין שניים, ואחרי זה בא than: לתואר קצר מוסיפים er, ולפני תואר ארוך בא more. יש גם יוצאי דופן, כמו good ו-better.");
            },
            ["en-superlative"] = r =>
            {
                var (sentence, fitting) = Pick(r,
                    ("He is the ___ boy in the class.", new[] { "tall", "fast", "happy", "old" }),
                    ("It is the ___ bag in the shop.", new[] { "expensive", "big", "beautiful", "good", "old" }),
                    ("It is the ___ book in the library.", new[] { "interesting", "old", "good", "big", "easy" }),
                    ("She is the ___ girl in the team.", new[] { "tall", "fast", "happy" }),
                    ("This is the ___ car in the street.", new[] { "fast", "old", "big", "expensive", "good" }),
                    ("It is the ___ house in the town.", new[] { "big", "old", "beautiful", "expensive" }),
                    ("This is the ___ film of the year.", new[] { "interesting", "good", "beautiful" }));
                var chosen = Pick(r, fitting);
                var adjective = Adjectives.First(x => x.Base == chosen);
                return Gap(r, sentence, adjective.Superlative, [adjective.Base, adjective.Comparative, adjective.Superlative],
                    "כשאחד עולה על כל השאר, ולפני זה בא the: לתואר קצר מוסיפים est, ולפני תואר ארוך בא most. יש גם יוצאי דופן, כמו good ו-best.");
            },
            ["en-much-many"] = r =>
            {
                var (noun, count) = Pick(r, ("apples", true), ("water", false), ("books", true), ("money", false),
                    ("friends", true), ("sugar", false), ("bags", true), ("time", false), ("milk", false), ("pens", true));
                var end = Pick(r, "do you have", "do we need", count ? "are there" : "is there", "do they want");
                return Gap(r, $"How ___ {noun} {end}?", count ? "many" : "much", ["much", "many"],
                    "many לדברים שאפשר לספור (apples, books). much לדברים שאי אפשר לספור (water, money, time).");
            },
            ["en-will"] = r =>
            {
                var verb = Pick(r, Verbs);
                var start = Pick(r, "I think she", "Maybe they", "I am sure Dana", "I hope we", "Perhaps my brother");
                var when = Pick(r, "tomorrow", "next week", "on Sunday", "next month");
                return Gap(r, $"{start} ___ {verb.After} {when}.", $"will {verb.Base}", [$"will {verb.Base}", verb.S, verb.Past],
                    $"לעתיד: will ואחריו הפועל בצורת הבסיס, לכל הגופים. המילים {when} מראות שזה עתיד.");
            },
            ["en-should"] = r =>
            {
                var (situation, advice, right) = Pick(r,
                    ("You look tired.", "go to bed early", true), ("It is very cold.", "wear a coat", true),
                    ("You have a test tomorrow.", "stay up all night", false), ("Your teeth hurt.", "eat a lot of sweets", false),
                    ("The room is very dark.", "open the window", true), ("The baby is sleeping.", "make a lot of noise", false));
                return Gap(r, $"{situation} You ___ {advice}.", right ? "should" : "shouldn't", ["should", "shouldn't"],
                    "should לעצה לעשות משהו. shouldn't לעצה לא לעשות. אחרי שתיהן הפועל בצורת הבסיס.");
            },
            ["en-adverbs"] = r =>
            {
                var (sentence, adjective, adverb) = Pick(r, ("She sings", "beautiful", "beautifully"), ("He runs", "quick", "quickly"),
                    ("They speak", "quiet", "quietly"), ("He drives", "careful", "carefully"), ("She writes", "slow", "slowly"),
                    ("They play", "good", "well"));
                return Gap(r, $"{sentence} ___.", adverb, [adjective, adverb],
                    "מילה שמתארת איך עושים פעולה היא תואר הפועל, ובדרך כלל מסתיימת ב-ly. יוצא דופן: good הופך ל-well.");
            },

            // ---- Grade 8 ----
            ["en-past-progressive"] = r =>
            {
                var (subject, third, plural) = Pick(r, Subjects);
                var verb = Pick(r, Verbs);
                var be = subject == "I" || (third && !plural) ? "was" : "were";
                return Gap(r, $"At six o'clock yesterday, {Lower(subject)} ___ {verb.After}.", $"{be} {verb.Ing}",
                    [$"{be} {verb.Ing}", verb.S, verb.Base],
                    "פעולה שהייתה באמצע בזמן מסוים בעבר: was או were, ואחריו פועל עם ing (Past Progressive).");
            },
            ["en-present-perfect"] = r =>
            {
                var verb = Pick(r, Verbs.Where(v => v.Participle != v.Base).ToArray());
                var start = Pick(r, "I have never", "We have already", "Dana has just", "They have never", "She has already", "My friends have just");
                return Gap(r, $"{start} ___ {verb.After}.", verb.Participle, [verb.Participle, verb.Base, verb.Ing],
                    $"ב-Present Perfect, אחרי have או has באה הצורה השלישית של הפועל. הצורה השלישית של {verb.Base} היא {verb.Participle}.");
            },
            ["en-passive"] = r =>
            {
                var (thing, verb) = Pick(r, Passives);
                var past = r.Next(2) == 0;
                return Gap(r, past ? $"{thing} ___ yesterday." : $"{thing} ___ every day.",
                    $"{(past ? "was" : "is")} {verb.Participle}", [$"{(past ? "was" : "is")} {verb.Participle}", verb.S, verb.Ing],
                    "בסביל (Passive) הנושא לא עושה את הפעולה, היא נעשית בו: is או was, ואחריו הצורה השלישית של הפועל.");
            },
            ["en-gerund"] = r =>
            {
                var verb = Pick(r, Verbs);
                var start = Pick(r, "I enjoy", "Dana enjoys", "We finished", "They don't mind", "My brother keeps", "She stopped");
                return Gap(r, $"{start} ___ {verb.After}.", verb.Ing, [verb.Ing, verb.Base, verb.S],
                    "אחרי פעלים כמו enjoy, finish, keep, stop ו-don't mind הפועל בא עם ing. הצורה הזאת נקראת Gerund, והיא מתנהגת כמו שם עצם.");
            },

            // ---- Grade 9 ----
            ["en-first-conditional"] = r =>
            {
                var verb = Pick(r, Verbs);
                var start = Pick(r,
                    "If we have time tomorrow, we", "If it rains on Friday, I", "If Dana comes early, she",
                    "If you help me, we", "If the shop is open, they", "If I finish my homework, I",
                    "If my friends come, we", "If he feels better, he");
                return Gap(r, $"{start} ___ {verb.After}.", $"will {verb.Base}",
                    [$"will {verb.Base}", $"would {verb.Base}", verb.Past],
                    "תנאי אמיתי, שיכול לקרות: אחרי if בא Present Simple, ובחלק השני will ואחריו הפועל בצורת הבסיס.");
            },
            ["en-used-to"] = r =>
            {
                var verb = Pick(r, Verbs);
                var start = Pick(r,
                    "When I was young, I", "Before we moved, we", "Years ago, my brother",
                    "In primary school, they", "When she was six, Dana", "Last year, my friends");
                var often = Pick(r, "every day", "every week", "all the time", "every summer");
                return Gap(r, $"{start} ___ {verb.Base} {verb.After} {often}.", "used to", ["used to", "use to", "am used"],
                    "used to ואחריו פועל בצורת הבסיס: משהו שהיה קורה בקביעות בעבר, והיום כבר לא.");
            },
            ["en-second-conditional"] = r =>
            {
                var verb = Pick(r, Verbs);
                var start = Pick(r,
                    "If I had more time, I", "If we lived near the sea, we", "If Dana had a free day, she",
                    "If they were on holiday, they", "If you were here, we", "If he knew how, he",
                    "If I were older, I", "If we had a big garden, we");
                return Gap(r, $"{start} ___ {verb.After}.", $"would {verb.Base}",
                    [$"would {verb.Base}", $"will {verb.Base}", verb.Past],
                    "תנאי דמיוני, שלא נכון עכשיו: אחרי if בא Past Simple, ובחלק השני would ואחריו הפועל בצורת הבסיס.");
            },
        };

    private static T Pick<T>(Random r, params T[] options) => options[r.Next(options.Length)];

    /// <summary>A subject in the middle of a sentence: lower case, except "I" and names.</summary>
    private static string Lower(string subject) =>
        subject is "I" or "Dana" ? subject : char.ToLowerInvariant(subject[0]) + subject[1..];

    /// <summary>
    /// A sentence with a gap and the words to choose from, in a random order. The answer is the place of
    /// the right word among the choices, so it is checked the same way as a number.
    /// </summary>
    private static Question Gap(Random r, string sentence, string right, string[] options, string rule)
    {
        var choices = options.Distinct().OrderBy(_ => r.Next()).ToList();
        return new Question(
            new Line(Choose, sentence),
            choices.IndexOf(right),
            [new Line(rule), new Line("המשפט המלא:", sentence.Replace("___", right))],
            Choices: choices);
    }
}
