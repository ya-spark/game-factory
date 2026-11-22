# Merge (game package `game_merge`)

Status: BUILT. The game lives once in `game-factory/games/merge/` (SH1, owner 2026-11-21); the Mind hub (Ember) is a container that lists it, brings its coins, ads, leaderboards, achievements and zen/daily features, and provides them through `GameHost` (`game_core/lib/host`) and the Mind kit (`game_core/lib/mind`). Rules in `lib/src/rules/`, the screen in `lib/src/merge_screen.dart`. Nothing is copied.

The text below was collected from the hub's spec when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## From the hub spec
### 4.6 Merge (new, coin-locked at 300 coins)
Calm. Rules are pure Dart in `lib/engine/minigames/merge/rules/`; the screen is
`lib/ui/minigames/merge_screen.dart`. Locked until 300 coins unlock it for good on this device.
- **Board:** 4 x 4 garden of plants in 12 stages (Seed, Sprout, Leaf, Bud, Blossom, Lily, Fern,
  Orchid, Bamboo, Bonsai, Grove, Garden). Each plant is drawn as a ring of petals (one more per
  stage) with its value (2 to the stage) as a number. The top stage does not merge further.
- **Move:** swipe on the board, or use the four arrow buttons (for screen readers and switch
  users). All plants slide; two of the same stage that meet grow into the next stage, once per move.
  A swipe that changes nothing is not a move. After a move one plant appears: stage 1 (90 percent)
  or stage 2 (10 percent).
- **Score:** each merge adds 2 to the new stage. Stars on the best score: 1000, 3000 and 6000. The
  best score of each mode is kept on the device, and the score is told to the hub after each move.
- **Undo:** takes back the last move (one step); offered again after the next move.
- **Modes:** Classic ends when no move is left (results screen). Relaxed has no game over: when no
  move is left, every plant of the lowest stage is cleared and play goes on; Finish ends it.
- **Motion:** plants do not animate (nothing to reduce).
- **Ads:** banner on the menu and results only; none in play; no interstitials. No rewarded
  Continue (not added).
- Test IDs: `merge.cell.N`, `merge.classic`, `merge.relaxed`, `merge.board`, `merge.up|down|left|right`,
  `merge.undo`, `merge.restart`, `merge.finish`, `merge.score`, `merge.back`, `merge.again`,
  `merge.done`, `merge.result.stars`, banners `merge.banner.menu` and `merge.banner.results`.

## Related lines
- **Score:** each merge adds 2 to the new stage. Stars on the best score: 1000, 3000 and 6000. The
- Test IDs: `merge.cell.N`, `merge.classic`, `merge.relaxed`, `merge.board`, `merge.up|down|left|right`,
- Merge and Mind Presto's games are not in the daily. Determinism (same seed, same puzzle) and
- **In the five hub-native games** (Sudoku, Solitaire, Ball sort, Mahjong, Merge) a Zen run means:
  - No timer anywhere (none is shown). Merge plays Relaxed only (one Play button, no Classic).

## Keyboard (K1, 2026-11-22)
- Arrows slide the board. On the menu Enter or 1 starts Classic (Zen: the garden), 2 starts Relaxed. On the results Enter plays again. The game has no timer, so no pause: Esc goes back (a game to its menu, the menu leaves; a Daily Challenge leaves).
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).
