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

class LogEntryResult {
  const LogEntryResult({required this.entry, required this.crisis});

  final LogEntry entry;
  /// True when the entry's text matched the crisis rules and the crisis screen should be shown.
  final bool crisis;
}
