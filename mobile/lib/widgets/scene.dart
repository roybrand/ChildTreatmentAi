import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/models.dart';

/// The learner's world as a backdrop: its two colours as a soft gradient, and the things that
/// belong to it drifting slowly behind the content.
class Scene extends StatefulWidget {
  const Scene({super.key, required this.world, required this.child, this.cinema = false});

  /// Switched off in tests, where an animation that never ends would never let a screen settle.
  static bool animate = true;

  /// Null while the world is still being read: the scene is then plain.
  final LessonWorld? world;
  final Widget child;

  /// A darker stage with the content lit in the middle, for the question screen.
  final bool cinema;

  @override
  State<Scene> createState() => _SceneState();
}

class _SceneState extends State<Scene> with SingleTickerProviderStateMixin {
  late final _drift = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void initState() {
    super.initState();
    if (Scene.animate) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final world = widget.world;
    final surface = Theme.of(context).colorScheme.surface;
    final a = world == null ? surface : Color(world.ingredientA.color);
    final b = world == null ? surface : Color(world.ingredientB.color);
    final base = widget.cinema ? const Color(0xFF14121C) : surface;
    final strength = widget.cinema ? 0.38 : 0.20;
    final decor = world?.decor.characters.toList() ?? const <String>[];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.alphaBlend(a.withValues(alpha: strength), base),
            Color.alphaBlend(b.withValues(alpha: strength), base),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (decor.isNotEmpty)
            // The backdrop never takes a tap meant for the content, and is skipped by screen readers.
            IgnorePointer(
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _drift,
                  builder: (context, _) => LayoutBuilder(
                    builder: (context, box) => Stack(
                      children: [
                        for (var i = 0; i < 10; i++) _floating(decor[i % decor.length], i, box.biggest),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (widget.cinema)
            // A spotlight: bright in the middle, dark towards the edges.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.1,
                    colors: [Color(0x00000000), Color(0x99000000)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }

  /// One drifting symbol. Each has its own place, size, and pace, worked out from its number,
  /// so the backdrop looks scattered and stays the same from one build to the next.
  Widget _floating(String symbol, int i, Size area) {
    final t = _drift.value * 2 * math.pi;
    final seedX = (i * 0.618) % 1;
    final seedY = (i * 0.381 + 0.13) % 1;
    final dx = math.sin(t + i * 1.7) * 18;
    final dy = math.cos(t * (0.6 + (i % 3) * 0.2) + i) * 26;
    return Positioned(
      left: seedX * (area.width - 56) + dx,
      top: seedY * (area.height - 56) + dy,
      child: Transform.rotate(
        angle: math.sin(t + i) * 0.25,
        child: Opacity(
          opacity: widget.cinema ? 0.28 : 0.34,
          child: Text(symbol, style: TextStyle(fontSize: 26.0 + (i % 4) * 9)),
        ),
      ),
    );
  }
}

/// A character that is alive: it bobs gently up and down.
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.lively = false});

  final Widget child;

  /// A bigger, quicker bounce, for a character that is pleased.
  final bool lively;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (Scene.animate) {
      _bob.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      child: widget.child,
      builder: (context, child) {
        final lift = Curves.easeInOut.transform(_bob.value);
        return Transform.translate(
          offset: Offset(0, -lift * (widget.lively ? 16 : 7)),
          child: Transform.rotate(angle: widget.lively ? (lift - 0.5) * 0.24 : 0, child: child),
        );
      },
    );
  }
}

/// The face of a character in a ring, with what it says in a bubble under it.
class Character extends StatelessWidget {
  const Character({super.key, required this.face, required this.says, this.lively = false, this.size = 96});

  final String face;
  final String says;
  final bool lively;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Bob(
          lively: lively,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surface,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
            ),
            child: Text(face, style: TextStyle(fontSize: size * 0.58)),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Container(
            key: ValueKey(says),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: Text(
              says,
              style: theme.textTheme.titleLarge?.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// A burst of the world's symbols, flying outward once, when something comes out right.
class Burst extends StatefulWidget {
  const Burst({super.key, required this.symbols});

  final String symbols;

  @override
  State<Burst> createState() => _BurstState();
}

class _BurstState extends State<Burst> with SingleTickerProviderStateMixin {
  late final _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (Scene.animate) {
      _fly.forward();
    } else {
      _fly.value = 1;
    }
  }

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final symbols = widget.symbols.characters.toList();
    if (symbols.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          height: 120,
          child: AnimatedBuilder(
            animation: _fly,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_fly.value);
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 12; i++)
                    Transform.translate(
                      offset: Offset.fromDirection(i * math.pi / 6, t * (70 + (i % 3) * 30)),
                      child: Opacity(
                        opacity: (1 - t).clamp(0, 1).toDouble(),
                        child: Text(symbols[i % symbols.length], style: TextStyle(fontSize: 22 + t * 12)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
