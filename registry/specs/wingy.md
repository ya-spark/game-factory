# Wingy - game spec

Status: DRAFT, awaiting owner approval on ya-spark/game-factory#11. When approved this is the contract for all later stages. Copy to `docs/SPEC.md` in `ya-spark/game-wingy` (repo-agent).

- id: `wingy`, display name: **Wingy**, package: `com.activemindcraft.wingy`, repo: `ya-spark/game-wingy`
- Base template: the block puzzle template (`template/flutter-game-template`). No flyer template exists. Wingy uses the template's service layer unchanged (`lib/core/`) and replaces the game itself: pure-Dart rules in `lib/game/rules/`, a new Flame view in `lib/game/flame/`, new game screen and widgets in `lib/ui/`.
- Naming rule: the name, art, characters, sounds and keywords of other one-tap flyers must not appear in code, assets, listing or keywords. No green pipes, no yellow bird, no "flappy". Obstacles are crystal spires and the hero is a moth (section 4).

## 1. Pitch
Wingy is a one-tap Android flyer. You are a small glowing moth crossing a twilight canyon of crystal spires. Tap to flap, slip through the gaps, and keep your balance between gravity and the next spire. Gaps differ in size and height, so no two runs feel alike. Original twist: **Glow Dash**. Glow orbs fill a three-pip meter; when full, a dash button lets Wingy blaze through the next two spires, shattering them for bonus points. Streaks of centered "Perfect" passes grow a Bloom bonus. Targets casual players who want a 1 to 5 minute, quick-restart, fair-but-tricky game with daily goals. Look: deep indigo-to-violet dusk gradient, softly glowing moth, translucent crystal spires, glowing score pill.

## 2. Core loop
- Second to second: tap to flap, aim for the middle of each gap, watch the next gap's height.
- Minute to minute: chain Perfect passes for a Bloom streak, grab glow orbs, fire Glow Dash at a tight cluster, beat the best score.
- Session to session: daily reward, play streak, three daily challenges, achievements, coins for streak freezes and Dash refills.

## 3. Rules and scoring (pure Dart, `lib/game/rules/`)
No Flutter, Flame or Android imports in this folder. Randomness comes from an injected seedable `Random`; time comes only from injected fixed-step deltas, so runs are deterministic in tests. Simulation uses a fixed step of 1/120 s. Units are logical world units (u); the world is 360 u wide and 640 u tall and the view scales uniformly to fit.

**World.** Ceiling at y=0, ground at y=584 (a 56 u strip). Touching the ground or ceiling ends the run. Wingy's hitbox is a circle of radius 14 u at x=100 (fixed; the world scrolls).

**Physics.** Gravity 1500 u/s^2. Flap sets vertical velocity to -430 u/s (up is negative), it does not add. Terminal fall speed 700 u/s. Flaps are accepted at any time (no cooldown). Wingy tilts visually from velocity only.

**Scroll speed.** Starts at 140 u/s and rises by 2 u/s per spire passed, capped at 220 u/s.

**Spires.** Spires come in pairs (top and bottom) with a gap between. Spacing between consecutive pairs is 220 u (horizontal, center to center). Spire width 56 u. First pair appears 360 u after start so the player can settle.

**Gap generation (varied size and height).**
- Base gap height starts at 210 u and shrinks by 1.5 u per spire passed, down to a floor of 150 u.
- Each gap's actual height = base + a random offset in [-20, +30] u, never below 150 u.
- Gap center y is random within [margin, 584 - margin] where margin = 40 u + gapHeight/2, so the gap always fits above the ground and below the ceiling.
- Reachability: the vertical distance between consecutive gap centers is limited to 200 u (clamped). The generator never produces an unwinnable pair; a unit test simulates an ideal tap pattern across 500 gaps for several seeds.
- Every 7th pair is a "wide breather": gap height base + 60 u. Every 10th pair has a moving gap (see below), starting from score 20.
- **Drifting gap** (score >= 20, one in ten pairs): the gap center oscillates +/-30 u with a 2.0 s period (sine). It is visibly marked with a shimmer on the spire tips.

