# Game spec

> Template. Filled in by the spec agent after the Q&A with the user.

## 1. Pitch
One paragraph: what the game is, who it is for.

## 2. Core loop
What the player does second-to-second, minute-to-minute, session-to-session.

## 3. Rules and scoring
Pure-Dart rules (lives in `lib/game/rules/`). List every rule, edge case and the scoring formula.

## 4. Content
Levels / pieces / modes. Difficulty curve.

## 5. Retention
Daily reward cycle, streaks (+freeze), daily challenges, achievements. Which are enabled.

## 6. Monetization
Ads: banner placement, interstitial triggers, rewarded placements. IAP: see `products.yaml`.
The template ships these products (ids are final once created in Play Console):
`remove_ads_all` (non-consumable), `coins_500`, `coins_1500`, `coins_4000` (consumable).
- Remove Ads removes the banner, the interstitials and the rewarded ads. Rewarded features
  (Continue) are then granted at once, without an ad. A saved legacy `remove_ads` entitlement
  counts as owned.
- Every real-money purchase goes through the parent gate first (a multiplication with factors
  6 to 9; 3 wrong answers in a row lock purchases for 60 s).
- Continue needs a rewarded ad (owner, 2026-11-06), up to 3 per run; with Remove Ads owned it
  is granted at once. Pressing it starts the ad directly (no choice sheet). A continue is
  granted only when the ad reports the reward as earned; if the ad fails, is not ready or is
  closed early, nothing is granted, the panel stays open and shows "No ad available right now.
  Try again in a moment.". Never a fallback to coins or a free continue.
- Acceptance: without Remove Ads, Continue calls the rewarded ad and spends no coins even with
  1000 coins; an ad not earned grants nothing and leaves coins unchanged; with Remove Ads no ad
  call; the limit of 3 holds.
- The coin is `CoinIcon` (gold disc, "MC", drawn in code); `StatChip` takes an icon or a widget.

## 7. Screens
Menu, game, shop, settings, daily reward, ... with test IDs (`lib/ui/test_ids.dart`).
- Game over panel (`game.over.panel`, `lib/ui/game_over_panel.dart`): rounded dark card at about
  90 % opacity with a light border and soft shadow. Top to bottom: Share (`game.over.share`, top
  left; shares the score text and the share card), title and scores, Play again
  (`game.over.retry`) and Home (`game.over.home`) side by side, Continue last in gold
  (`game.over.revive`).
  The eye button (`game.over.view`) fades the panel out in 0.2 s and a tap anywhere brings it back.
  Entrance 1 s ease-in: 0.3 s hold while the scene dims, then 0.7 s fade with a 24 px slide-up;
  buttons are tappable once it has settled. Reduce motion: a single 0.2 s fade.
- Parent gate dialog: `gate.dialog`, `gate.answer`, `gate.submit`, `gate.cancel`.
- Shop: Remove Ads first, then the coin packs by size; `shop.buy.<productId>`, `shop.restore`.
- Home tip of the day (`tip.home`, `tip.close`, `tip.dontShow`), never during a game.
- Settings: sound, volume, background sound, narrator voice, hand (left or right), vibration,
  reminders, tips, share app (only with a share link), privacy.

## 8. Art and audio
Style, palette, asset list (every asset must be in `assets/LICENSES.md`).
Sound: `AudioService` plays the narrator lines `assets/voice/<name>.mp3` (a playing line is
never cut off; priorities in `lib/core/audio/voice_arbiter.dart`: list the game's own line
names there) and loops one ambience track from `assets/ambience/` under it, ducked while a line
speaks. Settings: sound, volume, background sound (track or off), narrator voice.
Sharing: `ShareService` (system share sheet) with `captureShareCard` (`lib/ui/share_card.dart`,
drawn in code, restyle per game). `share.link_mode` in `app.config.yaml` (`internal_test`,
`store`, `off`) decides whether texts carry a link.

## 9. Play Games
Leaderboards / achievements to create (IDs go in `app.config.yaml`).

## 10. Store listing
Title, short description, full description, category, content rating notes.

## 11. Out of scope
Explicitly not doing: backend, Firebase, multiplayer, ...

## 12. Acceptance criteria
Testable statements the test agent turns into tests.
