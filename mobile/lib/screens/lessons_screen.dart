import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/cartoon.dart';
import '../widgets/chat.dart';
import '../widgets/errors.dart';
import '../widgets/scene.dart';

/// The top of the home page: the learner's world and its figure greeting them by name.
/// When the profile holds nothing the learner loves, it asks for one thing, since the world is built from it.
class WelcomeHeader extends StatefulWidget {
  const WelcomeHeader({
    super.key,
    required this.api,
    required this.child,
    required this.world,
    required this.onWorldChanged,
    this.guide,
  });

  /// What day it is. Tests set it, so the person and the word of the day are known.
  static DateTime Function() today = DateTime.now;

  /// The people and words of the world, or null while they are being read.
  final WorldGuide? guide;

  final ApiClient api;
  final Child child;

  /// The learner's world, or null while it is being prepared.
  final LessonWorld? world;

  /// Called when a new interest was saved, so the world can be built from it.
  final VoidCallback onWorldChanged;

  @override
  State<WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<WelcomeHeader> {
  static const _interests = 'StrengthsAndInterests';

  final _interest = TextEditingController();

  // Null until the profile has been read.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final world = widget.world;
    final guide = widget.guide;
    // The day picks who greets, what they say, and which word is shown.
    final now = WelcomeHeader.today();
    final day = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    final person = guide == null || guide.people.isEmpty ? null : guide.people[day % guide.people.length];
    final line = day % (Strings.welcomeLines.length + 1);
    final word = guide == null || guide.words.isEmpty ? null : guide.words[day % guide.words.length];

    return Column(
      children: [
        const SizedBox(height: 8),
        if (world == null)
          const Center(child: WaitingForReply(Strings.welcomePreparing))
        else ...[
          Text('${world.emoji} ${world.world}', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          // Someone who lives in this world greets the learner by name: a different person, saying
          // something different, each day. Until the people are known, the world's own figure does.
          if (person == null)
            Character(
              face: world.customer,
              figure: figureFor(world.world),
              says: '${widget.child.nickname}, ${world.greeting}',
              lively: true,
            )
          else
            Character(
              face: person.emoji,
              figure: figureOf(world.world, day % guide!.people.length, person.emoji),
              name: Strings.personCaption(person.name, person.role),
              says: '${widget.child.nickname}, ${line == 0 ? world.greeting : Strings.welcomeLines[line - 1]}',
              lively: true,
            ),
          if (word != null) ...[
            const SizedBox(height: 16),
            // One word a day from the learner's world. Nothing is counted and no day can be missed.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Column(
                    children: [
                      Text(
                        Strings.wordOfDay,
                        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 6),
                      Bob(child: Text(word.emoji, style: const TextStyle(fontSize: 52))),
                      Text(word.en, textDirection: TextDirection.ltr, style: theme.textTheme.headlineMedium),
                      Text(word.he, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        word.sentence,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
        if (_hasInterests == false) ...[
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
