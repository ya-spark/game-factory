import 'package:flutter/services.dart';

import 'design_tokens.dart';

/// The design files of one app, read from the bundled assets (no network).
///
/// Choice: tokens are loaded from the bundled JSON at start-up, not generated into Dart at build
/// time. The JSON files under `design/` stay the single source of truth, and `new_game.py` only
/// has to copy them (see `docs/DESIGN_SYSTEM.md`).
class DesignBundle {
  const DesignBundle({required this.shared, required this.app});
  final SharedTokens shared;
  final AppTokens app;

  static const assetRoot = 'assets/design';

  /// Asset path of an art file of this app, e.g. `scene_game.svg`.
  String artPath(String file) => '$assetRoot/${app.appId}/art/$file';

  /// Hero scene of a mode: `scene_game`, `scene_study`, or `scene_home` (Mind apps).
  String sceneFor(DesignMode mode) {
    final m = app.resolveMode(mode);
    return artPath(
      m == DesignMode.defaultMode ? 'scene_home.svg' : 'scene_${m.key}.svg',
    );
  }

  /// Mascot of a mode, or null: only Scout and Ranger have one (a friendly shape, never a
  /// person). Champion and the Mind apps use no character.
  String? mascotFor(DesignMode mode) {
    if (app.appId != 'craft_lowteen' && app.appId != 'craft_preteen') {
      return null;
    }
    final m = app.resolveMode(mode);
    return artPath('mascot_${m.key}.svg');
  }

  /// Asset path of an icon, e.g. `coin` -> `assets/design/icons/coin.svg`.
  static String iconPath(String name) => '$assetRoot/icons/$name.svg';

  static Future<DesignBundle> load(String appId, {AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    final shared = SharedTokens.fromJson(
      await b.loadString('$assetRoot/tokens.json'),
    );
    final app = AppTokens.fromJson(
      await b.loadString('$assetRoot/$appId/tokens.json'),
    );
    return DesignBundle(shared: shared, app: app);
  }
}
