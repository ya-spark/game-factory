# Asset licenses

Every file under `assets/` (other than this file) MUST be listed here by its relative path with
its source and license. `scripts/check_asset_licenses.sh` fails CI otherwise.

| File | Source | License | Notes |
|------|--------|---------|-------|

| assets/content/index.json | Written by the studio (content CLI `build-index`); empty list in the template | original | built-in content index; every pack and asset the games add under assets/content/ is listed here too |

Format for an asset row: `| assets/sfx/pop.ogg | https://example.org/pop | CC0-1.0 | by Jane Doe |`

Art drawn in code (no files under `assets/`): the game tile art, full colour 96 by 96 SVGs in `design/game_art/` turned into `lib/ui/kit/game_art_data.dart` by `scripts/gen_game_art.py` (quick_quiz, door_runner, balloon_pop, shooter, tug_of_war, true_false, flash_review, bridge_builder, cloze_fix, word_grid, memory_match, series_builder, word_builder, sort_bins, block_puzzle, blockfall, sudoku, solitaire, ball_sort, mahjong, merge, wingy, snake, bricks, stack, runner), are original work made for the studio on 2026-11-15, no third-party assets, no people. The avatar shapes in `lib/ui/kit/ds_art.dart` (fox, owl, bear, cat, frog, panda, rabbit, penguin) are original SVG shapes written by the studio. License: original.
