import 'package:flutter/material.dart';

import '../test_ids.dart';
import 'game_art_data.dart';
import 'ds_svg.dart';

/// Tile art for every minigame (full-colour 96 by 96 SVGs with their own background, generated into
/// `game_art_data.dart` by `scripts/gen_game_art.py`, never tinted) and one shape per avatar (small
/// SVGs held in code, theme colour through `currentColor`, no people). Listed in `assets/LICENSES.md`. A game without art here falls back to [fallbackGameArt].
const String fallbackGameArt = 'quick_quiz';

String _svg(String body) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" '
    'fill="currentColor">$body</svg>';

/// Game id to full-colour tile art, generated from `design/game_art/*.svg`.
final Map<String, String> gameArt = gameArtData;

/// Avatar id to a friendly shape (no people, no faces).
final Map<String, String> avatarArt = {
  'fox': _svg(
    '<path d="M6 8l12 8h12l12-8-3 20c-1 8-8 14-15 14S10 36 9 28z"/>'
    '<path d="M18 30h12l-6 10z" fill="#fff" opacity=".85"/>',
  ),
  'owl': _svg(
    '<path d="M10 6l8 6h12l8-6v26c0 7-6 12-14 12S10 39 10 32z"/>'
    '<circle cx="18" cy="22" r="5" fill="#fff" opacity=".85"/><circle cx="30" cy="22" r="5" fill="#fff" opacity=".85"/>'
    '<path d="M21 28h6l-3 5z" fill="#fff" opacity=".85"/>',
  ),
  'bear': _svg(
    '<circle cx="11" cy="12" r="6"/><circle cx="37" cy="12" r="6"/>'
    '<circle cx="24" cy="26" r="16"/>'
    '<ellipse cx="24" cy="32" rx="7" ry="5" fill="#fff" opacity=".85"/>',
  ),
  'cat': _svg(
    '<path d="M7 6l9 7h16l9-7v22c0 9-8 14-17 14S7 37 7 28z"/>'
    '<path d="M14 32h20M14 37h20" stroke="#fff" stroke-width="1.5" opacity=".8"/>',
  ),
  'frog': _svg(
    '<circle cx="14" cy="13" r="8"/><circle cx="34" cy="13" r="8"/>'
    '<ellipse cx="24" cy="29" rx="19" ry="14"/>'
    '<path d="M12 31q12 8 24 0" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" opacity=".85"/>',
  ),
  'panda': _svg(
    '<circle cx="11" cy="12" r="6" opacity=".8"/><circle cx="37" cy="12" r="6" opacity=".8"/>'
    '<circle cx="24" cy="26" r="16" opacity=".35"/>'
    '<ellipse cx="17" cy="24" rx="4" ry="6"/><ellipse cx="31" cy="24" rx="4" ry="6"/>'
    '<ellipse cx="24" cy="33" rx="4" ry="3"/>',
  ),
  'rabbit': _svg(
    '<ellipse cx="17" cy="11" rx="5" ry="10"/><ellipse cx="31" cy="11" rx="5" ry="10"/>'
    '<circle cx="24" cy="30" r="14"/>'
    '<ellipse cx="17" cy="11" rx="2" ry="6" fill="#fff" opacity=".7"/><ellipse cx="31" cy="11" rx="2" ry="6" fill="#fff" opacity=".7"/>',
  ),
  'penguin': _svg(
    '<ellipse cx="24" cy="25" rx="15" ry="19"/>'
    '<ellipse cx="24" cy="29" rx="9" ry="13" fill="#fff" opacity=".85"/>'
    '<path d="M20 17h8l-4 5z" opacity=".6"/>',
  ),
};

String _artFor(Map<String, String> m, String id, String fallback) =>
    m[id] ?? m[fallback]!;

/// The tile art of the game [gameId]. Full colour, never tinted; [dimmed] fades it (locked game).
class DsGameArt extends StatelessWidget {
  const DsGameArt(this.gameId, {super.key, this.size, this.dimmed = false});
  final String gameId;
  final double? size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final art = DsSvg.string(
      _artFor(gameArt, gameId, fallbackGameArt),
      key: TestIds.gameArt(gameId),
      size: size,
    );
    return dimmed ? Opacity(opacity: 0.45, child: art) : art;
  }
}

/// The shape of the avatar [avatarId].
class DsAvatarArt extends StatelessWidget {
  const DsAvatarArt(this.avatarId, {super.key, this.size, this.color});
  final String avatarId;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) => DsSvg.string(
    _artFor(avatarArt, avatarId, 'fox'),
    key: TestIds.avatarArt(avatarId),
    size: size,
    color: color ?? DefaultTextStyle.of(context).style.color,
  );
}
