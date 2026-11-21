/// The shared foundation of every game: the content and quiz engine (pure Dart, import
/// `package:game_core/engine/engine.dart` for it alone) and the host contract a game uses to
/// ask its container for speech, banners and settings.
library;

export 'engine/engine.dart';
export 'host/game_host.dart';
export 'kit/kit.dart';
export 'mind/mind.dart';
