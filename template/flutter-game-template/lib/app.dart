import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/services.dart';
import 'core/profile/child_profile.dart';
import 'ui/app_shell.dart';
import 'ui/home_screen.dart';
import 'ui/profile_picker_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/design_loader.dart';
import 'ui/theme/design_scope.dart';
import 'ui/theme/design_tokens.dart';

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
      // The look follows the active child: Game or Study mode, and the interface level from the
      // year level (Scout, Ranger). It changes at once when either changes.
      child: ListenableBuilder(
        listenable: services.profile,
        builder: (context, _) {
          final child = services.profile.activeChild;
          final mode = design?.app.resolveMode(
            child?.effectiveMode == LearnMode.study
                ? DesignMode.study
                : DesignMode.game,
          );
          return _app(cfg, seed, mode, design?.app.levelForYear(child?.year));
        },
      ),
    );
  }

  Widget _app(
    AppConfig cfg,
    Color seed,
    DesignMode? mode,
    InterfaceLevel? level,
  ) {
    return MaterialApp(
      title: cfg.displayName,
      debugShowCheckedModeBanner: false,
      theme: design != null
          ? buildDesignTheme(
              app: design!.app,
              shared: design!.shared,
              mode: mode!,
              level: level,
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
              mode: mode!,
              level: level,
              child: child!,
            ),
      home: !cfg.content.enabled && design != null
          ? FutureBuilder<ChildProfile>(
              // No learning content: no picker, one built-in local player.
              future: services.profile.ensureLocalPlayer(),
              builder: (_, snap) => snap.hasData
                  ? const AppShell()
                  : const Scaffold(body: SizedBox.shrink()),
            )
          : cfg.content.enabled
          ? ProfilePickerScreen(
              // The shell needs the design theme; a learning game without one keeps the old home.
              home: (_) =>
                  design == null ? const HomeScreen() : const AppShell(),
            )
          : const HomeScreen(),
    );
  }
}
