using System.Globalization;
using System.Numerics;

namespace ChildTreatment.Api.Learning;

/// <summary>An exact fraction, so an answer is compared without rounding.</summary>
public readonly record struct Rational
{
    public BigInteger Numerator { get; }
    public BigInteger Denominator { get; }

    public Rational(BigInteger numerator, BigInteger denominator)
    {
        if (denominator.IsZero)
            throw new DivideByZeroException();
        if (denominator.Sign < 0)
            (numerator, denominator) = (-numerator, -denominator);
        var gcd = BigInteger.GreatestCommonDivisor(BigInteger.Abs(numerator), denominator);
        Numerator = numerator / gcd;
        Denominator = denominator / gcd;
    }

    public static implicit operator Rational(int value) => new(value, 1);

    /// <summary>Reads what a learner typed: a whole number, a fraction such as 3/8, or a decimal such as 0.375.</summary>
    public static bool TryParse(string? text, out Rational value)
    {
        value = default;
        text = text?.Trim().Replace('−', '-').Replace(',', '.').Replace(" ", "");
        if (string.IsNullOrEmpty(text) || text.Length > 30)
            return false;

        var parts = text.Split('/');
        if (parts.Length == 2 && TryDecimal(parts[0], out var top) && TryDecimal(parts[1], out var bottom) &&
            !bottom.Numerator.IsZero)
        {
            value = new Rational(top.Numerator * bottom.Denominator, top.Denominator * bottom.Numerator);
            return true;
        }
        return parts.Length == 1 && TryDecimal(text, out value);
    }

    private static bool TryDecimal(string text, out Rational value)
    {
        value = default;
        if (!decimal.TryParse(text, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint,
                CultureInfo.InvariantCulture, out var number))
            return false;

        var scale = (decimal.GetBits(number)[3] >> 16) & 0xFF;
        var denominator = BigInteger.Pow(10, scale);
        value = new Rational(new BigInteger(number * (decimal)denominator), denominator);
        return true;
    }

    public override string ToString() => Denominator.IsOne ? Numerator.ToString() : $"{Numerator}/{Denominator}";
}

/// <summary>A sentence in Hebrew, with an optional line of mathematics shown left to right under it.</summary>
public sealed record Line(string Text, string? Math = null);

/// <summary>
/// The learner's world, for telling a question as a story: the place, and the things made or sold there
/// as a plural noun. The sentences around them are written in code so that they stay grammatical
/// whatever the noun: no verb or adjective in them agrees with it.
/// </summary>
public sealed record Story(string Place, string Items);

/// <summary>One question. Every number in it, its answer, and its explanation are made by code.</summary>
/// <param name="More">A second explanation, told another way, for a learner the first one did not reach.</param>
public sealed record Question(
    Line Ask, Rational Answer, IReadOnlyList<Line> Steps, Visual? Visual = null, IReadOnlyList<Line>? More = null);

/// <summary>
/// A picture of the solution, as numbers for the app to draw. The drawing is the app's; what it shows
/// is decided here, by code, from the same numbers as the answer.
/// </summary>
/// <param name="Kind">shelves: two shelves holding Numbers[0] and Numbers[1] groups of Numbers[2] things each.
/// percent: Numbers[0] percent of Numbers[1] is Numbers[2].</param>
public sealed record Visual(string Kind, IReadOnlyList<int> Numbers);

/// <summary>
/// Makes questions for the sub-topics of the curriculum. A question is rebuilt from its generator's
/// name and a seed, so an answer can be checked later without storing the question.
/// </summary>
public static class QuestionBank
{
    private const string M = "−";

    public static IReadOnlyCollection<string> Generators => Makers.Keys;

    /// <param name="story">When given, a question that has a story is told in this world. The numbers, the
    /// answer, and the steps are the same either way, so an answer is checked without knowing the world.</param>
    /// <param name="easy">Smaller numbers, for the question that follows one the learner did not get.</param>
    public static Question Make(string generator, int seed, Story? story = null, bool easy = false) =>
        Makers[generator](easy ? new EasyRandom(seed) : new Random(seed), story);

