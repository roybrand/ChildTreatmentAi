import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import '../widgets/crisis_button.dart';
import '../widgets/errors.dart';
import '../widgets/responsive.dart';
import 'accommodations_screen.dart';
import 'coach_screen.dart';
import 'log_screen.dart';
import 'profile_screen.dart';
import 'summary_screen.dart';

enum _MenuAction { signOut, delete }

/// The signed-in app for one child: coach, daily log, accommodation map, profile, and weekly summary.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Keeps the tabs, and anything half-typed in them, when a resized window switches layout.
  final _tabsKey = GlobalKey();
  int _tab = 0;

  void _selectTab(int index) => setState(() => _tab = index);

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

    final wide = isWide(context);

    // Each tab keeps its state while the parent moves between them.
    final tabs = ContentWidth(
      child: IndexedStack(
        key: _tabsKey,
        index: _tab,
        children: [
          CoachScreen(api: api, child: child),
          LogScreen(api: api, child: child),
          AccommodationsScreen(api: api, child: child),
          ProfileScreen(api: api, child: child),
          SummaryScreen(api: api, child: child),
        ],
      ),
    );

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
      // A phone has the tabs along the bottom. A tablet or a computer has them down the side.
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: _selectTab,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.chat_bubble_outline), label: Text(Strings.tabCoach)),
                    NavigationRailDestination(icon: Icon(Icons.edit_note), label: Text(Strings.tabLog)),
                    NavigationRailDestination(icon: Icon(Icons.map_outlined), label: Text(Strings.tabMap)),
                    NavigationRailDestination(icon: Icon(Icons.person_outline), label: Text(Strings.tabProfile)),
                    NavigationRailDestination(icon: Icon(Icons.insights_outlined), label: Text(Strings.tabSummary)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: tabs),
              ],
            )
          : tabs,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _selectTab,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: Strings.tabCoach),
                NavigationDestination(icon: Icon(Icons.edit_note), label: Strings.tabLog),
                NavigationDestination(icon: Icon(Icons.map_outlined), label: Strings.tabMap),
                NavigationDestination(icon: Icon(Icons.person_outline), label: Strings.tabProfile),
                NavigationDestination(icon: Icon(Icons.insights_outlined), label: Strings.tabSummary),
              ],
            ),
    );
  }
}
