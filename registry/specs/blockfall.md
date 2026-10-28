# Blockfall - game spec

Status: awaiting user approval. This is the contract for all later stages. Copy to `docs/SPEC.md` in `ya-spark/game-block-fall` (repo-agent).

- id: `blockfall`, display name: **Blockfall**, package: `com.activemindcraft.blockfall`, repo: `ya-spark/game-block-fall`
- Base template: block puzzle template (`template/flutter-game-template`). No falling-blocks template exists yet.
- Naming rule: the strings "Tetris" and "Block Blast", their logos, art, sounds, and piece letter-names-as-branding must not appear in code, assets, listing or keywords. Pieces are called by the original names in section 4.

## 1. Pitch
Blockfall is a single-player falling-blocks game for Android. Glossy gem pieces drop into a 10-wide well; fill a row and it clears. Hold a piece, peek at the next three, grab power-ups, and race the speed as levels climb. Original twist: **Prism cells**. Some pieces carry one glowing prism gem; clearing a row that contains one doubles that row's score and pays out coins. It targets casual players who want a quick, polished classic with daily goals, and plays well in 3 to 10 minute sessions. Look: midnight-teal gradient, glossy rounded gem blocks, glowing score pill (the app-factory block puzzle identity).

## 2. Core loop
- Second to second: move, rotate, soft/hard drop the falling piece; decide whether to Hold; read the Next queue.
- Minute to minute: clear rows, chain combos, collect prism coins, reach the line goal to level up (faster gravity), spend power-ups when the stack gets high.
- Session to session: daily reward, streak, three daily challenges, achievements, coins for power-ups, beat the best score.

## 3. Rules and scoring (pure Dart, `lib/game/rules/`)
No Flutter, Flame or Android imports in this folder. All randomness comes from an injected `Random` (seedable) and all time from injected delta values or `lib/core/clock.dart`, so rules are deterministic in tests.

**Well.** 10 columns x 20 visible rows plus 2 hidden rows above (spawn zone). Cells hold: empty, a color id (1 to 7), plus a `prism` flag.

**Pieces.** 7 four-cell shapes (section 4). Each piece has 4 rotation states.

**Spawn.** A new piece spawns in the hidden rows, horizontally centered (I and O at columns 3-6 / 4-5, others at columns 3-5). If any spawn cell overlaps a filled cell, the game is over ("block out"). A piece that locks with all cells in the hidden rows is also game over ("lock out").

**Rotation system (simple, original).** Tap rotates clockwise only (no counter-clockwise in v1). Rotation uses fixed 4-state tables per piece. If the rotated position collides, try these offsets in order and use the first free one: (0,0), (-1,0), (+1,0), (0,-1 i.e. up 1), (-2,0), (+2,0). If none fits, the rotation is ignored. No other kick tables, no T-spin logic. The O piece never changes.

**Randomizer.** 7-bag: each bag is a shuffled permutation of the 7 pieces; the queue refills when fewer than 7 pieces are upcoming. Never more than 12 pieces between two copies of the same piece type.

**Next queue.** Shows the next 3 pieces (the first is largest).

**Hold.** One hold slot. Hold swaps the falling piece with the held piece (or, if empty, stores it and spawns the next piece from the queue). The swapped-in piece respawns at the top in rotation state 0. Hold may be used **once per piece**: after use it is disabled until the next piece locks. The hold flag resets on lock only (not on swap).

**Gravity.** Seconds per row fall step by level (levels above 15 use the level 15 value):

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| s/row | 1.00 | 0.80 | 0.65 | 0.52 | 0.42 | 0.33 | 0.26 | 0.20 | 0.16 | 0.12 | 0.10 | 0.08 | 0.065 | 0.05 | 0.04 |

Soft drop falls at 20x the current gravity (minimum step 0.03 s/row). Hard drop moves the piece straight to the ghost position and locks it at once.

**Ghost.** A faint outline shows where the piece would land.

**Lock delay.** When the piece rests on something, it locks after 0.5 s. A successful move or rotation while resting restarts the 0.5 s timer, at most 10 restarts per piece; after that it locks on the next timer end. Hard drop locks instantly. Falling to a lower row resets the restart count.

