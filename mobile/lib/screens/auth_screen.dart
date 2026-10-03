import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import '../widgets/crisis_button.dart';
import '../widgets/errors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _newAccount = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.state.signIn(_email.text.trim(), _password.text, newAccount: _newAccount);
    } catch (e) {
      if (mounted) {
        showError(context, e, fallback: _newAccount ? Strings.errorRegister : Strings.errorLogin);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_newAccount ? Strings.authTitleRegister : Strings.authTitleLogin),
        actions: const [CrisisButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(Strings.appTitle, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (widget.state.signedOutForIdle) ...[
                    Text(Strings.idleSignedOut, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                  ],
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: Strings.email, border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    // Email addresses and passwords are typed left to right even in a Hebrew app.
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) =>
                        value == null || !value.contains('@') || !value.contains('.') ? Strings.emailInvalid : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: Strings.password,
                      helperText: Strings.passwordHint,
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) => value == null || value.length < 10 ? Strings.passwordTooShort : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_newAccount ? Strings.register : Strings.login),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _newAccount = !_newAccount),
                    child: Text(_newAccount ? Strings.switchToLogin : Strings.switchToRegister),
                  ),
                  const SizedBox(height: 16),
                  Text(Strings.notTherapy, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
