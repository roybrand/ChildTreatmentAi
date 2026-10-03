/// User-facing text. Hebrew is the first language; every string the user sees lives here.
class Strings {
  static const appTitle = 'ליווי הורים';

  // General
  static const save = 'שמירה';
  static const cancel = 'ביטול';
  static const add = 'הוספה';
  static const continueLabel = 'המשך';
  static const requiredField = 'שדה חובה';
  static const errorNetwork = 'אין חיבור לשרת. בדקו את החיבור ונסו שוב.';
  static const errorGeneric = 'משהו השתבש. נסו שוב.';

  // Sign in
  static const authTitleLogin = 'כניסה';
  static const authTitleRegister = 'הרשמה';
  static const email = 'אימייל';
  static const password = 'סיסמה';
  static const passwordHint = 'לפחות 10 תווים';
  static const emailInvalid = 'כתובת אימייל לא תקינה';
  static const passwordTooShort = 'הסיסמה צריכה להיות באורך 10 תווים לפחות';
  static const login = 'כניסה';
  static const register = 'יצירת חשבון';
  static const switchToRegister = 'אין לך חשבון? הרשמה';
  static const switchToLogin = 'יש לך חשבון? כניסה';
  static const errorLogin = 'האימייל או הסיסמה שגויים.';
  static const errorRegister = 'לא הצלחנו ליצור חשבון. ייתכן שהאימייל כבר רשום.';
  static const idleSignedOut = 'יצאתם מהחשבון אוטומטית אחרי זמן ללא פעילות, כדי לשמור על הפרטיות שלכם.';
  static const notTherapy ='האפליקציה אינה טיפול ואינה מחליפה איש מקצוע.';

  // Consent
  static const consentTitle = 'לפני שמתחילים';
  static const consentIntro = 'האפליקציה מלווה הורים לילדים ולבני נוער שמתמודדים עם חרדה. חשוב שתדעו:';
  static const consentPoints = [
    'האפליקציה אינה טיפול, אינה מאבחנת ואינה מחליפה איש מקצוע.',
    'המאמן הוא בינה מלאכותית ולא אדם. התשובות שלו עוברות בדיקת בטיחות, אבל הוא עלול לטעות.',
    'במצב חירום האפליקציה תפנה אתכם לגורמי עזרה ולא תנסה לטפל בעצמה.',
    'המידע שתכתבו על הילד/ה רגיש. הוא נשמר מוצפן, אינו נמכר ואינו משותף.',
    'לפני שטקסט נשלח למודל הבינה המלאכותית, שם הילד/ה מוחלף בכינוי.',
    'אפשר לייצא או למחוק את כל המידע בכל רגע דרך התפריט.',
  ];
  static const consentCheckbox = 'קראתי ואני מסכים/ה, כהורה או כאפוטרופוס של הילד/ה';
  static const consentDraftNote = 'נוסח זמני. הנוסח הסופי ייכתב עם עורך דין.';

  // Add child
  static const addChildTitle = 'על מי מדובר?';
  static const addChildIntro = 'מספיק כינוי או שם פרטי. לא צריך שם מלא, כתובת או שם בית ספר.';
  static const nickname = 'שם או כינוי';
  static const birthYear = 'שנת לידה';
  static const birthYearInvalid = 'האפליקציה מיועדת לגילאי בית ספר, 6 עד 18';

  // Home
  static const tabCoach = 'מאמן';
  static const tabLog = 'יומן';
  static const tabMap = 'מפה';
  static const tabProfile = 'פרופיל';
  static const tabSummary = 'סיכום';
  static const menuSignOut = 'יציאה';
  static const menuDelete = 'מחיקת החשבון וכל המידע';
  static const deleteConfirmTitle = 'למחוק הכול?';
  static const deleteConfirmBody = 'החשבון וכל המידע על המשפחה יימחקו לצמיתות. אי אפשר לבטל את הפעולה.';
  static const deleteConfirm = 'מחיקה';

  // Coach
  static const coachEmpty =
      'כאן מדברים עם המאמן. אפשר להתחיל בתיאור קצר של מה שקשה עכשיו, או של מה שקרה היום.';
  static const coachHint = 'כתבו למאמן';
  static const coachThinking = 'המאמן כותב תשובה. זה יכול לקחת עד חצי דקה.';
  static const send = 'שליחה';

