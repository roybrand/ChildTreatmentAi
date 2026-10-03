import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import '../widgets/crisis_button.dart';
import '../widgets/errors.dart';
import '../widgets/responsive.dart';

/// Nothing about a child is stored until the parent agrees here.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _accepted = false;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.state.giveConsent();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.consentTitle), actions: const [CrisisButton()]),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(Strings.consentIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            for (final point in Strings.consentPoints)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: 12, top: 2),
                      child: Icon(Icons.check_circle_outline, size: 20),
                    ),
                    Expanded(child: Text(point, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _accepted,
              onChanged: _busy ? null : (value) => setState(() => _accepted = value ?? false),
              title: const Text(Strings.consentCheckbox),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _accepted && !_busy ? _submit : null,
              child: const Text(Strings.continueLabel),
            ),
            const SizedBox(height: 16),
            Text(Strings.consentDraftNote, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
