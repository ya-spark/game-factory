import 'package:flutter/material.dart';

import 'core/services.dart';
import 'ui/home_screen.dart';
import 'ui/profile_picker_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/design_loader.dart';
import 'ui/theme/design_scope.dart';

class GameApp extends StatelessWidget {
  const GameApp({super.key, required this.services, this.design});
  final Services services;

  /// The app's design files (null: the plain seed-colour look). Loaded in `main` when
  /// `theme.design` is set in app.config.yaml.
  final DesignBundle? design;

  @override
  Widget build(BuildContext context) {
    final cfg = services.config;
    final seed = Color(cfg.themeSeedColor);
    return ServicesScope(
      services: services,
      child: MaterialApp(
        title: cfg.displayName,
        debugShowCheckedModeBanner: false,
        // The design theme is the app's first mode (Game for Craft, Default for Mind); the mode
        // switch and the child's level come with issue 02B.
        theme: design != null
            ? buildDesignTheme(
                app: design!.app,
                shared: design!.shared,
                mode: design!.app.modes.keys.first,
              )
            : ThemeData(
                useMaterial3: true,
                colorScheme:
                    ColorScheme.fromSeed(
                      seedColor: seed,
                      brightness: cfg.themeDark
                          ? Brightness.dark
                          : Brightness.light,
                    ).copyWith(
                      surface: cfg.themeDark ? const Color(0xFF0F2430) : null,
                    ),
              ),
        builder: design == null
            ? null
            : (context, child) => DesignScope(
                design: design!,
                mode: design!.app.modes.keys.first,
                child: child!,
              ),
        home: cfg.content.enabled
            ? ProfilePickerScreen(home: (_) => const HomeScreen())
            : const HomeScreen(),
      ),
    );
  }
}
