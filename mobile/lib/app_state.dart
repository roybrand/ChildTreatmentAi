import 'package:flutter/foundation.dart';

import 'api/api_client.dart';
import 'api/models.dart';

/// Where the parent is on the way into the app.
enum SessionStage { loading, signedOut, needsConsent, needsChild, ready }

/// The signed-in session: which stage the parent is at, and which child they are working with.
class AppState extends ChangeNotifier {
  AppState(this.api);

  /// The version of the consent text the parent agrees to. Change it when the text changes.
  static const consentVersion = 'draft-1';

  final ApiClient api;

  SessionStage stage = SessionStage.loading;
  List<Child> children = [];
  Child? child;

  /// True when the app signed the parent out after a stretch without activity, so the
  /// sign-in screen can say why.
  bool signedOutForIdle = false;

  /// Works out the stage from what the server says. Called at start and after each step.
  Future<void> refresh() async {
    if (!await api.hasSession()) {
      _set(SessionStage.signedOut);
      return;
    }

    try {
      children = await api.children();
      child = children.isEmpty ? null : children.first;
      _set(children.isEmpty ? SessionStage.needsChild : SessionStage.ready);
    } on ApiException catch (e) {
      if (e.isConsentRequired) {
        _set(SessionStage.needsConsent);
      } else if (e.isUnauthorized) {
        _set(SessionStage.signedOut);
      } else {
        rethrow;
      }
    }
  }

  Future<void> signIn(String email, String password, {required bool newAccount}) async {
    if (newAccount) {
      await api.register(email, password);
    }
    await api.login(email, password);
    signedOutForIdle = false;
    await refresh();
  }

  Future<void> giveConsent() async {
    await api.giveConsent(consentVersion);
    await refresh();
  }

  Future<void> addChild(String nickname, int birthYear) async {
    await api.addChild(nickname, birthYear);
    await refresh();
  }

  Future<void> signOut({bool idle = false}) async {
    await api.logout();
    signedOutForIdle = idle;
    _clear();
  }

  Future<void> deleteEverything() async {
    await api.deleteFamily();
    _clear();
  }

  void _clear() {
    children = [];
    child = null;
    _set(SessionStage.signedOut);
  }

  void _set(SessionStage value) {
    stage = value;
    notifyListeners();
  }
}
