import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import '../widgets/crisis_button.dart';
import '../widgets/errors.dart';
import 'accommodations_screen.dart';
import 'coach_screen.dart';
import 'log_screen.dart';

enum _MenuAction { signOut, delete }

/// The signed-in app: coach, daily log, and accommodation map for one child.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  Future<void> _onMenu(_MenuAction action) async {
    switch (action) {
      case _MenuAction.signOut:
        await widget.state.signOut();
      case _MenuAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(Strings.deleteConfirmTitle),
            content: const Text(Strings.deleteConfirmBody),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(Strings.cancel)),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(Strings.deleteConfirm),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return;
        }
        try {
          await widget.state.deleteEverything();
        } catch (e) {
          if (mounted) {
            showError(context, e);
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.state.api;
    final child = widget.state.child!;

    return Scaffold(
      appBar: AppBar(
        title: Text(child.nickname),
        actions: [
          const CrisisButton(),
          PopupMenuButton<_MenuAction>(
            onSelected: _onMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(value: _MenuAction.signOut, child: Text(Strings.menuSignOut)),
              PopupMenuItem(value: _MenuAction.delete, child: Text(Strings.menuDelete)),
            ],
          ),
        ],
      ),
      // Each tab keeps its state while the parent moves between them.
      body: IndexedStack(
        index: _tab,
        children: [
          CoachScreen(api: api, child: child),
          LogScreen(api: api, child: child),
          AccommodationsScreen(api: api, child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: Strings.tabCoach),
          NavigationDestination(icon: Icon(Icons.edit_note), label: Strings.tabLog),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: Strings.tabMap),
        ],
      ),
    );
  }
}
