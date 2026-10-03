import 'package:child_treatment/api/models.dart';
import 'package:child_treatment/lesson/mixer_lesson.dart';
import 'package:flutter_test/flutter_test.dart';

const world = LessonWorld(
  world: 'סטודיו ללק',
  scene: 'יצרת גוון משלך.',
  request: 'לקוחה רוצה בקבוק גדול.',
  ingredientA: Ingredient(name: 'ורוד', color: 0xFFE85D9A),
  ingredientB: Ingredient(name: 'לבן', color: 0xFFFFFFFF),
  smallLabel: 'הבקבוק הקטן',
  bigLabel: 'הבקבוק הגדול',
  resultWord: 'הגוון',
  whyNeeded: 'כדי להכין שוב את אותו דבר.',
);

void main() {
  test('equal fractions are the same mix, and others are not', () {
    expect(const Fraction(3, 4).sameAs(const Fraction(6, 8)), isTrue);
    expect(const Fraction(3, 4).sameAs(const Fraction(9, 12)), isTrue);
    expect(const Fraction(3, 4).sameAs(const Fraction(5, 8)), isFalse);
    expect(const Fraction(1, 2).sameAs(const Fraction(5, 10)), isTrue);
  });

  test('a mix that does not fit a container in whole parts has no answer', () {
    expect(const Fraction(3, 4).partsIn(8), 6);
    expect(const Fraction(3, 4).partsIn(10), isNull);
  });

  test('every pouring step can be solved in whole parts', () {
    final steps = mixerLessonSteps(world).whereType<MixStep>().toList();
    expect(steps, isNotEmpty);
    for (final step in steps) {
      expect(step.target.partsIn(step.slots), isNotNull, reason: step.text);
    }
  });

  test('every question has exactly one answer that matches', () {
    final steps = mixerLessonSteps(world).whereType<ChoiceStep>().toList();
    expect(steps, isNotEmpty);
    for (final step in steps) {
      final matching = [for (var i = 0; i < step.options.length; i++) if (step.matches(i)) i];
      expect(matching, hasLength(1), reason: step.text);
    }
  });

  test('the lesson ends with a closing step and names the ingredients from the world', () {
    final steps = mixerLessonSteps(world);
    expect(steps.last, isA<DoneStep>());
    expect((steps[1] as TellStep).text, contains('ורוד'));
  });
}
