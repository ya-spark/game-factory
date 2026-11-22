# Word search (game package `game_word_grid`)

Status: BUILT. The game lives once in `game-factory/games/word_grid/` (SH1, owner 2026-11-21); apps and the web list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, the screen in `lib/src/word_grid_screen.dart`, test IDs in `GameIds` (game_core) and `lib/src/word_grid_ids.dart` where the game has its own. It asks its container only through `GameHost` (`game_core/lib/host`).

The text below was collected from the apps' docs when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## How to play (as shown to the child)
- Choose word search or crossword on the start screen.
- Find the words in the grid, or fill in the crossword from the clues.
- Tips:
  - Start with the words you know best.
  - There is no need to hurry.

## From the app spec
- Levels: Foundation to Year 6 see every game above except Tug of war, Bridge builder and Word search and

## Keyboard (K1, 2026-11-22)
- Arrows move a highlighted cursor. Word search: Enter taps the first letter, then the last letter, of a word (Esc clears the first tap). Crossword: up and down choose a clue, Enter picks it, left and right move over the letters, Enter adds the letter, Esc drops the clue. Intro: 1 word search, 2 crossword. Esc leaves.
- Space (the shared pause key) is the same as Enter on the start and results screens (U2, 2026-11-22; the game has no pause); the key hints print "Enter / Space" there.
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).
