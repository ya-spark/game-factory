# Blockfall (game package `game_blockfall`)

Status: BUILT. The game lives once in `game-factory/games/blockfall/` (SH1, owner 2026-11-21); the standalone Blockfall app and Mind Ember are containers that show it and bring their own shop, profile, ads, theme and release setup. This file is the only copy of the game's behaviour; it was moved from the standalone app's `docs/SPEC.md`, so it also holds sections about the standalone app (shop, monetisation, store). Where a section is about the container, the container follows it; a hub follows its own spec for those parts.

The game asks its container only through `BlockfallServices` (`lib/src/host/`). Narrator voice and ambience come from `game_core/assets/audio`.

---

# Blockfall - game spec

Status: APPROVED by the user on 2026-10-28. This is the contract for all later stages. This file is the contract for the game and the only copy.

Implementation status (updated by the coder stage, chunk 3): sections 1 to 7, 9 and 12 are implemented and covered by tests; nothing is open in the code except the items below that need a real device. Accepted deviations: (a) Settings uses a single "On-screen buttons" switch for the Touch/Buttons scheme instead of a segmented control (`settings.controls` is that switch); (b) **audio is narrator voice plus background sound only** (see section 8): the effect sounds listed there are not built, haptics are implemented; (c) the achievement "Prism Collector" counts cleared rows that hold a prism (a row with two prisms counts once); (d) the daily-reward cycle replaced the template's coin-only cycle, and the old block-puzzle challenges and achievements were removed (old unlocked ids are dropped in the v3 save migration). Still to verify on a device or in the manual emulator job: real-AdMob test-ad behaviour, haptics, Flame frame rate, backgrounding, `integration_test/blockfall_bot_test.dart`. Not part of this stage: store listing text and privacy policy (listing stage), icon and screenshots (asset stage).

- id: `blockfall`, display name: **Blockfall**, package: `com.activemindcraft.blockfall`, repo: `ya-spark/game-block-fall`
- Base template: block puzzle template (`template/flutter-game-template`). No falling-blocks template exists yet.
- Naming rule: the strings "Tetris" and "Block Blast", their logos, art, sounds, and piece letter-names-as-branding must not appear in code, assets, listing or keywords. Pieces are called by the original names in section 4.

## 1. Pitch
Blockfall is a single-player falling-blocks game for Android. Glossy gem pieces drop into a 10-wide well; fill a row and it clears. Hold a piece, peek at the next three, grab power-ups, and race the speed as levels climb. Original twist: **Prism cells**. Some pieces carry one glowing prism gem; clearing a row that contains one doubles that row's score and pays out coins. It targets casual players who want a quick, polished classic with daily goals, and plays well in 3 to 10 minute sessions. Look: midnight-teal gradient, glossy rounded gem blocks, glowing score pill (the game-factory block puzzle identity).

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

**Randomizer.** 7-bag: each bag is a shuffled permutation of the 7 pieces. Never more than 12 pieces between two copies of the same piece type, and each bag holds each piece once. The Next queue holds 3 pieces; a piece is chosen at the moment it enters the queue, from the pieces of the current bag not yet dealt (a new bag is shuffled when none remain), by the well-fit rule: with probability `p(level) = max(0, (9 - level) / 8)` (level 1: 1, level 5: 0.5, level 9 and up: 0) take the best fit, otherwise take the next remaining piece in bag order (the plain bag; at level 9 and up the order equals the plain bag order for the seed). **Best fit:** for every remaining piece, simulate a hard drop of every rotation in every column on the current well and score the result; the piece with the lowest score wins. Score order (lexicographic, lower is better): (1) holes (empty cells below a filled cell in the same column), (2) bumpiness (sum of absolute height differences of neighbouring columns), (3) height (tallest column). Remaining ties go to the piece that comes first in bag order. The roll uses its own `Random` (seed `BLOCKFALL_SEED ^ 0xf17`), so a seed stays deterministic and prism placement is not affected.

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

**Prism twist details.** When a piece is generated, every 4th piece overall (piece index 3, 7, 11, ...) has exactly one random cell flagged `prism` (shown as a glowing gem). The prism stays with that cell when it locks. A prism cell is only collected by clearing its row; Sweep and Boom power-up removal do NOT pay coins. Max coins from prisms per game: 40 (stops coin farming).

