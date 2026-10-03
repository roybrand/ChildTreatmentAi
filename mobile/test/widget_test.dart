import 'package:child_treatment/main.dart';
import 'package:child_treatment/screens/crisis_screen.dart';
import 'package:child_treatment/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the app is laid out right to left', (tester) async {
    await tester.pumpWidget(const ChildTreatmentApp());

    final context = tester.element(find.text(Strings.homeGreeting));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('the crisis button on the home screen opens the emergency contacts', (tester) async {
    await tester.pumpWidget(const ChildTreatmentApp());

    await tester.tap(find.text(Strings.crisisButton));
    await tester.pumpAndSettle();

    expect(find.byType(CrisisScreen), findsOneWidget);
    for (final contact in crisisContacts) {
      expect(find.text(contact.name), findsOneWidget);
      expect(find.textContaining(contact.phone), findsOneWidget);
    }
  });
}
