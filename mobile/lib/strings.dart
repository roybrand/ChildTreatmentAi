/// User-facing text. Hebrew is the first language; every string the user sees lives here.
class Strings {
  // A working name. The product name is not decided.
  static const appTitle = 'ללמוד בדרך שלי';

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
  static const consentIntro =
      'האפליקציה מלמדת ילדים ובני נוער דרך משחקים, בעולם שהם אוהבים ובקצב שלהם. חשוב שתדעו:';
  static const consentPoints = [
    'זו אפליקציית לימוד. היא אינה טיפול, אינה מאבחנת ואינה מחליפה מורה או איש מקצוע.',
    'את הסיפור שסביב כל שיעור כותבת בינה מלאכותית, והוא עובר בדיקה לפני שהוא מוצג. את החשבון עצמו בודק קוד, לא בינה מלאכותית.',
    'בפרופיל נשמר רק מה שעוזר להתאים שיעור: מה הילד/ה אוהב/ת, מה קשה בלמידה ומה עוזר. לא אבחנות ולא מידע רפואי.',
    'במצב חירום האפליקציה תפנה אתכם לגורמי עזרה ולא תנסה לטפל בעצמה.',
    'המידע נשמר מוצפן, אינו נמכר ואינו משותף.',
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
  static const tabLessons = 'שיעורים';
  static const tabHome = 'בית';
  static const tabParent = 'להורים';

  // The parent's view. Facts, no grades.
  static String parentTitle(String name) => 'איך הולך ל$name בתרגול';
  static const parentWhatIsKept = 'נשמר רק באיזה נושא תרגלו, והאם ההצלחה הייתה בלי לראות את הפתרון. השאלות והתשובות עצמן לא נשמרות.';
  static const parentEmpty = 'עדיין אין תרגול. מה שיתורגל יופיע כאן.';
  static const parentThisWeek = 'בשבעת הימים האחרונים';
  static const parentTried = 'שאלות שנוסו';
  static const parentGotIt = 'נפתרו בלי לראות את הפתרון';
  static const parentSubtopics = 'נושאים שתורגלו';
  static const parentComeBackWhy = 'בשלוש השאלות האחרונות בנושאים האלה, פחות משתיים נפתרו בלי עזרה. זה לא ציון: זה סימן שכדאי לחזור.';
  static const parentAll = 'כל מה שתורגל';
  static const parentRefresh = 'רענון';
  static String parentLine(int tried, int gotIt, String date) =>
      'נוסו $tried, מהן $gotIt בלי לראות את הפתרון. לאחרונה: $date';
  static const tabTopics = 'נושאים';
  static const welcomePreparing = 'מכינים את העולם שלך. זה יכול לקחת עד חצי דקה.';
  static const lessonsIntro = 'כל שיעור הוא משחק קצר. אין ציונים, אין שעון, ואפשר לעצור ולחזור מתי שרוצים.';
  static const lessonMixerTitle = 'שברים: לערבב את אותו דבר שוב';
  static const lessonMixerSubtitle = 'בערך עשר דקות';
  static const lessonStart = 'להתחיל';
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
      'כאן נשמר מה שהאפליקציה יודעת על הילד/ה. שיחת היכרות קצרה עוזרת לבנות שיעורים מהעולם שהילד/ה אוהב/ת.';
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
    'WhatCalms': 'מה עוזר',
    'LearningPicture': 'מה קשה בלמידה',
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

  // Lesson. Read by a child whose gender the app does not know, so every form here fits a boy and a girl.
  static const lessonOpen = 'שיעור';
  static const lessonPreparing = 'מכינים את השיעור. זה יכול לקחת עד חצי דקה.';
  static const lessonNext = 'הלאה';
  static const lessonBack = 'אחורה';
  static const lessonRemove = 'להוציא חלק';
  static const lessonMine = 'מה שיצרת';
  static const lessonNow = 'מה שיש עכשיו';
  static String lessonNotFull(int missing) => missing == 1
      ? 'הכלי עוד לא מלא. חסר עוד חלק אחד.'
      : 'הכלי עוד לא מלא. חסרים עוד $missing חלקים.';
  static const lessonAgain = 'אפשר להתחיל מההתחלה';
  static String lessonMatch(String result) => 'שני העיגולים באותו צבע בדיוק. זה $result שיצרת.';
  static String lessonNotYet(String result) => 'שני העיגולים עוד לא באותו צבע, אז זה עוד לא $result שיצרת. אפשר לשנות.';
  static const lessonSame = 'זה בדיוק אותו חלק מהשלם, ולכן אותו צבע.';
  static const lessonNewWorld = 'עולם אחר';

  // Practice by grade and topic. Read by the learner, so every form fits a boy and a girl.
  static const practiceTitle = 'תרגול לפי כיתה ונושא';
  static const practiceSubtitle = 'לפי תוכנית הלימודים של משרד החינוך, כיתות ז עד ט';
  static const practiceOpen = 'לבחור נושא';
  static const practiceGo = 'תרגול';

  // Pictures of a solution. Every number is passed in by code.
  static const shelfFirst = 'הראשון';
  static const shelfSecond = 'השני';
  static String shelfLabel(String shelf, int perRound, int rounds, int things) =>
      '$shelf: $perRound בכל סיבוב, $rounds סיבובים, ביחד $things';
  static String shelvesCaption(int first, String firstName, int second, String secondName) =>
      // The names stand alone, with no prefix joined to them, so any name reads correctly.
      'בכל סיבוב: $firstName $first, $secondName $second. המספר שמעל כל קבוצה הוא מספר הסיבוב.';
  static String percentCaption(int percent, int whole, int part) => '$percent מכל 100. מתוך $whole זה $part.';
  static const treeGrade = 'הכיתה';
  static const treeSubject = 'המקצוע';
  static const subjectMath = 'מתמטיקה';
  // Subjects with no content yet. They are shown so the tree is whole, and marked as coming.
  static const subjectsComing = [('🔤', 'אנגלית'), ('🔬', 'מדעים')];
  static const practiceSoon = 'בקרוב';
  static const practiceDomains = {'algebra': 'אלגברה', 'number': 'מספרים', 'geometry': 'גאומטריה'};
  static const practiceAnswerHint = 'התשובה';
  static const practiceCheck = 'בדיקה';
  static const practiceSame = 'זו התשובה.';
  static const practiceNotYet = 'זו עוד לא התשובה. אפשר לנסות שוב, או לראות איך פותרים.';
  static const practiceShowHow = 'להראות לי איך';
  static const practiceEasier = 'שאלה דומה, עם מספרים קטנים יותר.';
  static const practiceComeBackTitle = 'כדאי לחזור אליהם';
  static const practiceComeBackWhy = 'נושאים שעוד לא התיישבו. אין לחץ: אפשר לנסות שוב מתי שרוצים.';
  static const practiceComeBackMark = 'לחזור לזה';
  static const practiceSteadyMark = 'הולך טוב';
  static const practiceAnotherWay = 'עדיין לא ברור? להראות בדרך אחרת';
  static const practiceAnotherWayTitle = 'דרך אחרת';
  static const practiceComeBack = 'אם זה עדיין לא מסתדר, זה בסדר. אפשר לעבור הלאה ולחזור לזה בפעם אחרת.';
  static String practiceTheAnswer(String answer) => 'התשובה: $answer';
  static const practiceNextQuestion = 'שאלה הבאה';
  static const practiceDone = 'סיימת את התרגול.';
  static const practiceMore = 'עוד שאלות';
  static String practiceCount(int index, int total) => 'שאלה $index מתוך $total';

  // The explanation of a step. Every number is passed in by code.
  static const explainOpen = 'להראות לי איך';
  static const explainMore = 'עוד צעד';
  static const explainGotIt = 'הבנתי, רוצה לנסות';
  static const explainMoveOn = 'להמשיך הלאה';
  static String explainSmall(int total, int partsA, String a, int partsB, String b) =>
      'בכלי הקטן יש $total חלקים: $partsA $a ו-$partsB $b.';
  static String explainTimes(int slots, int times, int small) =>
      'הכלי הגדול הוא $slots חלקים. זה בדיוק $times פעמים הכלי הקטן.';
  static String explainIngredient(String name, int times, int small, int big) =>
      'אז גם $name: $times פעמים $small, כלומר $big חלקים.';
  static String explainResult(int partsA, String a, int partsB, String b) =>
      '$partsA $a ו-$partsB $b. אותו חלק מהשלם, ולכן אותו צבע בדיוק.';
  static const lessonRestart = 'מההתחלה';
  static String lessonsAskInterest(String name) => 'מה $name הכי אוהב/ת?';
  static const lessonsAskInterestWhy = 'השיעור ייבנה מהעולם הזה: הסיפור, הצבעים ומי שמבקש עזרה.';
  static const lessonsInterestHint = 'למשל: לק ג\'ל וציפורניים, כדורגל, אפייה';
  static const lessonsSaveInterest = 'לשמור ולפתוח את השיעור';
  static const lessonLookAtBoth ='הנה שניהם זה ליד זה. אפשר לבחור שוב.';
  static const lessonParts = 'חלקים';

  // Crisis
  static const crisisButton = 'עזרה דחופה';
  static const crisisTitle = 'עזרה דחופה';
  static const crisisIntro =
      'אם יש סכנה מיידית לך או לילד/ה, התקשרו עכשיו. האפליקציה אינה מטפלת במצבי חירום.';
  static const crisisAlsoContact = 'כדאי לפנות בהקדם גם לרופא/ת הילדים, לפסיכולוג/ית או לקופת החולים.';
  static const call = 'חיוג';
  static const crisisOpenScreen = 'למסך העזרה הדחופה';
}
