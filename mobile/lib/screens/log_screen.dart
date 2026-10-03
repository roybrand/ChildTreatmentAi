import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/errors.dart';
import 'crisis_screen.dart';

/// The parent's daily log.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.api, required this.child});

  final ApiClient api;
  final Child child;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  List<LogEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.api.log(widget.child.id);
      if (mounted) {
        setState(() => _entries = entries);
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

  Future<void> _add() async {
    final result = await Navigator.of(context).push<LogEntryResult>(
      MaterialPageRoute(builder: (_) => _LogEntryForm(api: widget.api, child: widget.child)),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _entries = [result.entry, ..._entries]);

    // What the parent wrote matched the crisis rules: show them who to call.
    if (result.crisis) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CrisisScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // The tabs live side by side, so each floating button needs its own tag for page transitions.
        heroTag: 'log-add',
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text(Strings.logAdd),
      ),
      body: _entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(Strings.logEmpty,
                    style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: _entries.length,
              itemBuilder: (context, index) => _LogCard(_entries[index]),
            ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day}.${date.month}.${date.year}';

class _LogCard extends StatelessWidget {
  const _LogCard(this.entry);

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_formatDate(entry.date), style: theme.textTheme.labelLarge),
                const Spacer(),
                if (entry.parentMood != null)
                  Text('${Strings.logMood} ${entry.parentMood}/5', style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(entry.whatHappened),
            if (entry.childReaction != null) _Labelled(Strings.logChildReaction, entry.childReaction!),
            if (entry.parentResponse != null) _Labelled(Strings.logParentResponse, entry.parentResponse!),
          ],
        ),
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled(this.label, this.text);

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(text),
        ],
      ),
    );
  }
}

class _LogEntryForm extends StatefulWidget {
  const _LogEntryForm({required this.api, required this.child});

  final ApiClient api;
  final Child child;

  @override
  State<_LogEntryForm> createState() => _LogEntryFormState();
}

class _LogEntryFormState extends State<_LogEntryForm> {
  final _form = GlobalKey<FormState>();
  final _whatHappened = TextEditingController();
  final _childReaction = TextEditingController();
  final _parentResponse = TextEditingController();
  int? _mood;
  bool _busy = false;

  @override
  void dispose() {
    _whatHappened.dispose();
    _childReaction.dispose();
    _parentResponse.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await widget.api.addLogEntry(
        widget.child.id,
        date: DateTime.now(),
        whatHappened: _whatHappened.text.trim(),
        childReaction: _childReaction.text,
        parentResponse: _parentResponse.text,
        parentMood: _mood,
      );
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.logAdd)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _whatHappened,
                decoration: const InputDecoration(labelText: Strings.logWhatHappened, border: OutlineInputBorder()),
                minLines: 3,
                maxLines: 6,
                maxLength: 4000,
                validator: (value) => value == null || value.trim().isEmpty ? Strings.requiredField : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _childReaction,
                decoration: const InputDecoration(
                  labelText: Strings.logChildReaction,
                  helperText: Strings.logOptional,
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _parentResponse,
                decoration: const InputDecoration(
                  labelText: Strings.logParentResponse,
                  helperText: Strings.logOptional,
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              Text(Strings.logMood, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [for (var i = 1; i <= 5; i++) ButtonSegment(value: i, label: Text('$i'))],
                selected: {?_mood},
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _mood = selection.isEmpty ? null : selection.first),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text(Strings.logMoodLow, style: theme.textTheme.bodySmall),
                    const Spacer(),
                    Text(Strings.logMoodHigh, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _busy ? null : _save, child: const Text(Strings.save)),
            ],
          ),
        ),
      ),
    );
  }
}
