import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/api_client.dart';
import 'api/token_store.dart';
import 'app_state.dart';
import 'screens/add_child_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/home_screen.dart';
import 'strings.dart';
import 'widgets/crisis_button.dart';

void main() {
  final api = ApiClient(baseUrl: ApiClient.defaultBaseUrl, tokens: SecureTokenStore());
  runApp(ChildTreatmentApp(state: AppState(api)));
}

class ChildTreatmentApp extends StatefulWidget {
  const ChildTreatmentApp({super.key, required this.state});

  final AppState state;

  @override
  State<ChildTreatmentApp> createState() => _ChildTreatmentAppState();
}

class _ChildTreatmentAppState extends State<ChildTreatmentApp> {
  bool _startFailed = false;

  @override
  void initState() {
    super.initState();
    _start();
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
