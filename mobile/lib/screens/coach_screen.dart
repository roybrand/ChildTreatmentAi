import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/chat.dart';
import '../widgets/errors.dart';

/// The conversation with the Parent Coach.
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, required this.api, required this.child});

  final ApiClient api;
  final Child child;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<CoachMessage> _messages = [];
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
      final messages = await widget.api.coachHistory(widget.child.id);
      if (mounted) {
        setState(() => _messages = messages);
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
      _messages = [..._messages, CoachMessage(fromParent: true, kind: MessageKind.normal, text: text)];
      _sending = true;
    });
    _input.clear();
    _scrollToEnd();

    try {
      final reply = await widget.api.sendToCoach(widget.child.id, text);
      if (mounted) {
        setState(() => _messages = [..._messages, reply]);
      }
    } catch (e) {
      if (mounted) {
        // The message did not reach the server: take it back out and return the text to the box.
        setState(() => _messages = _messages.sublist(0, _messages.length - 1));
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const _EmptyHint(Strings.coachEmpty)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => MessageBubble(_messages[index]),
                ),
        ),
        if (_sending) const WaitingForReply(Strings.coachThinking),
        MessageComposer(controller: _input, hint: Strings.coachHint, sending: _sending, onSend: _send),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
      ),
    );
  }
}
