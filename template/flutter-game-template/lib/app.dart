import 'package:flutter/material.dart';

import 'core/services.dart';
import 'ui/home_screen.dart';

class GameApp extends StatelessWidget {
  const GameApp({super.key, required this.services});
  final Services services;

  @override
  Widget build(BuildContext context) {
    final cfg = services.config;
    final seed = Color(cfg.themeSeedColor);
    return ServicesScope(
      services: services,
      child: MaterialApp(
        title: cfg.displayName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: cfg.themeDark ? Brightness.dark : Brightness.light,
          ).copyWith(surface: cfg.themeDark ? const Color(0xFF0F2430) : null),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
