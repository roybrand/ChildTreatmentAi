import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'token_store.dart';

/// The API answered with an error, or could not be reached (status 0).
class ApiException implements Exception {
  const ApiException(this.status, [this.title]);

  final int status;
  final String? title;

  bool get isConsentRequired => status == 409 && title == 'consent_required';
  bool get isUnauthorized => status == 401;
  bool get isNetwork => status == 0;

  @override
  String toString() => 'ApiException($status, $title)';
}

/// The only place the app talks to the server.
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokens, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Set at build time: flutter run --dart-define=API_BASE_URL=https://...
  static const defaultBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5080');

  // A coach reply is two model calls on the server and can take half a minute.
  static const _timeout = Duration(seconds: 90);

  final String baseUrl;
  final TokenStore tokens;
  final http.Client _http;

  // ---- Account ----

  Future<void> register(String email, String password) async {
    await _send('POST', '/auth/register', body: {'email': email, 'password': password}, authorized: false);
  }

  Future<void> login(String email, String password) async {
    final json = await _send('POST', '/auth/login', body: {'email': email, 'password': password}, authorized: false);
    await _storeTokens(json as Map<String, dynamic>);
  }

  Future<void> logout() => tokens.clear();

  Future<bool> hasSession() async => await tokens.read() != null;

  Future<void> giveConsent(String consentVersion) async {
    await _send('POST', '/api/family/consent', body: {'accepted': true, 'consentVersion': consentVersion});
  }

  Future<void> deleteFamily() async {
    await _send('DELETE', '/api/family');
    await tokens.clear();
  }

  // ---- Children ----

  Future<List<Child>> children() async => _list(await _send('GET', '/api/children'), Child.fromJson);

  Future<Child> addChild(String nickname, int birthYear) async {
    final json = await _send('POST', '/api/children', body: {'nickname': nickname, 'birthYear': birthYear});
    return Child.fromJson(json as Map<String, dynamic>);
  }

  // ---- Accommodations ----

  Future<List<Accommodation>> accommodations(String childId) async =>
      _list(await _send('GET', '/api/children/$childId/accommodations'), Accommodation.fromJson);

  Future<Accommodation> addAccommodation(String childId, String description) async {
    final json = await _send('POST', '/api/children/$childId/accommodations', body: {'description': description});
    return Accommodation.fromJson(json as Map<String, dynamic>);
  }

  Future<Accommodation> updateAccommodation(
      String childId, String id, AccommodationStatus status, String? plannedChange) async {
    final json = await _send('PATCH', '/api/children/$childId/accommodations/$id',
        body: {'status': Accommodation.statusToJson(status), 'plannedChange': plannedChange});
    return Accommodation.fromJson(json as Map<String, dynamic>);
  }

  // ---- Daily log ----

  Future<List<LogEntry>> log(String childId) async =>
      _list(await _send('GET', '/api/children/$childId/log'), LogEntry.fromJson);

  Future<LogEntryResult> addLogEntry(
    String childId, {
    required DateTime date,
    required String whatHappened,
    String? childReaction,
    String? parentResponse,
    int? parentMood,
  }) async {
    final json = await _send('POST', '/api/children/$childId/log', body: {
      'date': _dateOnly(date),
      'whatHappened': whatHappened,
      'childReaction': _nullIfBlank(childReaction),
      'parentResponse': _nullIfBlank(parentResponse),
      'parentMood': parentMood,
    }) as Map<String, dynamic>;
    return LogEntryResult(
      entry: LogEntry.fromJson(json['entry'] as Map<String, dynamic>),
      crisis: json['crisis'] != null,
    );
  }

  // ---- Coach ----

  Future<List<CoachMessage>> coachHistory(String childId) async =>
      _list(await _send('GET', '/api/children/$childId/coach/messages'), CoachMessage.fromJson);

  Future<CoachMessage> sendToCoach(String childId, String text) async {
    final json = await _send('POST', '/api/children/$childId/coach/messages', body: {'text': text});
    return CoachMessage.fromReply(json as Map<String, dynamic>);
  }

  // ---- Profile ----

  Future<List<ProfileItem>> profileItems(String childId) async =>
      _list(await _send('GET', '/api/children/$childId/profile-items'), ProfileItem.fromJson);

  Future<ProfileItem> addProfileItem(String childId, String section, String text) async {
    final json = await _send('POST', '/api/children/$childId/profile-items', body: {'section': section, 'text': text});
    return ProfileItem.fromJson(json as Map<String, dynamic>);
  }

  /// Accepts or rejects an item the Profile Agent wrote down, or removes one the parent no longer wants.
  Future<void> setProfileItem(String childId, String id, {required bool confirmed}) async {
    await _send('PATCH', '/api/children/$childId/profile-items/$id',
        body: {'status': confirmed ? 'Confirmed' : 'Rejected'});
  }

  Future<Interview> interview(String childId) async {
    final json = await _send('GET', '/api/children/$childId/profile/interview');
    return Interview.fromJson(json as Map<String, dynamic>);
  }

  Future<InterviewTurn> sendToInterview(String childId, String text) async {
    final json = await _send('POST', '/api/children/$childId/profile/interview/messages', body: {'text': text});
    return InterviewTurn.fromJson(json as Map<String, dynamic>);
  }

  // ---- Weekly summary ----

  Future<List<WeeklySummary>> summaries(String childId) async =>
      _list(await _send('GET', '/api/children/$childId/summaries'), WeeklySummary.fromJson);

  Future<SummaryResult> createSummary(String childId) async {
    final json = await _send('POST', '/api/children/$childId/summaries');
    return SummaryResult.fromJson(json as Map<String, dynamic>);
  }

  // ---- Lessons ----

  static const fractionsMixer = 'fractions-mixer-1';

  /// The first time a lesson is opened the Tutor sets it in the child's world, which can take a while.
  Future<Lesson> lesson(String childId, String lessonId) async {
    final json = await _send('GET', '/api/children/$childId/lessons/$lessonId');
    return Lesson.fromJson(json as Map<String, dynamic>);
  }

  Future<void> saveLessonProgress(String childId, String lessonId, {required int step, required bool completed}) async {
    await _send('PUT', '/api/children/$childId/lessons/$lessonId/progress',
        body: {'step': step, 'completed': completed});
  }

  // ---- Plumbing ----

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String? _nullIfBlank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();

  static List<T> _list<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) =>
      (json as List<dynamic>).map((item) => fromJson(item as Map<String, dynamic>)).toList();

  Future<void> _storeTokens(Map<String, dynamic> json) => tokens.write(
        Tokens(access: json['accessToken'] as String, refresh: json['refreshToken'] as String),
      );

  Future<dynamic> _send(String method, String path, {Object? body, bool authorized = true}) async {
    var response = await _request(method, path, body, authorized);

    // An expired access token is renewed once with the refresh token, then the call is repeated.
    if (response.statusCode == 401 && authorized && await _refresh()) {
      response = await _request(method, path, body, authorized);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    }

    if (response.statusCode == 401 && authorized) {
      await tokens.clear();
    }
    throw ApiException(response.statusCode, _problemTitle(response));
  }

  Future<http.Response> _request(String method, String path, Object? body, bool authorized) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (authorized) {
      final current = await tokens.read();
      if (current != null) {
        request.headers['Authorization'] = 'Bearer ${current.access}';
      }
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    try {
      return await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on Exception {
      throw const ApiException(0);
    }
  }

  Future<bool> _refresh() async {
    final current = await tokens.read();
    if (current == null) {
      return false;
    }
    final response = await _request('POST', '/auth/refresh', {'refreshToken': current.refresh}, false);
    if (response.statusCode != 200) {
      return false;
    }
    await _storeTokens(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
    return true;
  }

  static String? _problemTitle(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json is Map<String, dynamic> ? json['title'] as String? : null;
    } on FormatException {
      return null;
    }
  }
}
