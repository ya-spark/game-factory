# Game tile art (full colour)

One SVG per game id, 96 by 96, drawn for the studio by Claude in a studio session on 2026-11-15 (owner request: the old
single-colour 32 px glyphs were "not great"). Original work, no people, no third-party assets. `preview.png` shows all 25.

Rules the files follow, so `flutter_svg` renders them the same everywhere: flat shapes, strokes and `linearGradient` only
(no filters, masks, text, CSS or `currentColor`); every gradient id is unique (`bg_<game id>`); each tile carries its own
rounded background (rx 24), so the art must be shown without a tint and without an extra coloured box behind it.

Ids: quick_quiz, door_runner, balloon_pop, tug_of_war, true_false, flash_review, bridge_builder, cloze_fix, word_grid,
memory_match, domino_chain, word_builder, sort_bins, block_puzzle, blockfall, sudoku, solitaire, ball_sort, mahjong, merge,
wingy, snake, bricks, stack, runner. They replace the entries of `gameArt` in `lib/ui/kit/ds_art.dart` (see the game-studio issue).
