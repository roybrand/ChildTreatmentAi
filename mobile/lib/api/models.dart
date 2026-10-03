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

class LogEntryResult {
  const LogEntryResult({required this.entry, required this.crisis});

  final LogEntry entry;
  /// True when the entry's text matched the crisis rules and the crisis screen should be shown.
  final bool crisis;
}
