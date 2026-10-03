import 'dart:convert';

import 'package:child_treatment/api/api_client.dart';
import 'package:child_treatment/api/token_store.dart';
import 'package:child_treatment/app_state.dart';
import 'package:child_treatment/main.dart';
import 'package:child_treatment/screens/crisis_screen.dart';
import 'package:child_treatment/strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A small stand-in for the server, enough to walk through the app.
class FakeServer {
  bool consented = false;
  final children = <Map<String, dynamic>>[];
  final coachMessages = <String>[];
  final profileItems = <Map<String, dynamic>>[];
  Map<String, dynamic> coachReply = {'kind': 'Reply', 'text': 'תשובת המאמן', 'contacts': <dynamic>[]};

  http.Client get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    final body = request.body.isEmpty ? null : jsonDecode(request.body) as Map<String, dynamic>;

    if (path == '/auth/register') {
      return _json(200, null);
    }
    if (path == '/auth/login') {
      return _json(200, {'accessToken': 'a', 'refreshToken': 'r'});
    }
    if (request.headers['Authorization'] != 'Bearer a') {
      return _json(401, null);
    }
    if (path == '/api/family/consent') {
      consented = true;
      return _json(200, {});
    }
    if (!consented) {
      return _json(409, {'title': 'consent_required'});
    }
    if (path == '/api/children' && request.method == 'GET') {
      return _json(200, children);
    }
    if (path == '/api/children' && request.method == 'POST') {
      children.add({'id': 'c1', 'nickname': body!['nickname'], 'birthYear': body['birthYear'], 'age': 15, 'mode': 'Teen'});
      return _json(201, children.last);
    }
    if (path.endsWith('/coach/messages') && request.method == 'POST') {
      coachMessages.add(body!['text'] as String);
      return _json(200, coachReply);
    }
    if (path.endsWith('/profile/interview')) {
      return _json(200, {'opening': 'מה נועה אוהבת?', 'complete': false, 'messages': <dynamic>[]});
    }
    if (path.endsWith('/profile/interview/messages')) {
      profileItems.add({'id': 'p1', 'section': 'StrengthsAndInterests', 'text': 'נועה אוהבת לצייר', 'status': 'Suggested'});
      return _json(200, {
        'kind': 'Reply',
        'text': 'ומה מפחיד את נועה?',
        'contacts': <dynamic>[],
        'items': profileItems,
        'complete': false,
      });
    }
    if (path.contains('/profile-items/') && request.method == 'PATCH') {
      final item = profileItems.firstWhere((i) => path.endsWith('/${i['id']}'));
      item['status'] = body!['status'];
      return _json(200, item);
    }
    if (path.endsWith('/profile-items') && request.method == 'GET') {
      return _json(200, profileItems.where((i) => i['status'] != 'Rejected').toList());
    }
    if (path.endsWith('/summaries') && request.method == 'POST') {
      return _json(200, {
        'kind': 'Created',
        'text': null,
        'summary': {
          'id': 's1',
          'weekStart': '2026-09-27',
          'weekEnd': '2026-10-03',
          'content': {
            'whatHappened': 'נועה נרדמה לבד פעמיים',
            'patterns': [
              {'text': 'הבכי התקצר', 'basis': 'observed'},
              {'text': 'אולי העייפות משפיעה', 'basis': 'guess'},
            ],
            'whatWorked': ['המשפט התומך'],
            'proposal': 'להמשיך באותו צעד',
          },
          'logEntries': 4,
          'moodAverage': 2.8,
          'previousMoodAverage': 2.5,
          'createdAt': '2026-10-03T09:00:00Z',
        },
      });
    }
    if (request.method == 'GET') {
      return _json(200, <dynamic>[]);
    }
    return _json(404, null);
  }

  static http.Response _json(int status, Object? body) => http.Response.bytes(
        body == null ? const <int>[] : utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}

Future<FakeServer> pumpApp(
  WidgetTester tester, {
  bool signedIn = false,
  bool ready = false,
  Duration? idleTimeout,
}) async {
  final server = FakeServer();
  final tokens = MemoryTokenStore();
  if (signedIn || ready) {
    await tokens.write(const Tokens(access: 'a', refresh: 'r'));
  }
  if (ready) {
    server.consented = true;
    server.children.add({'id': 'c1', 'nickname': 'נועה', 'birthYear': 2011, 'age': 15, 'mode': 'Teen'});
  }

  final api = ApiClient(baseUrl: 'http://test', tokens: tokens, httpClient: server.client);
  await tester.pumpWidget(ChildTreatmentApp(state: AppState(api), idleTimeout: idleTimeout));
  await tester.pumpAndSettle();
  return server;
}

