import 'package:flutter/material.dart';

import '../strings.dart';
import '../widgets/crisis_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.appTitle),
        actions: const [CrisisButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Strings.homeGreeting, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text(Strings.homeIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Text(Strings.homeNotTherapy, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            Text(Strings.homeComingSoon, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
