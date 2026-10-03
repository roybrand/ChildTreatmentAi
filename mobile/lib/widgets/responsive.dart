import 'package:flutter/material.dart';

/// From this width up the app is on a tablet or a computer, and navigation moves to the side.
const wideLayoutWidth = 840.0;

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideLayoutWidth;

/// Keeps content in a centred column, so lines stay readable on a wide screen.
/// On a phone the column is the full width and this changes nothing.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = reading});

  /// Conversations, lists, and long text.
  static const reading = 760.0;

  /// Forms with a few fields.
  static const form = 560.0;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
