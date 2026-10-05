import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/crisis_button.dart';
import '../widgets/cartoon.dart';
import '../widgets/errors.dart';
import '../widgets/scene.dart';
import '../widgets/visuals.dart';
import 'lesson_screen.dart';

/// The learner's home: their grade, then the subjects of that grade, then each subject's topics
/// and sub-topics as a tree. Everything is in view; nothing is folded away.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.api,
    required this.child,
    required this.world,
    this.guide,
    this.header,
    this.onLessonClosed,
    this.onWordsPlayed,
  });

  /// The people and the English words of the learner's world, or null while they are being read.
  final WorldGuide? guide;

  /// Called after a game of words, since a wider circle may have opened.
  final VoidCallback? onWordsPlayed;

  final ApiClient api;
  final Child child;
  final LessonWorld? world;

  /// Shown above the tree: the welcome into the learner's world.
  final Widget? header;

  /// Called when a lesson was closed, since a lesson can change the learner's world.
  final VoidCallback? onLessonClosed;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  // The order the areas of a subject are shown in. An area a subject does not have is skipped.
  static const _domains = ['number', 'algebra', 'geometry', 'grammar'];
  static const _domainSymbols = {'algebra': '🔤', 'number': '🔢', 'geometry': '📐', 'grammar': '✏️'};

  // Every subject's curriculum, and which subject and class are open.
  List<CurriculumSubject>? _subjects;
  int _subject = 0;
  int _grade = 0;

  List<CurriculumGrade>? get _grades => _subjects?[_subject].grades;

  // How each sub-topic has gone so far, by its id. A sub-topic never tried is not in it.
  Map<String, SubtopicProgress> _progress = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final progress = await widget.api.practiceProgress(widget.child.id);
      if (mounted) {
        setState(() => _progress = {for (final p in progress) p.subtopicId: p});
      }
    } catch (_) {
      // The tree works without the marks.
    }
  }

  Future<void> _load() async {
    try {
      final subjects = await widget.api.curriculum();
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _subject = 0;
          _grade = _ownGrade(subjects[0].grades);
        });
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  /// The learner's own class, worked out from their age: a child starts the first grade at about six.
  /// When that grade has no content yet, the nearest one that has is opened.
  int _ownGrade(List<CurriculumGrade> grades) {
    final own = widget.child.age - 6;
    var nearest = 0;
    for (var i = 1; i < grades.length; i++) {
      if ((grades[i].grade - own).abs() < (grades[nearest].grade - own).abs()) {
        nearest = i;
      }
    }
    return nearest;
  }

  Future<void> _practise(Subtopic subtopic) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuestionsScreen(
          api: widget.api,
          child: widget.child,
          world: widget.world,
          guide: widget.guide,
          subtopic: subtopic,
        ),
      ),
    );
    // What was just practised may have changed what is worth coming back to.
    await _loadProgress();
  }

  Future<void> _playWords(int circle) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuestionsScreen(
          api: widget.api,
          child: widget.child,
          world: widget.world,
          guide: widget.guide,
          circle: circle,
        ),
      ),
    );
    widget.onWordsPlayed?.call();
  }

  Future<void> _openLesson() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LessonScreen(api: widget.api, child: widget.child)),
    );
    widget.onLessonClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final grades = _grades;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scene(
      world: widget.world,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ?widget.header,
              if (grades == null)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else ...[
                // What did not go well lately, from every class, so it is not lost in the tree.
                if (_progress.values.any((p) => p.comeBack))
                  Card(
                    color: scheme.tertiaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(Strings.practiceComeBackTitle, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(Strings.practiceComeBackWhy, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final subject in _subjects!)
                                for (final grade in subject.grades)
                                  for (final topic in grade.topics)
                                    for (final subtopic in topic.subtopics)
                                      if (subtopic.hasQuestions && (_progress[subtopic.id]?.comeBack ?? false))
                                      FilledButton.tonalIcon(
                                        onPressed: () => _practise(subtopic),
                                        icon: const Icon(Icons.replay),
                                        label: Text(subtopic.title),
                                      ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                // Level one: the class. The learner's own class is opened first.
                _Level(Strings.treeGrade),
                Center(
                  child: SegmentedButton<int>(
                    style: SegmentedButton.styleFrom(
                      textStyle: theme.textTheme.titleMedium,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                // Level two: the subject. Only mathematics has content; the others are shown as coming.
                _Level(Strings.treeSubject),
                Center(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < _subjects!.length; i++)
                        ChoiceChip(
                          avatar: Text(Strings.subjects[_subjects![i].subject]?.$1 ?? '📘'),
                          label: Text(
                            Strings.subjects[_subjects![i].subject]?.$2 ?? _subjects![i].subject,
                            style: theme.textTheme.titleMedium,
                          ),
                          selected: i == _subject,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          // Each subject opens on the learner's own class.
                          onSelected: (_) => setState(() {
                            _subject = i;
                            _grade = _ownGrade(_subjects![i].grades);
                          }),
                        ),
                      for (final (symbol, name) in Strings.subjectsComing)
                        Chip(
                          avatar: Text(symbol),
                          label: Text(
                            '$name · ${Strings.practiceSoon}',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          backgroundColor: scheme.surfaceContainerLow,
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                    ],
                  ),
                ),
                // English starts from the learner's own world, before any grammar.
                if (_subjects![_subject].subject == 'english' && widget.guide != null)
                  _WordsCard(guide: widget.guide!, world: widget.world, onPlay: _playWords),
                // Level three: the topics of the subject, by area, each with its sub-topics.
                for (final domain in _domains)
                  if (grades[_grade].topics.any((t) => t.domain == domain)) ...[
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
                    for (final topic in grades[_grade].topics.where((t) => t.domain == domain))
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(topic.title, style: theme.textTheme.titleMedium),
                              const SizedBox(height: 6),
                              for (final subtopic in topic.subtopics)
                                _SubtopicRow(
                                  subtopic: subtopic,
                                  progress: _progress[subtopic.id],
                                  onLesson: subtopic.lessonId == null ? null : _openLesson,
                                  onPractise: subtopic.hasQuestions ? () => _practise(subtopic) : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                const SizedBox(height: 24),
                Text(Strings.lessonsIntro, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The English words of the learner's world: three circles, from the heart of the world outward.
/// A circle that is not open yet is shown, so the way ahead is seen, with no lock and no count.
class _WordsCard extends StatelessWidget {
  const _WordsCard({required this.guide, required this.world, required this.onPlay});

  final WorldGuide guide;
  final LessonWorld? world;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        elevation: 2,
        color: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${world?.emoji ?? '🌍'} ${Strings.wordsTitle}', style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(Strings.wordsWhy, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              for (var circle = 1; circle <= WorldGuide.circles; circle++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: circle <= guide.openCircle ? scheme.surface : scheme.surface.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: circle <= guide.openCircle
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(Strings.wordsCircles[circle - 1], style: theme.textTheme.titleMedium),
                                // The pictures of the circle's words, as a taste of what is inside.
                                Text(
                                  guide.words.where((w) => w.circle == circle).map((w) => w.emoji).join(' '),
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ],
                            ),
                            FilledButton.icon(
                              key: ValueKey('words-$circle'),
                              onPressed: () => onPlay(circle),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text(Strings.wordsPlay),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Strings.wordsCircles[circle - 1],
                              style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            Text(
                              Strings.wordsLater,
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The name of a level of the tree, above its choices.
class _Level extends StatelessWidget {
  const _Level(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// One sub-topic: its name, and what can be done with it. A lesson teaches it; practice drills it.
class _SubtopicRow extends StatelessWidget {
  const _SubtopicRow({
    required this.subtopic,
    required this.progress,
    required this.onLesson,
    required this.onPractise,
  });

  final Subtopic subtopic;

  /// How this sub-topic has gone, or null when it was never tried.
  final SubtopicProgress? progress;
  final VoidCallback? onLesson;
  final VoidCallback? onPractise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nothingYet = onLesson == null && onPractise == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: nothingYet ? scheme.surfaceContainerLow : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            subtopic.title,
            style: theme.textTheme.bodyLarge?.copyWith(color: nothingYet ? scheme.onSurfaceVariant : null),
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // A quiet word on how it has gone. Never a score.
              if (progress != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: progress!.comeBack ? scheme.tertiaryContainer : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    progress!.comeBack ? Strings.practiceComeBackMark : Strings.practiceSteadyMark,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              if (onLesson != null)
                FilledButton.icon(
                  onPressed: onLesson,
                  icon: const Icon(Icons.movie_outlined),
                  label: const Text(Strings.lessonOpen),
                ),
              if (onPractise != null)
                FilledButton.tonalIcon(
                  onPressed: onPractise,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(Strings.practiceGo),
                ),
              // No lesson and no questions yet: shown, so the tree is whole, and plainly not a button.
              if (nothingYet)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Text(Strings.practiceSoon, style: theme.textTheme.labelMedium),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A short set of questions on one sub-topic, or on one circle of the words of the learner's world,
/// staged like a scene: the people of that world take turns asking, and react when the answer fits.
/// Nothing is marked wrong: an answer that does not fit can be tried again, or the solution can be
/// shown, step by step.
class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({
    super.key,
    required this.api,
    required this.child,
    required this.world,
    this.guide,
    this.subtopic,
    this.circle,
  }) : assert((subtopic == null) != (circle == null));

  final ApiClient api;
  final Child child;
  final LessonWorld? world;

  /// The people who ask. Without them the world's own figure asks every question.
  final WorldGuide? guide;

  /// The sub-topic to practise, or null when the questions are on a circle of words.
  final Subtopic? subtopic;

  /// The circle of words to play in, or null when the questions are on a sub-topic.
  final int? circle;

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  final _answer = TextEditingController();
  List<PracticeQuestion>? _questions;
  int _index = 0;
  PracticeCheck? _check;
  bool _showSteps = false;
  bool _showMore = false;
  bool _busy = false;

  // The name of a circle that opened while this set was played, to be told at its end.
  String? _opened;

  /// What the records of these questions are kept under.
  String get _recordId => widget.subtopic?.id ?? 'en-words-${widget.circle}';

  Future<List<PracticeQuestion>> _fetch({int? count, bool easy = false}) => widget.circle == null
      ? widget.api.practice(widget.child.id, widget.subtopic!.id, count: count ?? 5, easy: easy)
      : widget.api.words(widget.child.id, widget.circle!, count: count ?? 6);

  Future<PracticeCheck> _checked(String questionId, String answer) => widget.circle == null
      ? widget.api.checkAnswer(questionId, answer)
      : widget.api.checkWord(widget.child.id, questionId, answer);

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
      final questions = await _fetch();
      if (mounted) {
        setState(() {
          _questions = questions;
          _index = 0;
          _opened = null;
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
    _showMore = false;
  }

  Future<void> _submit() async {
    final text = _answer.text.trim();
    if (text.isEmpty || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final check = await _checked(_questions![_index].id, text);
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

  /// Moves on. How the question went is recorded, and a question the learner did not get on their own
  /// is followed by one of the same kind with smaller numbers, so the next thing they meet is within reach.
  Future<void> _next() async {
    var questions = _questions!;
    final question = questions[_index];
    final gotIt = (_check?.same ?? false) && !_showSteps;
    // Recorded quietly: a failed save must not interrupt the learner.
    final recorded = widget.api.recordPractice(widget.child.id, _recordId, gotIt: gotIt).catchError((_) {});

    if (widget.circle != null) {
      // At the end of a game of words, a wider circle may have opened. That is worth telling.
      if (_index + 1 >= questions.length) {
        try {
          await recorded;
          final now = await widget.api.worldGuide(widget.child.id);
          if (now.openCircle > (widget.guide?.openCircle ?? WorldGuide.circles)) {
            _opened = Strings.wordsCircles[now.openCircle - 1];
          }
        } catch (_) {
          // The set ends the usual way.
        }
      }
    } else if (!gotIt && !_isEasy(question)) {
      try {
        final easier = await _fetch(count: 1, easy: true);
        questions = [...questions.sublist(0, _index + 1), ...easier, ...questions.sublist(_index + 1)];
      } catch (_) {
        // Without the easier question the set simply goes on.
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _questions = questions;
      _index++;
      _reset();
    });
  }

  /// An easy question carries a mark at the end of its id.
  static bool _isEasy(PracticeQuestion question) => question.id.endsWith(':e');

  Future<void> _showHow() async {
    try {
      final shown = _check ?? await _checked(_questions![_index].id, '');
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
    // The people of this world take turns asking. Until they are known, the world's own figure asks.
    final people = widget.guide?.people ?? const <GuidePerson>[];
    final person = people.isEmpty ? null : people[_index % people.length];
    final face = person?.emoji ?? world?.customer ?? '🙂';
    final figure = person == null
        ? figureFor(world?.world ?? '')
        : figureOf(world?.world ?? '', _index % people.length, person.emoji);
    final name = person == null ? null : Strings.personCaption(person.name, person.role);

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
                  Character(
                    face: face,
                    figure: figure,
                    name: name,
                    says: _opened == null ? Strings.practiceDone : Strings.wordsNewCircle(_opened!),
                    lively: true,
                  ),
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
                if (_isEasy(question))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      Strings.practiceEasier,
                      style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (solved) Burst(symbols: world?.decor ?? '✨'),
                // The character asks the question, and answers when it comes out right.
                Character(
                  face: face,
                  figure: figure,
                  name: name,
                  // A different short line each time. The world's own thanks belongs to the mixing lesson,
                  // where it is about the shade; said after every answer it would be wrong and tiresome.
                  says: solved
                      ? Strings.practiceCheers[question.id.hashCode.abs() % Strings.practiceCheers.length]
                      : question.ask.text,
                  lively: solved,
                ),
                if (question.ask.math != null) ...[
                  const SizedBox(height: 16),
                  _Board(question.ask.math!, large: true),
                ],
                const SizedBox(height: 20),
                if (question.choices.isNotEmpty)
                  // A question with words to choose from: tapping one is the answer.
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < question.choices.length; i++)
                        ChoiceChip(
                          label: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              question.choices[i],
                              // An English word reads left to right, a Hebrew meaning right to left.
                              textDirection: RegExp('[א-ת]').hasMatch(question.choices[i])
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          selected: _answer.text == '$i',
                          showCheckmark: false,
                          onSelected: solved || _busy
                              ? null
                              : (_) {
                                  _answer.text = '$i';
                                  _submit();
                                },
                        ),
                    ],
                  )
                else
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
                if (!solved && question.choices.isEmpty)
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
                // The picture of the solution: shown with the steps, and when the answer fits.
                if (check?.visual != null && (solved || _showSteps))
                  Card(
                    color: scheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SolutionPicture(visual: check!.visual!, world: world),
                    ),
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
                // The first explanation does not reach everyone. A second one tells it another way,
                // and after that the learner is told plainly that moving on is fine.
                if (_showSteps && check != null && check.more.isNotEmpty && !_showMore)
                  TextButton.icon(
                    onPressed: () => setState(() => _showMore = true),
                    icon: const Icon(Icons.alt_route),
                    label: const Text(Strings.practiceAnotherWay),
                  ),
                if (_showMore && check != null)
                  Card(
                    color: scheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            Strings.practiceAnotherWayTitle,
                            style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          for (final step in check.more) ...[
                            Text(
                              step.text,
                              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                            if (step.math != null) ...[const SizedBox(height: 6), _Board(step.math!)],
                            const SizedBox(height: 10),
                          ],
                          Text(
                            Strings.practiceComeBack,
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (solved || _showSteps) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: _next,
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
              title: Text(widget.subtopic?.title ?? Strings.wordsCircles[widget.circle! - 1]),
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
