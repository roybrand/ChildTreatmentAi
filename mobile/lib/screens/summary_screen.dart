import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/chat.dart';
import '../widgets/errors.dart';

/// The Planner's weekly summaries, newest first.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.api, required this.child});

  final ApiClient api;
  final Child child;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  List<WeeklySummary> _summaries = [];
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summaries = await widget.api.summaries(widget.child.id);
      if (mounted) {
        setState(() => _summaries = summaries);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _create() async {
    setState(() => _working = true);
    try {
      final result = await widget.api.createSummary(widget.child.id);
      if (!mounted) {
        return;
      }
      final summary = result.summary;
      if (summary != null && result.created) {
        setState(() => _summaries = [summary, ..._summaries]);
      } else {
        // No new summary: say why, in the server's words, or that today's is already there.
        _say(result.text ?? Strings.summaryExisting);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 8)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'summary-create',
        onPressed: _working ? null : _create,
        icon: const Icon(Icons.auto_awesome_outlined),
        label: const Text(Strings.summaryCreate),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          if (_working) const WaitingForReply(Strings.summaryWorking),
          if (_summaries.isEmpty && !_working)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(Strings.summaryEmpty, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            ),
          for (final summary in _summaries) _SummaryCard(summary),
          if (_summaries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(Strings.summaryNote, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day}.${date.month}';

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.summary);

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mood = summary.moodAverage;
    final previousMood = summary.previousMoodAverage;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(text, style: theme.textTheme.titleSmall),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_formatDate(summary.weekStart)} – ${_formatDate(summary.weekEnd)}.${summary.weekEnd.year}',
                style: theme.textTheme.titleMedium, textDirection: TextDirection.ltr),
            const SizedBox(height: 4),
            // The numbers come from the log itself, so the parent can check the summary against them.
            Text('${Strings.summaryEntries}: ${summary.logEntries}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            if (mood != null)
              Text(
                '${Strings.summaryMood}: $mood'
                '${previousMood == null ? '' : ' (${Strings.summaryPreviousMood}: $previousMood)'}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            heading(Strings.summaryWhatHappened),
            Text(summary.whatHappened),
            if (summary.patterns.isNotEmpty) ...[
              heading(Strings.summaryPatterns),
              for (final pattern in summary.patterns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsetsDirectional.only(end: 8, top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: pattern.observed ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          pattern.observed ? Strings.summaryObserved : Strings.summaryGuess,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      Expanded(child: Text(pattern.text)),
                    ],
                  ),
                ),
            ],
            if (summary.whatWorked.isNotEmpty) ...[
              heading(Strings.summaryWhatWorked),
              for (final worked in summary.whatWorked)
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $worked')),
            ],
            heading(Strings.summaryProposal),
            Text(summary.proposal),
          ],
        ),
      ),
    );
  }
}
