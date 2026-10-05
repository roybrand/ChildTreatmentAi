import 'dart:convert';

import 'package:child_treatment/api/api_client.dart';
import 'package:child_treatment/api/models.dart' show profileSections;
import 'package:child_treatment/api/token_store.dart';
import 'package:child_treatment/app_state.dart';
import 'package:child_treatment/main.dart';
import 'package:child_treatment/screens/crisis_screen.dart';
import 'package:child_treatment/screens/lessons_screen.dart';
import 'package:child_treatment/strings.dart';
import 'package:child_treatment/widgets/scene.dart';
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
  int lessonStep = 0;
  final practiceResults = <bool>[];

  /// How each question on the words of the world went.
  final wordResults = <bool>[];

  /// Whether the parent coaching side is switched on. The real server has it off.
  bool coaching = true;
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
    if (path == '/api/features') {
      return _json(200, {
        'familyCoaching': coaching,
        'profileSections': coaching
            ? profileSections
            : ['StrengthsAndInterests', 'WhatCalms', 'LearningPicture', 'WhatHasWorked'],
      });
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
    if (path == '/api/curriculum') {
      return _json(200, [
        {
          'subject': 'english',
          'grades': [
            {
              'grade': 7,
              'name': 'כיתה ז',
              'topics': [
                {
                  'title': 'Present Simple',
                  'domain': 'grammar',
                  'subtopics': [
                    {'id': 'e1', 'title': 'am, is, are', 'generator': 'en-to-be'},
                  ],
                },
              ],
            },
          ],
        },
        {
          'subject': 'mathematics',
        'grades': [
          {
            'grade': 7,
            'name': 'כיתה ז',
            'topics': [
              {
                'title': 'פתרון משוואות ושאלות מילוליות',
                'domain': 'algebra',
                'subtopics': [
                  {'id': 's1', 'title': 'פתרון משוואות', 'generator': 'linear-equation'},
                  {'id': 's2', 'title': 'שאלות מילוליות', 'generator': null},
                  {'id': 's3', 'title': 'שברים שווים', 'generator': null, 'lesson': 'fractions-mixer-1'},
                ],
              },
            ],
          },
        ],
        },
      ].reversed.toList());
    }
    if (path.endsWith('/world-guide')) {
      // The second circle opens once a word was got.
      final open = wordResults.contains(true) ? 2 : 1;
      return _json(200, {
        'people': [
          {'name': 'מיכל', 'role': 'לקוחה קבועה', 'emoji': '👩'},
          {'name': 'עומר', 'role': 'השליח', 'emoji': '🧑'},
        ],
        'words': [
          {'en': 'lipstick', 'he': 'שפתון', 'emoji': '💄', 'sentence': 'The lipstick is on the table.', 'circle': 1},
          {'en': 'mirror', 'he': 'מראה', 'emoji': '🪞', 'sentence': 'The mirror is on the wall.', 'circle': 1},
          if (open == 2)
            {'en': 'shop', 'he': 'חנות', 'emoji': '🏪', 'sentence': 'The shop is open today.', 'circle': 2},
        ],
        'openCircle': open,
      });
    }
    if (path.endsWith('/words/check')) {
      return _json(200, {
        'same': body!['answer'] == '1',
        'answer': 'lipstick',
        'steps': [
          {'text': '💄  שפתון', 'math': 'lipstick'},
        ],
      });
    }
    if (path.endsWith('/words/1')) {
      return _json(200, [
        {'id': 'en-words-1:7', 'text': 'איך אומרים את זה באנגלית?', 'math': '💄', 'choices': ['mirror', 'lipstick', 'brush']},
      ]);
    }
    if (path.endsWith('/practice/en-words-1/result')) {
      wordResults.add(body!['gotIt'] as bool);
      return _json(204, null);
    }
    if (path == '/api/practice/check') {
      return _json(200, {
        // The mathematics question is answered by 3. The English one by its second choice, 'is'.
        'same': body!['questionId'] == 'e1:1' ? body['answer'] == '1' : body['answer'] == '3',
        'answer': '3',
        'steps': [
          {'text': 'מחסרים 1 משני האגפים.', 'math': '2·x = 6'},
        ],
        'more': [
          {'text': 'אפשר גם לנסות מספרים.', 'math': '2·3 + 1 = 7'},
        ],
      });
    }
    if (path.endsWith('/practice/e1')) {
      return _json(200, [
        {'id': 'e1:1', 'text': 'בחרו את המילה שמשלימה את המשפט.', 'math': 'She ___ happy.', 'choices': ['am', 'is', 'are']},
      ]);
    }
    if (path.endsWith('/practice/e1/result')) {
      return _json(204, null);
    }
    if (path.endsWith('/practice/s1/result')) {
      practiceResults.add(body!['gotIt'] as bool);
      return _json(204, null);
    }
    if (path.endsWith('/practice-progress')) {
      return _json(200, [
        if (practiceResults.isNotEmpty)
          {
            'subtopicId': 's1',
            'tried': practiceResults.length,
            'gotIt': practiceResults.where((g) => g).length,
            'comeBack': !practiceResults.last,
            'lastAt': '2026-10-04T09:00:00Z',
            'triedThisWeek': practiceResults.length,
            'gotItThisWeek': practiceResults.where((g) => g).length,
          },
      ]);
    }
    if (path.endsWith('/practice/s1')) {
      // An easy question is asked for after a miss. Its id carries the mark.
      final easy = request.url.queryParameters['easy'] == 'true';
      return _json(200, [
        easy
            ? {'id': 's1:2:e', 'text': 'פתרו את המשוואה. מהו x?', 'math': 'x + 1 = 4'}
            : {'id': 's1:1', 'text': 'פתרו את המשוואה. מהו x?', 'math': '2·x + 1 = 7'},
      ]);
    }
    if (path.endsWith('/progress')) {
      lessonStep = body!['step'] as int;
      return _json(200, {});
    }
    if (path.contains('/lessons/')) {
      return _json(200, {
        'lessonId': 'fractions-mixer-1',
        'fromTutor': true,
        'stepReached': 0,
        'completed': false,
        'world': {
          'world': 'סטודיו ללק',
          'scene': 'יצרת גוון משלך.',
          'request': 'לקוחה רוצה בקבוק גדול.',
          'ingredientA': {'name': 'ורוד', 'color': '#E85D9A'},
          'ingredientB': {'name': 'לבן', 'color': '#FFFFFF'},
          'smallLabel': 'הבקבוק הקטן',
          'bigLabel': 'הבקבוק הגדול',
          'resultWord': 'הגוון',
          'whyNeeded': 'כדי להכין שוב את אותו דבר.',
        },
      });
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
  bool coaching = true,
}) async {
  final server = FakeServer()..coaching = coaching;
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
  // The drifting backdrop never ends, so a screen would never settle with it running.
  setUpAll(() => Scene.animate = false);

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
    // The button sits below the consent points, so the list is scrolled to it first.
    await tester.scrollUntilVisible(find.widgetWithText(FilledButton, Strings.continueLabel), 200);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, Strings.continueLabel)).onPressed, isNull);
    await tester.ensureVisible(find.byType(Checkbox));
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

  testWidgets('as a tutor the app opens on lessons, with no coaching tabs and no sections about conditions',
      (tester) async {
    await pumpApp(tester, ready: true, coaching: false);

    expect(find.text(Strings.tabHome), findsOneWidget);
    // The home page is in the learner's world: its name, and a greeting by name.
    expect(find.textContaining('סטודיו ללק'), findsOneWidget);
    expect(find.textContaining('נועה,'), findsOneWidget);
    expect(find.text(Strings.tabCoach), findsNothing);
    expect(find.text(Strings.tabLog), findsNothing);
    expect(find.text(Strings.tabMap), findsNothing);
    expect(find.text(Strings.tabSummary), findsNothing);

    await tester.tap(find.text(Strings.tabProfile));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.profileAdd));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text(Strings.profileSections['LearningPicture']!), findsWidgets);
    expect(find.text(Strings.profileSections['OtherConditions']!), findsNothing);
    expect(find.text(Strings.profileSections['AnxietyPicture']!), findsNothing);
    expect(find.text(Strings.profileSections['FamilyContext']!), findsNothing);
  });

  testWidgets('practice goes by grade and topic, shows the way when asked, and marks nothing wrong', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    final server = await pumpApp(tester, ready: true, coaching: false);

    // The home page is the tree: the class, the subject, then the topic with its sub-topics under it.
    final tree = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text(Strings.practiceGo), 200, scrollable: tree);
    await tester.ensureVisible(find.text(Strings.practiceGo));
    await tester.pumpAndSettle();
    expect(find.text('כיתה ז'), findsOneWidget);
    expect(find.text(Strings.subjectMath), findsOneWidget);
    expect(find.text('פתרון משוואות ושאלות מילוליות'), findsOneWidget);
    // A sub-topic with no questions yet says so and does not open.
    expect(find.text(Strings.practiceSoon), findsOneWidget);

    await tester.tap(find.text(Strings.practiceGo));
    await tester.pumpAndSettle();
    expect(find.text('2·x + 1 = 7'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text(Strings.practiceCheck));
    await tester.pumpAndSettle();
    expect(find.text(Strings.practiceNotYet), findsOneWidget);

    await tester.tap(find.text(Strings.practiceShowHow));
    await tester.pumpAndSettle();
    expect(find.text('2·x = 6'), findsOneWidget);
    expect(find.text(Strings.practiceTheAnswer('3')), findsOneWidget);

    // A second explanation is one tap away, and it ends by saying that moving on is fine.
    await tester.dragUntilVisible(find.text(Strings.practiceAnotherWay), find.byType(ListView), const Offset(0, -200));
    await tester.ensureVisible(find.text(Strings.practiceAnotherWay));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.practiceAnotherWay));
    await tester.pumpAndSettle();
    expect(find.text('2·3 + 1 = 7'), findsOneWidget);
    await tester.dragUntilVisible(find.text(Strings.practiceNextQuestion), find.byType(ListView), const Offset(0, -200));
    expect(find.text(Strings.practiceComeBack), findsOneWidget);
    await tester.ensureVisible(find.text(Strings.practiceNextQuestion));
    await tester.pumpAndSettle();

    await tester.tap(find.text(Strings.practiceNextQuestion));
    await tester.pumpAndSettle();

    // A question that was not got is followed by an easier one of the same kind, and the miss is recorded.
    expect(find.text(Strings.practiceEasier), findsOneWidget);
    expect(find.text('x + 1 = 4'), findsOneWidget);
    expect(server.practiceResults, [false]);

    // Getting the easier one right ends the set: an easy question is not followed by another.
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text(Strings.practiceCheck));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text(Strings.practiceNextQuestion), find.byType(ListView), const Offset(0, -200));
    await tester.ensureVisible(find.text(Strings.practiceNextQuestion));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.practiceNextQuestion));
    await tester.pumpAndSettle();
    expect(find.text(Strings.practiceDone), findsOneWidget);
    expect(server.practiceResults, [false, true]);

    // Back on the home page, the sub-topic is marked by how it went last.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(Strings.practiceSteadyMark), findsOneWidget);

    // The parent's page says the same in numbers: two tried, one without seeing the solution.
    await tester.tap(find.text(Strings.tabParent));
    await tester.pumpAndSettle();
    expect(find.text(Strings.parentTitle('נועה')), findsOneWidget);
    expect(find.textContaining(Strings.parentLine(2, 1, '4.10.2026')), findsOneWidget);
    expect(find.text('פתרון משוואות'), findsOneWidget);
  });

  testWidgets('english is a subject of its own, and its questions are answered by choosing a word', (tester) async {
    tester.view.devicePixelRatio = 1;
    // Tall enough for the welcome, the words of the world, and the grammar topics under them.
    tester.view.physicalSize = const Size(412, 2400);
    addTearDown(tester.view.reset);
    await pumpApp(tester, ready: true, coaching: false);

    // Mathematics is open first. Choosing English shows its own topics.
    expect(find.text('פתרון משוואות ושאלות מילוליות'), findsOneWidget);
    await tester.tap(find.text('אנגלית'));
    await tester.pumpAndSettle();
    expect(find.text('פתרון משוואות ושאלות מילוליות'), findsNothing);
    expect(find.text('am, is, are'), findsOneWidget);

    await tester.tap(find.text(Strings.practiceGo));
    await tester.pumpAndSettle();
    expect(find.text('She ___ happy.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    // A word that does not fit is not marked wrong, and another can be chosen.
    await tester.tap(find.text('are'));
    await tester.pumpAndSettle();
    expect(find.text(Strings.practiceNotYet), findsOneWidget);
    await tester.tap(find.text('is'));
    await tester.pumpAndSettle();
    expect(find.text(Strings.practiceSame), findsOneWidget);
  });

  testWidgets('someone from the world greets with a word of the day, and its words open in widening circles',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 2200);
    addTearDown(tester.view.reset);
    // The first day of the count: the first person greets, and the first word is shown.
    WelcomeHeader.today = () => DateTime.utc(1970, 1, 1);
    addTearDown(() => WelcomeHeader.today = DateTime.now);
    final server = await pumpApp(tester, ready: true, coaching: false);

    expect(find.text(Strings.personCaption('מיכל', 'לקוחה קבועה')), findsOneWidget);
    expect(find.text(Strings.wordOfDay), findsOneWidget);
    expect(find.text('lipstick'), findsOneWidget);
    expect(find.text('The lipstick is on the table.'), findsOneWidget);

    // Under English, before any grammar, are the words of the learner's own world. Only the heart is open.
    await tester.tap(find.text('אנגלית'));
    await tester.pumpAndSettle();
    expect(find.textContaining(Strings.wordsTitle), findsOneWidget);
    expect(find.text(Strings.wordsLater), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('words-1')));
    await tester.pumpAndSettle();
    // A person of the world asks, by name.
    expect(find.text(Strings.personCaption('מיכל', 'לקוחה קבועה')), findsOneWidget);
    expect(find.text('איך אומרים את זה באנגלית?'), findsOneWidget);

    await tester.tap(find.text('lipstick'));
    await tester.pumpAndSettle();
    expect(find.text(Strings.practiceSame), findsOneWidget);
    await tester.ensureVisible(find.text(Strings.practiceNextQuestion));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.practiceNextQuestion));
    await tester.pumpAndSettle();

    // The game is recorded, and the wider circle that opened is told as news, not as a score.
    expect(server.wordResults, [true]);
    expect(find.text(Strings.wordsNewCircle(Strings.wordsCircles[1])), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(Strings.wordsLater), findsOneWidget);
    expect(find.byKey(const ValueKey('words-2')), findsOneWidget);
  });

  testWidgets('the tutor opens a lesson from the lessons list', (tester) async {
    tester.view.devicePixelRatio = 1;
    // Tall enough for the welcome and the whole tree, so the lesson button is in view.
    tester.view.physicalSize = const Size(412, 1700);
    addTearDown(tester.view.reset);
    await pumpApp(tester, ready: true, coaching: false);

    // The lesson sits in the tree, on the sub-topic it teaches.
    await tester.scrollUntilVisible(find.text(Strings.lessonOpen), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text(Strings.lessonOpen));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.lessonOpen));
    await tester.pumpAndSettle();

    expect(find.textContaining('סטודיו ללק'), findsOneWidget);
    expect(find.text('יצרת גוון משלך.'), findsOneWidget);
  });

  testWidgets('a stuck learner is shown the solution step by step, and can try again or move on', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    await pumpApp(tester, ready: true);

    await tester.tap(find.byTooltip(Strings.lessonOpen));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(Strings.lessonNext));
      await tester.pumpAndSettle();
    }
    FilledButton next() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, Strings.lessonNext));

    // The explanation works the numbers out from the step: 3 of 4, twice, is 6 of 8.
    await tester.tap(find.text(Strings.explainOpen));
    await tester.pumpAndSettle();
    expect(find.text(Strings.explainSmall(4, 3, 'ורוד', 1, 'לבן')), findsOneWidget);
    await tester.tap(find.text(Strings.explainMore));
    await tester.pumpAndSettle();
    expect(find.text(Strings.explainTimes(8, 2, 4)), findsOneWidget);
    await tester.tap(find.text(Strings.explainMore));
    await tester.pumpAndSettle();
    expect(find.text(Strings.explainIngredient('ורוד', 2, 3, 6)), findsOneWidget);

    // "I get it" closes the explanation and leaves the work to the learner.
    await tester.tap(find.text(Strings.explainGotIt));
    await tester.pumpAndSettle();
    expect(next().onPressed, isNull);

    // "Move on" fills the step in, so nobody is left stuck.
    await tester.tap(find.text(Strings.explainOpen));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.explainMoveOn));
    await tester.pumpAndSettle();
    expect(find.text(Strings.lessonMatch('הגוון')), findsOneWidget);
    expect(next().onPressed, isNotNull);
  });

  testWidgets('in the lesson the child pours until the mix matches, and nothing is marked wrong', (tester) async {
    // A phone held upright, where the whole game fits without scrolling.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    final server = await pumpApp(tester, ready: true);

    await tester.tap(find.byTooltip(Strings.lessonOpen));
    await tester.pumpAndSettle();
    expect(find.textContaining('סטודיו ללק'), findsOneWidget);
    expect(find.text('יצרת גוון משלך.'), findsOneWidget);

    // Three sentences set the problem, then the game.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(Strings.lessonNext));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('8 חלקים'), findsWidgets);
    FilledButton next() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, Strings.lessonNext));
    expect(next().onPressed, isNull);

    Future<void> pour(String name, int times) async {
      for (var i = 0; i < times; i++) {
        await tester.tap(find.text(name));
        await tester.pump();
      }
    }

    // A full container with the wrong mix is described, not marked wrong, and can be changed.
    await pour('ורוד', 8);
    expect(find.text(Strings.lessonNotYet('הגוון')), findsOneWidget);
    expect(next().onPressed, isNull);
    await tester.tap(find.text(Strings.lessonRemove));
    await tester.pump();
    await tester.tap(find.text(Strings.lessonRemove));
    await tester.pump();

    await pour('לבן', 2);
    expect(find.text(Strings.lessonMatch('הגוון')), findsOneWidget);
    expect(next().onPressed, isNotNull);

    await tester.tap(find.text(Strings.lessonNext));
    await tester.pumpAndSettle();
    expect(find.textContaining('6 מתוך 8'), findsOneWidget);
    expect(server.lessonStep, 4);
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
