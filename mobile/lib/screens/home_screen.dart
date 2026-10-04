import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../app_state.dart';
import '../strings.dart';
import '../widgets/crisis_button.dart';
import '../widgets/errors.dart';
import '../widgets/responsive.dart';
import 'accommodations_screen.dart';
import 'coach_screen.dart';
import 'lesson_screen.dart';
import 'lessons_screen.dart';
import 'parent_screen.dart';
import 'practice_screen.dart';
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

  // The learner's world, shared by the welcome page and the topic map. Null while it is being prepared.
  LessonWorld? _world;

  @override
  void initState() {
    super.initState();
    if (!widget.state.features.familyCoaching) {
      _loadWorld();
    }
  }

  /// Reads the world, which the first time asks the Tutor to build it from the profile.
  Future<void> _loadWorld() async {
    try {
      final lesson = await widget.state.api.lesson(widget.state.child!.id, ApiClient.fractionsMixer);
      if (mounted) {
        setState(() => _world = lesson.world);
      }
    } catch (_) {
      // The pages still work without a world, on a plain background.
    }
  }

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
    final features = widget.state.features;
    final profile = ProfileScreen(api: api, child: child, sections: features.profileSections);

    // The tutor is the product. The parent coaching side appears only when the server has it switched on.
    final tabs = <(IconData, String, Widget)>[
      if (features.familyCoaching) ...[
        (Icons.chat_bubble_outline, Strings.tabCoach, CoachScreen(api: api, child: child)),
        (Icons.edit_note, Strings.tabLog, LogScreen(api: api, child: child)),
        (Icons.map_outlined, Strings.tabMap, AccommodationsScreen(api: api, child: child)),
        (Icons.person_outline, Strings.tabProfile, profile),
        (Icons.insights_outlined, Strings.tabSummary, SummaryScreen(api: api, child: child)),
      ] else ...[
        (
          Icons.home_outlined,
          Strings.tabHome,
          // The home page is the tree of what there is to learn, under a welcome into the learner's world.
          PracticeScreen(
            api: api,
            child: child,
            world: _world,
            onLessonClosed: _loadWorld,
            header: WelcomeHeader(api: api, child: child, world: _world, onWorldChanged: _loadWorld),
          ),
        ),
        (Icons.person_outline, Strings.tabProfile, ContentWidth(child: profile)),
        // Keyed by the tab, so the page is read again each time the parent comes to it.
        (Icons.insights_outlined, Strings.tabParent, ParentScreen(key: ValueKey(_tab == 2), api: api, child: child)),
      ],
    ];

    final wide = isWide(context);

    // Each tab keeps its state while the user moves between them.
    final stack = IndexedStack(
      key: _tabsKey,
      index: _tab,
      children: [for (final tab in tabs) tab.$3],
    );
    // The tutor's pages fill the window with the learner's world; the coaching pages stay in a column.
    final Widget body = features.familyCoaching ? ContentWidth(child: stack) : stack;

    return Scaffold(
      appBar: AppBar(
        title: Text(child.nickname),
        actions: [
          // With the coaching tabs on, the lesson opens from here, on its own screen.
          if (features.familyCoaching)
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => LessonScreen(api: api, child: child)),
              ),
              tooltip: Strings.lessonOpen,
              icon: const Icon(Icons.school_outlined),
            ),
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
                  destinations: [
                    for (final tab in tabs) NavigationRailDestination(icon: Icon(tab.$1), label: Text(tab.$2)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _selectTab,
              destinations: [
                for (final tab in tabs) NavigationDestination(icon: Icon(tab.$1), label: tab.$2),
              ],
            ),
    );
  }
}
