/// Data the API returns. Field names and enum values match the server's JSON.
library;

class Child {
  const Child({required this.id, required this.nickname, required this.age, required this.isTeen});

  final String id;
  final String nickname;
  final int age;
  final bool isTeen;

  factory Child.fromJson(Map<String, dynamic> json) => Child(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        age: json['age'] as int,
        isTeen: json['mode'] == 'Teen',
      );
}

enum AccommodationStatus { active, targeted, reduced }

class Accommodation {
  const Accommodation({required this.id, required this.description, required this.status, this.plannedChange});

  final String id;
  final String description;
  final AccommodationStatus status;
  final String? plannedChange;

  factory Accommodation.fromJson(Map<String, dynamic> json) => Accommodation(
        id: json['id'] as String,
        description: json['description'] as String,
        status: switch (json['status']) {
          'Targeted' => AccommodationStatus.targeted,
          'Reduced' => AccommodationStatus.reduced,
          _ => AccommodationStatus.active,
        },
        plannedChange: json['plannedChange'] as String?,
      );

  static String statusToJson(AccommodationStatus status) => switch (status) {
        AccommodationStatus.active => 'Active',
        AccommodationStatus.targeted => 'Targeted',
        AccommodationStatus.reduced => 'Reduced',
      };
}

class LogEntry {
  const LogEntry({
    required this.id,
    required this.date,
    required this.whatHappened,
    this.childReaction,
    this.parentResponse,
    this.parentMood,
  });

  final String id;
  final DateTime date;
  final String whatHappened;
  final String? childReaction;
  final String? parentResponse;
  final int? parentMood;

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        whatHappened: json['whatHappened'] as String,
        childReaction: json['childReaction'] as String?,
        parentResponse: json['parentResponse'] as String?,
        parentMood: json['parentMood'] as int?,
      );
}

class CrisisContactInfo {
  const CrisisContactInfo({required this.name, required this.phone, required this.description});

  final String name;
  final String phone;
  final String description;

  factory CrisisContactInfo.fromJson(Map<String, dynamic> json) => CrisisContactInfo(
        name: json['name'] as String,
        phone: json['phone'] as String,
        description: json['description'] as String,
      );
}

/// Kinds of message in the coaching conversation.
enum MessageKind {
  normal,
  /// The Safety Guard stopped the exchange. Shown with the emergency contacts.
  crisis,
  /// The coach's reply was withheld and a fixed text is shown instead.
  fallback,
  /// The model could not be reached. Not stored on the server.
  unavailable,
}

class CoachMessage {
  const CoachMessage({required this.fromParent, required this.kind, required this.text});

  final bool fromParent;
  final MessageKind kind;
  final String text;

  /// A message from the stored history.
  factory CoachMessage.fromJson(Map<String, dynamic> json) => CoachMessage(
        fromParent: json['role'] == 'Parent',
        kind: switch (json['kind']) {
          'Crisis' => MessageKind.crisis,
          'Fallback' => MessageKind.fallback,
          _ => MessageKind.normal,
        },
        text: json['text'] as String,
      );

  /// The coach's answer to a message just sent.
  factory CoachMessage.fromReply(Map<String, dynamic> json) => CoachMessage(
        fromParent: false,
        kind: switch (json['kind']) {
          'Crisis' => MessageKind.crisis,
          'Fallback' => MessageKind.fallback,
          'Unavailable' => MessageKind.unavailable,
          _ => MessageKind.normal,
        },
        text: json['text'] as String,
      );
}

/// Sections of the child's profile, in the order they are shown. Names match the server's.
const profileSections = [
  'StrengthsAndInterests',
  'AnxietyPicture',
  'WhatCalms',
  'LearningPicture',
  'OtherConditions',
  'FamilyContext',
  'WhatHasWorked',
];

class ProfileItem {
  const ProfileItem({required this.id, required this.section, required this.text, required this.confirmed});

  final String id;
  final String section;
  final String text;

  /// False while the item waits for the parent: the Profile Agent wrote it down and nobody has accepted it yet.
  final bool confirmed;

