import 'package:flutter/material.dart';

import '../test_ids.dart';
import 'ds_svg.dart';

/// Original tile art for every minigame and one shape per avatar, drawn as small SVGs held in
/// code (simple shapes, theme colour through `currentColor`, no people). Listed in
/// `assets/LICENSES.md`. A game without art here falls back to [fallbackGameArt].
const String fallbackGameArt = 'quick_quiz';

String _svg(String body) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" '
    'fill="currentColor">$body</svg>';

/// Game id to art. Keys are the minigame ids.
final Map<String, String> gameArt = {
  'quick_quiz': _svg(
    '<path d="M8 8h32a4 4 0 0 1 4 4v18a4 4 0 0 1-4 4H26l-9 8v-8H8a4 4 0 0 1-4-4V12a4 4 0 0 1 4-4z"/>'
    '<path d="M20 15a4 4 0 1 1 6 3.5c-1.5 1-2 1.5-2 3" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity=".9"/>'
    '<circle cx="24" cy="27" r="2" fill="#fff"/>',
  ),
  'door_runner': _svg(
    '<rect x="11" y="5" width="26" height="38" rx="3" opacity=".35"/>'
    '<rect x="15" y="9" width="18" height="34" rx="2"/>'
    '<circle cx="29" cy="27" r="2" fill="#fff"/>'
    '<rect x="5" y="42" width="38" height="3" rx="1.5"/>',
  ),
  'balloon_pop': _svg(
    '<ellipse cx="24" cy="19" rx="12" ry="15"/>'
    '<path d="M21 34h6l-3 4z"/>'
    '<path d="M24 38c-3 3 3 5 0 8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>'
    '<ellipse cx="19" cy="13" rx="3" ry="5" fill="#fff" opacity=".35"/>',
  ),
  'tug_of_war': _svg(
    '<rect x="4" y="22" width="40" height="4" rx="2"/>'
    '<rect x="21" y="14" width="6" height="20" rx="2" opacity=".6"/>'
    '<circle cx="9" cy="24" r="5"/><circle cx="39" cy="24" r="5" opacity=".5"/>',
  ),
  'true_false': _svg(
    '<circle cx="14" cy="24" r="10"/>'
    '<path d="M9 24l4 4 7-8" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
    '<circle cx="34" cy="24" r="10" opacity=".5"/>'
    '<path d="M30 20l8 8M38 20l-8 8" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>',
  ),
  'flash_review': _svg(
    '<rect x="8" y="6" width="28" height="22" rx="4" opacity=".4" transform="rotate(-8 22 17)"/>'
    '<rect x="12" y="16" width="28" height="22" rx="4"/>'
    '<path d="M18 24h16M18 30h10" stroke="#fff" stroke-width="3" stroke-linecap="round"/>',
  ),
  'equation_builder': _svg(
    '<path d="M8 20h12M14 14v12" stroke="currentColor" stroke-width="4" stroke-linecap="round"/>'
    '<path d="M28 18h12M28 26h12" stroke="currentColor" stroke-width="4" stroke-linecap="round"/>'
    '<rect x="6" y="34" width="36" height="6" rx="3" opacity=".4"/>',
  ),
  'cloze_fix': _svg(
    '<rect x="4" y="12" width="14" height="6" rx="3"/>'
    '<rect x="22" y="12" width="22" height="6" rx="3" opacity=".4"/>'
    '<rect x="4" y="26" width="22" height="6" rx="3"/>'
    '<rect x="30" y="25" width="14" height="8" rx="3" fill="none" stroke="currentColor" stroke-width="2" stroke-dasharray="3 2"/>',
  ),
  'word_grid': _svg(
    '<rect x="5" y="5" width="12" height="12" rx="2"/><rect x="18" y="5" width="12" height="12" rx="2" opacity=".5"/>'
    '<rect x="31" y="5" width="12" height="12" rx="2"/><rect x="5" y="18" width="12" height="12" rx="2" opacity=".5"/>'
    '<rect x="18" y="18" width="12" height="12" rx="2"/><rect x="31" y="18" width="12" height="12" rx="2" opacity=".5"/>'
    '<rect x="5" y="31" width="12" height="12" rx="2"/><rect x="18" y="31" width="12" height="12" rx="2" opacity=".5"/>'
    '<rect x="31" y="31" width="12" height="12" rx="2"/>',
  ),
  'memory_match': _svg(
    '<rect x="5" y="5" width="18" height="18" rx="4"/><rect x="25" y="5" width="18" height="18" rx="4" opacity=".4"/>'
    '<rect x="5" y="25" width="18" height="18" rx="4" opacity=".4"/><rect x="25" y="25" width="18" height="18" rx="4"/>'
    '<circle cx="14" cy="14" r="4" fill="#fff"/><circle cx="34" cy="34" r="4" fill="#fff"/>',
  ),
  'series_builder': _svg(
    '<rect x="5" y="30" width="8" height="12" rx="2" opacity=".4"/>'
    '<rect x="15" y="23" width="8" height="19" rx="2" opacity=".6"/>'
    '<rect x="25" y="16" width="8" height="26" rx="2" opacity=".8"/>'
    '<rect x="35" y="7" width="8" height="35" rx="2"/>',
  ),
  'word_builder': _svg(
    '<rect x="3" y="16" width="12" height="16" rx="3"/><rect x="18" y="16" width="12" height="16" rx="3" opacity=".6"/>'
    '<rect x="33" y="16" width="12" height="16" rx="3"/>'
    '<rect x="3" y="36" width="42" height="3" rx="1.5" opacity=".4"/>',
  ),
  'sort_bins': _svg(
    '<path d="M5 26h16l-2 16H7z"/><path d="M27 26h16l-2 16H29z" opacity=".5"/>'
    '<circle cx="13" cy="14" r="5"/><circle cx="35" cy="14" r="5" opacity=".5"/>',
  ),
};

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

/// The tile art of the game [gameId].
class DsGameArt extends StatelessWidget {
  const DsGameArt(this.gameId, {super.key, this.size, this.color});
  final String gameId;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) => DsSvg.string(
    _artFor(gameArt, gameId, fallbackGameArt),
    key: TestIds.gameArt(gameId),
    size: size,
    color: color ?? DefaultTextStyle.of(context).style.color,
  );
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