    /// <summary>Marks a question as an easy one. Every range a generator draws from is narrowed to its low end.</summary>
    private sealed class EasyRandom(int seed) : Random(seed);

    /// <summary>The generators whose questions can be told as a story from the learner's world.</summary>
    public static readonly IReadOnlySet<string> WithStory = new HashSet<string>
    {
        "order-of-operations", "rectangle-area", "box-volume", "linear-equation", "ratio-share",
        "proportion", "percent-of", "percent-change", "mean",
    };

    private static int R(Random r, int from, int to)
    {
        if (r is not EasyRandom)
            return r.Next(from, to + 1);

        // An easy question keeps the small end of each range, with at least two values to choose from.
        // A range that crosses zero keeps its small positive numbers, since a negative is not easier.
        var low = from < 0 && to > 0 ? 1 : from;
        return r.Next(low, Math.Min(to, low + Math.Max(1, (to - low) / 3)) + 1);
    }
    private static T Pick<T>(Random r, params T[] options) => options[r.Next(options.Length)];
    /// <summary>A number as a term after the first: "+ 5" or "− 5".</summary>
    private static string Plus(int n) => n < 0 ? $"{M} {-n}" : $"+ {n}";
    /// <summary>A number that may be negative, in brackets when it is.</summary>
    private static string N(int n) => n < 0 ? $"({M}{-n})" : $"{n}";
    private static string Sup(int n) => string.Concat(n.ToString().Select(c => c == '-' ? '⁻' : "⁰¹²³⁴⁵⁶⁷⁸⁹"[c - '0']));
    private static Question Q(string ask, string? math, Rational answer, params Line[] steps) =>
        new(new Line(ask, math), answer, steps);

