# Wingy (game package `game_wingy`)

Status: BUILT. The game lives once in `game-factory/games/wingy/` (SH1, owner 2026-11-21); the standalone Wingy app and Mind Presto are containers that show it and bring their own shop, profile, ads, theme and release setup. This file is the only copy of the game's behaviour; it was moved from the standalone app's `docs/SPEC.md`, so it also holds sections about the standalone app (shop, monetisation, store). Where a section is about the container, the container follows it; a hub follows its own spec for those parts.

The game asks its container only through `WingyServices` (`lib/src/host/`).

---

# Wingy - game spec

Status: APPROVED by the owner on ya-spark/game-factory#11 (PR #13).

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
- During Dash: Wingy is immune to spires (not the ground or ceiling), vertical velocity is 0 and Wingy eases toward the band y 200..400 when the dash starts outside it (at most 250 u/s, smooth; the clamp into [40, 544] stays as a safety bound), so a dash never ends near the ground; Wingy pulses (scale and glow) for the last 0.3 s of the dash as the "tap now" cue (`dashEnding`, drawn in the painter, no assets or particles); scroll speed is multiplied by 1.8, and each spire pair crossed is shattered (+3, section above). Roughly two pairs are crossed per dash at base speed.
- After Dash ends, a 0.4 s grace of spire immunity keeps the player from dying instantly on exit. Then a 0.5 s recovery float starts with vertical velocity 0: gravity x0.25 and fall speed capped at 150 u/s (about 45 u of drift). Any tap ends the float at once with a normal flap (-430). Ground and ceiling stay deadly; without a tap, normal gravity resumes after the float. Constants are in `world.dart`.
- Only one Dash at a time; the button is disabled during Dash and while the meter is below 3. Pause stops the timers, including the float.

**Run states.** `ready` (waiting for first tap; Wingy hovers), `playing`, `dead`. First tap flaps and starts the run. On death the run ends after a short 0.6 s fall/shake; then the game over dialog.

**Revive (player-facing name: Continue).** Up to three times per run, each via a rewarded ad (section 6): Wingy returns to the vertical center of the nearest upcoming gap, all spires within 300 u ahead are removed, 2.0 s of invulnerability with flicker; score, streak and meter are unchanged. After the third revive, the next death shows no Continue button.

