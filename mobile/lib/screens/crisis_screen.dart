import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../strings.dart';

class CrisisContact {
  const CrisisContact(this.name, this.phone, this.description);

  final String name;
  final String phone;
  final String description;
}

/// Emergency contacts for Israel. They are built into the app so the screen works with no
/// connection and without signing in. Keep them in step with SafetyTexts on the server, and
/// verify every number before launch (see docs/SAFETY.md).
const crisisContacts = [
  CrisisContact('ער"ן', '1201', 'עזרה ראשונה נפשית, 24 שעות ביממה'),
  CrisisContact('מגן דוד אדום', '101', 'חירום רפואי'),
  CrisisContact('משטרה', '100', 'סכנה מיידית'),
];

class CrisisScreen extends StatelessWidget {
  const CrisisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.crisisTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(Strings.crisisIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          for (final contact in crisisContacts)
            Card(
              child: ListTile(
                title: Text(contact.name),
                subtitle: Text(contact.description),
                trailing: FilledButton.icon(
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: contact.phone)),
                  icon: const Icon(Icons.phone),
                  // Phone numbers read left to right even inside Hebrew text.
                  label: Text('${Strings.call} ${contact.phone}', textDirection: TextDirection.rtl),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(Strings.crisisAlsoContact, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
