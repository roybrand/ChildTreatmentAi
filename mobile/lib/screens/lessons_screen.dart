import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/cartoon.dart';
import '../widgets/chat.dart';
import '../widgets/errors.dart';
import '../widgets/scene.dart';
import 'lesson_screen.dart';

/// The first thing the learner sees: their own world, a welcome, and where to go from here.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.api,
    required this.child,
    required this.world,
    required this.onWorldChanged,
    required this.onOpenTopics,
  });

  final ApiClient api;
  final Child child;

  /// The learner's world, or null while it is being prepared.
  final LessonWorld? world;

  /// Called when something happened that may have changed the world: a new interest, or a lesson closed.
  final VoidCallback onWorldChanged;
  final VoidCallback onOpenTopics;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _interests = 'StrengthsAndInterests';

  final _interest = TextEditingController();

  // Null until the profile has been read. The world is built from what the learner loves, so the
  // page asks for one interest when the profile has none.
  bool? _hasInterests;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _interest.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.profileItems(widget.child.id);
      if (mounted) {
        setState(() => _hasInterests = items.any((i) => i.section == _interests && i.confirmed));
      }
    } catch (_) {
      // Everything still opens without this, in the built-in world.
      if (mounted) {
        setState(() => _hasInterests = true);
      }
    }
  }

  Future<void> _saveInterest() async {
    final text = _interest.text.trim();
    if (text.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.addProfileItem(widget.child.id, _interests, text);
      if (mounted) {
        setState(() => _hasInterests = true);
        widget.onWorldChanged();
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openLesson() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LessonScreen(api: widget.api, child: widget.child)),
    );
    widget.onWorldChanged();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final world = widget.world;

    return Scene(
      world: world,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
        children: [
          if (world == null)
            const Center(child: WaitingForReply(Strings.welcomePreparing))
          else ...[
            Center(child: Bob(child: Text(world.emoji, style: const TextStyle(fontSize: 88)))),
            const SizedBox(height: 8),
            Text(world.world, style: theme.textTheme.displaySmall, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            // The figure who lives in this world greets the learner by name.
            Center(
              child: Character(
                face: world.customer,
                figure: figureFor(world.world),
                says: '${widget.child.nickname}, ${world.greeting}',
                lively: true,
              ),
            ),
          ],
          const SizedBox(height: 28),
          if (_hasInterests == false)
            _Centered(
              child: Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Strings.lessonsAskInterest(widget.child.nickname), style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(Strings.lessonsAskInterestWhy, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _interest,
                        decoration: const InputDecoration(
                          hintText: Strings.lessonsInterestHint,
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                        maxLength: 300,
                        onSubmitted: (_) => _saveInterest(),
                      ),
                      FilledButton(
                        onPressed: _saving ? null : _saveInterest,
                        child: const Text(Strings.lessonsSaveInterest),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _Door(
                symbol: '🎬',
                title: Strings.lessonMixerTitle,
                subtitle: Strings.lessonMixerSubtitle,
                action: Strings.lessonStart,
                onTap: _openLesson,
              ),
              _Door(
                symbol: '🗺️',
                title: Strings.practiceTitle,
                subtitle: Strings.practiceSubtitle,
                action: Strings.practiceOpen,
                onTap: widget.onOpenTopics,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(Strings.lessonsIntro, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child));
}

/// One of the two ways in from the welcome page.
class _Door extends StatelessWidget {
  const _Door({
    required this.symbol,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  final String symbol;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 300,
      child: Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(symbol, style: const TextStyle(fontSize: 44)),
                const SizedBox(height: 8),
                Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onTap, child: Text(action)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