**Game over layout.** Wingy uses the shared panel (same file as the other games): The card is **vertically centred** in the safe area (`Alignment.center`, 16 dp side padding, 8 dp above and below; owner, 2026-11-06), after the slide-up has finished. Top to bottom: Share icon (`game.over.share`, top left); title, score, best, medal; Play again (`game.over.retry`) and Home (`game.over.home`) side by side; Dash Refill (`game.over.refill`, small, in the panel's extra row, `extraButton`); `Continue · N left` (`game.over.revive`) last, gold primary, font 22, padding 28x16, hidden when no continue is left. Play again is secondary (font 15, padding 18x9) while Continue is offered; when Continue is unavailable it takes the large gold style (font 22, padding 28x16). The label is the constant `continueLabel` in `lib/ui/game_screen.dart`. Test IDs are unchanged.

## 4. Content
- **Hero:** Wingy, a round-bodied moth with two large soft wings and a glowing abdomen; wings flap on tap (3 frames drawn procedurally).
- **World:** a twilight canyon. Parallax layers: far violet ridge, mid mist band, near silhouettes of floating rocks; stars that twinkle slowly. Spires are translucent crystal columns (cyan-to-magenta tint, one stylized facet highlight), with a flat glowing tip. Ground is dark mossy rock with tiny glowing mushrooms. Six palettes rotate (cosmetic only), in this order, background gradient top / middle / bottom:

  | # | Palette | Colours |
  |---|---------|---------|
  | 0 | dusk | `0xFF1B1446`, `0xFF2B4FB0`, `0xFF2FA8C9` |
  | 1 | aurora | `0xFF0B2B3B`, `0xFF1C6A6E`, `0xFF3FBF9A` |
  | 2 | midnight | `0xFF05071A`, `0xFF111A4A`, `0xFF2B1B63` |
  | 3 | sunrise (rose-gold) | `0xFF3B1740`, `0xFFB5517A`, `0xFFF2A65A` |
  | 4 | emerald (deep green glow) | `0xFF06261F`, `0xFF0F6B4F`, `0xFF52D6A0` |
  | 5 | ember (red-orange dusk) | `0xFF2A0E12`, `0xFF8A2B26`, `0xFFF08A3C` |

  The palette changes every 20 points: `palette = order[(start + score ~/ 20) % 6]`. `start` is the saved profile value `paletteStart` (0 on a fresh install). When a run ends, `start` becomes the index after the palette in use at game over (`nextPaletteStart`), so the next run begins with a new look. A palette change cross-fades the background gradient over 1.5 s (0.3 s with Reduce motion on); a new run snaps to its start palette with no fade (`PaletteFade` in `lib/game/rules/world.dart`).
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
- **Achievements** (local; mirrored to Play Games when signed in): First Flight (score 1), Ten Gaps (score 10 in a run), Gold Wings (score 50 in a run), Prism Wings (score 100 in a run), Perfectionist (7 Perfect passes in a row), Orb Collector (50 orbs total), Dash Master (shatter 20 pairs with Dash total), Night Owl (score 60 in a run; no longer tied to a palette), Regular (50 runs total), Daily Devotee (7-day streak).
- Notifications (reminder for the daily reward) via `NotificationService`, opt-in, toggle in Settings.

### Sharing
- `ShareService` (`lib/core/share/`): `shareScore`, `shareAchievement`, `shareApp`. `SystemShareService` opens the Android share sheet through `share_plus` (imported only in `system_share_service.dart`); `FakeShareService` records texts for tests. No Facebook or Instagram SDK: the player picks the app in the system sheet. The app sends nothing itself.
- **Share card** (`lib/ui/share_card.dart`): drawn in code, rendered to PNG through a `RepaintBoundary` (360x450 logical, 3x): game name, big score (or achievement title), best score, the current background palette and the medal name. No player name, no id, no store text.
- **Texts:** score: `This is my high score in {game}: {score}. Can you beat it?`; achievement: `I unlocked "{title}" in {game}! Can you beat it?`. The link follows on a new line. The game name always appears. Share app (Settings) sends the score text with the saved best score (`Try {game}!` while there is no best yet) and the same link. The share picture stays free of names, ids and store text.
- **Config:** `app.config.yaml` `share: link_mode: internal_test | store | off` (default `internal_test`) and `internal_test_url`. `internal_test` adds `internal_test_url` (`https://play.google.com/apps/internaltest/4701195701671503239`); `store` adds `https://play.google.com/store/apps/details?id=<package_name>`; `off` adds no link and hides Share app. `internal_test` with an empty URL behaves like `off`. Loader: `ShareConfig`, `AppConfig.shareLink` (null = no link). The owner switches to `store` when the game is public. A share still sends nothing from the app: the link is only text in the system share sheet.
- **Buttons:** game over icon button `game.over.share` at the top left of the panel (see Game over screen); a share icon `achievement.share.<id>` on each unlocked achievement; Settings "Share app" `settings.shareApp`, visible unless the mode is `off` (or the URL is empty in `internal_test`).

### Game over screen
- A panel `game.over.panel`: rounded card (radius 24), solid deep indigo `#1B1233` at 90 % opacity, 1 px light border, soft shadow, so text and buttons never mix with the game background. Text and buttons keep at least 4.5:1 contrast against it (white on the panel; dark brown on the gold Continue; white on the darkened purple-pink secondary fill).
- The panel (`lib/ui/game_over_panel.dart`) is the same file in every game and the template (Blockfall is the reference); game-specific wording lives only in the callers. It has one optional extra row, `extraButton`, between the Play again / Home row and Continue (14 dp gaps): Wingy uses it for Dash Refill, the other games leave it empty. The card is **vertically centred** in the safe area (`Alignment.center`, 16 dp side padding, 8 dp above and below; owner, 2026-11-06), after the slide-up has finished.
- Top to bottom: Share icon button (`game.over.share`) at the top left; title, score (`game.over.score`), best (`game.over.best`), medal (`game.over.medal`); Play again (`game.over.retry`) and Home (`game.over.home`) side by side; Dash Refill (`game.over.refill`); Continue (`game.over.revive`, large and gold, last; hidden when no revive is left).
- **See how you failed:** an eye button `game.over.view` at the top right of the panel. Tapping it fades the panel out over 0.2 s so the whole final board shows (the frozen crash frame: moth, spires, background). A tap anywhere, or the eye button (which stays visible), brings the panel back. Nothing else changes while it is hidden: score and rewards are already final.

### Tips
- `lib/game/tips.dart`: 15 tips from this spec's rules, kind, at most 80 characters, unique, no mention of other games (unit-tested). `TipService` (`lib/core/tips/`, pure Dart) deals them from a shuffled bag (never the same tip twice in a row) and gives a tip of the day from the day index.
- The only place a tip appears is a dialog on the home page (`lib/ui/tip_dialog.dart`, `tip.home`): "Tip of the day", the tip, a "Don't show tips again" checkbox (`tip.dontShow`) and Close (`tip.close`). It opens once per day when the home page is first shown (saved `tipHomeDay`, set when it opens, so it does not return the same day however it was dismissed). Close alone hides it; ticking the box and closing turns tips off everywhere. Settings "Show tips" (`settings.tips`, on by default) is the same saved profile value (`tipsOff`). With tips off the dialog never opens.
- The dialog opens only while the home page is the page on top and no run is on screen (`Services.inRun`, set by the game screen), checked again after the save that marks the tip as shown. A blocked tip is never queued; the next time Home is shown it is tried again (still once per day).
- No tip is ever shown in a game or on the game over screen: no game over tip, no pause tip, no first-time special-block hints. The home page layout has no tip card.

## 6. Monetization
- **Banner:** Home (menu) only. Never during a run or on the game over dialog.
- **Interstitial:** after game over, when pressing Retry or Home on the game over dialog, honoring the caps (`interstitial_min_interval_seconds: 180`, `interstitial_every_n_game_overs: 2`, `max_interstitials_per_session: 6`, `no_interstitial_first_seconds: 60`). Never mid-run. Not shown if `remove_ads_all` is owned. Because runs are short, the every-2nd-game-over cap and the 180 s interval are what keep it unobtrusive.
- **Rewarded** (always optional): (a) Continue up to three times per run, (b) free Dash Refill (start the next run with a full meter), max 3 ad refills per day.
- **Remove Ads removes all ads.** With `remove_ads_all` owned there is no banner, no interstitial and no rewarded ad. Everything that used a rewarded ad is granted instantly within its normal limits (Continue up to 3 per run, free Dash Refill max 3 per day). A saved `remove_ads` entitlement (retired id) counts as owned, and a restore of the retired id is treated as `remove_ads_all`.
- **Coins:** earned from orbs (cap 40 per run), 1 coin per 5 points at run end, daily reward and challenges. Spent on: Dash Refill 40 coins, streak freeze 100 coins, flyer skins (see Flyer skins). Spending coins needs no parent gate.
- **Coin icon:** `CoinIcon` (`lib/ui/widgets.dart`), drawn in code: gold disc with a darker rim, inner ring, soft shine and "MC" in bold dark gold; sizes via a parameter; Semantics label "coins". It replaces every use of the old coin icon (home chip, daily reward, shop, game screen). Store prices such as "$2.99" stay as the real localised prices. `StatChip` takes a `leading` widget instead of an icon.
- **IAP** (`products.yaml`): `remove_ads_all` (non-consumable, "Remove Ads", "Removes all ads."; replaces the retired id `remove_ads`), `coins_500` ("Coin Pack", 500), `coins_1500` ("Big Coin Pack", 1500), `coins_4000` ("Coin Chest", 4000), the coin ones consumable. Prices set in Play Console, not in code.
- **Shop order:** Remove Ads, the coin packs in ascending size, a "Wings" section (flyer skins), then Dash Refill and Streak freeze. Products the store does not return stay hidden, or "Store unavailable" shows. Wording never pressures children.
- **Parent gate** (`lib/ui/parent_gate.dart`, logic in `lib/core/parent_gate.dart`): before any real-money purchase (Remove Ads and coin packs; not Restore, not spending coins) a dialog "Ask a grown-up" asks a typed multiplication such as `7 x 8` with factors 6 to 9, new numbers each time. A wrong answer shows a new question; 3 wrong answers in a row close the dialog and lock purchases for 60 s (the dialog then says so). A correct answer starts the normal purchase. IDs `gate.dialog`, `gate.answer`, `gate.submit`, `gate.cancel`.
- **Continue (game over):** the large gold button. With Remove Ads owned it continues at once (no ad, no coins). Otherwise pressing it starts the rewarded ad directly (no choice sheet; owner, 2026-11-06). A continue is granted only when the ad reports the reward as earned; if the ad fails to load, is not ready or is closed early, nothing is granted, the panel stays open and shows "No ad available right now. Try again in a moment.". Never a fallback to coins or a free continue; coins cannot pay for Continue. Limit: 3 per run, the button is hidden after that.
- **Flyer skins** (cosmetic only; hitbox and physics identical; `lib/game/rules/` does not know about skins; data in `lib/core/skins/flyer_skins.dart`, drawn by parameterising `drawMoth` in `lib/game/flame/wingy_painter.dart`): Moth (free, default), Butterfly (300 coins), Firefly (500), Dragonfly (800), Star Sprite (1,200). All insect or spirit shapes, original, no birds. Shop "Wings": a card per skin (`shop.skin.<id>`, ids `moth`, `butterfly`, `firefly`, `dragonfly`, `star_sprite`) with a small animated preview (still with Reduce motion), the price with the coin icon, and "Owned" / "Equipped". Buying (`shop.skin.<id>.buy`) uses coins, no parent gate, refuses when short of coins, and equips the new skin; tapping an owned skin (`shop.skin.<id>.equip`) equips it. Saved in the profile as `ownedSkins` and `equippedSkin` (save version 4). The home scene and the game use the equipped skin.
- Test ad IDs only in debug and in the template; release IDs only from the `app.config.yaml` release block. Everything goes through `AdService` and `PurchaseService`; nothing new in vendor SDKs.

## 7. Screens (test IDs added to `lib/ui/test_ids.dart`)
- **Home:** Play, Daily reward, Challenges, Shop, Settings, coins, best score, streak, banner. (Keep existing `home.*` IDs.) The page background is the gradient of the palette `order[paletteStart]`; other menu screens keep the plain gradient. Above the title is the animated hero scene `home.hero` (`lib/ui/home_hero.dart`), a 160 dp band drawn in code with the game's own `WingyPainter` (no assets): the moth flies left to right with a gentle flap and bob; crystal spires and glow orbs scroll right to left in three parallax layers; every 11 s a soft Glow Dash trail follows the moth for 1.4 s. One `CustomPainter`, one ticker, at most 12 moving objects (moth, trail, 6 spires, 3 orbs). The ticker stops while the home route is covered or the app is in the background; with Reduce motion on it shows one still frame. Decorative only: no gestures, excluded from semantics.
- **Game** (portrait): score pill top center, best score small under it, Bloom streak chip beside the score when active, orb meter (three pips) top-left, Dash button bottom-right, pause top-right. Tap anywhere on the play field flaps. IDs: `game.widget`, `game.field` (tap target), `game.score`, `game.best`, `game.streak`, `game.meter` (Semantics value = pips 0..3), `game.dash`, `game.dash.state` (Semantics: off/ready/active), `game.pause`, `game.back`, `game.ready` (tap-to-start hint). Game over: `game.over.dialog`, `game.over.score`, `game.over.best`, `game.over.medal`, `game.over.revive`, `game.over.refill`, `game.over.retry`, `game.over.home`, `game.over.share`, `game.over.panel`, `game.over.view`. Pause: `game.pause.resume`, `game.pause.quit`. Refill: `game.refill.coins`, `game.refill.ad`.
- **Daily reward, Challenges/Achievements, Shop, Settings:** existing IDs kept. Settings adds `settings.haptics`, `settings.reduceMotion` (disables screen shake and parallax), `settings.tips`, `settings.shareApp`. Game over adds `game.over.share`, `game.over.panel`, `game.over.view`; achievements add `achievement.share.<id>`; the home tip dialog uses `tip.home`, `tip.close`, `tip.dontShow` (see Sharing, Game over screen and Tips in section 5).
- **Input:** a tap anywhere on `game.field` (or the on-screen center of it) flaps. Dash is the only other control. Taps on the pause button and Dash button never flap. Pausing or app background pauses the run and the first tap after resume is swallowed with a 3-2-1 countdown.
- **Bot / testing hooks:** `--dart-define=WINGY_SEED=<int>` fixes the gap generator; a debug-only `game.autopilot` toggle is not shipped. Integration tests drive taps by key (`game.field`) and read score, streak, meter and dash state through Semantics values of the IDs above.

**More games** (`lib/ui/more_games_screen.dart`, `moreGames.screen`, `moreGames.back`)
- Title "More games", header "More from Active Mind Craft". One card per listed game (`moreGames.card.<id>`): a 48 dp rounded tile (12 dp radius) drawn in code (no asset), the name, the tagline, and "Get it" (`moreGames.get.<id>`, status `live`) or the text "Coming soon" (`coming_soon`, no button). "Get it" asks the parent gate first (the same "Ask a grown-up" dialog and lockout as purchases), then `ExternalLinkService.openStorePage(package)` (`market://details?id=<package>`, fallback `https://play.google.com/store/apps/details?id=<package>`). Cancelling the gate opens nothing.
- Never coins, items or any reward for opening or installing another game (Play bans incentivised installs). Not shown on game over, Continue or in play, and never in place of an interstitial.
- Entry points: a "More games" row in Settings (`settings.moreGames`, `Icons.apps`, below the tips switch) and a round icon in the Home top-right icon row (`home.moreGames`, see "Behaviour and feel"). No other entry points.
- The list is bundled: `more_games:` in `app.config.yaml` (`id`, `package_name`, `name`, `tagline`, `status` = `live` | `coming_soon` | `hidden`), loaded into `AppConfig.moreGames`; `AppConfig.visibleMoreGames` drops `hidden` entries and this game's own `package_name`, so the same list is copied to every game. With nothing to show, the Settings row and the Home icon are not shown. No network call, so the privacy policy and Data safety do not change. All entries start `hidden`; the owner flips an entry to `live` when that game is public. Taglines are under 60 characters, name no other studio and use no pressure wording.
- `ExternalLinkService` (`lib/core/links/`): `openStorePage(packageName)`; `UrlExternalLinkService` is the only file that imports `url_launcher`; `FakeExternalLinkService` records the packages in tests. The Android manifest `<queries>` lists the `market` and `https` VIEW intents.

## 8. Art and audio
- Style: drawn in code (Canvas/Flame shapes and gradients): moth (body ellipse, two wing shapes with a flap animation, glow), crystal spires (polygon with facet highlight), orbs (radial glow), parallax layers, mushrooms, stars. **No particle system in v1**; shatter on Dash is a short scale-fade of spire shards (6 fixed polygon pieces, tweened), pass feedback is a "+1/+2" text that floats up and fades.
- Assets drawn in code where possible. App icon, feature graphic and screenshots by asset-agent. Sounds: flap, pass, perfect (rising chime per streak step), orb, dash whoosh, shatter, hit, game over, button. All sounds CC0 or own-made; every asset is in `assets/LICENSES.md` with source and license.
- **Voice priority (never cut off):** High = `game_over`, `better_than_the_best`. Normal = `smashed_it`, `revived`, `nice`, `great`, `awesome`, `excellent`, `fantastic`, `incredible`, `unbelievable`, `well_done`, `you_did_it`. Low = `get_ready`, `go`, `careful`. A playing clip is never stopped. A high line arriving while a clip plays waits and plays after it (the newest waiting high line wins; a waiting high line is never replaced by a normal/low one). A normal or low line arriving while a clip plays is played after it only if the clip ends within 1 s, otherwise dropped. Implemented in `lib/core/audio/voice_arbiter.dart`.
- **Audio focus:** effect, voice and ambience players use the Android audio context focus `mixWithOthers`, so none takes audio focus from the others.
- **Background sound:** files in `assets/ambience/` (`night`, `bird`, `morning_birds`, `heartbeat`), looped at volume 0.25, ducked to 0.1 while a voice clip plays (voice 1.0, effects 0.7), all scaled by the master volume. Starts when the game screen opens, pauses on Pause and when the app goes to the background (resumes on Resume / app resume), stops when the game screen is left, keeps playing under the game over dialog. Default track: Night.
- **Sound settings (Settings, saved in the profile, applied without restart):** `Sound` switch (`settings.sound`, master mute, on top); `Master volume` slider 0-100 %, default 100 % (`settings.volume`); `Background sound` picker Off / Night (default) / Bird / Morning birds / Heartbeat (`settings.ambience`), with a play/stop preview button beside the picker (`settings.ambience.preview`) that loops the highlighted track until stopped; the picker text is ink-coloured on the white panel; a saved Before sunrise falls back to Night; `Voice` switch, default on (`settings.voice`); `Effects` switch, default on (`settings.sfx`).
- **Hand (Settings, `settings.hand`, saved):** Right (default) or Left. Left mirrors the in-game buttons: the Dash button moves from bottom right to bottom left, and the pause button and the Back + orb meter column swap top corners. Play field, score and game over screen are unchanged.
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
Multiplayer, online battles, Firebase or any backend, accounts, particle systems, multiple characters (cosmetic flyer skins are in), themed worlds beyond the six cosmetic palettes, extra modes (daily seed run, zen), iOS/web builds (kept possible via pure-Dart rules), cloud save beyond Play Games.

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
10. Glow Dash: the meter at 3 enables Dash; using it sets the meter to 0, lasts 1.2 s, ignores spire collisions, still dies on the ground or ceiling, and each pair crossed during Dash adds exactly 3 without changing the Perfect streak; 0.4 s of grace after Dash; a Dash started at y 544 ends with Wingy still alive after 0.5 s without a tap, a tap during the 0.5 s recovery float flaps normally (-430) and ends the float, and the ground still kills once the float is over; a Dash started outside y 200..400 ends inside that band; `dashEnding` is true only in the last 0.3 s of the Dash; a second Dash cannot start during the first; pausing stops the timers.
11. Drifting gaps appear only at score >= 20, about one in ten pairs, with +/-30 u and 2.0 s period.
12. Revive is available up to three times per run; after it, spires within 300 u ahead are removed, invulnerability lasts 2.0 s, score and streak are unchanged; the death after the third revive shows no revive.
13. Same seed gives identical gap sequence and score for the same tap trace.

App-level (widget/integration tests via test IDs):
14. Home shows the banner (`home` only); `game.banner` does not exist on the game screen.
15. Tapping `game.ready` / `game.field` starts the run and flaps (verified via Semantics values); the Dash button is off with fewer than 3 pips and ready at 3; tapping it sets `game.dash.state` to active.
16. Game over dialog shows `game.over.revive` while revives remain; interstitial obeys the caps (AdFrequency tests with fake clock); Dash Refill with 0 stock opens the refill sheet, `game.refill.coins` deducts 40 coins, `game.refill.ad` grants a refill via a fake AdService, max 3 ad refills per day.
17. Daily reward cycles 7 days with the rewards in section 5; streak freeze covers one missed day; 3 daily challenges are generated per day and claimable; each achievement unlocks on its condition (unit tests with fake clock).
18. Shop lists `remove_ads_all`, `coins_500`, `coins_1500` and `coins_4000` behind the parent gate (`gate.*`; wrong answers and the 60 s lock tested with a fake clock); `remove_ads_all` removes all ads and grants Continue and free Dash Refill without an ad; without Remove Ads, Continue calls the rewarded ad directly (no choice sheet) and spends no coins even with 1000 coins; an ad not earned grants nothing, keeps the panel open and the coin balance unchanged; the limit of 3 continues per run holds; skins (`shop.skin.<id>*`) are bought with coins, refused when short, equipped and persisted; the coin icon is found by type; app background pauses the run.
19. `flutter analyze`, `dart format`, `flutter test`, `scripts/ad_safety_check.sh` pass; `assets/LICENSES.md` lists every asset; no references to other flyer games' names in the repo outside `docs/SPEC.md`.
- More games: the Home icon and the Settings row open the screen; a `live` card shows "Get it", which asks the parent gate before the store page opens (Cancel opens nothing); `coming_soon` has no button; `hidden` entries and this game itself are absent; with nothing listed neither entry point shows; the screen has no coin or reward text (`test/ui/more_games_test.dart`).
- More games on Home at 360 x 640 dp and 360 x 592 dp with the banner: the icon row (More games, Shop, Settings) is 48 dp targets 8 dp apart at the top right and overlaps no Home element; Play is 240 x 60 and Daily reward / Challenges are 116 x 52 side by side, with no scrolling.

## What the generator and coder must change versus the block puzzle template
- `scripts/new_game.py` should generate `ya-spark/game-wingy` with id `wingy`, package `com.activemindcraft.wingy`, display name Wingy, `BLOCKFALL`-style define renamed to `WINGY_SEED`, and the `app.config.yaml` `retention:` block all true.
- **Reused unchanged from `lib/core/`:** ads (`AdService`, `AdFrequency`, AdMob impl), purchase (`PurchaseService`, products.yaml), save (`SaveService`), identity, leaderboard, notifications, analytics (no-op), remote_config, profile, clock, config, retention (`daily_reward`, `streaks`, `achievements`, `daily_challenges`, with Wingy templates and achievement definitions added).
- **New:** `lib/game/rules/` (world, physics, spire/gap generator, orbs, scoring, Perfect/Bloom streak, Glow Dash, revive, game state machine), `lib/game/flame/` (parallax, moth, spires, orbs, input), `lib/ui/game_screen.dart` and widgets (HUD, meter, Dash button), extended `test_ids.dart`, new challenge templates and achievements, Dash Refill stock and streak freeze counts in save, sounds and icon.
- **Replaced:** the block puzzle rules and Flame components (grid, tray pieces, hold/next UI).

## Third-party packages
`share_plus` 13.3.1 (pinned exactly): opens the Android system share sheet for scores, achievements and the app link; it sends nothing itself and is imported only in `lib/core/share/system_share_service.dart`.

Otherwise existing template packages only (Flutter, Flame, `google_mobile_ads`, `in_app_purchase`, `flutter_local_notifications`, the Play Games plugin and the audio package already in the template). Any addition needs a recorded reason from the coder stage.

Added for "More games": `url_launcher` 6.3.3 (exact pin, so a plugin update never changes behaviour or permissions unreviewed): opens Play Store pages for "More games"; imported only in `lib/core/links/url_external_link_service.dart`; sends nothing itself.

## Behaviour and feel (owner decisions, exact values)

**Home screen fits without scrolling** (owner, 2026-11-06). Code: `lib/ui/home_screen.dart`, `homeLayout` and `HomeGrid` in `lib/ui/widgets.dart`.
- At normal text size the whole Home fits with no scrolling on a 360 x 640 dp window with the banner shown (also 360 x 592), and on taller ones.
- Order (layout v2, owner 2026-11-06, replaces the 2 x 2 grid): a **top-right icon row**, then hero, title, stat chips, **Play** (240 x 60 dp, icon 30, label 24), then **Daily reward and Challenges side by side** in one row (each 132 x 52 dp, 8 dp apart, 272 dp in all (owner 2026-11-09: widened from 116 / 240 so the label does not touch the rounded ends), 6 dp inner padding each side, icon 22, label 15 sp scaled down with `FittedBox` and never wrapping, badges unchanged). If `retention` hides one of the two, the other spans the full 272 dp; if both are hidden the row is gone.
- **Top-right icon row** (`HomeIconButton` in `lib/ui/widgets.dart`): inside the safe area, 8 dp from the top and right edges, 8 dp between icons, in this order from the right: Settings (`home.settings`, `Icons.settings`), Shop (`home.shop`, `Icons.shopping_basket`), and More games (`home.moreGames`, `Icons.apps`) when at least one other game is listed. Each is a round gradient button, 44 dp visual with a 2 dp white border and a white 24 dp icon, 48 dp tap target (the key sits on the 48 dp target), Semantics labels "Settings", "Shop", "More games". Shop and Settings keep their old colours. The title never overlaps the row at 360 dp wide.
- `MenuButton` default size is 240 x 52 dp (primary 240 x 60) everywhere it is used.
- `HomeHero` is 160 dp when there is room and shrinks down to 96 dp when the space is short. Spacing between groups is 10 dp, and 8 dp when space is short (`homeLayout`).
- A `SingleChildScrollView` stays only as a safety net (very small windows, text scale above 1.3).
- Test IDs are unchanged (`home.play`, `home.dailyReward`, `home.challenges`, `home.shop`, `home.settings` (now on the icon buttons), `home.banner`, chips). The banner is not moved or hidden. Tests: `test/ui/home_fit_test.dart`.

**Autosave, Remove Ads offer, power description (owner, 2026-11-09)**
- **Autosave and resume:** a run in progress (hero position and speed, spires with their state, score, streaks, orbs, coins, meter, Dash and revive state, palette start) is saved after every pass or orb and when it is paused, including when the app goes to the background (`SaveData.game`, `WingyRun.toJson`, `WingyRun.restore`). It is cleared when the run ends (hit) or the player taps Quit. Opening the game screen resumes an unfinished run **paused**: a light "Game resumed" snack bar and the Paused dialog (Resume starts the 3-2-1 countdown). The Android Back button pauses (Paused dialog with Resume or Quit) instead of leaving. A corrupt save is dropped and a new run starts. The spire random stream restarts on resume, so spires after the saved ones differ from the original seed.
- **Remove Ads offer:** until `remove_ads_all` is owned, a small white "Remove ads" pill (`RemoveAdsPill`) shows on the game over panel under the medal (`game.over.removeAds`) and opens the Shop; it disappears once owned. It is **not** on Home (owner, 2026-11-09). In the Shop, Remove Ads is the first item, above the coin packs.
- **Power description before buying:** the Dash Refill sheet shows what Glow Dash does (`game.refill.description`) under its title.
- **Play and pause (owner, 2026-11-09):** Home always shows only Play. Play with an unfinished run saved asks **Resume** or **New game** (`home.resume.dialog`, `home.resume.resume`, `home.resume.new`; dismissing the question stays on Home); with nothing saved it starts a new run directly. The pause button, the back arrow and the Android Back button all open the same Paused dialog with **Resume** (`game.pause.resume`) and **Exit** (`game.pause.quit`). Exit keeps the unfinished run saved and leaves; it is recorded when it ends. A run that never started has nothing to keep.

## Keyboard (K1, 2026-11-22)
- Enter or up flaps, down uses the dash, Space or Esc pause (Resume or Exit). Flame's own focus is off (`autofocus: false`).
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).
