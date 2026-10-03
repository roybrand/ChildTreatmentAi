import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/errors.dart';
import 'crisis_screen.dart';

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
  late final _inputFocus = FocusNode(onKeyEvent: _onKey);
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
    _inputFocus.dispose();
    super.dispose();
  }

  /// On a computer, Enter sends and Shift+Enter starts a new line. On a phone, Enter is a new line.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    const computers = {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux};
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter ||
        HardwareKeyboard.instance.isShiftPressed ||
        !computers.contains(defaultTargetPlatform)) {
      return KeyEventResult.ignored;
    }
    _send();
    return KeyEventResult.handled;
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
                  itemBuilder: (context, index) => _Bubble(_messages[index]),
                ),
        ),
        if (_sending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text(Strings.coachThinking, style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocus,
                    decoration: const InputDecoration(hintText: Strings.coachHint, border: OutlineInputBorder()),
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 4000,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  tooltip: Strings.send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
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

class _Bubble extends StatelessWidget {
  const _Bubble(this.message);

  final CoachMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCrisis = message.kind == MessageKind.crisis && !message.fromParent;

    final (background, foreground) = switch ((message.fromParent, message.kind)) {
      (true, _) => (scheme.primaryContainer, scheme.onPrimaryContainer),
      (false, MessageKind.crisis) => (scheme.errorContainer, scheme.onErrorContainer),
      (false, MessageKind.normal) => (scheme.surfaceContainerHighest, scheme.onSurface),
      // A withheld or unavailable reply is shown plainly, so it is not mistaken for coaching.
      (false, _) => (scheme.surfaceContainerLow, scheme.onSurfaceVariant),
    };

    // Sized against the conversation column, which is narrower than the window on a wide screen.
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: message.fromParent ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.85),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(message.text, style: TextStyle(color: foreground, height: 1.4)),
              if (isCrisis) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(CrisisScreen.route()),
                  icon: const Icon(Icons.support),
                  label: const Text(Strings.crisisOpenScreen),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
