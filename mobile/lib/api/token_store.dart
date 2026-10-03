import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tokens {
  const Tokens({required this.access, required this.refresh});

  final String access;
  final String refresh;
}

/// Where the sign-in tokens are kept between runs of the app.
abstract class TokenStore {
  Future<Tokens?> read();
  Future<void> write(Tokens tokens);
  Future<void> clear();
}

/// Keeps tokens in the platform's secure storage (Android Keystore, iOS Keychain).
/// In a browser they live only as long as the tab: closing it signs the parent out, so the next
/// person at a shared computer does not find the account open (docs/PRIVACY.md).
class SecureTokenStore implements TokenStore {
  static const _access = 'access_token';
  static const _refresh = 'refresh_token';

  final _storage = const FlutterSecureStorage(webOptions: WebOptions(useSessionStorage: true));

  @override
  Future<Tokens?> read() async {
    final access = await _storage.read(key: _access);
    final refresh = await _storage.read(key: _refresh);
    return access == null || refresh == null ? null : Tokens(access: access, refresh: refresh);
  }

  @override
  Future<void> write(Tokens tokens) async {
    await _storage.write(key: _access, value: tokens.access);
    await _storage.write(key: _refresh, value: tokens.refresh);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}

/// Keeps tokens only while the app runs. Used in tests.
class MemoryTokenStore implements TokenStore {
  Tokens? _tokens;

  @override
  Future<Tokens?> read() async => _tokens;

  @override
  Future<void> write(Tokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
