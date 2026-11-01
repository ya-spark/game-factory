import 'package:games_services/games_services.dart';
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

  /// Silent check for an existing sign-in (app start). Never throws.
  Future<void> refresh();

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
  Future<void> refresh() async {}
  @override
  Future<PlayerIdentity> signIn() async => current;
  @override
  Future<void> signOut() async {}
}

/// Google Play Games identity (`games_services`). Android signs the player in automatically at
/// launch when possible; [signIn] retries explicitly (user tapped "Sign in"). Until a Play Games
/// player is known the local guest identity is used, so the game always works offline.
class PlayGamesIdentityService implements IdentityService {
  PlayGamesIdentityService(this._fallback);
  final IdentityService _fallback;

  PlayerIdentity? _player;

  @override
  PlayerIdentity get current => _player ?? _fallback.current;
  @override
  bool get isSignedIn => _player != null;
  @override
  bool get isStub => false;

  /// Silent check at startup; never throws.
  @override
  Future<void> refresh() async {
    try {
      if (await GamesServices.isSignedIn) await _load();
    } on Object {
      _player = null;
    }
  }

  @override
  Future<PlayerIdentity> signIn() async {
    try {
      await GamesServices.signIn();
      if (await GamesServices.isSignedIn) await _load();
    } on Object {
      // Cancelled / offline / not configured: stay a guest.
    }
    return current;
  }

  Future<void> _load() async {
    final id = await GamesServices.getPlayerID();
    final name = await GamesServices.getPlayerName();
    if (id == null) return;
    _player = PlayerIdentity(
      id: id,
      displayName: name ?? 'Player',
      isGuest: false,
    );
  }

  /// Play Games has no in-app sign-out on Android (the player manages it in the Play Games app).
  @override
  Future<void> signOut() async {}
}
