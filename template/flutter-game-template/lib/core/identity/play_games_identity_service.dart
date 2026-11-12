import 'package:games_services/games_services.dart';

import 'identity_service.dart';

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