**Line clear.** After lock, every full row is removed and rows above fall by the number of cleared rows below them.

**Levels and goal.** Level starts at 1. Goal is 10 lines per level: `level = 1 + totalLines ~/ 10`. The HUD shows LEVEL and GOAL (lines still needed to reach the next level = `10 - totalLines % 10`). Power-up "Sweep" lines count towards totalLines (the game rewards using it).

**Scoring** (all line scores multiplied by the current level, taken before a level-up from this clear):
- Single 100, Double 300, Triple 500, Quad (4 rows) 800.
- Prism bonus: each cleared row that contains at least one prism cell scores x2 for that row's share (row share = line score / rows cleared). Each prism cell cleared pays 1 coin.
- Combo: clears on consecutive locks. From the 2nd consecutive clearing lock, add `50 * (combo-1) * level`. A lock with no clear resets combo to 0.
- Back-to-back: a Quad directly after another Quad (any lock that is not a Quad, including a non-clearing lock, resets it) scores x1.5.
- Perfect clear (well empty after a clear): +1000 x level.
- Soft drop: +1 per row dropped by the player. Hard drop: +2 per row dropped.
- Score is an int, never negative. Best score is stored via SaveService.

**Prism twist details.** When a piece is generated, every 4th piece overall (piece index 3, 7, 11, ...) has exactly one random cell flagged `prism` (shown as a glowing gem). The prism stays with that cell when it locks. A prism cell is only collected by clearing its row; Sweep and Bomb removal do NOT pay coins. Max coins from prisms per game: 40 (stops coin farming).

**Power-ups** (3 types, max 3 uses of each type per game; each use costs 1 from the player inventory):
1. **Sweep** (icon: wave): removes the 3 bottom rows of the well; everything above falls by 3. Gives no score, counts 3 towards totalLines and goal, does not change combo.
2. **Slow** (icon: hourglass): for 20 s of play time (pauses with the game) seconds per row are doubled (half speed). Using it while already active is refused and costs nothing.
3. **Bomb** (icon: bomb): replaces the currently falling piece with a single-cell bomb at the same column. It falls like a piece; on lock it removes all cells in the 3x3 area around its cell, cells above are not moved (no collapse) and rows that become full are not cleared. The bomb leaves no cell behind. No score.

Inventory: a fresh install starts with 1 of each type; stock persists in the save (earned from coins or rewarded ads). Coin prices: Sweep 60, Slow 40, Bomb 50. A power-up button with 0 stock opens a sheet with two choices: "Buy with coins" and "Watch ad for +1" (rewarded). A refill via rewarded ad grants +1 of that type, at most 3 rewarded refills per game.

**Revive.** Once per game, after game over, a rewarded ad lets the player continue: the top 8 rows of the well (including hidden) are cleared and the next piece spawns; score and level are kept. Only one revive per game. The dialog hides the revive button after it was used.

**Pause.** Pausing stops gravity and lock timer. Backgrounding the app auto-pauses. No score or timer progress while paused.

## 4. Content
**Pieces (original names).** Same 7 four-cell shapes; colors are gem hues:

| Name | Shape | Gem color |
|---|---|---|
| Bar | 4 in a line | cyan |
| Cube | 2x2 square | gold |
| Prong | T shape | violet |
| Zig | S shape | green |
| Zag | Z shape | red |
| Hook | J shape | blue |
| Boot | L shape | orange |

**Difficulty.** 15 gravity levels (table above). Level 1 starts relaxed; level 10 (0.12 s/row) needs good Hold/Next use. No level cap on play; speed caps at level 15. Modes in v1: one mode (Marathon, endless until block out).

