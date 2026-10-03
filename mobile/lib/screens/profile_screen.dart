import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/chat.dart';
import '../widgets/crisis_button.dart';
import '../widgets/errors.dart';
import '../widgets/responsive.dart';

/// What the app knows about the child. The parent adds, accepts, and removes items here.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api, required this.child});

  final ApiClient api;
  final Child child;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<ProfileItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.profileItems(widget.child.id);
      if (mounted) {
        setState(() => _items = items);
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

  Future<void> _openInterview() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => InterviewScreen(api: widget.api, child: widget.child)),
    );
    // The interview writes items down, so the list is read again on the way back.
    await _load();
  }

  Future<void> _add() async {
    final added = await showDialog<(String, String)>(context: context, builder: (_) => const _AddItemDialog());
    if (added == null) {
      return;
    }
    try {
      final item = await widget.api.addProfileItem(widget.child.id, added.$1, added.$2);
      if (mounted) {
        setState(() => _items = [..._items, item]);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  /// Accepting keeps the item as fact. Rejecting or removing takes it out of the profile.
  Future<void> _decide(ProfileItem item, bool confirmed) async {
    try {
      await widget.api.setProfileItem(widget.child.id, item.id, confirmed: confirmed);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = [
          for (final i in _items)
            if (i.id != item.id)
              i
            else if (confirmed)
              ProfileItem(id: i.id, section: i.section, text: i.text, confirmed: true),
        ];
      });
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final sections = [
      for (final section in profileSections)
        if (_items.any((i) => i.section == section)) section,
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'profile-interview',
        onPressed: _openInterview,
        icon: const Icon(Icons.forum_outlined),
        label: const Text(Strings.profileInterview),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(Strings.profileEmpty, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            ),
          for (final section in sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text(Strings.profileSections[section] ?? section, style: theme.textTheme.titleSmall),
            ),
            for (final item in _items.where((i) => i.section == section))
              item.confirmed
                  ? Card(
                      child: ListTile(
                        title: Text(item.text),
                        trailing: IconButton(
                          onPressed: () => _decide(item, false),
                          tooltip: Strings.profileRemove,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    )
                  : PendingItemCard(item: item, onDecide: (confirmed) => _decide(item, confirmed)),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text(Strings.profileAdd),
            ),
          ),
        ],
      ),
    );
  }
}

/// Something the Profile Agent wrote down from the interview, waiting for the parent to say whether it is right.
class PendingItemCard extends StatelessWidget {
  const PendingItemCard({super.key, required this.item, required this.onDecide});

  final ProfileItem item;
  final void Function(bool confirmed) onDecide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Strings.profileWaiting, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(item.text, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(onPressed: () => onDecide(true), child: const Text(Strings.profileAccept)),
                TextButton(onPressed: () => onDecide(false), child: const Text(Strings.profileReject)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _text = TextEditingController();
  String _section = profileSections.first;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.profileAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _section,
            decoration: const InputDecoration(labelText: Strings.profileSection, border: OutlineInputBorder()),
            items: [
              for (final section in profileSections)
                DropdownMenuItem(value: section, child: Text(Strings.profileSections[section] ?? section)),
            ],
            onChanged: (value) => setState(() => _section = value ?? _section),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            decoration: const InputDecoration(labelText: Strings.profileItemText, border: OutlineInputBorder()),
            minLines: 2,
            maxLines: 5,
            maxLength: 300,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(Strings.cancel)),
        FilledButton(
          onPressed: () {
            final text = _text.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(context).pop((_section, text));
            }
          },
          child: const Text(Strings.save),
        ),
      ],
    );
  }
}

/// The onboarding interview with the Profile Agent.
class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key, required this.api, required this.child});

  final ApiClient api;
  final Child child;

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  // Messages, and after an answer the items written down from it.
  List<Object> _entries = [];
  bool _complete = false;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final interview = await widget.api.interview(widget.child.id);
      if (mounted) {
        setState(() {
          _entries = [
            CoachMessage(fromParent: false, kind: MessageKind.normal, text: interview.opening),
            ...interview.messages,
          ];
          _complete = interview.complete;
        });
        _scrollToEnd();
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

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _entries = [..._entries, CoachMessage(fromParent: true, kind: MessageKind.normal, text: text)];
      _sending = true;
    });
    _input.clear();
    _scrollToEnd();

    try {
      final turn = await widget.api.sendToInterview(widget.child.id, text);
      if (mounted) {
        setState(() {
          _entries = [..._entries, turn.message, ...turn.items];
          _complete = _complete || turn.complete;
        });
      }
    } catch (e) {
      if (mounted) {
        // The message did not reach the server: take it back out and return the text to the box.
        setState(() => _entries = _entries.sublist(0, _entries.length - 1));
        _input.text = text;
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  Future<void> _decide(ProfileItem item, bool confirmed) async {
    try {
      await widget.api.setProfileItem(widget.child.id, item.id, confirmed: confirmed);
      if (mounted) {
        // Once decided, the card leaves the conversation. The profile shows what was accepted.
        setState(() => _entries = [for (final e in _entries) if (e != item) e]);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.profileInterview), actions: const [CrisisButton()]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidth(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) => switch (_entries[index]) {
                        final CoachMessage message => MessageBubble(message),
                        final ProfileItem item =>
                          PendingItemCard(item: item, onDecide: (confirmed) => _decide(item, confirmed)),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ),
                  if (_complete && !_sending)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(Strings.interviewComplete, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  if (_sending) const WaitingForReply(Strings.interviewThinking),
                  MessageComposer(
                    controller: _input,
                    hint: Strings.interviewHint,
                    sending: _sending,
                    onSend: _send,
                  ),
                ],
              ),
            ),
    );
  }
}
