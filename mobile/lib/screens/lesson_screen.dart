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

  Future<void> _load({bool newWorld = false}) async {
    if (newWorld) {
      setState(() => _world = null);
    }
    try {
      final lesson = await widget.api.lesson(widget.child.id, ApiClient.fractionsMixer, newWorld: newWorld);
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

  /// The mix the current step asks for and the size of its container, when it has a solution to explain.
  (Fraction, int)? get _toExplain => switch (_steps[_index]) {
        MixStep(:final slots, :final target) => (target, slots),
        final ChoiceStep step => (step.target, step.toFraction(_matching(step))!.total),
        _ => null,
      };

  static int _matching(ChoiceStep step) =>
      [for (var i = 0; i < step.options.length; i++) i].firstWhere(step.matches);

  /// Shows the solution, picture by picture. If the learner chooses to move on, the step is filled in.
  Future<void> _explain() async {
    final (target, slots) = _toExplain!;
    final result = await showDialog<_Explained>(
      context: context,
      builder: (_) => _Explanation(world: _world!, target: target, slots: slots),
    );
    if (!mounted || result != _Explained.moveOn) {
      return;
    }
    setState(() {
      switch (_steps[_index]) {
        case MixStep():
          final partsA = target.partsIn(slots)!;
          _pours = [for (var i = 0; i < slots; i++) i < partsA];
        case final ChoiceStep step:
          _chosen = _matching(step);
        default:
      }
    });
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

    final surface = theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text('${world.emoji} ${world.world}'),
        actions: [
          IconButton(
            onPressed: _index == 0 ? null : () => _go(0),
            tooltip: Strings.lessonRestart,
            icon: const Icon(Icons.replay),
          ),
          IconButton(
            onPressed: () => _load(newWorld: true),
            tooltip: Strings.lessonNewWorld,
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          const CrisisButton(),
        ],
      ),
      // The screen takes on the colours of the mix, softly, so each world looks like itself.
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(_colorA(world).withValues(alpha: 0.14), surface),
              Color.alphaBlend(_colorB(world).withValues(alpha: 0.14), surface),
            ],
          ),
        ),
        child: SafeArea(
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
                      TellStep(:final text, :final show, :final fromCustomer) => fromCustomer
                          ? _Speech(face: world.customer, text: text, large: true)
                          : _Tell(text: text, show: show, world: world),
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
                // Always in reach, on a line of its own: a learner who is stuck should never have to hunt for help.
                if (_toExplain != null && !_stepDone)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.tonalIcon(
                      onPressed: _explain,
                      icon: const Icon(Icons.lightbulb_outline),
                      label: const Text(Strings.explainOpen),
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
            crossAxisAlignment: WrapCrossAlignment.end,
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

/// Something said by whoever asks for the mix: their face, and their words in a speech bubble.
class _Speech extends StatelessWidget {
  const _Speech({required this.face, required this.text, this.large = false});

  final String face;
  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: large ? 112 : 64,
          height: large ? 112 : 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant, width: 2),
          ),
          child: Text(face, style: TextStyle(fontSize: large ? 64 : 36)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text(
            text,
            style: (large ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
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
  const _Container({
    required this.slots,
    required this.world,
    this.pours = const [],
    this.cells,
    this.groupSize,
    this.width = 84,
    this.caption,
    this.label,
  });

  /// The height of one part, the same in every container.
  static const _partHeight = 20.0;
  static const _groupGap = 8.0;

  final int slots;
  final LessonWorld world;

  /// What was poured, from the bottom up: true for the first ingredient.
  final List<bool> pours;

  /// Each part on its own, for the explanation, where parts fill out of order. Null is an empty part.
  final List<bool?>? cells;

  /// When set, the parts are drawn in groups of this size with a gap between groups.
  final int? groupSize;

  final double width;
  final String? caption;

  /// A few words under the container saying which one it is.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = cells ?? [for (var i = 0; i < slots; i++) i < pours.length ? pours[i] : null];
    final partsA = parts.where((p) => p == true).length;
    final partsB = parts.where((p) => p == false).length;
    final mixed = mixColor(_colorA(world), _colorB(world), partsA, partsB);
    final gaps = groupSize == null ? 0 : (slots - 1) ~/ groupSize!;

    // A bottle or a flask has a cap; the wider containers are open at the top.
    final capped = world.container == 'bottle' || world.container == 'flask';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width * 0.4,
          height: 18,
          decoration: BoxDecoration(
            color: capped ? scheme.outline : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        Container(
          width: width,
          // Every part is the same size in every container, so a container with more parts is
          // really bigger. The story is about a bigger bottle, and the picture has to say the same.
          height: slots * _partHeight + gaps * _groupGap + 12,
          padding: const EdgeInsets.all(4),
          // A grey inside, so an empty part never looks like a part filled with a pale ingredient.
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border.all(color: scheme.outline, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            // The first pour sits at the bottom, as liquid would.
            verticalDirection: VerticalDirection.up,
            children: [
              for (var i = 0; i < slots; i++) ...[
                if (groupSize != null && i > 0 && i % groupSize! == 0) const SizedBox(height: _groupGap),
                SizedBox(
                  height: _partHeight,
                  // The colour slides in, so a part being filled is seen to fill.
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: switch (parts[i]) {
                        true => _colorA(world),
                        false => _colorB(world),
                        null => scheme.surfaceContainerHighest,
                      },
                      // A filled part has a firm edge; an empty one only a faint outline.
                      border: Border.all(color: parts[i] != null ? scheme.outline : scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        // The swatch: what the mix looks like. An empty container has none yet.
        AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: partsA + partsB == 0 ? scheme.surfaceContainerHighest : mixed,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outline),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(caption!, style: Theme.of(context).textTheme.titleMedium, textDirection: TextDirection.ltr),
        ],
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(label!, style: Theme.of(context).textTheme.labelLarge),
        ],
      ],
    );
  }
}

/// How the explanation ended.
enum _Explained {
  /// The learner wants to do it themselves now.
  gotIt,

  /// The learner wants to go on; the step is filled in for them.
  moveOn,
}

/// A walk through the solution, one small picture at a time, for a learner who is stuck.
/// It runs as long as the learner wants and ends when they say so, either way without a mark.
/// Every number in it is worked out by code from the step itself.
class _Explanation extends StatefulWidget {
  const _Explanation({required this.world, required this.target, required this.slots});

  final LessonWorld world;

  /// The mix to match, for example 3 parts out of 4.
  final Fraction target;

  /// The size of the container to fill.
  final int slots;

  @override
  State<_Explanation> createState() => _ExplanationState();
}

class _ExplanationState extends State<_Explanation> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final world = widget.world;
    final a = world.ingredientA.name;
    final b = world.ingredientB.name;
    final small = widget.target.total;
    final smallA = widget.target.parts;
    final smallB = small - smallA;
    final times = widget.slots ~/ small;
    final bigA = smallA * times;
    final bigB = smallB * times;

    // The big container as copies of the small one, stacked: each group is one copy.
    List<bool?> big({required bool withA, required bool withB}) => [
          for (var i = 0; i < widget.slots; i++)
            i % small < smallA ? (withA ? true : null) : (withB ? false : null),
        ];
    final smallCells = [for (var i = 0; i < small; i++) i < smallA];

    Widget smallOne() => _Container(slots: small, cells: smallCells, world: world, width: 60);
    Widget bigOne(List<bool?> cells) =>
        _Container(slots: widget.slots, cells: cells, groupSize: small, world: world, width: 60);

    final pages = <(String, List<Widget>)>[
      (
        Strings.explainSmall(small, smallA, a, smallB, b),
        [smallOne()],
      ),
      (
        Strings.explainTimes(widget.slots, times, small),
        [
          for (var i = 0; i < times; i++) smallOne(),
          Padding(
            padding: const EdgeInsets.only(bottom: 70),
            child: Text('=', style: theme.textTheme.displaySmall),
          ),
          bigOne(big(withA: false, withB: false)),
        ],
      ),
      (
        Strings.explainIngredient(a, times, smallA, bigA),
        [smallOne(), bigOne(big(withA: true, withB: false))],
      ),
      (
        Strings.explainIngredient(b, times, smallB, bigB),
        [smallOne(), bigOne(big(withA: true, withB: true))],
      ),
      (
        Strings.explainResult(bigA, a, bigB, b),
        [smallOne(), bigOne(big(withA: true, withB: true))],
      ),
    ];
    final last = _page == pages.length - 1;
    final (text, pictures) = pages[_page];

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // One dot per picture, in the colours of the mix.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: i <= _page ? _colorA(world) : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        text,
                        style: theme.textTheme.titleLarge?.copyWith(height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 14,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: pictures,
                      ),
                      if (last) ...[
                        const SizedBox(height: 12),
                        _Speech(face: world.customer, text: world.thanks),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => setState(() => _page--),
                      child: const Text(Strings.lessonBack),
                    ),
                  if (!last)
                    FilledButton(
                      onPressed: () => setState(() => _page++),
                      child: const Text(Strings.explainMore),
                    ),
                  // The learner can leave at any picture. Understanding is theirs to call.
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(_Explained.gotIt),
                    child: const Text(Strings.explainGotIt),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_Explained.moveOn),
                    child: const Text(Strings.explainMoveOn),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
          // The two containers stand on the same line, so the bigger one is plainly taller.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Container(
              slots: step.target.total,
              pours: [for (var i = 0; i < step.target.total; i++) i < step.target.parts],
              world: world,
              label: Strings.lessonMine,
            ),
            const SizedBox(width: 32),
            _Container(slots: step.slots, pours: pours, world: world, label: Strings.lessonNow),
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
              ? Strings.lessonNotFull(step.slots - pours.length)
              : matches
                  ? Strings.lessonMatch(world.resultWord)
                  : Strings.lessonNotYet(world.resultWord),
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        // When the mix matches, the one who asked for it answers.
        if (matches) ...[
          const SizedBox(height: 16),
          _Speech(face: world.customer, text: world.thanks),
        ],
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
            crossAxisAlignment: WrapCrossAlignment.end,
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
