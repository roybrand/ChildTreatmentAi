import 'package:flutter/material.dart';

import '../api/models.dart';
import '../strings.dart';
import 'scene.dart';

/// The picture of a solution. What it shows comes from the server as numbers, worked out by code
/// together with the answer; this only draws them, in the colours and shapes of the learner's world.
class SolutionPicture extends StatelessWidget {
  const SolutionPicture({super.key, required this.visual, required this.world});

  final SolutionVisual visual;
  final LessonWorld? world;

  @override
  Widget build(BuildContext context) {
    final n = visual.numbers;
    return switch (visual.kind) {
      'shelves' when n.length == 3 => _Shelves(first: n[0], second: n[1], perGroup: n[2], world: world),
      'percent' when n.length == 3 => _Percent(percent: n[0], whole: n[1], part: n[2], world: world),
      // A picture this version of the app does not know how to draw is left out.
      _ => const SizedBox.shrink(),
    };
  }
}

Color _a(LessonWorld? world) => world == null ? const Color(0xFFE85D9A) : Color(world.ingredientA.color);
Color _b(LessonWorld? world) => world == null ? const Color(0xFF6C4AB6) : Color(world.ingredientB.color);

/// Runs once from 0 to 1 when the picture appears, so its pieces can arrive one after another.
class _Arrive extends StatefulWidget {
  const _Arrive({required this.builder});

  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<_Arrive> with SingleTickerProviderStateMixin {
  late final _run = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    if (Scene.animate) {
      _run.forward();
    } else {
      _run.value = 1;
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _run, builder: (context, _) => widget.builder(context, _run.value));
}

/// How far piece [index] of [count] has arrived at time [t]: each starts a little after the one before.
double _arrived(double t, int index, int count) {
  final start = count <= 1 ? 0.0 : index / count * 0.75;
  return Curves.easeOutBack.transform(((t - start) / 0.25).clamp(0.0, 1.0));
}

/// Two shelves, filled in rounds: each round puts a few things on the first shelf and a few on the
/// second, as the ratio says. The rounds arrive one after another, on both shelves together, so the
/// learner sees the dealing out. [perGroup] is the number of rounds.
class _Shelves extends StatelessWidget {
  const _Shelves({required this.first, required this.second, required this.perGroup, required this.world});

  final int first;
  final int second;
  final int perGroup;
  final LessonWorld? world;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final capped = world == null || world!.container == 'bottle' || world!.container == 'flask';
    final rounds = perGroup;

    Widget shelf(String name, int perRound, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.shelfLabel(name, perRound, rounds, perRound * rounds),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            _Arrive(
              builder: (context, t) => Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  for (var round = 0; round < rounds; round++)
                    Transform.scale(
                      // Round by round, and the same round lands on both shelves at the same moment.
                      scale: _arrived(t, round, rounds),
                      alignment: Alignment.bottomCenter,
                      child: _Group(count: perRound, label: '${round + 1}', color: color, capped: capped),
                    ),
                ],
              ),
            ),
            // The plank the things stand on.
            Container(
              height: 12,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFC9955B), Color(0xFF8A5A2B)],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4))],
              ),
            ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        shelf(Strings.shelfFirst, first, _a(world)),
        const SizedBox(height: 22),
        shelf(Strings.shelfSecond, second, _b(world)),
        const SizedBox(height: 12),
        Text(
          Strings.shelvesCaption(first, second, rounds),
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// What one round puts on a shelf: a small tray of things, with the number of the round above it.
class _Group extends StatelessWidget {
  const _Group({required this.count, required this.label, required this.color, required this.capped});

  final int count;
  final String label;
  final Color color;
  final bool capped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Up to six in a row, so a group of twelve is two rows and stays compact.
    final perRow = count <= 6 ? count : (count / 2).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row * perRow < count; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = row * perRow; i < count && i < (row + 1) * perRow; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: _Item(color: color, capped: capped),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One thing on the shelf: a small bottle with a cap, or a jar where the world's things are not bottles.
class _Item extends StatelessWidget {
  const _Item({required this.color, required this.capped});

  final Color color;
  final bool capped;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (capped)
          Container(
            width: 6,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFF2B2230),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ),
        Container(
          width: 13,
          height: capped ? 17 : 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color.lerp(color, Colors.white, 0.35)!, color, Color.lerp(color, Colors.black, 0.18)!],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

/// A hundred squares, with the percent of them filled, and under it what that is of the whole.
class _Percent extends StatelessWidget {
  const _Percent({required this.percent, required this.whole, required this.part, required this.world});

  final int percent;
  final int whole;
  final int part;
  final LessonWorld? world;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        _Arrive(
          builder: (context, t) => Wrap(
            spacing: 3,
            runSpacing: 3,
            alignment: WrapAlignment.center,
            children: [
              for (var row = 0; row < 5; row++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = row * 20; i < (row + 1) * 20; i++)
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          // The squares fill in order, up to the percent.
                          color: i < percent * t ? _a(world) : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          Strings.percentCaption(percent, whole, part),
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