**Collision.** Circle vs. spire rectangles and world bounds. A hit ends the run unless Dash is active.

**Glow orbs.** An orb (radius 10 u) appears in the middle of about every 4th gap (deterministic: pairs 3, 7, 11, ... plus a 25% chance on others, from the injected Random, never two orbs in adjacent pairs). Touching an orb: +1 point, +1 meter pip (max 3), +1 coin (coin cap per run 40).

**Scoring.**
- Pass a spire pair (Wingy's x moves past the spire's trailing edge): +1.
- Perfect pass: Wingy's center is within the middle 30% of the gap height when passing: the pass is worth +2 instead of +1 and extends the Perfect streak by 1. A non-perfect pass resets the streak to 0.
- Bloom bonus: when the Perfect streak is 3 or more, each Perfect pass adds an extra `min(streak - 2, 5)` points (streak 3 gives +1, streak 4 +2, ... streak 7 or more +5).
- Orb: +1.
- Dash-shattered spire pair: a flat +3 for the pair (counts as passed; no Perfect or Bloom evaluation, streak is kept).
- Score is the sum. Best score is stored locally.
- Medals at run end: Bronze 10, Silver 25, Gold 50, Prism 100.

**Glow Dash (the original mechanic).**
- Meter: 0 to 3 pips from orbs. Meter resets to 0 at run start (a coin refill can start a run with a full meter, section 6).
- With 3 pips, the Dash button (`game.dash`) lights up. Tapping it starts a Dash: duration 1.2 s, meter set to 0.
- During Dash: Wingy is immune to spires (not the ground or ceiling), vertical velocity is damped to 0 and held at the current altitude (clamped into [40, 544]), scroll speed is multiplied by 1.8, and each spire pair crossed is shattered (+3, section above). Roughly two pairs are crossed per dash at base speed.
- After Dash ends, a 0.4 s grace of spire immunity keeps the player from dying instantly on exit. Gravity resumes with vertical velocity 0.
- Only one Dash at a time; the button is disabled during Dash and while the meter is below 3. Pause stops the timers.

**Run states.** `ready` (waiting for first tap; Wingy hovers), `playing`, `dead`. First tap flaps and starts the run. On death the run ends after a short 0.6 s fall/shake; then the game over dialog.

**Revive.** Once per run, via rewarded ad (section 6): Wingy returns to the vertical center of the nearest upcoming gap, all spires within 300 u ahead are removed, 2.0 s of invulnerability with flicker; score, streak and meter are unchanged. A second death shows no revive.

## 4. Content
- **Hero:** Wingy, a round-bodied moth with two large soft wings and a glowing abdomen; wings flap on tap (3 frames drawn procedurally).
- **World:** a twilight canyon. Parallax layers: far violet ridge, mid mist band, near silhouettes of floating rocks; stars that twinkle slowly. Spires are translucent crystal columns (cyan-to-magenta tint, one stylized facet highlight), with a flat glowing tip. Ground is dark mossy rock with tiny glowing mushrooms. Colors shift slowly through three palettes: dusk (0 to 24), aurora (25 to 59), midnight (60+). Palette change is cosmetic only.
- **Difficulty curve:** speed 140 to 220 u/s, gap 210 to 150 u, drifting gaps from score 20. No level cap.
- **Modes in v1:** one mode (Endless). 

