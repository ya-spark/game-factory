import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/products.dart';
import 'core/services.dart';
import 'ui/theme/design_loader.dart';

import 'package:game_core/kit/keys/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final config = AppConfig.fromYamlString(
    await rootBundle.loadString('app.config.yaml'),
  );
  final catalog = ProductCatalog.fromYamlString(
    await rootBundle.loadString('products.yaml'),
  );
  final services = await Services.create(config: config, catalog: catalog);
  final design = config.designId == null
      ? null
      : await DesignBundle.load(config.designId!);
  final keys = await loadGameKeyMap(
    PrefsGameKeyStore(await SharedPreferences.getInstance()),
  );
  runApp(GameApp(services: services, design: design, keys: keys));
  // Slow plugin work (consent form, billing, notifications) after the first frame.
  services.initPlugins();
}
