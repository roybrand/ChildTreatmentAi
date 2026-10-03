/// The Mixer lesson: fractions as parts of a whole, and equal fractions.
///
/// Everything here is arithmetic and wording frames, written and checked by code.
/// The Tutor supplies only the world (names and colours), never a number.
/// See docs/TUTOR_LESSONS.md.
library;

import 'dart:ui';

import '../api/models.dart';

/// A fraction of the first ingredient: [parts] out of [total] equal parts.
class Fraction {
  const Fraction(this.parts, this.total);

  final int parts;
  final int total;

  /// Equal fractions give the same mix. Compared by cross-multiplying, so there is no rounding.
  bool sameAs(Fraction other) => parts * other.total == other.parts * total;

  /// How many parts of the first ingredient make this mix in a container of [slots] parts.
  /// Null when it does not come out as a whole number of parts.
  int? partsIn(int slots) => (parts * slots) % total == 0 ? parts * slots ~/ total : null;

  String get written => '$parts⁄$total';
}

/// The colour of a mix: a point between the two ingredient colours.
Color mixColor(Color a, Color b, int partsA, int partsB) {
  final total = partsA + partsB;
  return total == 0 ? const Color(0x00000000) : Color.lerp(b, a, partsA / total)!;
}

sealed class LessonStep {
  const LessonStep();
}

/// One sentence, optionally with containers shown beside it.
class TellStep extends LessonStep {
  const TellStep(this.text, {this.show = const []});

  final String text;

  /// Filled containers to show, each as a fraction of the first ingredient.
  final List<Fraction> show;
}

/// The child pours into a container of [slots] parts until the mix matches [target].
class MixStep extends LessonStep {
  const MixStep(this.text, {required this.slots, required this.target});

  final String text;
  final int slots;
  final Fraction target;
}

/// A question with a few answers to tap. Nothing is marked wrong: a tap that does not match
/// shows both mixes side by side, and the child chooses again.
class ChoiceStep extends LessonStep {
  const ChoiceStep(this.text, {required this.options, required this.target, required this.toFraction});

  final String text;
  final List<String> options;
  final Fraction target;

  /// The mix an answer stands for, so it can be shown next to the target. Null for "not the same".
  final Fraction? Function(int option) toFraction;

  /// Decided by arithmetic, never by the Tutor.
  bool matches(int option) => toFraction(option)?.sameAs(target) ?? false;
}

class DoneStep extends LessonStep {
  const DoneStep(this.text);

  final String text;
}

const _yes = 'כן';
const _no = 'לא';

/// The steps of the lesson, in order: a real problem, play, discover, name it, practise, bridge to school.
List<LessonStep> mixerLessonSteps(LessonWorld world) {
  const mine = Fraction(3, 4);
  const half = Fraction(1, 2);
  final a = world.ingredientA.name;
  final b = world.ingredientB.name;
  final result = world.resultWord;

  return [
    // 1. A real problem
    TellStep(world.scene),
    TellStep('${world.smallLabel}: 4 חלקים. 3 $a ו-1 $b.', show: const [mine]),
    TellStep(world.request),
    // 2. Play
    MixStep('${world.bigLabel}: 8 חלקים. צריך בדיוק את $result שיצרת.', slots: 8, target: mine),
    // 3. Discover
    TellStep('3 מתוך 4, ו-6 מתוך 8: זה בדיוק אותו דבר.', show: const [mine, Fraction(6, 8)]),
    const TellStep('שני המספרים הוכפלו, והתערובת נשארה אותה תערובת.', show: [mine, Fraction(6, 8)]),
    MixStep('ועכשיו 12 חלקים. שוב צריך בדיוק את $result שיצרת.', slots: 12, target: mine),
    // 4. Name it
    const TellStep('למה שעשית יש שם. 3 חלקים מתוך 4 כותבים ¾, וזה שבר.'),
    const TellStep('¾ ו-6⁄8 הם אותה כמות. קוראים להם שברים שווים.', show: [mine, Fraction(6, 8)]),
    TellStep(world.whyNeeded),
    // 5. Practise
    MixStep('תערובת חדשה: חצי $a וחצי $b. קודם ב-4 חלקים.', slots: 4, target: half),
    MixStep('אותה תערובת, חצי וחצי, ב-10 חלקים.', slots: 10, target: half),
    ChoiceStep(
      'מישהו הביא 16 חלקים, ומתוכם 12 $a. זה $result שיצרת?',
      options: const [_yes, _no],
      target: mine,
      toFraction: (option) => option == 0 ? const Fraction(12, 16) : null,
    ),
    // 6. Bridge to school
    const TellStep('¾ = 6⁄8 = 9⁄12', show: [mine, Fraction(6, 8), Fraction(9, 12)]),
    const TellStep('ככה זה נראה בדף עבודה. זה אותו דבר שעשית עם הכלים.'),
    ChoiceStep(
      'להשלים: ¾ = ?⁄8',
      options: const ['5', '6', '7'],
      target: mine,
      toFraction: (option) => Fraction(5 + option, 8),
    ),
    ChoiceStep(
      'האם ½ ו-5⁄10 שווים?',
      options: const [_yes, _no],
      target: half,
      toFraction: (option) => option == 0 ? const Fraction(5, 10) : null,
    ),
    const DoneStep('סיימת את השיעור. אפשר לחזור אליו מתי שרוצים.'),
  ];
}
