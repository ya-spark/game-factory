# Sort into bins (game package `game_sort_bins`)

Status: BUILT. The game lives once in `game-factory/games/sort_bins/` (SH1, owner 2026-11-21); apps and the web list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, the screen in `lib/src/sort_bins_screen.dart`, test IDs in `GameIds` (game_core) and `lib/src/sort_bins_ids.dart` where the game has its own. It asks its container only through `GameHost` (`game_core/lib/host`).

The text below was collected from the apps' docs when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## How to play (as shown to the child)
- Put each item into the right bin. Drag it there, or tap the item and then the bin.
- A wrong drop never ends the round. The item stays and you try again.
- Tips:
  - Read the names of the bins first.
  - Take your time. Every item gets as many tries as it needs.

## Rules and behaviour (from the app's engine notes at the move)
- Sort into bins (`sortBinsGame`, view `lib/ui/minigames/sort_bins_screen.dart`, rules

## Keyboard (K1, 2026-11-22)
- Up and down (or left and right) move over the bins, Enter drops the item in the highlighted bin, 1 to 4 drop it in that bin, Enter goes on after a round. Esc leaves the game.
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).
