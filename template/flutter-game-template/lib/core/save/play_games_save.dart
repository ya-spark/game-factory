import 'package:games_services/games_services.dart';

import 'save_service.dart';

/// Google Play Games "Saved Games" backend (`games_services`). One snapshot holds the whole
/// [SaveData] JSON. Throws when the player is not signed in; [SyncingSaveService] treats that as
/// "cloud unavailable" and keeps using local storage.
class PlayGamesCloudSave implements CloudSaveBackend {
  static const String slot = 'save';

  @override
  Future<String?> read() => GamesServices.loadGame(name: slot);

  @override
  Future<void> write(String json) async {
    await GamesServices.saveGame(data: json, name: slot);
  }
}
