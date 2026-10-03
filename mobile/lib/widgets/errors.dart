import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../strings.dart';

/// Shows a short message for a failed action. [fallback] replaces the generic text for server errors.
void showError(BuildContext context, Object error, {String? fallback}) {
  final message = error is ApiException && error.isNetwork ? Strings.errorNetwork : fallback ?? Strings.errorGeneric;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
