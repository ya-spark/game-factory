# Mahjong (game package `game_mahjong`)

Status: BUILT. The game lives once in `game-factory/games/mahjong/` (SH1, owner 2026-11-21); the Mind hub (Ember) is a container that lists it, brings its coins, ads, leaderboards, achievements and zen/daily features, and provides them through `GameHost` (`game_core/lib/host`) and the Mind kit (`game_core/lib/mind`). Rules in `lib/src/rules/`, the screen in `lib/src/mahjong_screen.dart`. Nothing is copied.

The text below was collected from the hub's spec when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## From the hub spec
### 4.5 Mahjong solitaire (new, free with ads)
Calm and untimed. Rules are pure Dart in `lib/engine/minigames/mahjong/rules/`; the screen is
`lib/ui/minigames/mahjong_screen.dart`. The random source is injected.
- **Layouts:** 9 (Rows, Pyramid, Diamond, Towers, Wall, Ring, Steps, Twin hills, Cross), 24 to 34
  tiles each, picked from the menu. Tile places are in half tiles (x, y) and layers (z).
- **Tiers (M3, issue 168):** a tier chip row in the menu (`mahjong.tier.easy|medium|hard|expert`, kept on
  the device as `mahjong.tier`) sets the layouts on offer and the limits (pure Dart `MahjongTier`). A hint
  still costs 40 points and a shuffle 80 in every tier; at the limit the button is disabled and the
  label counts down, for example "Hint (2)", "Shuffle (1)".

  | Tier | Layouts | Hints | Shuffles |
  |---|---|---|---|
  | Easy | the nine above | unlimited | unlimited |
  | Medium | the nine above | 3 | 2 |
  | Hard | Terrace (56 tiles), Castle (60), Mound (52) | 3 | 1 |
  | Expert | Fortress (72), Tower block (66), Brick wall (68, upper layer half a tile off) | 1 | 1 |

  The stats variant is the tier label ("Easy" to "Expert"; M2 keeps the fastest solve per tier). The
  **Hints** menu switch (`mahjong.hints`, default on) hides the Hint button; scoring is unchanged. Tiles
  are never smaller than 40 dp: a layout too big for the screen at that size scrolls both ways
  (`mahjong.board.scroll`). Mahjong never saved a layout choice, so there is nothing to migrate.
- **Free tile:** nothing lies on it (a tile one layer up that overlaps it) and its left or its right
  side is open. A move takes two free tiles with the same face.
- **Solvable by construction:** a deal repeatedly picks two free places of the still-full layout,
  gives them one face, and removes them; the faces are dealt from a shuffled deck of 24. Playing the
  pairs in that order clears the table. If a draw gets stuck it is redrawn (up to 500 times). Tests
  prove each layout (the nine and the six new ones) with 25 seeds by search.
- **Faces:** 24 original faces: 4 suits (Ember, Leaf, Wave, Star; each its own drawn shape and ink
  colour) x ranks 1 to 6 (the shape drawn that many times). No mahjong artwork. Blocked tiles are grey.
- **Undo** unlimited (takes back the last pair). **Hint** shows a free pair (outlined in orange).
  **Shuffle** deals the faces of the remaining tiles again with the same construction (so the table
  stays solvable when its shape allows it, otherwise it mixes until a pair exists); it clears undo.
  When no pair is left the game says to use Shuffle.
- **Score and stars:** a cleared table scores 50 per pair + 100, minus 40 per hint and 80 per shuffle
  (at least 50). Stars on the best score: 300, 500 and 700.
- **Ads:** banner on the menu and results only; none in play; no interstitials; no Continue.
- Test IDs: `mahjong.tile.N`, `mahjong.level.N` (layout buttons), `mahjong.undo`, `mahjong.hint`,
  `mahjong.shuffle`, `mahjong.back`, `mahjong.message`, `mahjong.again`, `mahjong.done`,
  `mahjong.result.stars`, banners `mahjong.banner.menu` and `mahjong.banner.results`.

- Daily entry point (issue 156): `daily:` (a `DailyRun`) starts the screen straight in the puzzle of the day with no menu, from the given seed and tier, a fixed layout; it reports `onSolved(seconds, mistakes)` on the game's own win condition and `onProgress` when the child leaves. Seconds are foreground-only active seconds and a resumed puzzle continues from its saved seconds. Mahjong: the weekday tier gives the tier (Easy, Medium, Hard, Expert; hints and shuffles follow it) and a layout: the smallest of the tier, except Medium which plays the 5th smallest of the nine.

## Related lines
- **Tiers (M3, issue 168):** a tier chip row in the menu (`mahjong.tier.easy|medium|hard|expert`, kept on
- Test IDs: `mahjong.tile.N`, `mahjong.level.N` (layout buttons), `mahjong.undo`, `mahjong.hint`,
- Game by day: Sudoku, Ball sort, Solitaire, Mahjong rotate (`day % 4`). Difficulty tier by weekday,
- **In the five hub-native games** (Sudoku, Solitaire, Ball sort, Mahjong, Merge) a Zen run means:
  - Unlimited hints at no cost in Sudoku, Solitaire (even a level with no hints) and Mahjong; Mahjong shuffles are

## Keyboard (K1, 2026-11-22)
- Left, up and right, down step over the free tiles in reading order (a highlighted cursor), Enter picks or drops the tile (the same as a tap), 1 hint, 2 undo, 3 shuffle. Menu: Enter or 1 to 4 pick the layout. The game has no timer, so no pause: Esc goes back (a game to its menu, the menu leaves; a Daily Challenge leaves).
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).
