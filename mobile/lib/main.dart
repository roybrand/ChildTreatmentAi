import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/api_client.dart';
import 'api/token_store.dart';
import 'app_state.dart';
import 'screens/add_child_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/crisis_screen.dart';
import 'screens/home_screen.dart';
import 'strings.dart';
import 'widgets/crisis_button.dart';

void main() {
  final api = ApiClient(baseUrl: ApiClient.defaultBaseUrl, tokens: SecureTokenStore());
  runApp(ChildTreatmentApp(
    state: AppState(api),
    // A browser may be on a computer the whole family uses. A phone has its own lock.
    idleTimeout: kIsWeb ? const Duration(minutes: 15) : null,
  ));
}

class ChildTreatmentApp extends StatefulWidget {
  const ChildTreatmentApp({super.key, required this.state, this.idleTimeout});

  final AppState state;

  /// Signs the parent out after this long with no touch, click, scroll, or key press. Null turns it off.
  final Duration? idleTimeout;

  @override
  State<ChildTreatmentApp> createState() => _ChildTreatmentAppState();
}

class _ChildTreatmentAppState extends State<ChildTreatmentApp> {
  final _navigator = GlobalKey<NavigatorState>();
  Timer? _idleTimer;
  bool _startFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.idleTimeout != null) {
      widget.state.addListener(_restartIdleTimer);
      HardwareKeyboard.instance.addHandler(_onKey);
    }
    _start();
  }

  @override
  void dispose() {
    if (widget.idleTimeout != null) {
      widget.state.removeListener(_restartIdleTimer);
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
    _idleTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _startFailed = false);
    try {
      await widget.state.refresh();
    } catch (_) {
      // The server could not be reached at start: offer a retry, with the crisis screen still in reach.
      if (mounted) {
        setState(() => _startFailed = true);
      }
    }
  }

  bool _onKey(KeyEvent event) {
    _restartIdleTimer();
    // Not handled here: the key still goes to whatever has the focus.
    return false;
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    final signedIn = widget.state.stage != SessionStage.signedOut && widget.state.stage != SessionStage.loading;
    _idleTimer = signedIn ? Timer(widget.idleTimeout!, _signOutForIdle) : null;
  }

  Future<void> _signOutForIdle() async {
    // Close anything open on top, such as a half-written log entry, so nothing is left on screen.
    // The crisis screen stays: it holds no family data, and it must never close on someone who needs it.
    _navigator.currentState?.popUntil((route) => route.isFirst || route.settings.name == CrisisScreen.routeName);
    await widget.state.signOut(idle: true);
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      navigatorKey: _navigator,
      title: Strings.appTitle,
      debugShowCheckedModeBanner: false,
      // Hebrew only for now. The Hebrew locale makes the whole app right-to-left.
      locale: const Locale('he'),
      supportedLocales: const [Locale('he')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F7D7B)),
      ),
      home: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          if (_startFailed) {
            return _StartFailedScreen(onRetry: _start);
          }
          return switch (widget.state.stage) {
            SessionStage.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
            SessionStage.signedOut => AuthScreen(state: widget.state),
            SessionStage.needsConsent => ConsentScreen(state: widget.state),
            SessionStage.needsChild => AddChildScreen(state: widget.state),
            // Keyed by child, so screens reload when the child changes.
            SessionStage.ready => HomeScreen(key: ValueKey(widget.state.child!.id), state: widget.state),
          };
        },
      ),
    );

    if (widget.idleTimeout == null) {
      return app;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restartIdleTimer(),
      onPointerSignal: (_) => _restartIdleTimer(),
      child: app,
    );
  }
}

class _StartFailedScreen extends StatelessWidget {
  const _StartFailedScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.appTitle), actions: const [CrisisButton()]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(Strings.errorNetwork, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text(Strings.continueLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
