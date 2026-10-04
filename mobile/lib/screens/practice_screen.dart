import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/crisis_button.dart';
import '../widgets/errors.dart';
import '../widgets/scene.dart';

/// The curriculum as a map: a grade at the top, then each area of mathematics with its topics,
/// and under each topic its sub-topics as buttons. Everything is in view; nothing is folded away.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.api, required this.child, required this.world});

  final ApiClient api;
  final Child child;
  final LessonWorld? world;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  static const _domains = ['algebra', 'number', 'geometry'];
  static const _domainSymbols = {'algebra': '🔤', 'number': '🔢', 'geometry': '📐'};

  List<CurriculumGrade>? _grades;
  int _grade = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final grades = await widget.api.curriculum();
      if (mounted) {
        setState(() => _grades = grades);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  void _open(Subtopic subtopic) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuestionsScreen(api: widget.api, child: widget.child, world: widget.world, subtopic: subtopic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grades = _grades;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (grades == null) {
      return Scene(world: widget.world, child: const Center(child: CircularProgressIndicator()));
    }
    final topics = grades[_grade].topics;

    return Scene(
      world: widget.world,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(Strings.practiceTitle, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              // The grade: three large buttons, always in the same place.
              Center(
                child: SegmentedButton<int>(
                  style: SegmentedButton.styleFrom(
                    textStyle: theme.textTheme.titleMedium,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    backgroundColor: scheme.surface,
                  ),
                  segments: [
                    for (var i = 0; i < grades.length; i++) ButtonSegment(value: i, label: Text(grades[i].name)),
                  ],
                  selected: {_grade},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => setState(() => _grade = selection.first),
                ),
              ),
              for (final domain in _domains)
                if (topics.any((t) => t.domain == domain)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                    child: Row(
                      children: [
                        Text(_domainSymbols[domain]!, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 10),
                        Text(Strings.practiceDomains[domain]!, style: theme.textTheme.titleLarge),
                      ],
                    ),
                  ),
                  for (final topic in topics.where((t) => t.domain == domain))
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(topic.title, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final subtopic in topic.subtopics)
                                  subtopic.hasQuestions
                                      ? FilledButton.tonalIcon(
                                          onPressed: () => _open(subtopic),
                                          icon: const Icon(Icons.play_arrow_rounded),
                                          label: Text(subtopic.title),
                                        )
                                      // No questions yet: shown, so the map is whole, but plainly not a button.
                                      : Chip(
                                          label: Text(
                                            '${subtopic.title} · ${Strings.practiceSoon}',
                                            style: TextStyle(color: scheme.onSurfaceVariant),
                                          ),
                                          backgroundColor: scheme.surfaceContainerLow,
                                          side: BorderSide(color: scheme.outlineVariant),
                                        ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A short set of questions on one sub-topic, staged like a scene: a character from the learner's
/// world asks, and reacts when the answer fits. Nothing is marked wrong: an answer that does not
/// fit can be tried again, or the solution can be shown, step by step.
class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({
    super.key,
    required this.api,
    required this.child,
    required this.world,
    required this.subtopic,
  });

  final ApiClient api;
  final Child child;
  final LessonWorld? world;
  final Subtopic subtopic;

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  final _answer = TextEditingController();
  List<PracticeQuestion>? _questions;
  int _index = 0;
  PracticeCheck? _check;
  bool _showSteps = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _questions = null);
    try {
      final questions = await widget.api.practice(widget.child.id, widget.subtopic.id);
      if (mounted) {
        setState(() {
          _questions = questions;
          _index = 0;
          _reset();
        });
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
        Navigator.of(context).pop();
      }
    }
  }

  void _reset() {
    _answer.clear();
    _check = null;
    _showSteps = false;
  }

  Future<void> _submit() async {
    final text = _answer.text.trim();
    if (text.isEmpty || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final check = await widget.api.checkAnswer(_questions![_index].id, text);
      if (mounted) {
        setState(() => _check = check);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showHow() async {
    try {
      final shown = _check ?? await widget.api.checkAnswer(_questions![_index].id, '');
      if (mounted) {
        setState(() {
          _check = shown;
          _showSteps = true;
        });
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final world = widget.world;
    final questions = _questions;
    final face = world?.customer ?? '🙂';

    // The stage is dark, so everything on it takes a dark theme in the colour of the learner's world.
    final stage = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: world == null ? const Color(0xFF3F7D7B) : Color(world.ingredientA.color),
        brightness: Brightness.dark,
      ),
    );

    return Theme(
      data: stage,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;

          Widget body;
          if (questions == null) {
            body = const Center(child: CircularProgressIndicator());
          } else if (_index >= questions.length) {
            body = Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Burst(symbols: world?.decor ?? '✨'),
                  Character(face: face, says: Strings.practiceDone, lively: true),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _load, child: const Text(Strings.practiceMore)),
                ],
              ),
            );
          } else {
            final question = questions[_index];
            final check = _check;
            final solved = check?.same ?? false;

            body = ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // Where in the set the learner is: one dot per question.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < questions.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 26 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: i <= _index ? scheme.primary : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  Strings.practiceCount(_index + 1, questions.length),
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (solved) Burst(symbols: world?.decor ?? '✨'),
                // The character asks the question, and answers when it comes out right.
                Character(
                  face: face,
                  says: solved ? (world?.thanks ?? Strings.practiceSame) : question.ask.text,
                  lively: solved,
                ),
                if (question.ask.math != null) ...[
                  const SizedBox(height: 16),
                  _Board(question.ask.math!, large: true),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: _answer,
                  // Numbers and expressions read left to right, also inside a Hebrew screen.
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                  decoration: InputDecoration(
                    hintText: Strings.practiceAnswerHint,
                    filled: true,
                    fillColor: scheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  enabled: !solved,
                  onChanged: (_) => setState(() => _check = null),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                if (!solved)
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text(Strings.practiceCheck, style: theme.textTheme.titleMedium),
                  ),
                if (check != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    solved ? Strings.practiceSame : Strings.practiceNotYet,
                    style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface),
                    textAlign: TextAlign.center,
                  ),
                ],
                // The way to the solution is always open, before an answer and after one.
                if (!_showSteps && !solved)
                  TextButton.icon(
                    onPressed: _showHow,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text(Strings.practiceShowHow),
                  ),
                if (_showSteps && check != null)
                  Card(
                    color: scheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final step in check.steps) ...[
                            Text(
                              step.text,
                              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                            if (step.math != null) ...[const SizedBox(height: 6), _Board(step.math!)],
                            const SizedBox(height: 14),
                          ],
                          Text(
                            Strings.practiceTheAnswer(check.answer),
                            style: theme.textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (solved || _showSteps) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => setState(() {
                      _index++;
                      _reset();
                    }),
                    child: const Text(Strings.practiceNextQuestion),
                  ),
                ],
              ],
            );
          }

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: Text(widget.subtopic.title),
              actions: const [CrisisButton()],
            ),
            body: Scene(
              world: world,
              cinema: true,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: body),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Mathematics on a board: written left to right, large, on its own lit panel.
class _Board extends StatelessWidget {
  const _Board(this.math, {this.large = false});

  final String math;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: large ? 18 : 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        math,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        style: (large ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)
            ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}
