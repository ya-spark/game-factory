import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/services.dart';
import 'parent_gate.dart';
import 'test_ids.dart';
import 'widgets.dart';

/// "More games": the studio's other games, from the bundled `more_games:` config.
/// No rewards of any kind for opening or installing another game.
class MoreGamesScreen extends StatelessWidget {
  const MoreGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final games = s.config.visibleMoreGames;
    return Scaffold(
      key: TestIds.moreGamesScreen,
      appBar: AppBar(
        leading: BackButton(key: TestIds.moreGamesBack),
        title: const Text(
          'More games',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: KidColors.grape,
        foregroundColor: Colors.white,
      ),
      body: KidPage(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'More from Active Mind Craft',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: KidColors.ink,
                ),
              ),
            ),
            for (final g in games) _GameCard(game: g),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});
  final MoreGame game;

  /// "Get it" asks a grown-up first, then opens the Play Store page.
  Future<void> _get(BuildContext context) async {
    final s = ServicesScope.of(context);
    if (await showParentGate(context, s.parentGate)) {
      await s.links.openStorePage(game.packageName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = game.status == MoreGameStatus.live;
    return KeyedSubtree(
      key: TestIds.moreGamesCard(game.id),
      child: KidPanel(
        child: ListTile(
          leading: _GameIcon(game: game),
          title: Text(
            game.name,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(game.tagline),
          trailing: live
              ? FilledButton(
                  key: TestIds.moreGamesGet(game.id),
                  onPressed: () => _get(context),
                  child: const Text('Get it'),
                )
              : const Text(
                  'Coming soon',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}

/// Small rounded tile drawn in code (no asset): the game's colour and a simple shape.
class _GameIcon extends StatelessWidget {
  const _GameIcon({required this.game});
  final MoreGame game;

  static const _colors = {
    'blockpuzzle': (Color(0xFF2EC4B6), Icons.grid_view_rounded),
    'blockfall': (Color(0xFFFF8A3D), Icons.view_agenda_rounded),
    'wingy': (Color(0xFF4FC3F7), Icons.flutter_dash),
  };

  @override
  Widget build(BuildContext context) {
    final (color, icon) =
        _colors[game.id] ?? (KidColors.grape, Icons.sports_esports);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

/// Opens [MoreGamesScreen].
void openMoreGames(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const MoreGamesScreen()));
