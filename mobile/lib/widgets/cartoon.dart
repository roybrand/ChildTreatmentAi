import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scene.dart';

enum Hair { bob, long, short, curly, bun, cap }

enum Extra { none, glasses, headband, earrings }

/// How a character looks at this moment.
enum Mood {
  /// Asking something: eyes open, a small smile.
  asking,

  /// Pleased: eyes closed in a smile, a wide open smile, a bounce.
  happy,
}

/// One member of the fixed cast: a drawn cartoon figure, the same every time it appears.
class Figure {
  const Figure({
    required this.skin,
    required this.hair,
    required this.shirt,
    required this.style,
    this.extra = Extra.none,
  });

  final Color skin;
  final Color hair;
  final Color shirt;
  final Hair style;
  final Extra extra;
}

/// The cast. Drawn in code, so there are no image files to load and every figure scales to any screen.
const cast = [
  Figure(skin: Color(0xFFF2C9A8), hair: Color(0xFF5A3825), shirt: Color(0xFFE85D9A), style: Hair.long, extra: Extra.earrings),
  Figure(skin: Color(0xFFC68B5E), hair: Color(0xFF1F1A17), shirt: Color(0xFF3D8BDB), style: Hair.curly),
  Figure(skin: Color(0xFFFFDDBF), hair: Color(0xFFE0A93B), shirt: Color(0xFF4CAF7A), style: Hair.bob, extra: Extra.glasses),
  Figure(skin: Color(0xFF8D5A3B), hair: Color(0xFF2A1B14), shirt: Color(0xFFF2994A), style: Hair.short),
  Figure(skin: Color(0xFFEBB58F), hair: Color(0xFFB5462F), shirt: Color(0xFF8E6BD6), style: Hair.bun, extra: Extra.headband),
  Figure(skin: Color(0xFFD9A074), hair: Color(0xFF3A2A20), shirt: Color(0xFFE2574C), style: Hair.cap),
  Figure(skin: Color(0xFFFFD2B0), hair: Color(0xFF2B2B33), shirt: Color(0xFF2FB7B0), style: Hair.long, extra: Extra.glasses),
  Figure(skin: Color(0xFFA9714B), hair: Color(0xFF4A2E1E), shirt: Color(0xFFD94F8A), style: Hair.bob, extra: Extra.earrings),
];

