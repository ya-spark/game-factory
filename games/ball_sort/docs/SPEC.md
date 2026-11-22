# Ball sort (game package `game_ball_sort`)

Status: BUILT. The game lives once in `game-factory/games/ball_sort/` (SH1, owner 2026-11-21); the Mind hub (Ember) is a container that lists it, brings its coins, ads, leaderboards, achievements and zen/daily features, and provides them through `GameHost` (`game_core/lib/host`) and the Mind kit (`game_core/lib/mind`). Rules in `lib/src/rules/`, the screen in `lib/src/ball_sort_screen.dart`. Nothing is copied.

The text below was collected from the hub's spec when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## From the hub spec
### 4.4 Ball sort (new, coin-locked at 300 coins)
Calm and untimed. Rules are pure Dart in `lib/engine/minigames/ball_sort/rules/`; the screen is
`lib/ui/minigames/ball_sort_screen.dart`. Locked until 300 coins unlock it for good on this device
(like Blockfall); the lock is the registry's `coins` access.
- **Board:** tubes hold 4 balls. A level has N colours (4 balls each), N full tubes and 2 empty ones.
  N = 3 at level 1 and one more every two levels, up to 10 (level 15 on).
- **Move:** tap a tube, then another. The top run of one colour moves onto an empty tube or onto the
  same colour, as many balls as fit. A move that does not fit says so and keeps the new tube selected.
  Solved when every tube is empty or full of one colour.
- **Levels:** generated from a seed (`level * 7919 + 13`, so a level is always the same layout); the
  generator shuffles up to 30 times and keeps the first layout a depth-first solver (at most 20000
  positions) proves solvable, and never one that starts sorted. Restart level redeals the same layout.
- **Undo** unlimited; **Add a tube** once per level (one more empty tube; undo can take it back, but it
  stays used in the score rules). Either one costs the clean-play bonus. The level reached is kept on
  the device; the menu offers Play level N and Start from level 1.
- **Colour-blind patterns:** every colour also has its own pattern drawn in the ball (solid, horizontal
  stripes, dots, vertical stripes, cross, diagonal stripes, ring, checker, triangle, diamond for red,
  blue, green, orange, purple, yellow, teal, pink, brown, grey). Tubes have screen-reader labels that
  name the colours bottom to top.
- **Score and stars:** a solved level scores 200 + 50 per colour - 1 per move (at least 50), plus 100
  when no undo and no extra tube was used. Stars on the best score: 300, 500 and 700.
- **Ads:** banner on the menu and results only; none in play; no interstitials; no Continue.
- Test IDs: `ballsort.tube.N`, `ballsort.ball.C`, `ballsort.undo`, `ballsort.addtube`,
  `ballsort.restart`, `ballsort.play`, `ballsort.reset`, `ballsort.back`, `ballsort.again` (Next level),
  `ballsort.done`, `ballsort.message`, banners `ballsort.banner.menu` and `ballsort.banner.results`.

- Daily entry point (issue 156): `daily:` (a `DailyRun`) starts the screen straight in the puzzle of the day with no menu, from the given seed and tier, a fixed layout; it reports `onSolved(seconds, mistakes)` on the game's own win condition and `onProgress` when the child leaves. Seconds are foreground-only active seconds and a resumed puzzle continues from its saved seconds. Ball sort: the daily ignores the coin lock; tier gives levels 1, 5, 9, 13. A resumed puzzle regenerates the same seeded board and continues the saved seconds.

## Related lines
- Game by day: Sudoku, Ball sort, Solitaire, Mahjong rotate (`day % 4`). Difficulty tier by weekday,
- **In the five hub-native games** (Sudoku, Solitaire, Ball sort, Mahjong, Merge) a Zen run means:

## Keyboard (K1, 2026-11-22)
- Left and right move a highlighted cursor over the tubes, Enter or up lifts and drops (the same as a tap), 1 to 9 pick that tube at once. Menu: Enter or 1 plays the level. Results: Enter goes on. The game has no timer, so no pause: Esc goes back (a game to its menu, the menu leaves; a Daily Challenge leaves).
- Space (the shared pause key) is the same as Enter on the start and results screens (U2, 2026-11-22; the game has no pause); the key hints print "Enter / Space" there.
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).