## 5. Retention (all four ON; `app.config.yaml` `retention:` all true; reuse `lib/core/retention`)
- **Daily reward**: 7-day cycle: day 1 30 coins, day 2 40, day 3 50, day 4 1x Slow, day 5 70 coins, day 6 1x Bomb, day 7 150 coins plus 1x Sweep. Miss a day resets to day 1 unless a streak freeze covers it.
- **Streaks with freeze**: consecutive daily-play streak; one freeze (earned at 7-day streak or bought for 100 coins) covers one missed day automatically.
- **Three daily challenges** (picked per day from the pool; reuse `ChallengeKind` approach, new templates for falling blocks). Reward 25 to 60 coins each:
  1. Score N points in one game (e.g. 3000/5000/8000).
  2. Clear N lines in total today (20/40/60).
  3. Clear a Quad (4 rows) N times (1/2/3).
  4. Reach level N in one game (4/6/8).
  5. Clear N rows that contain a prism (3/6).
  6. Make a combo of N in one game (3/4/5).
  7. Use Hold N times (10/20).
  8. Play N games (3/5).
- **Achievements** (local; also mirrored to Play Games when signed in): First Row (clear 1 line), Century (clear 100 lines total), Quad Squad (4 Quads in total), Prism Collector (collect 50 prisms total), Combo Master (combo of 5), Speed Demon (reach level 10), Perfect (perfect clear), Hold Tactician (use Hold 100 times), Marathoner (score 20,000 in one game), Daily Devotee (7-day streak).
- Notifications (reminder for daily reward) via `NotificationService`, opt-in, toggle in Settings.

## 6. Monetization
- **Banner**: Home (menu) only. Never during play or on the game over dialog.
- **Interstitial**: after game over, when returning to the game over dialog's Retry or Home actions, honoring existing caps (`interstitial_min_interval_seconds: 90`, `interstitial_every_n_game_overs: 2`, `max_interstitials_per_session: 6`, `no_interstitial_first_seconds: 60`). Never mid-game. Not shown if `remove_ads` owned.
- **Rewarded**: (a) power-up refill (+1), (b) revive once per game. Always optional; stays available with `remove_ads`.
- **IAP** (`products.yaml`, unchanged ids): `remove_ads` (non-consumable, removes banner and interstitials), `coins_500` (consumable, 500 coins). Display titles "Remove Ads", "Coin Pack". Prices are set in Play Console, not in code.
- Test ad IDs only in debug; release IDs only from `app.config.yaml` release block.
- Everything goes through `AdService`, `PurchaseService` interfaces. Nothing new in vendor SDKs.

## 7. Screens (test IDs added to `lib/ui/test_ids.dart`)
Reference layout for the game screen (portrait): score pill on top, well in the middle, HOLD box on the left with LEVEL and GOAL under it, NEXT queue on the right, three power-up buttons along the bottom.

