# Solitaire (game package `game_solitaire`)

Status: BUILT. The game lives once in `game-factory/games/solitaire/` (SH1, owner 2026-11-21); the Mind hub (Ember) is a container that lists it, brings its coins, ads, leaderboards, achievements and zen/daily features, and provides them through `GameHost` (`game_core/lib/host`) and the Mind kit (`game_core/lib/mind`). Rules in `lib/src/rules/`, the screen in `lib/src/solitaire_screen.dart`. Nothing is copied.

The text below was collected from the hub's spec when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## From the hub spec
### 4.3 Solitaire (Klondike, new, free with ads)
Calm and untimed. Rules are pure Dart in `lib/engine/minigames/solitaire/rules/`; the screen is
`lib/ui/minigames/solitaire_screen.dart`.
- **Rules:** standard Klondike. 7 columns of 1 to 7 cards (top card up), 24 in the stock. Columns build
  down in alternating colours; only a king (or a king-led run) goes to an empty column; foundations
  build up by suit from the ace. Any face-up run moves as a unit.
- **Levels (M3, issue 168):** presets in the menu (kept on the device; the old Draw and Winnable choices
  map to the matching level on first load). Pure Dart `SolitaireLevel`:

  | Level | Draw | Deal | Hints | Win bonus |
  |---|---|---|---|---|
  | Easy | one | winnable | 3 | 300 |
  | Medium | one | plain shuffle | 3 | 500 |
  | Hard | three | winnable | 1 | 800 |
  | Expert | three | plain shuffle | none | 1200 |

  **Custom** shows the Draw and Winnable switches below (3 hints, bonus 500). The stats variant is the
  level name ("Easy" to "Expert", "Custom"). IDs `solitaire.level.easy|medium|hard|expert|custom`.
- **Hint (M3):** the Hint button (`solitaire.hint`, shows the hints left) names the best move in words
  (`solitaire.hint.text`) and draws a thick border on the source and the target (`solitaire.hint.source`,
  `solitaire.hint.target`, the foundation, or the stock), so colour is not the only cue. Priority
  (`findKlondikeHint`): a move to a foundation; a move that turns a face-down card; a king (or king-led
  run) to an empty column; another column move (not a run that already sits on a fitting card); draw from
  the stock (turn the waste over at most twice). If nothing useful exists it says "No useful move right
  now" and charges nothing. Each hint costs 10 points (never below 0); undo does not refund it. The
  **Hints** switch in the menu (`solitaire.hints`, default on) hides the button; scoring is unchanged.
- **Draw:** Draw one or Draw three (by level, or Custom). Draw three shows the last three
  waste cards fanned, only the top one playable. An empty stock turns the waste over again.
- **Move:** tap a card to send it to its foundation, else to the first column it fits; or drag a card
  or run onto a column or foundation. Tapping the stock draws. A foundation top card can be moved
  back to a column.
- **Undo:** unlimited; it restores cards and score, and the move counter keeps counting.
- **Auto-complete:** the button appears when the stock and waste are empty and no card is face down;
  it then plays every remaining card to the foundations (without delay when reduced motion is on).
- **Winnable deals** (menu switch, on by default): the dealer tries up to 12 shuffles and keeps the
  first that a depth-first solver (at most 8000 positions each) proves winnable. If none is proven,
  the last shuffle is used, so the guarantee holds only when a proof was found (most Draw one deals).
  Off: a plain shuffle.
- **Score and stars:** points: waste to column +5, any card to a foundation +10, a card turned face up
  +5, a card back from a foundation -15, turning the waste over -100 (Draw one) or -20 (Draw three),
  never below 0. A win scores the points plus the level's win bonus (4.3 Levels; 500 in Custom); only wins are reported. Stars on the best score:
  500, 1000 and 1500 (any win is 1 star).
- **Ads:** banner on the menu and results only; none in play; no interstitials; no Continue.
- **Cards:** drawn with text and shapes only (rank and suit symbol, red or dark; the suit is also its
  symbol, so colour is not the only cue); each card has a screen-reader label such as "queen of
  hearts"; text scales to 150 percent (the page scrolls). Test IDs: `solitaire.stock`,
  `solitaire.waste`, `solitaire.waste.top`, `solitaire.found.F`, `solitaire.found.F.top`,
  `solitaire.col.N`, `solitaire.card.ID` (ID = suit * 13 + rank - 1), `solitaire.undo`,
  `solitaire.new`, `solitaire.auto`, `solitaire.draw1`, `solitaire.draw3`, `solitaire.winnable`,
  `solitaire.play`, `solitaire.back`, `solitaire.again`, `solitaire.done`, banners
  `solitaire.banner.menu` and `solitaire.banner.results`.
- No save between sessions (a game in progress is lost on leaving).

- Daily entry point (issue 156): `daily:` (a `DailyRun`) starts the screen straight in the puzzle of the day with no menu, from the given seed and tier, a fixed layout; it reports `onSolved(seconds, mistakes)` on the game's own win condition and `onProgress` when the child leaves. Seconds are foreground-only active seconds and a resumed puzzle continues from its saved seconds. Tier gives Draw one (tiers 0, 1) or Draw three (tiers 2, 3), always a deal the solver proved winnable; a resumed deal regenerates from the seed and continues the saved seconds.

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
- **Hint (M3):** the Hint button (`solitaire.hint`, shows the hints left) names the best move in words
- Game by day: Sudoku, Ball sort, Solitaire, Mahjong rotate (`day % 4`). Difficulty tier by weekday,
- **In the five hub-native games** (Sudoku, Solitaire, Ball sort, Mahjong, Merge) a Zen run means:
  - Unlimited hints at no cost in Sudoku, Solitaire (even a level with no hints) and Mahjong; Mahjong shuffles are

## Keyboard (K1, 2026-11-22)
- Left and right move the cursor over the stock, the waste and the seven columns, up and down pick the card in a column (face-up cards only), Enter plays the highlighted card as a tap does (draws from the stock), 1 hint, 2 undo. Menu: Enter starts a deal. The game has no timer, so no pause: Esc goes back (a game to its menu, the menu leaves; a Daily Challenge leaves).
- Space (the shared pause key) is the same as Enter on the start and results screens (U2, 2026-11-22; the game has no pause); the key hints print "Enter / Space" there.
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).