  factory ProfileItem.fromJson(Map<String, dynamic> json) => ProfileItem(
        id: json['id'] as String,
        section: json['section'] as String,
        text: json['text'] as String,
        confirmed: json['status'] == 'Confirmed',
      );
}

/// The onboarding interview so far.
class Interview {
  const Interview({required this.opening, required this.complete, required this.messages});

  /// The first question, written by people and shown before any message.
  final String opening;
  final bool complete;
  final List<CoachMessage> messages;

  factory Interview.fromJson(Map<String, dynamic> json) => Interview(
        opening: json['opening'] as String,
        complete: json['complete'] as bool,
        messages: (json['messages'] as List<dynamic>)
            .map((m) => CoachMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

/// The Profile Agent's answer to one message: the next question and what it wrote down.
class InterviewTurn {
  const InterviewTurn({required this.message, required this.items, required this.complete});

  final CoachMessage message;
  final List<ProfileItem> items;
  final bool complete;

  factory InterviewTurn.fromJson(Map<String, dynamic> json) => InterviewTurn(
        message: CoachMessage.fromReply(json),
        items: (json['items'] as List<dynamic>).map((i) => ProfileItem.fromJson(i as Map<String, dynamic>)).toList(),
        complete: json['complete'] as bool,
      );
}

class SummaryPattern {
  const SummaryPattern({required this.text, required this.observed});

  final String text;

  /// True when the pattern is in the log. False when it is the Planner's guess.
  final bool observed;
}

class WeeklySummary {
  const WeeklySummary({
    required this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.whatHappened,
    required this.patterns,
    required this.whatWorked,
    required this.proposal,
    required this.logEntries,
    this.moodAverage,
    this.previousMoodAverage,
  });

  final String id;
  final DateTime weekStart;
  final DateTime weekEnd;
  final String whatHappened;
  final List<SummaryPattern> patterns;
  final List<String> whatWorked;
  final String proposal;

  // Counted by the server from the log, not written by the model.
  final int logEntries;
  final double? moodAverage;
  final double? previousMoodAverage;

  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>;
    return WeeklySummary(
      id: json['id'] as String,
      weekStart: DateTime.parse(json['weekStart'] as String),
      weekEnd: DateTime.parse(json['weekEnd'] as String),
      whatHappened: content['whatHappened'] as String,
      patterns: (content['patterns'] as List<dynamic>)
          .map((p) => p as Map<String, dynamic>)
          .map((p) => SummaryPattern(text: p['text'] as String, observed: p['basis'] == 'observed'))
          .toList(),
      whatWorked: (content['whatWorked'] as List<dynamic>).cast<String>(),
      proposal: content['proposal'] as String,
      logEntries: json['logEntries'] as int,
      moodAverage: (json['moodAverage'] as num?)?.toDouble(),
      previousMoodAverage: (json['previousMoodAverage'] as num?)?.toDouble(),
    );
  }
}

/// What came back from asking for this week's summary.
class SummaryResult {
  const SummaryResult({required this.created, this.summary, this.text});

  /// True only when a new summary was written now.
  final bool created;

  /// The summary, new or already written today. Null when none could be made.
  final WeeklySummary? summary;

  /// Why there is no summary, in words for the parent.
  final String? text;

  factory SummaryResult.fromJson(Map<String, dynamic> json) => SummaryResult(
        created: json['kind'] == 'Created',
        summary: json['summary'] == null ? null : WeeklySummary.fromJson(json['summary'] as Map<String, dynamic>),
        text: json['text'] as String?,
      );
}

/// Which parts of the product the server has switched on.
class Features {
  const Features({required this.familyCoaching, required this.profileSections});

  /// The tutor on its own: the parent coaching side is off, and the profile holds learning only.
  static const tutor = Features(
    familyCoaching: false,
    profileSections: ['StrengthsAndInterests', 'WhatCalms', 'LearningPicture', 'WhatHasWorked'],
  );

  /// The parent coaching side: coach, daily log, accommodation map, weekly summary.
  final bool familyCoaching;

  /// The profile sections in use, by the server's names.
  final List<String> profileSections;

  factory Features.fromJson(Map<String, dynamic> json) => Features(
        familyCoaching: json['familyCoaching'] as bool,
        profileSections: (json['profileSections'] as List<dynamic>).cast<String>(),
      );
}

class Subtopic {
  const Subtopic({required this.id, required this.title, required this.hasQuestions, this.lessonId});

  /// The hand-built lesson that teaches this sub-topic, when there is one.
  final String? lessonId;

  final String id;
  final String title;

  /// False when no questions are built for this sub-topic yet.
  final bool hasQuestions;

  factory Subtopic.fromJson(Map<String, dynamic> json) => Subtopic(
        id: json['id'] as String,
        title: json['title'] as String,
        hasQuestions: json['generator'] != null,
        lessonId: json['lesson'] as String?,
      );
}

class CurriculumTopic {
  const CurriculumTopic({required this.title, required this.domain, required this.subtopics});

  final String title;

  /// algebra, number, or geometry.
  final String domain;
  final List<Subtopic> subtopics;

  factory CurriculumTopic.fromJson(Map<String, dynamic> json) => CurriculumTopic(
        title: json['title'] as String,
        domain: json['domain'] as String,
        subtopics:
            (json['subtopics'] as List<dynamic>).map((s) => Subtopic.fromJson(s as Map<String, dynamic>)).toList(),
      );
}

class CurriculumGrade {
  const CurriculumGrade({required this.grade, required this.name, required this.topics});

  final int grade;
  final String name;
  final List<CurriculumTopic> topics;

  factory CurriculumGrade.fromJson(Map<String, dynamic> json) => CurriculumGrade(
        grade: json['grade'] as int,
        name: json['name'] as String,
        topics:
            (json['topics'] as List<dynamic>).map((t) => CurriculumTopic.fromJson(t as Map<String, dynamic>)).toList(),
      );
}

/// A sentence, with an optional line of mathematics shown left to right under it.
class MathLine {
  const MathLine({required this.text, this.math});

  final String text;
  final String? math;

  factory MathLine.fromJson(Map<String, dynamic> json) =>
      MathLine(text: json['text'] as String, math: json['math'] as String?);
}

class PracticeQuestion {
  const PracticeQuestion({required this.id, required this.ask});

  final String id;
  final MathLine ask;

  factory PracticeQuestion.fromJson(Map<String, dynamic> json) =>
      PracticeQuestion(id: json['id'] as String, ask: MathLine.fromJson(json));
}

/// What the server says about an answer. It is checked by code, with exact arithmetic.
class PracticeCheck {
  const PracticeCheck({
    required this.same,
    required this.answer,
    required this.steps,
    this.visual,
    this.more = const [],
  });

  /// A second explanation, told another way, for when the first one did not land. Empty when there is none.
  final List<MathLine> more;

  /// A picture of the solution, when the question has one.
  final SolutionVisual? visual;

  final bool same;
  final String answer;
  final List<MathLine> steps;

  factory PracticeCheck.fromJson(Map<String, dynamic> json) => PracticeCheck(
        same: json['same'] as bool,
        answer: json['answer'] as String,
        steps: (json['steps'] as List<dynamic>).map((s) => MathLine.fromJson(s as Map<String, dynamic>)).toList(),
        visual: json['visual'] == null ? null : SolutionVisual.fromJson(json['visual'] as Map<String, dynamic>),
        more: ((json['more'] as List<dynamic>?) ?? const [])
            .map((s) => MathLine.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

/// What a picture of a solution shows, as numbers worked out by the server. The app only draws them.
class SolutionVisual {
  const SolutionVisual({required this.kind, required this.numbers, this.labels = const []});

  /// Names for the parts of the picture, when it has named parts: the two sides of a share.
  final List<String> labels;

  /// shelves: two shelves with numbers[0] and numbers[1] groups of numbers[2] things each.
  /// percent: numbers[0] percent of numbers[1] is numbers[2].
  final String kind;
  final List<int> numbers;

  factory SolutionVisual.fromJson(Map<String, dynamic> json) => SolutionVisual(
        kind: json['kind'] as String,
        numbers: (json['numbers'] as List<dynamic>).cast<int>(),
        labels: ((json['labels'] as List<dynamic>?) ?? const []).cast<String>(),
      );
}

/// How the learner is doing on one sub-topic.
class SubtopicProgress {
  const SubtopicProgress({
    required this.subtopicId,
    required this.tried,
    required this.gotIt,
    required this.comeBack,
    required this.lastAt,
    this.triedThisWeek = 0,
    this.gotItThisWeek = 0,
  });

  /// When the sub-topic was last practised.
  final DateTime lastAt;
  final int triedThisWeek;
  final int gotItThisWeek;

  final String subtopicId;
  final int tried;
  final int gotIt;

  /// True when the latest questions did not go well, so the sub-topic is worth returning to.
  final bool comeBack;

  factory SubtopicProgress.fromJson(Map<String, dynamic> json) => SubtopicProgress(
        subtopicId: json['subtopicId'] as String,
        tried: json['tried'] as int,
        gotIt: json['gotIt'] as int,
        comeBack: json['comeBack'] as bool,
        lastAt: DateTime.tryParse(json['lastAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        triedThisWeek: json['triedThisWeek'] as int? ?? 0,
        gotItThisWeek: json['gotItThisWeek'] as int? ?? 0,
      );
}

class Ingredient {
  const Ingredient({required this.name, required this.color});

  final String name;

  /// 0xAARRGGBB, from the server's "#RRGGBB".
  final int color;

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: json['name'] as String,
        color: 0xFF000000 | int.parse((json['color'] as String).substring(1), radix: 16),
      );
}

/// The world a lesson is set in: words and colours only. The numbers belong to the game.
class LessonWorld {
  const LessonWorld({
    required this.world,
    required this.scene,
    required this.request,
    required this.ingredientA,
    required this.ingredientB,
    required this.smallLabel,
    required this.bigLabel,
    required this.resultWord,
    required this.whyNeeded,
    this.emoji = '🎨',
    this.customer = '🙂',
    this.container = 'jar',
    this.thanks = 'בדיוק אותו דבר. תודה!',
    this.greeting = 'טוב לראות אותך.',
    this.decor = '✨⭐🎈',
  });

  final String world;
  final String scene;
  final String request;
  final Ingredient ingredientA;
  final Ingredient ingredientB;
  final String smallLabel;
  final String bigLabel;
  final String resultWord;
  final String whyNeeded;

  /// A symbol for the place, shown beside its name.
  final String emoji;

  /// The face of whoever asks for more of the mix.
  final String customer;

  /// The kind of container the game draws: bottle, jar, jug, bowl, bucket, or flask.
  final String container;

  /// What the one who asked says when the mix matches.
  final String thanks;

  /// The sentence that welcomes the learner into their world.
  final String greeting;

  /// Emoji that belong to this world, one after another. They drift across the backdrop.
  final String decor;

  factory LessonWorld.fromJson(Map<String, dynamic> json) => LessonWorld(
        world: json['world'] as String,
        scene: json['scene'] as String,
        request: json['request'] as String,
        ingredientA: Ingredient.fromJson(json['ingredientA'] as Map<String, dynamic>),
        ingredientB: Ingredient.fromJson(json['ingredientB'] as Map<String, dynamic>),
        smallLabel: json['smallLabel'] as String,
        bigLabel: json['bigLabel'] as String,
        resultWord: json['resultWord'] as String,
        whyNeeded: json['whyNeeded'] as String,
        emoji: json['emoji'] as String? ?? '🎨',
        customer: json['customer'] as String? ?? '🙂',
        container: json['container'] as String? ?? 'jar',
        thanks: json['thanks'] as String? ?? 'בדיוק אותו דבר. תודה!',
        greeting: json['greeting'] as String? ?? 'טוב לראות אותך.',
        decor: json['decor'] as String? ?? '✨⭐🎈',
      );
}

class Lesson {
  const Lesson({required this.world, required this.stepReached, required this.completed});

  final LessonWorld world;
  final int stepReached;
  final bool completed;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        world: LessonWorld.fromJson(json['world'] as Map<String, dynamic>),
        stepReached: json['stepReached'] as int,
        completed: json['completed'] as bool,
      );
}

class LogEntryResult {
  const LogEntryResult({required this.entry, required this.crisis});

  final LogEntry entry;
  /// True when the entry's text matched the crisis rules and the crisis screen should be shown.
  final bool crisis;
}
