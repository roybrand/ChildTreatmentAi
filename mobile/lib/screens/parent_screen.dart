import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/errors.dart';
import '../widgets/responsive.dart';

/// The parent's view of how practice is going: this week at a glance, what is worth returning to,
/// and every sub-topic that was practised, with when and how it went.
///
/// It reports facts and gives no grade. The learner's own pages never show these numbers.
class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key, required this.api, required this.child});

  final ApiClient api;
  final Child child;

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  List<SubtopicProgress>? _progress;
  // Sub-topic id to its title and the title of its topic, for showing names in place of ids.
  Map<String, (String, String)> _names = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final subjects = await widget.api.curriculum();
      final progress = await widget.api.practiceProgress(widget.child.id);
      if (mounted) {
        setState(() {
          _names = {
            for (var circle = 1; circle <= WorldGuide.circles; circle++)
              'en-words-$circle': (Strings.parentWords(circle), Strings.parentWordsGroup),
            for (final subject in subjects)
              for (final grade in subject.grades)
                for (final topic in grade.topics)
                  for (final subtopic in topic.subtopics)
                    subtopic.id: (
                      subtopic.title,
                      '${Strings.subjects[subject.subject]?.$2 ?? subject.subject} · ${grade.name} · ${topic.title}',
                    ),
          };
          _progress = progress;
        });
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  static String _date(DateTime at) {
    final local = at.toLocal();
    return '${local.day}.${local.month}.${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (progress == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final triedThisWeek = progress.fold(0, (sum, p) => sum + p.triedThisWeek);
    final gotItThisWeek = progress.fold(0, (sum, p) => sum + p.gotItThisWeek);
    final practisedThisWeek = progress.where((p) => p.triedThisWeek > 0).length;
    final comeBack = progress.where((p) => p.comeBack).toList();

    return ContentWidth(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: Text(Strings.parentTitle(widget.child.nickname), style: theme.textTheme.headlineSmall)),
                IconButton(onPressed: _load, tooltip: Strings.parentRefresh, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 4),
            Text(Strings.parentWhatIsKept, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (progress.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(Strings.parentEmpty, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              )
            else ...[
              // This week, in three plain numbers.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Strings.parentThisWeek, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 28,
                        runSpacing: 12,
                        children: [
                          _Figure('$triedThisWeek', Strings.parentTried),
                          _Figure('$gotItThisWeek', Strings.parentGotIt),
                          _Figure('$practisedThisWeek', Strings.parentSubtopics),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (comeBack.isNotEmpty)
                Card(
                  color: scheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Strings.practiceComeBackTitle, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(Strings.parentComeBackWhy, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        for (final p in comeBack) Text('• ${_names[p.subtopicId]?.$1 ?? p.subtopicId}'),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Text(Strings.parentAll, style: theme.textTheme.titleMedium),
              ),
              // Everything practised, the most recent first.
              for (final p in progress)
                Card(
                  child: ListTile(
                    title: Text(_names[p.subtopicId]?.$1 ?? p.subtopicId),
                    subtitle: Text(
                      '${_names[p.subtopicId]?.$2 ?? ''}\n'
                      '${Strings.parentLine(p.tried, p.gotIt, _date(p.lastAt))}',
                    ),
                    isThreeLine: true,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: p.comeBack ? scheme.tertiaryContainer : scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        p.comeBack ? Strings.practiceComeBackMark : Strings.practiceSteadyMark,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A number with what it counts under it.
class _Figure extends StatelessWidget {
  const _Figure(this.number, this.label);

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(number, style: theme.textTheme.headlineMedium),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