**Special blocks and Gold Rush** (code: `CellKind { normal, prism, boom, gold }` in `well.dart`; dealing in `BlockfallGame._refillQueue`; effects in `BlockfallGame._clearRows`; constants in `scoring.dart`). The prism is the "gem" block and stays exactly as above.
- Dealing: every `boomEveryNthPiece = 9`th piece (index 8, 17, ...) has one Boom block cell and every `goldEveryNthPiece = 13`th piece (index 12, 25, ...) one golden cell. A piece carries at most one special cell; when several fall on one piece the order is gold, then boom, then prism. The cell index (0..3) is drawn from its own seeded `Random` (seed `BLOCKFALL_SEED ^ 0xb00`), so the bag order never changes and prism placement is still drawn whenever a prism is due. The kind travels with the cell into the well, is saved with the cell and is removed with it.
- Effects resolve when the row that holds the cell clears:
  - **Boom block**: every filled cell in the 3x3 area around it that is not in a cleared row is removed first (same rules as the Boom power-up: cells above do not fall because of the blast, rows that become full because of it are not cleared). Each such extra cell scores `blastCellPoints = 5` x level (the level before any level-up from this clear), not doubled by Gold Rush. Then the normal row clear and collapse follow. Cells removed by a blast do not trigger their own effect, except prism cells, which still pay their coin (the row-score doubling needs the prism's own row to clear).
  - **Golden block**: starts **Gold Rush**: for `rushSeconds = 10` s of play time (the timer pauses with the game, ends mid-tick exactly) every line, combo, back-to-back and perfect-clear score is multiplied by `rushMultiplier = 2`. The clear that brings the golden block is not doubled unless a rush already runs. Each further golden block during a rush adds 10 s, capped at `rushCapSeconds = 30`. A new game starts with no rush.
- Look: every kind is an overlay on top of the current theme skin (Boom block = friendly star-burst, golden = gold sheen with a star; prism keeps its sparkle). The blast is a 0.5 s cartoon star burst on each removed cell (grows and fades, no flashing). During a rush the well has a soft golden shimmer (slow sway, no flashing) and a chip "GOLD RUSH x2 · Ns" shows the seconds left. Test ID `game.rush`: Semantics value = whole seconds left (0 when off). The HUD row with the streak, combo, Gold Rush chip and prism coins is a `Wrap` (centred, 14 dp gaps, 2 dp between lines): when it does not fit it breaks onto a second line and never overflows (test at 360 dp wide with all of them showing).

**Power-ups** (3 types, max 3 uses of each type per game; each use costs 1 from the player inventory):
1. **Sweep** (icon: wave): removes the 3 bottom rows of the well; everything above falls by 3. Gives no score, counts 3 towards totalLines and goal, does not change combo.
2. **Slow** (icon: hourglass): for 20 s of play time (pauses with the game) seconds per row are doubled (half speed). Using it while already active is refused and costs nothing.
3. **Boom** (icon: bomb; shown as "Boom" to the player, code and test IDs keep `bomb`): replaces the currently falling piece with a single-cell bomb at the same column. It falls like a piece; on lock it removes all cells in the 3x3 area around its cell, cells above are not moved (no collapse) and rows that become full are not cleared. The bomb leaves no cell behind. No score.

Inventory: a fresh install starts with 1 of each type; stock persists in the save (earned from coins or rewarded ads). Coin prices: Sweep 60, Slow 40, Boom 50. A power-up button with 0 stock opens a sheet with two choices: "Buy with coins" and "Watch ad for +1" (rewarded). A refill via rewarded ad grants +1 of that type, at most 3 rewarded refills per game.

**Revive.** Up to three times per run (`PowerUpRules.maxRevivesPerRun = 3`), after game over, a rewarded ad lets the player continue: the top 8 rows of the well (including hidden) are cleared and the next piece spawns; score and level are kept. The label counts the continues left (`Continue · 3 left`, then 2, then 1). The dialog hides the Continue button when none is left. **Continue needs a rewarded ad (owner, 2026-11-06).** Pressing Continue with `remove_ads_all` (or the retired `remove_ads`) owned continues at once (no ad, no coins). Otherwise it starts the rewarded ad directly, with no choice sheet. A continue is granted only when the ad reports the reward as earned; if the ad fails to load, is not ready or is closed early, nothing is granted, the panel stays open and shows "No ad available right now. Try again in a moment.". Never a fallback to coins or a free continue; coins cannot pay for Continue. Player-facing wording is "Continue" (the code and test IDs keep "revive").

**Game over layout.** Everything sits in one panel (`game.over.panel`): rounded card (radius 24), solid dark surface `#140B2B` at about 90 % opacity, thin light border (1 px, 40 % white), soft shadow, so text and buttons never mix with the game background; text and button contrast against the panel at least 4.5:1. The card is **vertically centred** in the safe area (`Alignment.center`, 16 dp side padding, 8 dp above and below; owner, 2026-11-06), after the slide-up has finished. The panel (`lib/ui/game_over_panel.dart`) is the same file in every game and the template (Blockfall is the reference); game-specific wording lives only in the callers. It has one optional extra row, `extraButton`, between the Play again / Home row and Continue (14 dp gaps): Wingy uses it for Dash Refill, the other games leave it empty. Top to bottom: Share icon button at the top left (`game.over.share`); title, score, best score; one row with Play again (secondary, font size 15, padding 18x9) and Home (ghost, font size 15, padding 18x9) side by side; Continue last, at the bottom: label `Continue · N left` (constant `kContinueLabel` in `lib/ui/game_screen.dart`), gold primary style, font size 22, padding 28x16; not shown when no continue is left. When Continue is not available, Play again takes the large gold style (font size 22, padding 28x16). Test IDs: `game.over.revive` (Continue), `game.over.retry` (Play again), `game.over.home`, `game.over.share`, `game.over.score`, `game.over.dialog`, `game.over.panel`, `game.over.view`.

**Game over ease-in.** The game over is never abrupt (about 1 s in total): (a) the run ends, input is locked and the scene freezes, and the game over voice line starts; (b) 0.3 s hold while the scene dims to about 40 % (black scrim, 60 %); (c) the panel (`game.over.panel`, present from the first frame of this step) fades 0 to 100 % and slides up 24 px over 0.7 s, ease-out cubic; (d) the buttons (and the eye button `game.over.view`) become tappable when the panel has settled. With reduce motion (system animations off): a single 0.2 s fade, no dim, no slide. The eye button fades the panel with the same 0.2 s and lifts the dim. The shown score never changes during the transition. Constants in `GameOverPanel`.

**View board.** A small eye button (`game.over.view`) at the top right of the panel. Tapping it fades the panel out in 0.2 s so the whole final board is visible; a tap anywhere, or the eye button (which stays visible), brings the panel back. The final well with the locked pieces stays visible and still; nothing else changes while the panel is hidden (scores and rewards are already final).

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

**Difficulty.** 15 gravity levels (table above). Level 1 starts relaxed; level 10 (0.12 s/row) needs good Hold/Next use. No level cap on play; speed caps at level 15. Piece choice helps early and fades out: `p(level) = max(0, (9 - level) / 8)` is the chance that the next piece is the best fit for the well (see Randomizer), so from level 9 the pieces are the plain bag. Modes in v1: one mode (Marathon, endless until block out).

## 5. Retention (all four ON; `app.config.yaml` `retention:` all true; reuse `lib/core/retention`)
- **Daily reward**: 7-day cycle: day 1 30 coins, day 2 40, day 3 50, day 4 1x Slow, day 5 70 coins, day 6 1x Boom, day 7 150 coins plus 1x Sweep. Miss a day resets to day 1 unless a streak freeze covers it.
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
- **Interstitial**: after game over, when returning to the game over dialog's Retry or Home actions, honoring existing caps (`interstitial_min_interval_seconds: 180`, `interstitial_every_n_game_overs: 2`, `max_interstitials_per_session: 6`, `no_interstitial_first_seconds: 60`). Never mid-game. Not shown if `remove_ads_all` owned.
- **Rewarded**: (a) power-up refill (+1, max 3 per game), (b) game-over Continue (within the per-run revive limit). Always optional. With `remove_ads_all` owned there is **no rewarded ad either**: both are granted instantly within the same limits, and the refill button reads "Get +1 free (N left)".
- **IAP** (`products.yaml`): `remove_ads_all` (non-consumable, "Remove Ads", "Removes all ads."), `coins_500` ("Coin Pack"), `coins_1500` ("Big Coin Pack"), `coins_4000` ("Coin Chest"), the coin packs consumable. The old id `remove_ads` is retired in Play; a saved or restored `remove_ads` still counts as Remove Ads (`ProductDef.legacyRemoveAdsId`). Prices are set in Play Console, not in code.
- **Shop**: order Remove Ads, then coin packs ascending (coin packs show the coin icon). Wording never pressures children. Products the store does not return stay hidden; no products at all shows "Store unavailable".
- **Parent gate** (`ParentGate`, `lib/core/purchase/parent_gate.dart`, dialog `lib/ui/parent_gate_dialog.dart`): before every real-money purchase (Remove Ads and coin packs; not Restore, not spending coins) a dialog "Ask a grown-up" asks a typed multiplication such as `7 x 8` (factors 6 to 9, new numbers each time). A wrong answer shows a new question; 3 wrong in a row close the dialog and lock purchases for 60 s (a note shows while locked). A correct answer starts the normal purchase flow.
- **Coin icon**: `CoinIcon` (`lib/ui/widgets.dart`), drawn in code: gold coin, darker rim, inner ring, soft shine, bold dark-gold "MC", Semantics label "coins". Used for every coin display (home chip, daily reward, shop, refill sheet). Store prices like "$2.99" are the real localised prices.
- Test ad IDs only in debug; release IDs only from `app.config.yaml` release block.
- Everything goes through `AdService`, `PurchaseService` interfaces. Nothing new in vendor SDKs.

## 7. Screens (test IDs added to `lib/ui/test_ids.dart`)
Reference layout for the game screen (portrait): score pill on top, well in the middle, HOLD box on the left with LEVEL and GOAL under it, NEXT queue on the right, three power-up buttons along the bottom.

- **Home**: Play, Daily reward, Challenges, Shop, Settings, coins, best score, streak, banner. (Keep existing `home.*` IDs.)
- **Home scene and background** (`lib/ui/home_hero.dart`, `ThemeBackground` in `lib/ui/theme_fade.dart`): above the title, a code-drawn band 160 dp tall (no assets, no gestures, test ID `home.hero`) with 10 objects: the seven piece shapes plus three single gems (prism, Boom, golden), slowly falling and drifting sideways (alternating directions) with a gentle spin. Painted with the current theme's block skin (theme at the saved `themeIndex`, restyled when it changes) plus the prism glow and Boom/golden overlays. One `CustomPainter`, one ticker; it stops while the home route is covered and while the app is in the background. The home background is the current theme's background at the saved `themeIndex`, with the same 1.5 s cross-fade. The title is white with a dark shadow. Other menu screens keep the plain gradient.
- **Sharing** (`lib/core/share/`, `lib/ui/share_card.dart`): `ShareService` (`shareScore`, `shareAchievement`, `shareApp`); `SystemShareService` opens the Android share sheet through `share_plus`, imported only in that file and pinned to the exact version `13.3.1` (same as game-wingy and game-block-puzzle; an exact pin so a share plugin update never changes behaviour or permissions unreviewed). `FakeShareService` records the texts in tests. No Facebook or Instagram SDK. The app sends nothing itself; the player starts sharing and picks the target app.
  - Share card: a widget drawn in code and rendered to a PNG through a `RepaintBoundary` (360x450 at 3x): game name, big score (or achievement title), best score, and the current look (the current theme's background and one block of each of the 7 colours in its skin). No player name, no id, no store text.
  - Texts: score `This is my high score in {game}: {score}. Can you beat it?`, achievement `I unlocked "{title}" in {game}! Can you beat it?`, app `Try {game}!`; each followed by a new line and the link when there is one. The game name always appears; the share picture stays free of names, ids and store text.
  - Config in `app.config.yaml`: `share: link_mode: internal_test | store | off` (default `internal_test`) and `internal_test_url`. `internal_test` uses `internal_test_url` (`https://play.google.com/apps/internaltest/4700823638704685278`); `store` uses `https://play.google.com/store/apps/details?id=<package_name>`; `off` adds no link and hides "Share app". `internal_test` with an empty URL behaves like `off`. The owner switches to `store` when the game is public. Loader: `AppConfig.shareLink` (null = no link).
  - Buttons: game over, a small ghost Share icon button at the top left of the panel (`game.over.share`); each unlocked achievement has a share icon (`achievement.share.<id>`); Settings "Share app" (`settings.shareApp`) is visible unless there is no link (mode `off`) and shares the same message and link.
- **Tips** (`lib/game/tips.dart`, `lib/core/tips/tip_service.dart`, `lib/ui/tip_card.dart`): 15 tips (at most 80 characters, unique, none mention other games). `TipService` (pure Dart) gives the tip of the day from the day index.
  - The only place a tip appears is one dialog on the Home page, opened the first time Home is shown each day (saved `tipHomeDay`, marked as soon as it opens, so not again the same day). It shows "Tip of the day", the tip, a "Don't show tips again" checkbox (`tip.dontShow`) and Close (`tip.close`); the card carries `tip.home`. The checkbox + Close turns tips off everywhere; the dialog never opens while tips are off. There is no tip card in the Home layout, so the buttons are never pushed down.
  - The dialog opens only while Home is the page on top and no run is on screen (`Services.inRun`, set by the game screen), checked again after the save that marks the tip as shown. A blocked tip is never queued; the next time Home is shown it is tried again (still once per day).
  - No tip, hint or one-time special-block hint is ever shown in a game, on the pause overlay or on the game over screen.
  - Settings "Show tips" switch (`settings.tips`, on by default) is the same saved profile value (`tipsOff`).
  - Test fakes turn tips off by default (`buildFakeServices(tips: true)` turns them on).
- **Game**: IDs `game.widget`, `game.well`, `game.score`, `game.score_label`, `game.best`, `game.best_text`, `game.level`, `game.theme` (invisible, value = theme id), `game.goal`, `game.hold` (tap to hold), `game.holdPiece`, `game.next.0`, `game.next.1`, `game.next.2`, `game.combo`, `game.rush`, `game.pause`, `game.back`, `game.powerup.sweep`, `game.powerup.slow`, `game.powerup.bomb`, and for each `game.powerup.<name>.count`; refill sheet `game.refill.coins`, `game.refill.ad`. Game over: `game.over.dialog`, `game.over.revive`, `game.over.retry`, `game.over.home`, `game.over.score`. Parent gate: `gate.dialog`, `gate.answer`, `gate.submit`, `gate.cancel`. Shop buttons: `shop.buy.<productId>`. Pause dialog: `game.pause.resume`, `game.pause.quit`.
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

**More games** (`lib/ui/more_games_screen.dart`, `moreGames.screen`, `moreGames.back`)
- Title "More games", header "More from Active Mind Craft". One card per listed game (`moreGames.card.<id>`): a 48 dp rounded tile (12 dp radius) drawn in code (no asset), the name, the tagline, and "Get it" (`moreGames.get.<id>`, status `live`) or the text "Coming soon" (`coming_soon`, no button). "Get it" asks the parent gate first (the same "Ask a grown-up" dialog and lockout as purchases), then `ExternalLinkService.openStorePage(package)` (`market://details?id=<package>`, fallback `https://play.google.com/store/apps/details?id=<package>`). Cancelling the gate opens nothing.
- Never coins, items or any reward for opening or installing another game (Play bans incentivised installs). Not shown on game over, Continue or in play, and never in place of an interstitial.
- Entry points: a "More games" row in Settings (`settings.moreGames`, `Icons.apps`, below the tips switch) and a round icon in the Home top-right icon row (`home.moreGames`, see "Behaviour and feel"). No other entry points.
- The list is bundled: `more_games:` in `app.config.yaml` (`id`, `package_name`, `name`, `tagline`, `status` = `live` | `coming_soon` | `hidden`), loaded into `AppConfig.moreGames`; `AppConfig.visibleMoreGames` drops `hidden` entries and this game's own `package_name`, so the same list is copied to every game. With nothing to show, the Settings row and the Home icon are not shown. No network call, so the privacy policy and Data safety do not change. All entries start `hidden`; the owner flips an entry to `live` when that game is public. Taglines are under 60 characters, name no other studio and use no pressure wording.
- `ExternalLinkService` (`lib/core/links/`): `openStorePage(packageName)`; `UrlExternalLinkService` is the only file that imports `url_launcher`; `FakeExternalLinkService` records the packages in tests. The Android manifest `<queries>` lists the `market` and `https` VIEW intents.

## 8. Art and audio
- Style: reuse block puzzle identity: midnight-teal gradient background, glossy rounded gem blocks (7 hues), glowing score pill; prism cell has a bright white-cyan sparkle core. **No particle effects in v1**; line clears use a short flash/fade of the row (no particles).
- **Themes** (background + block skin + 7 colours + well and grid colours, all drawn in code, no assets). Same six themes, ids and order as game-block-puzzle; the first is the look described above:

  | # | id | Name | Background | Block skin |
  |---|---|---|---|---|
  | 0 | `gems` | Gems | midnight-teal to blue gradient | glossy faceted gem (the original look) |
  | 1 | `cakes` | Cakes | brown wafer | biscuit with icing and sprinkles |
  | 2 | `wood` | Wood | green gradient | wooden tile with grain |
  | 3 | `candy` | Candy | pink and sky gradient | glossy gumdrop |
  | 4 | `ocean` | Ocean | deep blue with bubbles | pearly shell |
  | 5 | `space` | Space | violet night with stars | ringed planet |

  Each theme has 7 colours, one per piece type (colour id 1..7 in the well): a piece type keeps one colour inside a theme and has a different colour in each theme. Every skin carries a small mark per colour (dot, ring, bar, ...) so colours stay distinguishable without hue, and the prism cell keeps the bright sparkle core in every skin. The well still stores only a colour id and a prism flag per cell; `lib/game/rules/` only gains the pure rotation rule `ThemeRotation`.
  **Block tile and contrast (look).** In every skin except Gems (already a filled tile, unchanged) each cell is first drawn on a base tile (`paintBaseTile` in `lib/game/themes/block_theme.dart`): rounded square filling the whole cell (0.5/64 gap per side = 1 px grid gap, corner radius 16 % of the cell, at most 18 %), filled with the dark shade (lightness -0.3) of the cell's own colour, with a 1.5/64 outline at 45 % black (`0x73000000`) and a 1/64 inner edge on the top and left at 35 % white (`0x59FFFFFF`). The motif (gumdrop, shell, planet, icing, wood face) is drawn on top and is at least 80 % of the tile width (planet disc 83 %). Falling piece, ghost, Hold and Next use the same skin. Every palette colour has a WCAG contrast of at least 3:1 against the theme's empty cell colour (well colour blended over `backgroundTop`) and, in Cakes, Candy, Ocean and Space, against `backgroundTop`. Gems and Wood have bright mid-tone backgrounds that no on-theme colour can reach 3:1 against, so only the empty cell check applies there. Colour-blind marks stay. Candy colours were darkened (e.g. raspberry `#C4155A`, lemon `#7A5B00`), Cakes chocolate/cherry, Wood walnut/cherry wood/dark and Ocean lilac/blue were lightened. Test: `test/ui/block_contrast_test.dart`.
  **Change rule.** No picker, no setting. The theme changes on every **level-up**, in table order, wrapping from `space` to `gems`: theme index = (start index + level - 1) mod 6. The index is saved in the profile (`themeIndex`, written at each level-up) and a new game starts from it; a new install starts at `gems`.
  **Cross-fade.** On a change the new theme fades in over the old one in 1.5 s: background, well, locked cells, falling piece, ghost, Hold and Next previews. No flashing; it never blocks input or delays a lock. Cell pictures are cached per (theme, colour). The current theme id is the Semantics value of the invisible `game.theme`.
  **HUD text colour.** Each theme has `hudText` (and `hudSubtle` for the "SCORE" label) and `backgroundTop` (top colour of its background gradient). The game screen's HUD text drawn on the background (score digits, SCORE label, "Day N streak" line, combo, GOLD RUSH chip text, best-score number) uses the current theme's colours; the star icon stays amber, and text inside dark pills/buttons (HOLD / LEVEL / GOAL / NEXT, power-ups) is unchanged. Dark themes keep white (`hudSubtle` teal-grey `0xFF7FB7BD`); Candy uses dark plum `0xFF5B2A55` / `0xFF6E3A68`. The colours blend during the 1.5 s cross-fade (`HudColors` in `ThemeBackground`). Tests: Candy `hudText` and `hudSubtle` contrast against `backgroundTop` is at least 4.5 (WCAG); other themes keep a floor of 2.0. Test IDs: `game.score_label` is the SCORE label, `game.best_text` the best-score number.
  **HUD text shadow.** Gems and Ocean (`hudShadows` in `BlockTheme`, `kHudTextShadow`) give the HUD texts a soft dark shadow (2 px blur, 40 % black, no offset) so contrast stays at least 4.5:1 on their bright backgrounds; layout unchanged. Other themes have none. Test: `test/ui/game_over_ease_in_test.dart`.
- Assets: game blocks drawn in code (Canvas/Flame shapes) where possible; app icon, feature graphic and screenshots by asset-agent; sounds: move tick, rotate, lock, line clear (1 to 4 rows rising), level up, game over, button. All sounds are CC0/own-made; every asset is listed in `assets/LICENSES.md` with source and license.
- Haptics: light tick on lock, medium on clear (toggle in Settings).
- **Voice** (`assets/voice/`, narrator lines; v1 has no effect sounds). One voice player; a clip that is playing is never stopped by a new line (`lib/core/audio/voice_arbiter.dart`). Priorities: **High** `game_over`, `better_than_the_best`; **Normal** `awesome`, `combo`, `excellent`, `fantastic`, `great`, `incredible`, `nice`, `unbelievable`, `unstoppable`, `well_done`, `you_did_it`; **Low** `get_ready`, `go`, `careful`. A high line that arrives while a clip plays waits and plays right after it (the newest waiting high line wins); a normal or low line that arrives while a clip plays is played only if the current clip ends within 1 s, otherwise it is dropped (a waiting high line beats it).
- **Background sound** (`assets/ambience/`): loops at volume 0.25 (voice 1.0), 0.1 while a voice clip plays, both times master volume. Starts when the game screen opens; pauses on pause and when the app goes to the background; resumes on resume; stops when leaving the game screen; keeps playing under the game over dialog. Default track **Morning birds** (`morning_birds.mp3`); other Heartbeat (`heartbeat.mp3`), Off. Voice and ambience players use the Android audio context `mixWithOthers`, so neither takes audio focus or interrupts the other.
- **Sound settings** (saved in the profile, applied immediately): **Sound** switch (`settings.sound`, master mute, stays on top); **Master volume** slider 0 to 100 % in 5 % steps, default 100 % (`settings.volume`); **Background sound** picker Off / Morning birds (default) / Heartbeat (`settings.ambience`), with a play/stop preview button beside the picker (`settings.ambience.preview`) that loops the track until stopped; picker text is ink-coloured on the white panel; a saved Before sunrise falls back to Morning birds; **Voice** switch, default on (`settings.voice`). No Effects switch. "On-screen buttons" and "Ghost piece" are unchanged.
- **Hand** (`settings.hand`, Right default / Left, saved in the profile as `leftHanded`). Left mirrors the Hold box (moves to the far right of the HUD row), the on-screen control buttons when on (soft/hard drop move to the left of the row, mirrored in order; move-left, rotate, move-right stay in that order on the right so arrows keep their meaning), and swaps pause and back in the header (pause left, back right). The well, the score and the game over screen are unchanged.

## 9. Play Games
- Leaderboard: `leaderboard_high_score` (best score). ID placeholder in `app.config.yaml` until the user creates it.
- Achievements: the 10 in section 5, ids `ach_first_row`, `ach_century`, `ach_quad_squad`, `ach_prism_collector`, `ach_combo_master`, `ach_speed_demon`, `ach_perfect`, `ach_hold_tactician`, `ach_marathoner`, `ach_daily_devotee`. Created in Play Console by the user; the game works fully offline/unsigned.

## 10. Store listing
- Title: Block Fall (max 30 chars)
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
15. Sweep removes the bottom 3 rows, adds 3 to lines, no score; Slow doubles seconds per row for 20 s of game time and the timer stops while paused; Boom removes the 3x3 area at its landing; a 4th use of one type in a game is refused; stock never goes negative.
16. Revive: available up to three times per run; after each, the top 8 rows are empty and score/level are unchanged; the game over after the third shows no revive button.

App-level (widget/integration tests via test IDs):
17. Home shows banner (`home` only); no ad widget exists on the game screen (`game.banner` absent).
18. Game over dialog shows `game.over.revive` while a continue is left; interstitial obeys the caps (AdFrequency tests with fake clock).
19. Tap on `game.well` rotates; drag of 3 cell-widths moves 3 columns; fling down hard-drops; `game.hold` holds (verified via Semantics values).
20. With Buttons scheme all `game.ctl.*` exist and work; with Touch they are absent.
21. Power-up with 0 stock opens refill sheet; `game.refill.coins` deducts the price (60/40/50) and adds 1; `game.refill.ad` adds 1 via a fake AdService; max 3 ad refills per game.
22. Daily reward cycles 7 days with the rewards in section 5; streak freeze covers one missed day; 3 daily challenges generated per day and claimable; each achievement unlocks on its condition (unit tests with fake clock).
23. Shop lists `remove_ads_all`, `coins_500`, `coins_1500`, `coins_4000` in that order; `remove_ads_all` removes banner, interstitial and rewarded ads (Continue and refills are instant); pause on app background.
24. Parent gate blocks purchases until answered, shows a new question after a wrong answer, locks for 60 s after 3 wrong in a row (fake clock); Restore needs no gate.
25. Without Remove Ads, Continue calls the rewarded ad directly (no choice sheet) and spends no coins even with 1000 coins; an ad not earned grants nothing, keeps the panel open and the coin balance unchanged; with Remove Ads it continues with no ad call.
24. `flutter analyze`, `dart format`, `flutter test`, `scripts/ad_safety_check.sh` pass; `assets/LICENSES.md` lists every asset; no occurrences of "Tetris" or "Block Blast" in the repo outside `docs/SPEC.md` (CI grep excludes that file, which states the naming rule).
- More games: the Home icon and the Settings row open the screen; a `live` card shows "Get it", which asks the parent gate before the store page opens (Cancel opens nothing); `coming_soon` has no button; `hidden` entries and this game itself are absent; with nothing listed neither entry point shows; the screen has no coin or reward text (`test/ui/more_games_test.dart`).
- More games on Home at 360 x 640 dp and 360 x 592 dp with the banner: the icon row (More games, Shop, Settings) is 48 dp targets 8 dp apart at the top right and overlaps no Home element; Play is 240 x 60 and Daily reward / Challenges are 116 x 52 side by side, with no scrolling.

## Reuse versus new
- **Reused unchanged from `lib/core/`**: ads (`AdService`, `AdFrequency`, AdMob impl), purchase (`PurchaseService`, products.yaml loading), save (`SaveService`), identity, leaderboard, notifications, analytics (no-op), remote_config, profile, clock, config, retention (`daily_reward`, `streaks`, `achievements`, `daily_challenges` with new templates/achievement definitions added).
- **New**: `lib/game/rules/` (well, piece tables, bag randomizer, rotation, gravity table, scoring, hold, power-ups, prism, game state machine), `lib/game/flame/` rendering and gesture input, `lib/ui/game_screen.dart` and widgets (HUD, hold/next boxes, power-up bar, controls), extended `test_ids.dart`, new challenge templates and achievements, power-up inventory in save, new sounds and icon.
- **Replaced**: block-puzzle rules and Flame components of the template (grid placement, tray pieces).

## Third-party packages
Added for sharing: `share_plus` 13.3.1 (exact pin, used only in `lib/core/share/system_share_service.dart`; the Android share sheet, no network of its own). Otherwise existing template packages only (Flutter, Flame, `google_mobile_ads`, `in_app_purchase`, `flutter_local_notifications`, Play Games plugin as already in the template, audio package already in the template). If the template has no audio package, reuse what it already uses for sounds; adding a package needs a recorded reason from the coder stage.

Added for "More games": `url_launcher` 6.3.3 (exact pin, so a plugin update never changes behaviour or permissions unreviewed): opens Play Store pages for "More games"; imported only in `lib/core/links/url_external_link_service.dart`; sends nothing itself.

## Behaviour and feel (owner decisions, exact values)

**Home screen fits without scrolling** (owner, 2026-11-06). Code: `lib/ui/home_screen.dart`, `homeLayout` and `HomeGrid` in `lib/ui/widgets.dart`.
- At normal text size the whole Home fits with no scrolling on a 360 x 640 dp window with the banner shown (also 360 x 592), and on taller ones.
- Order (layout v2, owner 2026-11-06, replaces the 2 x 2 grid): a **top-right icon row**, then hero, title (one line, scaled down if too wide), stat chips, **Play** (240 x 60 dp, icon 30, label 24), then **Daily reward and Challenges side by side** in one row (each 132 x 52 dp, 8 dp apart, 272 dp in all (owner 2026-11-09: widened from 116 / 240 so the label does not touch the rounded ends), 6 dp inner padding each side, icon 22, label 15 sp scaled down with `FittedBox` and never wrapping, badges unchanged). If `retention` hides one of the two, the other spans the full 272 dp; if both are hidden the row is gone.
- **Top-right icon row** (`HomeIconButton` in `lib/ui/widgets.dart`): inside the safe area, 8 dp from the top and right edges, 8 dp between icons, in this order from the right: Settings (`home.settings`, `Icons.settings`), Shop (`home.shop`, `Icons.shopping_basket`), and More games (`home.moreGames`, `Icons.apps`) when at least one other game is listed. Each is a round gradient button, 44 dp visual with a 2 dp white border and a white 24 dp icon, 48 dp tap target (the key sits on the 48 dp target), Semantics labels "Settings", "Shop", "More games". Shop and Settings keep their old colours. The title never overlaps the row at 360 dp wide.
- `MenuButton` default size is 240 x 52 dp (primary 240 x 60) everywhere it is used.
- `HomeHero` is 160 dp when there is room and shrinks down to 96 dp when the space is short. Spacing between groups is 10 dp, and 8 dp when space is short (`homeLayout`).
- A `SingleChildScrollView` stays only as a safety net (very small windows, text scale above 1.3).
- Test IDs are unchanged (`home.shop` and `home.settings` now sit on the icon buttons). The banner is not moved or hidden. Tests: `test/ui/home_fit_test.dart`.

**Autosave, Remove Ads offer, power descriptions (owner, 2026-11-09)**
- **Autosave and resume:** the running game (well with special cells, falling piece with its position and rotation, queue, hold, score, lines, combo, Slow and Gold Rush timers, power-up uses, ad refills, revives, theme start) is saved after every lock and power-up and when the game pauses (`SaveData.game`, `BlockfallGame.toJson`, `BlockfallGame.restore`). It is cleared when the game ends. Opening the game screen resumes an unfinished game **paused** with a light "Game resumed" snack bar; the player taps Resume to go on. Leaving with the on-screen back button keeps the game (it is recorded when it ends); Back and an app switch pause it. A corrupt save is dropped and a new game starts.
- **Remove Ads offer:** until `remove_ads_all` is owned, a small white "Remove ads" pill (`RemoveAdsPill`) shows on the game over panel under the best score (`game.over.removeAds`) and opens the Shop; it disappears once owned. It is **not** on Home (owner, 2026-11-09). In the Shop, Remove Ads is the first item, above the coin packs.
- **Power description before buying:** the refill sheet shows what the power does (`game.refill.description`): Sweep clears the bottom 3 rows, Slow halves the falling speed for 20 seconds, Boom turns the falling piece into a bomb that blasts 3x3 where it lands.
- **Play and pause (owner, 2026-11-09):** Home always shows only Play. Play with an unfinished game saved asks **Resume** or **New game** (`home.resume.dialog`, `home.resume.resume`, `home.resume.new`; dismissing the question stays on Home); with nothing saved it starts a new game directly. The pause button, both back arrows and the Android Back button all open the same pause screen with **Resume** (`game.pause.resume`) and **Exit** (`game.pause.quit`). Exit saves the game and leaves; it is recorded when it ends. Starting over happens only through Play, after exiting.

## Two players: Versus (R2, BUILT 2026-11-22; shared rules in `game-factory/docs/TWO_PLAYER.md`)
- **Mode.** "2 players" on the start screen, windows about 900 dp wide and up. Two wells side by side (player 1 on the left, player 2 on the right), each the normal 10 x 20 well, with its own next queue and hold box; the same piece sequence for both (one seed), so luck is equal. Power-ups, prisms, Gold Rush and coins are off; the level rises with time (level +1 every 45 seconds of play, to the cap of one player) so a game always ends.
- **Garbage.** Clearing lines sends garbage rows to the other well: 1 line none, 2 lines 1 row, 3 lines 2 rows, 4 lines 4 rows; a back-to-back quad adds 1. A garbage row is full except one hole; rows sent together share the hole's column. Garbage rises from the bottom after the sender's piece locks, pushing the stack up; the receiver sees a warning bar on the side of their well while rows are waiting (rows arrive after the receiver's next lock, so they can answer with a clear first and cancel garbage 1 for 1).
- **End.** A player whose stack cannot spawn the next piece (or is pushed over the top) is out; the other player wins. Both out in the same step is "A draw!". No score, no coins, no leaderboard.
- **Controls.** Player 1: left and right move (held keys repeat), up rotates, down soft-drops while held, **Enter hard-drops**, **1 holds**. Player 2: A and D, W, S, **F hard-drops**, **Z holds**. Space or Esc pause. Q and 3 are unused in this mode.
- **Layout.** The stage is wider (`GameFrame` `maxWidth` about 960 for this mode); a pause button and a "Player 1 / Player 2" tag with marker above each well; key hints for both players under the wells; on a window too narrow for two wells the button is not offered.
- **Pure rules.** `lib/src/game/rules/blockfall_versus.dart`: `BlockfallVersus` owns two `BlockfallGame`s fed from one seed (the same `PieceBag` order, no best-fit helper, no special blocks, no power-up stock), the garbage waiting for each player, `tick(dt)` for both with the level raised by the clock, one method per command for each player, and the winner. `BlockfallGame` gained `receiveGarbage(rows, holeColumn)` (the stack rises, the falling piece is lifted, a push over the top ends the game) and `forcedLevel`; `Well.pushGarbage`.\n- **As built.** `lib/src/ui/versus_screen.dart` (`BlockfallVersusScreen`): player 2's well on the left, player 1's on the right, hold and next beside each well, a red bar beside each well for the garbage coming (also read out), an intro with both key sets, pause (Space or Esc, Leave), results with Play again and Leave, both players' hints on windows 600 dp wide and up; no profile or services are needed. A garbage row is full except one hole, the hole column is drawn at random for each batch. A clear cancels the garbage waiting for the clearer first, then sends the rest. The choice is made inside the game: `GameScreen(offerVersus: true)` shows "1 player (Enter or 1)" or "2 players: versus (2)" over a fresh game on a window 600 dp wide and up (never when resuming a saved game or on a phone); the standalone Blockfall app and the Ember hub host opt in. Level rises every 45 s from the clock (the level floor).
- **Test IDs.** `TestIds`: `game.mode.one`, `game.mode.two`, `game.versus.screen`, `game.versus.start`, `game.p1.well`, `game.p2.well`, `game.p1.garbage`, `game.p2.garbage`, `game.p1.hold`, `game.p2.hold`, `game.winner`, `game.again`, `game.versus.leave` and the pause ids.
- **Acceptance (one named test each).** Both wells get the same pieces in the same order; each player's keys move only their well; a double sends 1 row, a triple 2, a quad 4, a back-to-back quad 5; garbage arrives after the receiver's lock with the right hole and can be cancelled by a clear; top-out ends the game with the right winner and the draw case; the level rises on the clock; power-ups and prisms are off; pause freezes both wells; the mode is not offered on a narrow window; no progress recorded.