## 5. Retention (all four ON; `app.config.yaml` `retention:` all true; reuse `lib/core/retention`)
- **Daily reward:** 7-day cycle: day 1 30 coins, day 2 40, day 3 50, day 4 1x Dash Refill, day 5 70 coins, day 6 1x Dash Refill, day 7 150 coins plus 1 streak freeze. Missing a day resets to day 1 unless a streak freeze covers it. A Dash Refill is a stock item consumed to start a run with a full meter.
- **Streaks with freeze:** consecutive daily-play streak; one freeze (earned at day 7 or bought for 100 coins) covers one missed day automatically.
- **Three daily challenges** (picked per day from the pool; new `ChallengeKind` templates for Wingy). Reward 25 to 60 coins each:
  1. Score N points in one run (15/30/50).
  2. Pass N spire pairs in total today (40/80/150).
  3. Make N Perfect passes in a row in one run (3/5/8).
  4. Collect N glow orbs in total today (6/12/20).
  5. Use Glow Dash N times (1/2/3).
  6. Shatter N spire pairs with Dash in total today (2/4/6).
  7. Reach a Bloom bonus of +3 or more (once/twice).
  8. Play N runs (3/5).
- **Achievements** (local; mirrored to Play Games when signed in): First Flight (score 1), Ten Gaps (score 10 in a run), Gold Wings (score 50 in a run), Prism Wings (score 100 in a run), Perfectionist (7 Perfect passes in a row), Orb Collector (50 orbs total), Dash Master (shatter 20 pairs with Dash total), Night Owl (reach midnight palette, score 60), Regular (50 runs total), Daily Devotee (7-day streak).
- Notifications (reminder for the daily reward) via `NotificationService`, opt-in, toggle in Settings.

## 6. Monetization
- **Banner:** Home (menu) only. Never during a run or on the game over dialog.
- **Interstitial:** after game over, when pressing Retry or Home on the game over dialog, honoring the caps (`interstitial_min_interval_seconds: 90`, `interstitial_every_n_game_overs: 2`, `max_interstitials_per_session: 6`, `no_interstitial_first_seconds: 60`). Never mid-run. Not shown if `remove_ads` is owned. Because runs are short, the every-2nd-game-over cap and the 90 s interval are what keep it unobtrusive.
- **Rewarded** (always optional; stays available with `remove_ads`): (a) revive once per run, (b) free Dash Refill (start the next run with a full meter), max 3 ad refills per day.
- **Coins:** earned from orbs (cap 40 per run), 1 coin per 5 points at run end, daily reward and challenges. Spent on: Dash Refill 40 coins, streak freeze 100 coins.
- **IAP** (`products.yaml`, ids unchanged): `remove_ads` (non-consumable, removes banner and interstitials), `coins_500` (consumable, 500 coins). Prices set in Play Console, not in code.
- Test ad IDs only in debug and in the template; release IDs only from the `app.config.yaml` release block. Everything goes through `AdService` and `PurchaseService`; nothing new in vendor SDKs.

## 7. Screens (test IDs added to `lib/ui/test_ids.dart`)
- **Home:** Play, Daily reward, Challenges, Shop, Settings, coins, best score, streak, banner. (Keep existing `home.*` IDs.)
- **Game** (portrait): score pill top center, best score small under it, Bloom streak chip beside the score when active, orb meter (three pips) top-left, Dash button bottom-right, pause top-right. Tap anywhere on the play field flaps. IDs: `game.widget`, `game.field` (tap target), `game.score`, `game.best`, `game.streak`, `game.meter` (Semantics value = pips 0..3), `game.dash`, `game.dash.state` (Semantics: off/ready/active), `game.pause`, `game.back`, `game.ready` (tap-to-start hint). Game over: `game.over.dialog`, `game.over.score`, `game.over.best`, `game.over.medal`, `game.over.revive`, `game.over.refill`, `game.over.retry`, `game.over.home`. Pause: `game.pause.resume`, `game.pause.quit`. Refill: `game.refill.coins`, `game.refill.ad`.
- **Daily reward, Challenges/Achievements, Shop, Settings:** existing IDs kept. Settings adds `settings.haptics`, `settings.reduceMotion` (disables screen shake and parallax).
- **Input:** a tap anywhere on `game.field` (or the on-screen center of it) flaps. Dash is the only other control. Taps on the pause button and Dash button never flap. Pausing or app background pauses the run and the first tap after resume is swallowed with a 3-2-1 countdown.
- **Bot / testing hooks:** `--dart-define=WINGY_SEED=<int>` fixes the gap generator; a debug-only `game.autopilot` toggle is not shipped. Integration tests drive taps by key (`game.field`) and read score, streak, meter and dash state through Semantics values of the IDs above.