    private static readonly Dictionary<string, Func<Random, Story?, Question>> Makers = new()
    {
        // ---- Grades 5 and 6 ----
        ["equivalent-fraction"] = (r, w) =>
        {
            int b = R(r, 2, 8), a = R(r, 1, b - 1), k = R(r, 2, 6);
            return Q("השלימו כך שיתקבלו שברים שווים. מהו x?", $"{a}/{b} = x/{b * k}", a * k,
                new Line($"המכנה הוכפל ב-{k}.", $"{b}·{k} = {b * k}"),
                new Line("כדי שהשבר יישאר שווה, מכפילים גם את המונה באותו מספר.", $"x = {a}·{k} = {a * k}"));
        },

        // ---- Grade 7 ----
        ["sequence-term"] = (r, w) =>
        {
            int a = R(r, 2, 6), b = R(r, 1, 9), k = R(r, 5, 12);
            return Q($"בסדרה, האיבר במקום ה-n נתון בביטוי שלמטה. מהו האיבר במקום ה-{k}?", $"{a}·n + {b}", a * k + b,
                new Line($"מציבים n = {k} בביטוי.", $"{a}·{k} + {b} = {a * k} + {b} = {a * k + b}"));
        },
        ["substitute"] = (r, w) =>
        {
            int a = R(r, 2, 9), b = R(r, -9, 9), x = R(r, 2, 8);
            return Q($"מהו ערך הביטוי כאשר x = {x}?", $"{a}·x {Plus(b)}", a * x + b,
                new Line($"מציבים {x} במקום x.", $"{a}·{x} {Plus(b)}"),
                new Line("קודם כפל, ואחר כך חיבור או חיסור.", $"{a * x} {Plus(b)} = {a * x + b}"));
        },
        ["like-terms"] = (r, w) =>
        {
            int a = R(r, 2, 9), b = R(r, 2, 9), c = R(r, 1, a + b - 1);
            return Q("מכנסים איברים דומים. מהו המקדם של x בביטוי המכונס?", $"{a}·x + {b}·x {M} {c}·x", a + b - c,
                new Line("לכל האיברים אותו משתנה, אז מחברים ומחסרים את המקדמים.", $"{a} + {b} {M} {c} = {a + b - c}"),
                new Line("הביטוי המכונס:", $"{a + b - c}·x"));
        },
        ["order-of-operations"] = (r, w) =>
        {
            int a = R(r, 2, 20), b = R(r, 2, 9), c = R(r, 2, 9), d = R(r, 1, a + b * c - 1);
            return Q(
                w is null
                    ? "חשבו לפי סדר פעולות החשבון."
                    : $"ב{w.Place}: בקופה {a} שקלים. נכנסו {b} הזמנות של {c} שקלים כל אחת, ויצאו {d} שקלים על חומרים. כמה שקלים יש בקופה עכשיו?",
                $"{a} + {b}·{c} {M} {d}", a + b * c - d,
                new Line("כפל קודם לחיבור ולחיסור.", $"{b}·{c} = {b * c}"),
                new Line("עכשיו משמאל לימין.", $"{a} + {b * c} {M} {d} = {a + b * c - d}"));
        },
        ["power"] = (r, w) =>
        {
            int b = R(r, 2, 5), n = R(r, 2, b <= 3 ? 4 : 3);
            var value = (int)Math.Pow(b, n);
            return Q("חשבו את החזקה.", $"{b}{Sup(n)}", value,
                new Line($"חזקה היא כפל חוזר: {b} כפול עצמו {n} פעמים.", $"{string.Join("·", Enumerable.Repeat(b, n))} = {value}"));
        },
        ["square-root"] = (r, w) =>
        {
            int n = R(r, 2, 15);
            return Q("חשבו את השורש הריבועי.", $"√{n * n}", n,
                new Line("מחפשים מספר חיובי שכפול עצמו נותן את המספר שמתחת לשורש.", $"{n}·{n} = {n * n}"));
        },
        ["rectangle-area"] = (r, w) =>
        {
            int a = R(r, 3, 15), b = R(r, 2, 12);
            return Q(
                w is null
                    ? $"מלבן שאורכו {a} ס\"מ ורוחבו {b} ס\"מ. מהו שטחו בסמ\"ר?"
                    : $"מכינים שלט מלבני ל{w.Place}: אורכו {a} ס\"מ ורוחבו {b} ס\"מ. מהו שטח השלט בסמ\"ר?",
                null, a * b,
                new Line("שטח מלבן הוא אורך כפול רוחב.", $"{a}·{b} = {a * b}"));
        },
        ["box-volume"] = (r, w) =>
        {
            int a = R(r, 2, 10), b = R(r, 2, 8), c = R(r, 2, 6);
            return Q(
                w is null
                    ? $"תיבה שממדיה {a} ס\"מ, {b} ס\"מ ו-{c} ס\"מ. מהו נפחה בסמ\"ק?"
                    : $"קופסת משלוח של {w.Items} מ{w.Place}: ממדיה {a} ס\"מ, {b} ס\"מ ו-{c} ס\"מ. מהו נפח הקופסה בסמ\"ק?",
                null, a * b * c,
                new Line("נפח תיבה הוא מכפלת שלושת הממדים.", $"{a}·{b}·{c} = {a * b * c}"));
        },
        ["box-surface"] = (r, w) =>
        {
            int a = R(r, 2, 8), b = R(r, 2, 6), c = R(r, 2, 5);
            var area = 2 * (a * b + b * c + a * c);
            return Q($"תיבה שממדיה {a} ס\"מ, {b} ס\"מ ו-{c} ס\"מ. מהו שטח הפנים שלה בסמ\"ר?", null, area,
                new Line("לתיבה שלושה זוגות של פאות שוות.", $"{a}·{b} = {a * b},  {b}·{c} = {b * c},  {a}·{c} = {a * c}"),
                new Line("מחברים את שלוש הפאות ומכפילים בשתיים.", $"2·({a * b} + {b * c} + {a * c}) = {area}"));
        },
        ["linear-equation"] = (r, w) =>
        {
            int a = R(r, 2, 9), x = R(r, 1, 12), b = R(r, 1, 20);
            return Q(
                w is null
                    ? "פתרו את המשוואה. מהו x?"
                    : $"הזמנה מ{w.Place}: {a} {w.Items} ועוד {b} שקלים דמי משלוח, יחד {a * x + b} שקלים. מה המחיר ליחידה? במשוואה, x הוא המחיר ליחידה.",
                $"{a}·x + {b} = {a * x + b}", x,
                new Line($"מחסרים {b} משני האגפים.", $"{a}·x = {a * x}"),
                new Line($"מחלקים את שני האגפים ב-{a}.", $"x = {x}"));
        },
        ["signed-add"] = (r, w) =>
        {
            int a = R(r, 2, 15), b = R(r, 2, 15);
            return Pick(r, 0, 1) == 0
                ? Q("חשבו.", $"({M}{a}) + {b}", b - a,
                    new Line($"על ציר המספרים: מתחילים ב-{M}{a} וזזים {b} צעדים ימינה.", $"({M}{a}) + {b} = {N(b - a)}"))
                : Q("חשבו.", $"{a} {M} ({M}{b})", a + b,
                    new Line("לחסר מספר שלילי זה כמו לחבר את המספר הנגדי לו.", $"{a} {M} ({M}{b}) = {a} + {b} = {a + b}"));
        },
        ["signed-multiply"] = (r, w) =>
        {
            int a = R(r, 2, 9), b = R(r, 2, 9);
            return Pick(r, 0, 1) == 0
                ? Q("חשבו.", $"({M}{a})·({M}{b})", a * b,
                    new Line("מכפלה של שני מספרים שליליים היא חיובית.", $"({M}{a})·({M}{b}) = {a * b}"))
                : Q("חשבו.", $"({M}{a})·{b}", -a * b,
                    new Line("מכפלה של מספר שלילי במספר חיובי היא שלילית.", $"({M}{a})·{b} = {M}{a * b}"));
        },
        ["triangle-area"] = (r, w) =>
        {
            int b = 2 * R(r, 2, 8), h = R(r, 3, 12);
            return Q($"במשולש, אורך צלע הוא {b} ס\"מ והגובה לצלע זו הוא {h} ס\"מ. מהו שטח המשולש בסמ\"ר?", null, b * h / 2,
                new Line("שטח משולש הוא צלע כפול הגובה אליה, חלקי שתיים.", $"{b}·{h} : 2 = {b * h} : 2 = {b * h / 2}"));
        },
        ["adjacent-angle"] = (r, w) =>
        {
            int a = R(r, 20, 160);
            return Q($"זווית היא בת {a}°. בת כמה מעלות הזווית הצמודה לה?", null, 180 - a,
                new Line("סכום זוויות צמודות הוא 180°.", $"180 {M} {a} = {180 - a}"));
        },
        ["function-value"] = (r, w) =>
        {
            int a = R(r, 2, 6), b = R(r, 1, 9), x = R(r, 2, 10);
            return Q($"חוק ההתאמה: מכפילים את המספר ב-{a} ומוסיפים {b}. איזה מספר מתאים ל-{x}?", null, a * x + b,
                new Line($"מכפילים את {x} ב-{a}, ואז מוסיפים {b}.", $"{a}·{x} + {b} = {a * x + b}"));
        },
        ["linear-equation-both-sides"] = (r, w) =>
        {
            int c = R(r, 1, 5), a = c + R(r, 1, 5), x = R(r, 1, 10), b = R(r, 1, 15), d = (a - c) * x + b;
            return Q("פתרו את המשוואה. מהו x?", $"{a}·x + {b} = {c}·x + {d}", x,
                new Line($"מחסרים {c}·x משני האגפים.", $"{a - c}·x + {b} = {d}"),
                new Line($"מחסרים {b} משני האגפים.", $"{a - c}·x = {d - b}"),
                new Line($"מחלקים את שני האגפים ב-{a - c}.", $"x = {x}"));
        },
        ["triangle-angle"] = (r, w) =>
        {
            int a = R(r, 25, 90), b = R(r, 25, 150 - a);
            return Q($"במשולש, שתי זוויות הן {a}° ו-{b}°. בת כמה מעלות הזווית השלישית?", null, 180 - a - b,
                new Line("סכום הזוויות במשולש הוא 180°.", $"180 {M} {a} {M} {b} = {180 - a - b}"));
        },

        // ---- Grade 8 ----
        ["linear-value"] = (r, w) =>
        {
            int m = Pick(r, -4, -3, -2, 2, 3, 4, 5), b = R(r, -8, 8), x = R(r, -3, 6);
            return Q($"נתונה פונקציה קווית. מהו f({x})?", $"f(x) = {N(m)}·x {Plus(b)}", m * x + b,
                new Line($"מציבים x = {x}.", $"{N(m)}·{N(x)} {Plus(b)} = {N(m * x)} {Plus(b)} = {N(m * x + b)}"));
        },
        ["slope"] = (r, w) =>
        {
            int m = Pick(r, -3, -2, -1, 1, 2, 3, 4), x1 = R(r, 0, 4), dx = R(r, 1, 4), y1 = R(r, -3, 6);
            int x2 = x1 + dx, y2 = y1 + m * dx;
            return Q($"ישר עובר דרך הנקודות ({x1}, {y1}) ו-({x2}, {y2}). מהו שיפוע הישר?", null, m,
                new Line("שיפוע הוא השינוי ב-y חלקי השינוי ב-x.", $"({N(y2)} {M} {N(y1)}) : ({x2} {M} {x1}) = {N(y2 - y1)} : {dx} = {N(m)}"));
        },
        ["ratio-share"] = (r, w) =>
        {
            int a = R(r, 1, 5), b = R(r, 1, 5), k = R(r, 2, 12), total = (a + b) * k;
            return Q(
                w is null
                    ? $"מחלקים {total} שקלים בין שניים ביחס {a}:{b}. כמה שקלים מקבל הראשון?"
                    : $"ב{w.Place} מסדרים {total} {w.Items} על שני מדפים, ביחס {a}:{b}. כמה יהיו על המדף הראשון?",
                null, a * k,
                // Told as dealing out in rounds, which a learner can picture. "Equal parts" was not clear.
                new Line($"היחס {a}:{b} אומר: בכל פעם שהראשון מקבל {a}, השני מקבל {b}."),
                new Line("אז מחלקים בסיבובים. כמה מחלקים בסיבוב אחד?", $"{a} + {b} = {a + b}"),
                new Line($"כמה סיבובים צריך עד שכל ה-{total} מחולקים?", $"{total} : {a + b} = {k}"),
                new Line($"הראשון מקבל {a} בכל סיבוב, ויש {k} סיבובים.", $"{a}·{k} = {a * k}")) with
            {
                Visual = new Visual("shelves", [a, b, k]),
                // A second way, slower: the rounds one by one, with the running total, until everything is dealt.
                More =
                [
                    new Line("אפשר גם בלי חילוק: מחלקים סיבוב אחרי סיבוב, וסופרים כמה כבר חולק."),
                    .. Enumerable.Range(1, k).Select(i => new Line($"סיבוב {i}:", $"{a * i} + {b * i} = {(a + b) * i}")),
                    new Line($"בסיבוב {k} הגענו בדיוק ל-{total}, אז עוצרים. הראשון קיבל עד עכשיו:", $"{a * k}"),
                ],
            };
        },
        ["proportion"] = (r, w) =>
        {
            int a = R(r, 1, 9), b = R(r, 2, 9), k = R(r, 2, 6);
            return Q(
                w is null
                    ? "מצאו את x בפרופורציה."
                    : $"ב{w.Place}, עבור {b} שקלים מקבלים {a} {w.Items}. כמה {w.Items} מקבלים עבור {b * k} שקלים?",
                $"{a} : {b} = x : {b * k}", a * k,
                new Line($"המספר השני הוכפל ב-{k}.", $"{b}·{k} = {b * k}"),
                new Line("כדי שהיחס יישמר, מכפילים גם את המספר הראשון באותו מספר.", $"x = {a}·{k} = {a * k}"));
        },
        ["scale"] = (r, w) =>
        {
            int s = Pick(r, 100, 200, 500, 1000, 2000), c = R(r, 2, 12);
            return Q($"במפה בקנה מידה 1:{s}, המרחק בין שתי נקודות הוא {c} ס\"מ. מהו המרחק במציאות, במטרים?", null, c * s / 100,
                new Line($"כל ס\"מ במפה הוא {s} ס\"מ במציאות.", $"{c}·{s} = {c * s}"),
                new Line("מעבירים מסנטימטרים למטרים: מחלקים ב-100.", $"{c * s} : 100 = {c * s / 100}"));
        },
        ["isosceles-angle"] = (r, w) =>
        {
            int apex = 2 * R(r, 10, 70);
            return Q($"במשולש שווה שוקיים, זווית הראש היא {apex}°. בת כמה מעלות כל אחת מזוויות הבסיס?", null, (180 - apex) / 2,
                new Line("סכום הזוויות במשולש הוא 180°, ושתי זוויות הבסיס שוות זו לזו.", $"(180 {M} {apex}) : 2 = {180 - apex} : 2 = {(180 - apex) / 2}"));
        },
        ["linear-equation-brackets"] = (r, w) =>
        {
            int a = R(r, 2, 6), b = R(r, 1, 9), x = R(r, 1, 10);
            return Q("פתרו את המשוואה. מהו x?", $"{a}·(x + {b}) = {a * (x + b)}", x,
                new Line("פותחים סוגריים בעזרת חוק הפילוג.", $"{a}·x + {a * b} = {a * (x + b)}"),
                new Line($"מחסרים {a * b} משני האגפים.", $"{a}·x = {a * x}"),
                new Line($"מחלקים את שני האגפים ב-{a}.", $"x = {x}"));
        },
        ["expand-brackets"] = (r, w) =>
        {
            int a = R(r, 2, 9), b = R(r, 2, 9);
            return Q("פותחים סוגריים. מהו המספר החופשי, זה שבלי x, בביטוי שמתקבל?", $"{a}·(x + {b})", a * b,
                new Line("חוק הפילוג: מכפילים כל איבר שבסוגריים.", $"{a}·x + {a}·{b} = {a}·x + {a * b}"));
        },
        ["percent-of"] = (r, w) =>
        {
            int p = Pick(r, 10, 20, 25, 30, 40, 50, 60, 75), n = 20 * R(r, 2, 25);
            return Q(
                w is null
                    ? $"כמה הם {p}% מתוך {n}?"
                    : $"ב{w.Place} יש {n} {w.Items}, ו-{p}% כבר נמכרו. כמה נמכרו?",
                null, n * p / 100,
                new Line("אחוז הוא חלק ממאה: מכפילים באחוז ומחלקים ב-100.", $"{n}·{p} : 100 = {n * p / 100}")) with { Visual = new Visual("percent", [p, n, n * p / 100]) };
        },
        ["percent-change"] = (r, w) =>
        {
            int p = Pick(r, 10, 20, 25, 30, 50), n = 20 * R(r, 3, 20);
            return Q(
                w is null
                    ? $"מחיר של מוצר הוא {n} שקלים. הוא מוזל ב-{p}%. מהו המחיר אחרי ההוזלה?"
                    : $"ב{w.Place}, חבילה של {w.Items} עולה {n} שקלים. היום יש הנחה של {p}%. מה המחיר אחרי ההנחה?",
                null, n - n * p / 100,
                new Line("מחשבים את גודל ההוזלה.", $"{n}·{p} : 100 = {n * p / 100}"),
                new Line("מחסרים אותה מהמחיר.", $"{n} {M} {n * p / 100} = {n - n * p / 100}")) with { Visual = new Visual("percent", [p, n, n * p / 100]) };
        },
        ["mean"] = (r, w) =>
        {
            var count = Pick(r, 4, 5);
            var mean = R(r, 5, 12);
            var numbers = Enumerable.Range(0, count - 1).Select(_ => R(r, 2, 15)).ToList();
            var last = mean * count - numbers.Sum();
            // The last number makes the mean a whole number; when it would fall out of range, a simple set is used.
            if (last is < 1 or > 30)
            {
                numbers = Enumerable.Repeat(mean, count - 1).ToList();
                last = mean;
                numbers[0] -= 2;
                numbers[1] += 2;
            }
            numbers.Add(last);
            return Q(
                w is null
                    ? $"מהו הממוצע של המספרים: {string.Join(", ", numbers)}?"
                    : $"ב{w.Place} רשמו כמה {w.Items} נמכרו בכל יום: {string.Join(", ", numbers)}. מה הממוצע ליום?",
                null, mean,
                new Line("מחברים את כל המספרים.", $"{string.Join(" + ", numbers)} = {numbers.Sum()}"),
                new Line($"מחלקים במספר המספרים, {count}.", $"{numbers.Sum()} : {count} = {mean}"));
        },
        ["simple-probability"] = (r, w) =>
        {
            int red = R(r, 1, 6), blue = R(r, 1, 6);
            var answer = new Rational(red, red + blue);
            return Q($"בשקית {red} כדורים אדומים ו-{blue} כדורים כחולים. מוציאים כדור אחד בלי להסתכל. מהי ההסתברות שהוא אדום? אפשר לכתוב שבר.", null, answer,
                new Line("ההסתברות היא מספר התוצאות המתאימות חלקי מספר כל התוצאות.", $"{red} : ({red} + {blue}) = {red}/{red + blue}"),
                new Line("אם אפשר, מצמצמים.", $"{answer}"));
        },
        ["similar-side"] = (r, w) =>
        {
            int a = R(r, 2, 6), b = a + R(r, 1, 5), k = R(r, 2, 4);
            return Q($"שני משולשים דומים. במשולש הקטן צלעות באורך {a} ס\"מ ו-{b} ס\"מ. במשולש הגדול, הצלע המתאימה לראשונה היא {a * k} ס\"מ. מהו אורך הצלע המתאימה לשנייה?", null, b * k,
                new Line("מוצאים את יחס הדמיון.", $"{a * k} : {a} = {k}"),
                new Line("כל צלע במשולש הגדול גדולה פי אותו מספר.", $"{b}·{k} = {b * k}"));
        },
        ["system"] = (r, w) =>
        {
            int x = R(r, 3, 12), y = R(r, 1, x - 1);
            return Q("פתרו את מערכת המשוואות. מהו x?", $"x + y = {x + y}   ,   x {M} y = {x - y}", x,
                new Line("מחברים את שתי המשוואות, ו-y מתבטל.", $"2·x = {2 * x}"),
                new Line("מחלקים ב-2.", $"x = {x}"),
                new Line("אפשר למצוא גם את y בהצבה.", $"y = {x + y} {M} {x} = {y}"));
        },
        ["absolute-value"] = (r, w) =>
        {
            int a = R(r, 1, 9), b = a + R(r, 1, 9);
            return Q("חשבו.", $"|{a} {M} {b}|", b - a,
                new Line("קודם מחשבים את מה שבתוך הערך המוחלט.", $"{a} {M} {b} = {M}{b - a}"),
                new Line("ערך מוחלט הוא המרחק מאפס, והוא אף פעם לא שלילי.", $"|{M}{b - a}| = {b - a}"));
        },
        ["pythagoras"] = (r, w) =>
        {
            var (a, b, c) = Pick(r, (3, 4, 5), (5, 12, 13), (8, 15, 17), (6, 8, 10), (9, 12, 15), (7, 24, 25));
            return Q($"במשולש ישר זווית, אורכי הניצבים הם {a} ס\"מ ו-{b} ס\"מ. מהו אורך היתר?", null, c,
                new Line("משפט פיתגורס: סכום ריבועי הניצבים שווה לריבוע היתר.", $"{a}{Sup(2)} + {b}{Sup(2)} = {a * a} + {b * b} = {c * c}"),
                new Line("מוציאים שורש.", $"√{c * c} = {c}"));
        },

        // ---- Grade 9 ----
        ["power-rule"] = (r, w) =>
        {
            int a = R(r, 2, 9), m = R(r, 2, 7), n = R(r, 2, 7);
            return Q("כותבים את המכפלה כחזקה אחת של אותו בסיס. מהו המעריך?", $"{a}{Sup(m)} · {a}{Sup(n)}", m + n,
                new Line("כשכופלים חזקות בעלות אותו בסיס, מחברים את המעריכים.", $"{a}{Sup(m)} · {a}{Sup(n)} = {a}{Sup(m + n)}"));
        },
        ["negative-exponent"] = (r, w) =>
        {
            int a = Pick(r, 2, 3, 5, 10), n = R(r, 1, a == 2 ? 4 : 2);
            var value = (int)Math.Pow(a, n);
            return Q("חשבו את החזקה. אפשר לכתוב שבר.", $"{a}{Sup(-n)}", new Rational(1, value),
                new Line("מעריך שלילי: אחד חלקי אותה חזקה עם מעריך חיובי.", $"{a}{Sup(-n)} = 1/{a}{Sup(n)} = 1/{value}"));
        },
        ["two-events"] = (r, w) =>
        {
            int red = R(r, 1, 4), total = red + R(r, 1, 4);
            var answer = new Rational(red * red, total * total);
            return Q($"בשקית {total} כדורים, ומהם {red} אדומים. מוציאים כדור, מחזירים אותו, ומוציאים שוב. מהי ההסתברות ששני הכדורים אדומים? אפשר לכתוב שבר.", null, answer,
                new Line("ההסתברות לכדור אדום בהוצאה אחת:", $"{red}/{total}"),
                new Line("שתי ההוצאות אינן תלויות זו בזו, ולכן מכפילים.", $"{red}/{total} · {red}/{total} = {red * red}/{total * total} = {answer}"));
        },
        ["square-of-sum"] = (r, w) =>
        {
            int a = R(r, 1, 12);
            return Q("פותחים סוגריים לפי נוסחת הכפל המקוצר. מהו המקדם של x?", $"(x + {a}){Sup(2)}", 2 * a,
                new Line("ריבוע של סכום: ריבוע הראשון, ועוד פעמיים המכפלה, ועוד ריבוע השני.", $"(x + {a}){Sup(2)} = x{Sup(2)} + 2·{a}·x + {a}{Sup(2)}"),
                new Line("המקדם של x:", $"2·{a} = {2 * a}"));
        },
        ["parabola-vertex"] = (r, w) =>
        {
            int p = R(r, 1, 9), q = R(r, -9, 9);
            return Q("מהו שיעור ה-x של קודקוד הפרבולה?", $"f(x) = (x {M} {p}){Sup(2)} {Plus(q)}", p,
                new Line("הביטוי שבריבוע אף פעם אינו שלילי, והוא הכי קטן כשהוא שווה לאפס.", $"x {M} {p} = 0"),
                new Line("לכן הקודקוד נמצא ב:", $"x = {p}"));
        },
        ["quadratic-root"] = (r, w) =>
        {
            int small = R(r, 1, 6), large = small + R(r, 1, 6);
            return Q("פתרו את המשוואה הריבועית. מהו הפתרון הגדול מבין השניים?", $"x{Sup(2)} {M} {small + large}·x + {small * large} = 0", large,
                new Line($"מחפשים שני מספרים שמכפלתם {small * large} וסכומם {small + large}.", $"{small}·{large} = {small * large}   ,   {small} + {large} = {small + large}"),
                new Line("מפרקים לגורמים.", $"(x {M} {small})·(x {M} {large}) = 0"),
                new Line("מכפלה שווה לאפס כשאחד הגורמים שווה לאפס.", $"x = {small}   ,   x = {large}"));
        },
        ["parallelogram-angle"] = (r, w) =>
        {
            int a = R(r, 35, 145);
            return Q($"במקבילית, אחת הזוויות היא {a}°. בת כמה מעלות הזווית הסמוכה לה?", null, 180 - a,
                new Line("במקבילית, סכום שתי זוויות סמוכות הוא 180°.", $"180 {M} {a} = {180 - a}"));
        },
        ["midsegment"] = (r, w) =>
        {
            int side = 2 * R(r, 3, 15);
            return Q($"במשולש, אורך צלע הוא {side} ס\"מ. מהו אורך קטע האמצעים המקביל לה?", null, side / 2,
                new Line("קטע אמצעים במשולש מקביל לצלע השלישית ושווה למחציתה.", $"{side} : 2 = {side / 2}"));
        },
        ["median-to-hypotenuse"] = (r, w) =>
        {
            int c = 2 * R(r, 3, 15);
            return Q($"במשולש ישר זווית, אורך היתר הוא {c} ס\"מ. מהו אורך התיכון ליתר?", null, c / 2,
                new Line("במשולש ישר זווית, התיכון ליתר שווה למחצית היתר.", $"{c} : 2 = {c / 2}"));
        },
    };
}
