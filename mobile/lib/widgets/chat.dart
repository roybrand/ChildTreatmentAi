import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/models.dart';
import '../screens/crisis_screen.dart';
import '../strings.dart';

/// One message in a conversation with an agent.
class MessageBubble extends StatelessWidget {
  const MessageBubble(this.message, {super.key});

  final CoachMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCrisis = message.kind == MessageKind.crisis && !message.fromParent;

    final (background, foreground) = switch ((message.fromParent, message.kind)) {
      (true, _) => (scheme.primaryContainer, scheme.onPrimaryContainer),
      (false, MessageKind.crisis) => (scheme.errorContainer, scheme.onErrorContainer),
      (false, MessageKind.normal) => (scheme.surfaceContainerHighest, scheme.onSurface),
      // A withheld or unavailable reply is shown plainly, so it is not mistaken for the agent's own words.
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

/// The line shown while an agent is writing its answer.
class WaitingForReply extends StatelessWidget {
  const WaitingForReply(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// The text box and send button at the bottom of a conversation.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final bool sending;
  final VoidCallback onSend;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  late final _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void dispose() {
    _focus.dispose();
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
    widget.onSend();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                decoration: InputDecoration(hintText: widget.hint, border: const OutlineInputBorder()),
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: widget.sending ? null : widget.onSend,
              tooltip: Strings.send,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