- **Home**: Play, Daily reward, Challenges, Shop, Settings, coins, best score, streak, banner. (Keep existing `home.*` IDs.)
- **Game**: IDs `game.widget`, `game.well`, `game.score`, `game.best`, `game.level`, `game.goal`, `game.hold` (tap to hold), `game.holdPiece`, `game.next.0`, `game.next.1`, `game.next.2`, `game.combo`, `game.pause`, `game.back`, `game.powerup.sweep`, `game.powerup.slow`, `game.powerup.bomb`, and for each `game.powerup.<name>.count`; refill sheet `game.refill.coins`, `game.refill.ad`. Game over: `game.over.dialog`, `game.over.revive`, `game.over.retry`, `game.over.home`, `game.over.score`. Pause dialog: `game.pause.resume`, `game.pause.quit`.
- **On-screen controls** (control scheme "Buttons", an accessibility option and the bot's driver): `game.ctl.left`, `game.ctl.right`, `game.ctl.rotate`, `game.ctl.softDrop`, `game.ctl.hardDrop`. Present only when Settings controls = Buttons; Hold and power-ups are always on screen.
- **Daily reward**, **Challenges/Achievements**, **Shop**, **Settings**: existing IDs kept. Settings adds `settings.controls` (Touch/Buttons), `settings.ghost`.

**Touch gestures on `game.well`** (default scheme "Touch"):
- Tap (movement under 10 px, under 250 ms): rotate clockwise.
- Horizontal drag: the piece moves one column for every 1 well-cell width (well width / 10) of horizontal travel since the last move; works both directions while the finger is down.
- Vertical slow drag downward (velocity under 1200 px/s): soft drop while the finger moves down or rests down; releasing stops soft drop.
- Fast fling downward (velocity at least 1200 px/s): hard drop.
- Tap on `game.hold`: Hold.
- Swipe up has no function.

**How the integration bot drives it**: (1) Deterministic start: route argument / `--dart-define=BLOCKFALL_SEED=<int>` fixes the bag order and prism placement. (2) Primary driver: switch Settings to Buttons (or launch with `--dart-define=BLOCKFALL_CONTROLS=buttons`) and tap `game.ctl.*`, `game.hold`, `game.powerup.*` by key. (3) Gesture test: one dedicated integration test uses `tester.tap(find.byKey(game.well))`, `tester.drag(find.byKey(game.well), Offset(dx, 0))` and `tester.fling(find.byKey(game.well), Offset(0, 400), 2000)` and checks the result through Semantics values. (4) State readout: `game.score`, `game.level`, `game.goal`, `game.combo`, power-up counts and `game.holdPiece` expose their value in Semantics `value` (e.g. `holdPiece` value is the piece name or `empty`). (5) A debug-only test hook (`kDebugMode` or `--dart-define=BLOCKFALL_TEST=true`) may preload a well layout for rows/game-over scenarios; it is absent from release builds.

## 8. Art and audio
- Style: reuse block puzzle identity: midnight-teal gradient background, glossy rounded gem blocks (7 hues), glowing score pill; prism cell has a bright white-cyan sparkle core. **No particle effects in v1**; line clears use a short flash/fade of the row (no particles).
- Assets: game blocks drawn in code (Canvas/Flame shapes) where possible; app icon, feature graphic and screenshots by asset-agent; sounds: move tick, rotate, lock, line clear (1 to 4 rows rising), level up, game over, button. All sounds are CC0/own-made; every asset is listed in `assets/LICENSES.md` with source and license.
- Haptics: light tick on lock, medium on clear (toggle in Settings).

## 9. Play Games
- Leaderboard: `leaderboard_high_score` (best score). ID placeholder in `app.config.yaml` until the user creates it.
- Achievements: the 10 in section 5, ids `ach_first_row`, `ach_century`, `ach_quad_squad`, `ach_prism_collector`, `ach_combo_master`, `ach_speed_demon`, `ach_perfect`, `ach_hold_tactician`, `ach_marathoner`, `ach_daily_devotee`. Created in Play Console by the user; the game works fully offline/unsigned.

## 10. Store listing
- Title: Blockfall: Gem Drop Puzzle (max 30 chars)
- Short (80 chars): Drop glowing gem pieces, clear rows, grab prisms. Hold, Next and power-ups.
- Full description: describe classic row clearing with an original Prism twist, Hold and 3-piece Next queue, 15 speed levels, three power-ups, daily rewards, streaks, daily challenges, achievements, play offline, no account needed, ads removable with a one-time purchase. No mention of other games' names.
- Category: Games > Puzzle. Content rating: Everyone, contains ads, optional in-app purchases. Keywords: falling blocks, gem puzzle, row clear, offline puzzle (never Tetris/Block Blast).
- Privacy: AdMob (ad ID), Play Billing; no account, no backend. Data safety form to match.

## 11. Out of scope (v1)
Multiplayer, attackers/target/rival panels, online battles, Firebase or any backend, accounts, particle effects, counter-clockwise rotate, T-spin scoring, extra modes (sprint/ultra), themes shop, iOS/web builds (kept possible via pure-Dart rules), cloud save beyond Play Games.

## 12. Acceptance criteria (testable)
Rules (VM unit tests, `test/rules/`):
1. A full bottom row clears; rows above shift down by 1; score rises by 100 x level at level 1 (+100).
2. Clearing 2, 3, 4 rows at once at level 1 scores 300, 500, 800.
3. A row containing a prism clears with that row's share doubled (a single with a prism = 200 at level 1) and adds 1 coin per prism; coin cap per game is 40.
4. Two consecutive clearing locks at level 1: second adds 50; a non-clearing lock resets combo to 0.
5. Quad followed directly by another Quad scores 1200 for the second (800 x 1.5); a non-Quad in between resets it.
6. Perfect clear adds 1000 x level.
7. Hard drop of d rows adds 2 x d; soft drop of d rows adds d.
8. Hold stores the current piece and spawns the next on first use; a second Hold before locking is ignored; after the next lock Hold works again; the swapped-in piece spawns in rotation 0.
9. With seed S, the first 14 pieces contain each of the 7 types exactly twice (two bags); never 3 same types in 14.
10. Next queue length is 3 and always full.
11. `level = 1 + lines ~/ 10`: after 10 cleared lines level is 2, GOAL is 10; gravity step is 0.80 s/row at level 2 and 0.04 at level 15 and 20.
12. After 10 resets the lock timer is not restarted by moves; the piece locks after at most 0.5 s.
13. Rotation: the I piece next to the left wall rotated to vertical applies a kick offset and lands in bounds; if no offset fits, the state is unchanged; O never changes.
14. Game over: spawning when a spawn cell is filled ends the game; a piece locked fully in the hidden rows ends the game.
15. Sweep removes the bottom 3 rows, adds 3 to lines, no score; Slow doubles seconds per row for 20 s of game time and the timer stops while paused; Bomb removes the 3x3 area at its landing; a 4th use of one type in a game is refused; stock never goes negative.
16. Revive: available exactly once per game; after it the top 8 rows are empty and score/level are unchanged; the second game over shows no revive button.

App-level (widget/integration tests via test IDs):
17. Home shows banner (`home` only); no ad widget exists on the game screen (`game.banner` absent).
18. Game over dialog shows `game.over.revive` once; interstitial obeys the caps (AdFrequency tests with fake clock).
19. Tap on `game.well` rotates; drag of 3 cell-widths moves 3 columns; fling down hard-drops; `game.hold` holds (verified via Semantics values).
20. With Buttons scheme all `game.ctl.*` exist and work; with Touch they are absent.
21. Power-up with 0 stock opens refill sheet; `game.refill.coins` deducts the price (60/40/50) and adds 1; `game.refill.ad` adds 1 via a fake AdService; max 3 ad refills per game.
22. Daily reward cycles 7 days with the rewards in section 5; streak freeze covers one missed day; 3 daily challenges generated per day and claimable; each achievement unlocks on its condition (unit tests with fake clock).
23. Shop lists `remove_ads` and `coins_500`; `remove_ads` removes banner and interstitial but keeps rewarded; pause on app background.
24. `flutter analyze`, `dart format`, `flutter test`, `scripts/ad_safety_check.sh` pass; `assets/LICENSES.md` lists every asset; no occurrences of "Tetris" or "Block Blast" in the repo outside `docs/SPEC.md` (CI grep excludes that file, which states the naming rule).

## Reuse versus new
- **Reused unchanged from `lib/core/`**: ads (`AdService`, `AdFrequency`, AdMob impl), purchase (`PurchaseService`, products.yaml loading), save (`SaveService`), identity, leaderboard, notifications, analytics (no-op), remote_config, profile, clock, config, retention (`daily_reward`, `streaks`, `achievements`, `daily_challenges` with new templates/achievement definitions added).
- **New**: `lib/game/rules/` (well, piece tables, bag randomizer, rotation, gravity table, scoring, hold, power-ups, prism, game state machine), `lib/game/flame/` rendering and gesture input, `lib/ui/game_screen.dart` and widgets (HUD, hold/next boxes, power-up bar, controls), extended `test_ids.dart`, new challenge templates and achievements, power-up inventory in save, new sounds and icon.
- **Replaced**: block-puzzle rules and Flame components of the template (grid placement, tray pieces).

## Third-party packages
None new. Existing template packages only (Flutter, Flame, `google_mobile_ads`, `in_app_purchase`, `flutter_local_notifications`, Play Games plugin as already in the template, audio package already in the template). If the template has no audio package, reuse what it already uses for sounds; adding a package needs a recorded reason from the coder stage.
