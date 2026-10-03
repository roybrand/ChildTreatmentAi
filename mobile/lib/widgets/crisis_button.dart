import 'package:flutter/material.dart';

import '../screens/crisis_screen.dart';
import '../strings.dart';

/// Opens the crisis screen. Every screen's app bar carries it (docs/SAFETY.md: reachable from everywhere).
class CrisisButton extends StatelessWidget {
  const CrisisButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).push(CrisisScreen.route()),
        icon: const Icon(Icons.support),
        label: const Text(Strings.crisisButton),
      ),
    );
  }
}