## 8. Art and audio
- Style: drawn in code (Canvas/Flame shapes and gradients): moth (body ellipse, two wing shapes with a flap animation, glow), crystal spires (polygon with facet highlight), orbs (radial glow), parallax layers, mushrooms, stars. **No particle system in v1**; shatter on Dash is a short scale-fade of spire shards (6 fixed polygon pieces, tweened), pass feedback is a "+1/+2" text that floats up and fades.
- Assets drawn in code where possible. App icon, feature graphic and screenshots by asset-agent. Sounds: flap, pass, perfect (rising chime per streak step), orb, dash whoosh, shatter, hit, game over, button. All sounds CC0 or own-made; every asset is in `assets/LICENSES.md` with source and license.
- Haptics: light tick on perfect pass, medium on hit (toggle in Settings). Screen shake 0.25 s on hit unless `reduceMotion`.

## 9. Play Games
- Leaderboard: `leaderboard_high_score` (best score). ID placeholder in `app.config.yaml` until the user creates it.
- Achievements: the 10 in section 5, ids `ach_first_flight`, `ach_ten_gaps`, `ach_gold_wings`, `ach_prism_wings`, `ach_perfectionist`, `ach_orb_collector`, `ach_dash_master`, `ach_night_owl`, `ach_regular`, `ach_daily_devotee`. Created in Play Console by the user; the game works fully offline and unsigned.

## 10. Store listing
- Title: Wingy: One-Tap Moth Flyer (max 30 chars)
- Short (80 chars): Tap to flap through crystal gaps. Chain perfect passes and blaze with Glow Dash.
- Full description: one-tap flying through a twilight canyon, gaps that change size and height, Perfect streaks and Bloom bonus, the Glow Dash twist, daily rewards, streaks, daily challenges, achievements, plays offline, no account needed, ads removable with a one-time purchase. No mention of other games' names.
- Category: Games > Arcade. Content rating: Everyone, contains ads, optional in-app purchases. Keywords: one tap game, moth, endless flyer, arcade, offline game (never names of other flyers).
- Privacy: AdMob (ad ID), Play Billing; no account, no backend. Data safety form to match.

## 11. Out of scope (v1)
Multiplayer, online battles, Firebase or any backend, accounts, particle systems, multiple characters or skins shop, themed worlds beyond the three cosmetic palettes, extra modes (daily seed run, zen), iOS/web builds (kept possible via pure-Dart rules), cloud save beyond Play Games.