void main() {
  testWidgets('the app is laid out right to left', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.text(Strings.appTitle));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('the emergency contacts can be reached before signing in', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(Strings.crisisButton));
    await tester.pumpAndSettle();

    expect(find.byType(CrisisScreen), findsOneWidget);
    for (final contact in crisisContacts) {
      expect(find.text(contact.name), findsOneWidget);
      expect(find.textContaining(contact.phone), findsOneWidget);
    }
  });

  testWidgets('a new parent registers, consents, adds a child and reaches the coach', (tester) async {
    final server = await pumpApp(tester);

    await tester.tap(find.text(Strings.switchToRegister));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(0), 'parent@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'a long password');
    await tester.tap(find.text(Strings.register));
    await tester.pumpAndSettle();

    // Consent comes before anything about a child, and cannot be skipped.
    expect(find.text(Strings.consentTitle), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, Strings.continueLabel)).onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text(Strings.continueLabel));
    await tester.tap(find.text(Strings.continueLabel));
    await tester.pumpAndSettle();
    expect(server.consented, isTrue);

    expect(find.text(Strings.addChildTitle), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'נועה');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${DateTime.now().year - 15}').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.continueLabel));
    await tester.pumpAndSettle();

    expect(find.text('נועה'), findsOneWidget);
    expect(find.text(Strings.coachEmpty), findsOneWidget);
    expect(find.text(Strings.tabLog), findsOneWidget);
    expect(find.text(Strings.tabMap), findsOneWidget);
  });

  testWidgets('a message to the coach shows the reply', (tester) async {
    final server = await pumpApp(tester, ready: true);

    await tester.enterText(find.byType(TextField), 'מה עושים הערב?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(server.coachMessages, ['מה עושים הערב?']);
    expect(find.text('מה עושים הערב?'), findsOneWidget);
    expect(find.text('תשובת המאמן'), findsOneWidget);
  });

  testWidgets('a crisis reply offers the emergency screen', (tester) async {
    final server = await pumpApp(tester, ready: true);
    server.coachReply = {'kind': 'Crisis', 'text': 'זה דורש איש מקצוע עכשיו', 'contacts': <dynamic>[]};

    await tester.enterText(find.byType(TextField), 'הודעה מדאיגה');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    await tester.tap(find.text(Strings.crisisOpenScreen));
    await tester.pumpAndSettle();
    expect(find.byType(CrisisScreen), findsOneWidget);
  });

  testWidgets('a parent who has not consented is taken to the consent screen', (tester) async {
    await pumpApp(tester, signedIn: true);

    expect(find.text(Strings.consentTitle), findsOneWidget);
  });

  testWidgets('the interview shows what was written down, and accepting it puts it in the profile', (tester) async {
    final server = await pumpApp(tester, ready: true);

    await tester.tap(find.text(Strings.tabProfile));
    await tester.pumpAndSettle();
    expect(find.text(Strings.profileEmpty), findsOneWidget);

    await tester.tap(find.text(Strings.profileInterview));
    await tester.pumpAndSettle();
    expect(find.text('מה נועה אוהבת?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'היא אוהבת לצייר');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.text('ומה מפחיד את נועה?'), findsOneWidget);
    expect(find.text(Strings.profileWaiting), findsOneWidget);
    expect(find.text('נועה אוהבת לצייר'), findsOneWidget);

    await tester.tap(find.text(Strings.profileAccept));
    await tester.pumpAndSettle();
    expect(server.profileItems.single['status'], 'Confirmed');
    expect(find.text(Strings.profileWaiting), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('נועה אוהבת לצייר'), findsOneWidget);
    expect(find.text(Strings.profileSections['StrengthsAndInterests']!), findsOneWidget);
  });

  testWidgets('the weekly summary shows the numbers and marks a guess as a guess', (tester) async {
    await pumpApp(tester, ready: true);

    await tester.tap(find.text(Strings.tabSummary));
    await tester.pumpAndSettle();
    expect(find.text(Strings.summaryEmpty), findsOneWidget);

    await tester.tap(find.text(Strings.summaryCreate));
    await tester.pumpAndSettle();

    expect(find.text('נועה נרדמה לבד פעמיים'), findsOneWidget);
    expect(find.textContaining('2.8'), findsOneWidget);
    expect(find.text(Strings.summaryObserved), findsOneWidget);
    expect(find.text(Strings.summaryGuess), findsOneWidget);
    expect(find.text('להמשיך באותו צעד'), findsOneWidget);
  });

  /// Sets the window size for one test, in logical pixels.
  void setWindow(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  testWidgets('a phone has the tabs along the bottom', (tester) async {
    setWindow(tester, const Size(390, 800));
    await pumpApp(tester, ready: true);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('a computer has the tabs down the side and a readable column', (tester) async {
    setWindow(tester, const Size(1400, 900));
    await pumpApp(tester, ready: true);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.getSize(find.byType(TextField)).width, lessThan(760));

    await tester.tap(find.text(Strings.tabLog));
    await tester.pumpAndSettle();
    expect(find.text(Strings.logEmpty), findsOneWidget);
  });

  testWidgets('on a computer Enter sends the message and Shift+Enter does not', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final server = await pumpApp(tester, ready: true);

    await tester.enterText(find.byType(TextField), 'שורה ראשונה');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(server.coachMessages, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(server.coachMessages, ['שורה ראשונה']);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('resizing the window keeps a half-typed message', (tester) async {
    setWindow(tester, const Size(390, 800));
    await pumpApp(tester, ready: true);
    await tester.enterText(find.byType(TextField), 'טיוטה');

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('טיוטה'), findsOneWidget);
  });

  testWidgets('after a stretch without activity the parent is signed out', (tester) async {
    await pumpApp(tester, ready: true, idleTimeout: const Duration(minutes: 15));

    await tester.pump(const Duration(minutes: 10));
    await tester.tap(find.text(Strings.tabLog));
    await tester.pump(const Duration(minutes: 10));
    await tester.pumpAndSettle();
    // The tap restarted the clock, so the parent is still in.
    expect(find.text(Strings.logEmpty), findsOneWidget);

    await tester.pump(const Duration(minutes: 16));
    await tester.pumpAndSettle();
    expect(find.text(Strings.idleSignedOut), findsOneWidget);
    expect(find.text(Strings.tabLog), findsNothing);
  });

  testWidgets('the automatic sign-out leaves the crisis screen open', (tester) async {
    await pumpApp(tester, ready: true, idleTimeout: const Duration(minutes: 15));

    await tester.tap(find.text(Strings.crisisButton));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 16));
    await tester.pumpAndSettle();

    expect(find.byType(CrisisScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(Strings.idleSignedOut), findsOneWidget);
  });
}