/// The cast member who belongs to a world. The same world always gets the same figure.
Figure figureFor(String world) {
  var hash = 7;
  for (final unit in world.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return cast[hash % cast.length];
}

/// A cartoon figure that is alive: it blinks, and its face changes with its mood.
class Cartoon extends StatefulWidget {
  const Cartoon({super.key, required this.figure, this.mood = Mood.asking, this.size = 120});

  final Figure figure;
  final Mood mood;
  final double size;

  @override
  State<Cartoon> createState() => _CartoonState();
}

class _CartoonState extends State<Cartoon> with SingleTickerProviderStateMixin {
  // One cycle is a few seconds of open eyes and a quick blink at the end.
  late final _life = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));

  @override
  void initState() {
    super.initState();
    if (Scene.animate) {
      _life.repeat();
    }
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _life,
      builder: (context, _) {
        final blinking = _life.value > 0.94;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _FigurePainter(widget.figure, widget.mood, blinking: blinking),
        );
      },
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.figure, this.mood, {required this.blinking});

  final Figure figure;
  final Mood mood;
  final bool blinking;

  static const _ink = Color(0xFF2B2230);

  @override
  void paint(Canvas canvas, Size size) {
    // Everything is drawn on a 100 by 100 sheet and scaled to the size asked for.
    canvas.scale(size.width / 100);
    final skin = Paint()..color = figure.skin;
    final hair = Paint()..color = figure.hair;
    final shade = Paint()..color = Color.lerp(figure.skin, Colors.brown, 0.18)!;
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Hair that falls behind the head.
    switch (figure.style) {
      case Hair.long:
        canvas.drawRRect(RRect.fromLTRBR(20, 22, 80, 90, const Radius.circular(26)), hair);
      case Hair.bob:
        canvas.drawRRect(RRect.fromLTRBR(19, 20, 81, 70, const Radius.circular(28)), hair);
      case Hair.curly:
        for (final (x, y) in [(24.0, 34.0), (20.0, 50.0), (76.0, 34.0), (80.0, 50.0), (34.0, 20.0), (66.0, 20.0), (50.0, 15.0)]) {
          canvas.drawCircle(Offset(x, y), 12, hair);
        }
      case Hair.bun:
        canvas.drawCircle(const Offset(50, 11), 11, hair);
      case Hair.short || Hair.cap:
        break;
    }

    // Shoulders and neck.
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(16, 80, 84, 104, topLeft: const Radius.circular(26), topRight: const Radius.circular(26)),
      Paint()..color = figure.shirt,
    );
    canvas.drawRRect(RRect.fromLTRBR(42, 68, 58, 86, const Radius.circular(6)), shade);

    // Ears and head.
    canvas.drawCircle(const Offset(23, 48), 6, skin);
    canvas.drawCircle(const Offset(77, 48), 6, skin);
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 46), width: 54, height: 60), skin);

    // Hair on top of the head.
    final top = Path();
    switch (figure.style) {
      case Hair.cap:
        canvas.drawArc(const Rect.fromLTRB(22, 10, 78, 58), math.pi, math.pi, true, Paint()..color = figure.shirt);
        canvas.drawRRect(RRect.fromLTRBR(18, 32, 62, 38, const Radius.circular(3)), Paint()..color = figure.shirt);
      case Hair.short:
        top
          ..moveTo(23, 40)
          ..quadraticBezierTo(24, 12, 50, 13)
          ..quadraticBezierTo(76, 12, 77, 40)
          ..quadraticBezierTo(62, 26, 50, 28)
          ..quadraticBezierTo(38, 26, 23, 40);
        canvas.drawPath(top, hair);
      default:
        // A fringe swept to one side.
        top
          ..moveTo(22, 44)
          ..quadraticBezierTo(22, 13, 50, 13)
          ..quadraticBezierTo(78, 13, 78, 44)
          ..quadraticBezierTo(70, 28, 52, 27)
          ..quadraticBezierTo(38, 30, 22, 44);
        canvas.drawPath(top, hair);
    }
    if (figure.extra == Extra.headband) {
      canvas.drawArc(
        const Rect.fromLTRB(22, 14, 78, 62),
        math.pi * 1.12,
        math.pi * 0.76,
        false,
        Paint()
          ..color = figure.shirt
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }

    // Cheeks.
    final blush = Paint()..color = const Color(0x55FF6F91);
    canvas.drawCircle(const Offset(34, 58), 6, blush);
    canvas.drawCircle(const Offset(66, 58), 6, blush);

    // Eyes: closed in a smile when happy, a line when blinking, open otherwise.
    for (final x in [39.0, 61.0]) {
      if (mood == Mood.happy) {
        canvas.drawArc(Rect.fromCenter(center: Offset(x, 49), width: 12, height: 10), math.pi, math.pi, false, line);
      } else if (blinking) {
        canvas.drawLine(Offset(x - 5, 48), Offset(x + 5, 48), line);
      } else {
        canvas.drawOval(Rect.fromCenter(center: Offset(x, 47), width: 11, height: 13), Paint()..color = Colors.white);
        canvas.drawCircle(Offset(x + 0.6, 48), 4.2, Paint()..color = _ink);
        canvas.drawCircle(Offset(x + 2, 46.2), 1.4, Paint()..color = Colors.white);
      }
    }

    // Brows, lifted a little when asking.
    final lift = mood == Mood.asking ? 37.0 : 38.5;
    canvas.drawLine(Offset(33, lift + 1), Offset(44, lift), line);
    canvas.drawLine(Offset(56, lift), Offset(67, lift + 1), line);

    if (figure.extra == Extra.glasses) {
      final frame = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawCircle(const Offset(39, 48), 9, frame);
      canvas.drawCircle(const Offset(61, 48), 9, frame);
      canvas.drawLine(const Offset(48, 48), const Offset(52, 48), frame);
    }
    if (figure.extra == Extra.earrings) {
      final gold = Paint()..color = const Color(0xFFF2C037);
      canvas.drawCircle(const Offset(22, 57), 2.6, gold);
      canvas.drawCircle(const Offset(78, 57), 2.6, gold);
    }

    // Mouth: a wide open smile when happy, a small smile when asking.
    if (mood == Mood.happy) {
      final mouth = Path()
        ..moveTo(39, 61)
        ..quadraticBezierTo(50, 77, 61, 61)
        ..close();
      canvas.drawPath(mouth, Paint()..color = const Color(0xFF7A2E3A));
      canvas.drawPath(mouth, line);
    } else {
      canvas.drawArc(const Rect.fromLTRB(42, 56, 58, 68), 0.25, math.pi - 0.5, false, line);
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.figure != figure || old.mood != mood || old.blinking != blinking;
}