## 12. Acceptance criteria (testable)
Rules (VM unit tests, `test/rules/`, fixed-step simulation with seeded Random):
1. Gravity: with no taps, Wingy's vy after 0.1 s is 150 u/s; falling speed never exceeds 700 u/s.
2. A flap sets vy to exactly -430 regardless of the prior vy; two flaps in a row do not stack.
3. Hitting the ground (y >= 584 - 14) or ceiling (y <= 14) ends the run.
4. Passing the first spire pair scores 1 (non-centered) and 2 (centered, within the middle 30% of the gap).
5. Perfect streak: 3 consecutive Perfect passes score 2, 2, and 2+1; the 4th adds +2; Bloom bonus is capped at +5; a non-Perfect pass resets the streak to 0.
6. Gap generation: for 20 seeds and 500 pairs, every gap height is >= 150 u, every gap fits within [40, 584-40], consecutive center delta <= 200 u, and every 7th pair is at least base+60 u. Gap height shrinks by 1.5 u per pair from 210 down to the floor 150 after about 40 pairs.
7. Reachability: a reference autopilot (tap when vy-projected position falls below the next gap center) survives 500 pairs for each of 20 seeds.
8. Scroll speed is 140 u/s at start, 142 after one pass, and 220 at cap.
9. Orbs: touching an orb gives +1 score, +1 meter pip (max 3) and +1 coin; run coin cap is 40; no two orbs in adjacent pairs.
10. Glow Dash: the meter at 3 enables Dash; using it sets the meter to 0, lasts 1.2 s, ignores spire collisions, still dies on the ground or ceiling, and each pair crossed during Dash adds exactly 3 without changing the Perfect streak; 0.4 s of grace after Dash; a second Dash cannot start during the first; pausing stops the timers.
11. Drifting gaps appear only at score >= 20, about one in ten pairs, with +/-30 u and 2.0 s period.
12. Revive is available exactly once per run; after it, spires within 300 u ahead are removed, invulnerability lasts 2.0 s, score and streak are unchanged; the second death shows no revive.
13. Same seed gives identical gap sequence and score for the same tap trace.

App-level (widget/integration tests via test IDs):
14. Home shows the banner (`home` only); `game.banner` does not exist on the game screen.
15. Tapping `game.ready` / `game.field` starts the run and flaps (verified via Semantics values); the Dash button is off with fewer than 3 pips and ready at 3; tapping it sets `game.dash.state` to active.
16. Game over dialog shows `game.over.revive` once; interstitial obeys the caps (AdFrequency tests with fake clock); Dash Refill with 0 stock opens the refill sheet, `game.refill.coins` deducts 40 coins, `game.refill.ad` grants a refill via a fake AdService, max 3 ad refills per day.
17. Daily reward cycles 7 days with the rewards in section 5; streak freeze covers one missed day; 3 daily challenges are generated per day and claimable; each achievement unlocks on its condition (unit tests with fake clock).
18. Shop lists `remove_ads` and `coins_500`; `remove_ads` removes banner and interstitial but keeps rewarded; app background pauses the run.
19. `flutter analyze`, `dart format`, `flutter test`, `scripts/ad_safety_check.sh` pass; `assets/LICENSES.md` lists every asset; no references to other flyer games' names in the repo outside `docs/SPEC.md`.

## What the generator and coder must change versus the block puzzle template
- `scripts/new_game.py` should generate `ya-spark/game-wingy` with id `wingy`, package `com.activemindcraft.wingy`, display name Wingy, `BLOCKFALL`-style define renamed to `WINGY_SEED`, and the `app.config.yaml` `retention:` block all true.
- **Reused unchanged from `lib/core/`:** ads (`AdService`, `AdFrequency`, AdMob impl), purchase (`PurchaseService`, products.yaml), save (`SaveService`), identity, leaderboard, notifications, analytics (no-op), remote_config, profile, clock, config, retention (`daily_reward`, `streaks`, `achievements`, `daily_challenges`, with Wingy templates and achievement definitions added).
- **New:** `lib/game/rules/` (world, physics, spire/gap generator, orbs, scoring, Perfect/Bloom streak, Glow Dash, revive, game state machine), `lib/game/flame/` (parallax, moth, spires, orbs, input), `lib/ui/game_screen.dart` and widgets (HUD, meter, Dash button), extended `test_ids.dart`, new challenge templates and achievements, Dash Refill stock and streak freeze counts in save, sounds and icon.
- **Replaced:** the block puzzle rules and Flame components (grid, tray pieces, hold/next UI).

## Third-party packages
None new. Existing template packages only (Flutter, Flame, `google_mobile_ads`, `in_app_purchase`, `flutter_local_notifications`, the Play Games plugin and the audio package already in the template). Any addition needs a recorded reason from the coder stage.