  // Log
  static const logEmpty = 'עדיין אין רשומות. רשומה יומית קצרה עוזרת למאמן לראות מה באמת קורה.';
  static const logAdd = 'רשומה חדשה';
  static const logWhatHappened = 'מה קרה?';
  static const logChildReaction = 'איך הילד/ה הגיב/ה?';
  static const logParentResponse = 'איך הגבת?';
  static const logMood = 'איך הרגשת היום?';
  static const logMoodLow = 'קשה מאוד';
  static const logMoodHigh = 'טוב';
  static const logOptional = 'לא חובה';

  // Accommodation map
  static const mapEmpty =
      'כאן רושמים את הדברים שהמשפחה עושה בגלל החרדה: לענות שוב ושוב על אותה שאלה, לדבר במקום הילד/ה, '
      'להימנע ממקומות. המאמן יעזור לבחור במה להתחיל.';
  static const mapAdd = 'הוספה למפה';
  static const mapDescription = 'מה אתם עושים בגלל החרדה?';
  static const mapStatusActive = 'פעיל';
  static const mapStatusTargeted = 'עובדים על זה';
  static const mapStatusReduced = 'צומצם';
  static const mapSetTarget = 'להתחיל לעבוד על זה';
  static const mapPlannedChange = 'מה תעשו אחרת?';
  static const mapMarkReduced = 'סימון כצומצם';
  static const mapBackToActive = 'החזרה לרשימה';
  static const mapOneAtATime = 'עובדים על דבר אחד בכל פעם. סיימו או החזירו את הנוכחי לפני שבוחרים חדש.';

  // Profile
  static const profileEmpty =
      'כאן נשמר מה שהאפליקציה יודעת על הילד/ה. שיחת היכרות קצרה עוזרת למאמן להתאים את עצמו למשפחה שלכם.';
  static const profileInterview = 'שיחת היכרות';
  static const profileAdd = 'הוספה לפרופיל';
  static const profileSection = 'נושא';
  static const profileItemText = 'מה כדאי שנדע?';
  static const profileWaiting = 'נרשם מהשיחה. זה נכון?';
  static const profileAccept = 'נכון';
  static const profileReject = 'לא נכון';
  static const profileRemove = 'הסרה מהפרופיל';
  static const profileSections = {
    'StrengthsAndInterests': 'חוזקות ותחומי עניין',
    'AnxietyPicture': 'תמונת החרדה',
    'WhatCalms': 'מה מרגיע',
    'LearningPicture': 'למידה',
    'OtherConditions': 'אבחנות של איש מקצוע',
    'FamilyContext': 'ההקשר המשפחתי',
    'WhatHasWorked': 'מה עבד',
  };
  static const interviewHint = 'כתבו תשובה';
  static const interviewThinking = 'רושמים את התשובה. זה יכול לקחת עד חצי דקה.';
  static const interviewComplete = 'שיחת ההיכרות הסתיימה. אפשר להמשיך לכתוב ולהוסיף בכל רגע.';

  // Weekly summary
  static const summaryEmpty =
      'כאן יופיע סיכום של השבוע מתוך היומן: מה קרה, מה חוזר על עצמו, מה עזר, והצעה לשבוע הבא.';
  static const summaryCreate = 'סיכום השבוע';
  static const summaryWorking = 'מכינים את הסיכום. זה יכול לקחת עד דקה.';
  static const summaryExisting = 'הסיכום של היום כבר מוכן.';
  static const summaryEntries = 'רשומות ביומן';
  static const summaryMood = 'מצב הרוח שלך, מ-1 עד 5';
  static const summaryPreviousMood = 'בשבוע הקודם';
  static const summaryWhatHappened = 'מה קרה';
  static const summaryPatterns = 'מה חוזר על עצמו';
  static const summaryObserved = 'מהיומן';
  static const summaryGuess = 'השערה';
  static const summaryWhatWorked = 'מה עזר';
  static const summaryProposal = 'הצעה לשבוע הבא';
  static const summaryNote = 'הסיכום נכתב על ידי בינה מלאכותית מתוך היומן שלך. המספרים נספרו מהיומן.';

  // Crisis
  static const crisisButton = 'עזרה דחופה';
  static const crisisTitle = 'עזרה דחופה';
  static const crisisIntro =
      'אם יש סכנה מיידית לך או לילד/ה, התקשרו עכשיו. האפליקציה אינה מטפלת במצבי חירום.';
  static const crisisAlsoContact = 'כדאי לפנות בהקדם גם לרופא/ת הילדים, לפסיכולוג/ית או לקופת החולים.';
  static const call = 'חיוג';
  static const crisisOpenScreen = 'למסך העזרה הדחופה';
}
