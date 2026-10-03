import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import '../widgets/crisis_button.dart';
import '../widgets/errors.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  static const _minAge = 6;
  static const _maxAge = 18;

  final _form = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  int? _birthYear;
  bool _busy = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.state.addChild(_nickname.text.trim(), _birthYear!);
    } catch (e) {
      if (mounted) {
        showError(context, e);
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
    final thisYear = DateTime.now().year;
    final years = [for (var age = _minAge; age <= _maxAge; age++) thisYear - age];

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.addChildTitle), actions: const [CrisisButton()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(Strings.addChildIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nickname,
                decoration: const InputDecoration(labelText: Strings.nickname, border: OutlineInputBorder()),
                maxLength: 50,
                validator: (value) => value == null || value.trim().isEmpty ? Strings.requiredField : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _birthYear,
                decoration: const InputDecoration(labelText: Strings.birthYear, border: OutlineInputBorder()),
                items: [for (final year in years) DropdownMenuItem(value: year, child: Text('$year'))],
                onChanged: (value) => setState(() => _birthYear = value),
                validator: (value) => value == null ? Strings.birthYearInvalid : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: const Text(Strings.continueLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
