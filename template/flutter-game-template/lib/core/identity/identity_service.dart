import 'package:shared_preferences/shared_preferences.dart';

class PlayerIdentity {
  const PlayerIdentity({
    required this.id,
    required this.displayName,
    required this.isGuest,
  });
  final String id;
  final String displayName;
  final bool isGuest;
}

/// Who is playing. Game/UI code never talks to Play Games directly.
abstract interface class IdentityService {
  PlayerIdentity get current;

  /// True when a real (non-guest) identity is active.
  bool get isSignedIn;

  /// True if this implementation is a placeholder for a real vendor integration.
  bool get isStub;

  Future<PlayerIdentity> signIn();
  Future<void> signOut();
}

/// Local guest identity (generated once, stored locally).
class LocalIdentityService implements IdentityService {
  LocalIdentityService(this._prefs);
  final SharedPreferences _prefs;

  @override
  PlayerIdentity get current {
    var id = _prefs.getString('identity.guest_id');
    if (id == null) {
      id = 'guest-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      _prefs.setString('identity.guest_id', id);
    }
    return PlayerIdentity(id: id, displayName: 'Guest', isGuest: true);
  }

  @override
  bool get isSignedIn => false;
  @override
  bool get isStub => false;
  @override
  Future<PlayerIdentity> signIn() async => current;
  @override
  Future<void> signOut() async {}
}

// ---------------------------------------------------------------------------
// STUB: Google Play Games identity.
// Not implemented in v1. Falls back to the local guest identity. To implement:
// use a Play Games plugin (e.g. `games_services`) in this file only, keep the
// IdentityService interface unchanged, and follow docs/PLAY_SETUP.md (Play Games Services).
// ---------------------------------------------------------------------------
class PlayGamesIdentityStub implements IdentityService {
  PlayGamesIdentityStub(this._fallback);
  final IdentityService _fallback;

  @override
  PlayerIdentity get current => _fallback.current;
  @override
  bool get isSignedIn => false;
  @override
  bool get isStub => true;
  @override
  Future<PlayerIdentity> signIn() => _fallback.signIn(); // STUB: no Play Games sign-in yet
  @override
  Future<void> signOut() => _fallback.signOut();
}
