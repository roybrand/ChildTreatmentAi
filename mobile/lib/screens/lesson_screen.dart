import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../lesson/mixer_lesson.dart';
import '../strings.dart';
import '../widgets/chat.dart';
import '../widgets/crisis_button.dart';
import '../widgets/errors.dart';
import '../widgets/responsive.dart';

/// The Mixer lesson, set in the child's own world.
/// Nothing here is ever marked wrong: the colour shows the result and the child adjusts.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.api, required this.child});

  final ApiClient api;
  final Child child;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  LessonWorld? _world;
  List<LessonStep> _steps = [];
  int _index = 0;

  // The mix being poured in the current step: true for the first ingredient, in pouring order.
  List<bool> _pours = [];
  // The answer last tapped in a choice step, if any.
  int? _chosen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lesson = await widget.api.lesson(widget.child.id, ApiClient.fractionsMixer);
      if (!mounted) {
        return;
      }
      final steps = mixerLessonSteps(lesson.world);
      setState(() {
        _world = lesson.world;
        _steps = steps;
        // A finished lesson opens from the start; an unfinished one resumes where it stopped.
        _index = lesson.completed ? 0 : lesson.stepReached.clamp(0, steps.length - 1);
      });
    } catch (e) {
      if (mounted) {
        showError(context, e);
        Navigator.of(context).pop();
      }
    }
  }

  void _go(int index) {
    setState(() {
      _index = index;
      _pours = [];
      _chosen = null;
    });
    // Progress is saved quietly. A failed save must not interrupt a child in the middle of a lesson.
    widget.api
        .saveLessonProgress(widget.child.id, ApiClient.fractionsMixer,
            step: index, completed: _steps[index] is DoneStep)
        .catchError((_) {});
  }

  /// Whether the current step is finished, so the lesson can move on.
  bool get _stepDone => switch (_steps[_index]) {
        MixStep(:final slots, :final target) =>
          _pours.length == slots && Fraction(_pours.where((p) => p).length, slots).sameAs(target),
        final ChoiceStep step => _chosen != null && step.matches(_chosen!),
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final world = _world;
    if (world == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(Strings.lessonOpen), actions: const [CrisisButton()]),
        body: const Center(child: WaitingForReply(Strings.lessonPreparing)),
      );
    }

    final step = _steps[_index];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(world.world), actions: const [CrisisButton()]),
      body: SafeArea(
        child: ContentWidth(
          maxWidth: ContentWidth.form,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LinearProgressIndicator(value: (_index + 1) / _steps.length),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: switch (step) {
                      TellStep(:final text, :final show) => _Tell(text: text, show: show, world: world),
                      DoneStep(:final text) => _Tell(text: text, show: const [], world: world),
                      final MixStep mix => _Mixer(
                          step: mix,
                          world: world,
                          pours: _pours,
                          onChanged: (pours) => setState(() => _pours = pours),
                        ),
                      final ChoiceStep choice => _Choice(
                          step: choice,
                          world: world,
                          chosen: _chosen,
                          onChosen: (option) => setState(() => _chosen = option),
                        ),
                    },
                  ),
                ),
                Row(
                  children: [
                    if (_index > 0)
                      TextButton(onPressed: () => _go(_index - 1), child: const Text(Strings.lessonBack)),
                    const Spacer(),
                    if (step is DoneStep)
                      OutlinedButton(onPressed: () => _go(0), child: const Text(Strings.lessonAgain))
                    else
                      FilledButton(
                        onPressed: _stepDone ? () => _go(_index + 1) : null,
                        style: FilledButton.styleFrom(textStyle: theme.textTheme.titleMedium),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(Strings.lessonNext),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _colorA(LessonWorld world) => Color(world.ingredientA.color);
Color _colorB(LessonWorld world) => Color(world.ingredientB.color);

/// One sentence in large type, with containers under it when the step shows any.
class _Tell extends StatelessWidget {
  const _Tell({required this.text, required this.show, required this.world});

  final String text;
  final List<Fraction> show;
  final LessonWorld world;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Sentence(text),
        if (show.isNotEmpty) ...[
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (final fraction in show)
                _Container(
                  slots: fraction.total,
                  pours: [for (var i = 0; i < fraction.total; i++) i < fraction.parts],
                  world: world,
                  caption: fraction.written,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Sentence extends StatelessWidget {
  const _Sentence(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(height: 1.5),
      textAlign: TextAlign.center,
    );
  }
}

/// A container divided into equal parts, filled from the bottom in the order poured.
class _Container extends StatelessWidget {
  const _Container({required this.slots, required this.pours, required this.world, this.caption});

  final int slots;
  final List<bool> pours;
  final LessonWorld world;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final partsA = pours.where((p) => p).length;
    final mixed = mixColor(_colorA(world), _colorB(world), partsA, pours.length - partsA);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 176,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            // The first pour sits at the bottom, as liquid would.
            verticalDirection: VerticalDirection.up,
            children: [
              for (var i = 0; i < slots; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: i < pours.length ? (pours[i] ? _colorA(world) : _colorB(world)) : null,
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // The swatch: what the mix looks like. An empty container has none yet.
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: pours.isEmpty ? null : mixed,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outline),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(caption!, style: Theme.of(context).textTheme.titleMedium, textDirection: TextDirection.ltr),
        ],
      ],
    );
  }
}

/// The game: pour the two ingredients until the mix matches the one the child made.
class _Mixer extends StatelessWidget {
  const _Mixer({required this.step, required this.world, required this.pours, required this.onChanged});

  final MixStep step;
  final LessonWorld world;
  final List<bool> pours;
  final ValueChanged<List<bool>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final full = pours.length == step.slots;
    final partsA = pours.where((p) => p).length;
    final matches = full && Fraction(partsA, step.slots).sameAs(step.target);

    Widget pour(Ingredient ingredient, bool first) => FilledButton.tonalIcon(
          onPressed: full ? null : () => onChanged([...pours, first]),
          icon: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Color(ingredient.color),
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outline),
            ),
          ),
          label: Text(ingredient.name, style: theme.textTheme.titleMedium),
        );

    return Column(
      children: [
        _Sentence(step.text),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Text(Strings.lessonMine, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                _Container(
                  slots: step.target.total,
                  pours: [for (var i = 0; i < step.target.total; i++) i < step.target.parts],
                  world: world,
                ),
              ],
            ),
            const SizedBox(width: 32),
            Column(
              children: [
                Text(Strings.lessonNow, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                _Container(slots: step.slots, pours: pours, world: world),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            pour(world.ingredientA, true),
            pour(world.ingredientB, false),
            OutlinedButton(
              onPressed: pours.isEmpty ? null : () => onChanged(pours.sublist(0, pours.length - 1)),
              child: const Text(Strings.lessonRemove),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          !full
              ? '${pours.length} / ${step.slots} ${Strings.lessonParts}. ${Strings.lessonKeepPouring}'
              : matches
                  ? Strings.lessonMatch(world.resultWord)
                  : Strings.lessonNotYet(world.resultWord),
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// A question with answers to tap. An answer that does not match is not marked wrong:
/// the two mixes are shown side by side and the child chooses again.
class _Choice extends StatelessWidget {
  const _Choice({required this.step, required this.world, required this.chosen, required this.onChosen});

  final ChoiceStep step;
  final LessonWorld world;
  final int? chosen;
  final ValueChanged<int> onChosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = chosen;
    final matched = picked != null && step.matches(picked);
    // What to lay beside the target: the picked mix, or for "not the same" the mix in question.
    final beside = picked == null ? null : step.toFraction(picked) ?? step.toFraction(0);

    return Column(
      children: [
        _Sentence(step.text),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < step.options.length; i++)
              ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(step.options[i], style: theme.textTheme.titleLarge),
                ),
                selected: picked == i,
                showCheckmark: false,
                onSelected: (_) => onChosen(i),
              ),
          ],
        ),
        if (picked != null) ...[
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            alignment: WrapAlignment.center,
            children: [
              for (final fraction in [step.target, ?beside])
                _Container(
                  slots: fraction.total,
                  pours: [for (var i = 0; i < fraction.total; i++) i < fraction.parts],
                  world: world,
                  caption: fraction.written,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            matched ? Strings.lessonSame : Strings.lessonLookAtBoth,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
