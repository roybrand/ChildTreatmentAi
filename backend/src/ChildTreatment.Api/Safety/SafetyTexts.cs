namespace ChildTreatment.Api.Safety;

public sealed record CrisisContact(string Name, string Phone, string Description);

/// <summary>
/// Fixed texts shown when the Safety Guard acts. They are written by people, never generated.
/// Contacts must be verified before launch (see docs/SAFETY.md).
/// </summary>
public static class SafetyTexts
{
    public static readonly IReadOnlyList<CrisisContact> CrisisContacts =
    [
        new("ער\"ן", "1201", "עזרה ראשונה נפשית, 24 שעות ביממה"),
        new("מגן דוד אדום", "101", "חירום רפואי"),
        new("משטרה", "100", "סכנה מיידית"),
    ];

    public const string Crisis =
        "מה שכתבת נשמע כמו מצב שדורש עזרה של איש מקצוע עכשיו, ולא ליווי של אפליקציה.\n\n" +
        "אם יש סכנה מיידית, התקשרו ל-101 או ל-100. לשיחה עם גורם מקצועי בכל שעה אפשר להתקשר לער\"ן בטלפון 1201. " +
        "כדאי גם לפנות בהקדם לרופא/ת הילדים, לפסיכולוג/ית או לקופת החולים.\n\n" +
        "אם כתבת את הדברים כביטוי ולא כתיאור של סכנה, אפשר להמשיך בשיחה.";

    public const string Fallback =
        "קראתי את מה שכתבת, וחשוב לי לענות על זה כמו שצריך. הפעם לא הצלחתי לנסח תשובה מספיק טובה, " +
        "וזה לא בגלל הדרך שבה כתבת.\n\n" +
        "אפשר לשלוח את ההודעה שוב, או להמשיך ולספר עוד. " +
        "אם מדובר בשאלה רפואית או במצב דחוף, כדאי לפנות לאיש מקצוע.";

    public const string Unavailable =
        "יש כרגע תקלה זמנית ואי אפשר לקבל תשובה. ההודעה שלך נשמרה, ואפשר לנסות שוב בעוד כמה דקות.";
}
