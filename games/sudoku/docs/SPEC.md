# Sudoku (game package `game_sudoku`)

Status: BUILT. The game lives once in `game-factory/games/sudoku/` (SH1, owner 2026-11-21); the Mind hub (Ember) is a container that lists it, brings its coins, ads, leaderboards, achievements and zen/daily features, and provides them through `GameHost` (`game_core/lib/host`) and the Mind kit (`game_core/lib/mind`). Rules in `lib/src/rules/`, the screen in `lib/src/sudoku_screen.dart`. Nothing is copied.

The text below was collected from the hub's spec when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## From the hub spec
### 4.2 Sudoku (new, free with ads)
Calm and untimed, 9 by 9. Rules are pure Dart in `lib/engine/minigames/sudoku/rules/`; the screen is
`lib/ui/minigames/sudoku_screen.dart`.
- **Levels and clues:** Easy 40, Medium 34, Hard 30, Expert 26 given digits. Each puzzle is generated
  (seeded random, injected) by removing digits from a full grid while a solver proves the solution is
  still unique; the generator may stop up to 3 clues above the target.
- **Play:** tap a square, then a digit; tapping the same digit clears it; Notes mode toggles pencil
  notes (a right digit clears that note in its row, column and box); Erase; Undo (unlimited); givens
  never change. The puzzle is solved when every square equals the solution.
- **Mistakes:** a digit that differs from the solution counts as a mistake. "Show mistakes" (menu
  switch, on by default) marks it with an underline and "!" (not colour alone) and shows the count;
  off hides both. The setting is kept on the device.
- **Hint (stepped, M3 issue 168):** 3 per puzzle, in three presses of `sudoku.hint`. (1) Where to look
  (free): the row, column or box (or the square) is outlined and named in words, for example "Look at
  row 3.". (2) Why (free): "Only one place for 7 in this row." (hidden single) or "Only one digit fits
  here: ..." (naked single). (3) Fill the digit: one of the 3 hints, 100 points as before. Pure Dart
  `findSudokuHint` / `SudokuHintStep` explains naked singles and hidden singles only (wrong digits the
  player entered are ignored); when the puzzle needs more, the hint reveals a cell at once as before
  (the selected square, else the first empty or wrong one). Any move resets the steps. With 0 hints
  left the first two steps still work; the fill says "No hints left for this puzzle." No rewarded
  Hint: the hub's only rewarded placement is the Continue. The **Hints** menu switch (`sudoku.hints`,
  default on) hides the button; scoring is unchanged. Levels stay by clue count (the stats variant).
- **Auto-save:** after every move, one save per level in shared preferences; the menu then shows
  Resume and New puzzle. A solved puzzle clears its save.
- **Score and stars:** a win scores the level base (Easy 300, Medium 600, Hard 1000, Expert 1500) minus
  50 per mistake and 100 per hint, never below a tenth of the base. The best score gives 1, 2 and 3
  stars at 300, 800 and 1400 (Hard or Expert needed for 2 stars; 3 stars needs a near-clean Expert).
- **Ads:** banner on the menu and results only; none in play; no interstitials; no Continue.
- **Access and screens:** screen-reader labels on every square and control, no animation, text scales
  to 150 percent (the page scrolls). Test IDs: `sudoku.cell.N`, `sudoku.digit.D`,
  `sudoku.level.<level>`, `sudoku.level.<level>.resume`, `sudoku.mistakes`, `sudoku.pencil`,
  `sudoku.erase`, `sudoku.undo`, `sudoku.hint`, `sudoku.back`, `sudoku.again`, `sudoku.done`, banners
  `sudoku.banner.menu` and `sudoku.banner.results`.

- Daily entry point (issue 156): `daily:` (a `DailyRun`) starts the screen straight in the puzzle of the day with no menu, from the given seed and tier, a fixed layout; it reports `onSolved(seconds, mistakes)` on the game's own win condition and `onProgress` when the child leaves. Seconds are foreground-only active seconds and a resumed puzzle continues from its saved seconds. Tier gives Sudoku Easy, Medium, Hard, Expert. The daily puzzle has its own save (one per day), separate from the level saves.

## Related lines
- **Hint (stepped, M3 issue 168):** 3 per puzzle, in three presses of `sudoku.hint`. (1) Where to look
- Game by day: Sudoku, Ball sort, Solitaire, Mahjong rotate (`day % 4`). Difficulty tier by weekday,
- **New personal best**: one calm line ("New personal best in Sudoku: 1200", or "New personal best: your fastest
- **In the five hub-native games** (Sudoku, Solitaire, Ball sort, Mahjong, Merge) a Zen run means:
  - Unlimited hints at no cost in Sudoku, Solitaire (even a level with no hints) and Mahjong; Mahjong shuffles are

## Keyboard (K1, 2026-11-22)
- Arrows move over the squares, 1 to 9 fill the square (5 to 9 are read straight from the keyboard), Backspace, Delete or 0 erase, N toggles notes, Enter asks for a hint (the same three stages as the button). Menu: Enter or 1 to 4 pick the level (Resume when a puzzle is saved). The game has no timer, so no pause: Esc goes back (a game to its menu, the menu leaves; a Daily Challenge leaves).
- Space (the shared pause key) is the same as Enter on the start and results screens (U2, 2026-11-22; the game has no pause); the key hints print "Enter / Space" there.
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).
