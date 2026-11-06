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
  reminders, tips, More games (`settings.moreGames`, `Icons.apps`, above share app and privacy),
  share app (only with a share link), privacy.
- More games (`lib/ui/more_games_screen.dart`, `moreGames.screen`, `moreGames.back`): title
  "More games", header "More from Active Mind Craft". One card per listed game
  (`moreGames.card.<id>`): 48 dp rounded tile (12 dp radius) drawn in code, name, tagline, and
  "Get it" (`moreGames.get.<id>`, `live`) or the text "Coming soon" (`coming_soon`, no button).
  "Get it" asks the parent gate first, then `ExternalLinkService.openStorePage(package)`
  (`market://details?id=<package>`, fallback `https://play.google.com/store/apps/details?id=<package>`).
  Never coins or anything else for opening or installing another game (Play bans incentivised
  installs). Not shown on game over, Continue or in play, and never in place of an interstitial.
- Home More games icon (`home.moreGames`): top-right corner inside the safe area, 40 dp visual
  (white `Icons.apps` 24 dp on a 45 % black circle), 48 dp tap target, 4 dp from the edges,
  Semantics label "More games". Adds no row and moves nothing.
- The list is bundled: `more_games:` in `app.config.yaml` (`id`, `package_name`, `name`,
  `tagline`, `status` = `live` | `coming_soon` | `hidden`). `hidden` entries and the game's own
  package are skipped. With nothing to show, the Settings row and Home icon are not shown.
  No network call, so the privacy policy and Data safety do not change. All entries start
  `hidden`; the owner flips them to `live` when a game is public.
- Third-party: `url_launcher` 6.3.3 (exact pin), only in `lib/core/links/url_external_link_service.dart`,
  to open Play Store pages; the Android manifest `<queries>` lists the `market` and `https` VIEW intents.

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
- The Home icon and the Settings row open More games; a `live` card shows "Get it", which asks the
  parent gate before the store page opens (Cancel opens nothing); `coming_soon` has no button;
  `hidden` entries and the game itself are absent; with nothing listed neither entry point
  shows; the screen has no coin or reward text (`test/ui/more_games_test.dart`).
- Home at 360 x 640 dp: the icon is 48 dp at the top right and overlaps no Home element.
