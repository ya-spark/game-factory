# Game spec

> Template. Filled in by the spec agent after the Q&A with the user.

## 1. Pitch
One paragraph: what the game is, who it is for.

## 2. Core loop
What the player does second-to-second, minute-to-minute, session-to-session.

## 3. Rules and scoring
Pure-Dart rules (lives in `lib/game/rules/`). List every rule, edge case and the scoring formula.

**Special blocks and Gold Rush** (template default, built once for every block game; code: `CellKind` in `piece.dart`, kinds stored next to the colour in `Board`; dealing in `piece_generator.dart`; effects in `Board.place` and `GameState.place`). A game that does not want them sets `PieceGenerator(random, 0)` or lists the change in its own spec.
- Cell kinds: `normal`, `gem` (the diamond block), `boom` (the **blast block**, shown as "Blast block"; the code name stays `boom`), `gold` ("golden block"). A kind travels with the piece cell onto the board and is cleared with the cell.
- Dealing: every `specialEveryNthTray = 4`th dealt tray (the first tray of a game is tray 1) has exactly one special cell, on a random piece of at least 2 cells. Kind weights: gem 3, blast 2, gold 1, from the game's seeded generator. The first tray never has a special cell. Every dealt piece still fits.
- Effects resolve when a line containing the special cell clears:
  - Gem: `gemPoints = 50` added to the line base before the combo multiplier (`(10 * lines^2 + 50 * gems) * combo`), plus 1 coin (the same coin balance as shop and daily reward, granted in `GameScreen`).
  - Blast block: after the line clear, every filled cell in the 3x3 area around it is emptied (clipped at the edges, no gravity, no chain reaction). Each extra emptied cell scores `blastCellPoints = 5` (flat). Gems emptied by a blast still pay.
  - Golden block: starts Gold Rush.
- Gold Rush: for the next `rushPlacements = 5` placements all points of the placement (cells, line bonus, gem, blast) are doubled (`rushMultiplier = 2`), after the combo multiplier. The placement that clears the golden block is not itself doubled. Another golden block during a rush adds `rushExtend = 5` placements, capped at `rushCap = 15`. A new game starts with no rush.
- Look: each kind is an overlay drawn in code on top of the block (`lib/game/flame/special_overlay.dart`; gem = bright faceted gem, blast block = friendly star-burst, golden = gold sheen with a star), no assets. The blast is a 0.5 s cartoon star burst on each emptied cell (grows and fades, no flashing). During a rush the board has a soft golden shimmer (slow sway, no flashing) and a chip "GOLD RUSH x2 · N" shows the placements left. Test ID `game.rush`: Semantics value = placements left (0 when off). The HUD row with the streak, combo, Gold Rush chip is a `Wrap` (centred, 14 dp gaps, 2 dp between lines): when it does not fit it breaks onto a second line and never overflows (test at 360 dp wide with all of them showing).

## 4. Content
Levels / pieces / modes. Difficulty curve.

## 5. Retention
Daily reward cycle, streaks (+freeze), daily challenges, achievements. Which are enabled.

## 6. Monetization
Ads and the compliance profile (issue 1C2, owner 2026-11-09; details in `docs/ENGINE.md`):
- `audience: child | teen | adult` in `app.config.yaml`. The template ships `adult`.
- No interstitials anywhere (`ads.interstitials_enabled` is false in every profile).
- Banner only before and after a game: placements `menu`, `pre_game`, `post_game`; never during
  play. The template shows `menu` on Home and `post_game` on the game-over panel.
- Rewarded ads (the Continue) exist only in the `adult` profile. `child` and `teen` apps have
  banner only; the Continue is not offered there.
- `child` and `teen`: child-directed ads, parent gate on every real-money purchase and coin spend.
  `adult`: no parent gate. Play Games sign-in: none in `child`, optional in `teen` and `adult`.
IAP: see `products.yaml`.
The template ships these products (ids are final once created in Play Console):
`remove_ads_all` (non-consumable), `coins_500`, `coins_1500`, `coins_4000` (consumable).
- Remove Ads removes the banner, the interstitials and the rewarded ads. Rewarded features
  (Continue) are then granted at once, without an ad. A saved legacy `remove_ads` entitlement
  counts as owned.
- In `child` and `teen` apps every real-money purchase goes through the parent gate first (a
  multiplication with factors 6 to 9; 3 wrong answers in a row lock purchases for 60 s). Not in
  `adult` apps.
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
  The card is **vertically centred** in the safe area (`Alignment.center`, 16 dp side padding, 8 dp above and below; owner, 2026-11-06), after the slide-up has finished.
  The panel (`lib/ui/game_over_panel.dart`) is the same file in every game and the template (Blockfall is the reference); game-specific wording lives only in the callers. It has one optional extra row, `extraButton`, between the Play again / Home row and Continue (14 dp gaps): Wingy uses it for Dash Refill, the other games leave it empty.
  The eye button (`game.over.view`) fades the panel out in 0.2 s and a tap anywhere brings it back.
  Entrance 1 s ease-in: 0.3 s hold while the scene dims, then 0.7 s fade with a 24 px slide-up;
  buttons are tappable once it has settled. Reduce motion: a single 0.2 s fade.
- Parent gate dialog: `gate.dialog`, `gate.answer`, `gate.submit`, `gate.cancel`.
- Shop: Remove Ads first, then the coin packs by size; `shop.buy.<productId>`, `shop.restore`.
- Home tip of the day (`tip.home`, `tip.close`, `tip.dontShow`), never during a game: it opens only while Home is the page on top and no run is on screen (`Services.inRun`, set by the game screen), checked again after the save that marks the tip as shown. A blocked tip is never queued; the next time Home is shown it is tried again (still once per day).
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
- Home layout v2 (owner, 2026-11-06): a **top-right icon row** (`HomeIconButton`), inside the safe area, 8 dp from the top and right edges, 8 dp apart, from the right: Settings (`home.settings`, `Icons.settings`), Shop (`home.shop`, `Icons.shopping_basket`), and More games (`home.moreGames`, `Icons.apps`) when at least one other game is listed. Each is a round gradient button, 44 dp visual with a 2 dp white border and a white 24 dp icon, 48 dp tap target, Semantics labels "Settings", "Shop", "More games". Below the title and stat chips: **Play** (240 x 60 dp), then **Daily reward and Challenges side by side** (each 116 x 52 dp, 8 dp apart; a lone one spans 240 dp; none leaves no row). `MenuButton` is 240 x 52 dp (primary 240 x 60) everywhere.
- The list is bundled: `more_games:` in `app.config.yaml` (`id`, `package_name`, `name`,
  `tagline`, `status` = `live` | `coming_soon` | `hidden`). `hidden` entries and the game's own
  package are skipped. With nothing to show, the Settings row and Home icon are not shown.
  No network call, so the privacy policy and Data safety do not change. All entries start
  `hidden`; the owner flips them to `live` when a game is public.
- Third-party: `url_launcher` 6.3.3 (exact pin), only in `lib/core/links/url_external_link_service.dart`,
  to open Play Store pages; the Android manifest `<queries>` lists the `market` and `https` VIEW intents.

- Modes and Study screens (learning games with a design): Game (Play, Challenges, Shop) and Study (Learn, Progress,
  Revise) per child, remembered, parent lock behind the gate; the Mind hubs have no modes. Test IDs: `tab.learn`,
  `tab.progress`, `tab.revise`, `learn.goal`, `progress.topic.<key>`, `revise.topic.<key>`.
  Mastery: Mastered at 90% passed and 80% correct, Learning below 40% passed. Accuracy shows for Ranger and Champion,
  never for Scout. Pack cards show no price. Data (in the child's save, `ChildProgress`): `topics` (passed, answers,
  correct), `items` (attempts, passes, last result: the "revise" list), `games` (passed, best score), `rewards`.

## 8. Art and audio
Style, palette, asset list (every asset must be in `assets/LICENSES.md`).
Look (issue 02A): when `app.config.yaml` has `theme.design`, the app uses the design system in
`docs/DESIGN_SYSTEM.md`: tokens per mode, the app's font, the shared widgets in `lib/ui/kit/`, text that follows the
phone's size setting plus a large-text option, a reduce-motion option, 4.5 to 1 contrast and screen-reader labels.
No human figures, faces or silhouettes in any art. Debug builds have a theme gallery in Settings.
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
- Special blocks (`test/game/special_blocks_test.dart`): every 4th tray has exactly one special cell on a piece of 2+ cells, none on the first tray, deterministic for a seed; a kind travels onto the board; a blast block empties the 3x3 area (clipped at the edges) and scores 5 per extra cell; a gem pays 50 and 1 coin and still pays inside a blast; a golden block starts a 5-placement rush that doubles points, extends by 5 up to 15; `game.rush` is on the game screen (value 0 when off).
- The Home icon and the Settings row open More games; a `live` card shows "Get it", which asks the
  parent gate before the store page opens (Cancel opens nothing); `coming_soon` has no button;
  `hidden` entries and the game itself are absent; with nothing listed neither entry point
  shows; the screen has no coin or reward text (`test/ui/more_games_test.dart`).
- Engine lock (`scripts/engine_lock.py`, `engine.lock`): `check` passes on a fresh copy and fails after any edit under `lib/engine`, `test/engine`, `test/fixtures` or `tool/content_cli.dart`; the hash does not depend on the game's package name (factory tests `test_new_game.py`, `test_sync_engine.py`, which also cover the generator profiles and the `CI_ENABLED` guard).
- Home at 360 x 640 dp: the icon row (More games, Shop, Settings) is 48 dp targets 8 dp apart at the top right and overlaps no Home element.

## Craft screen fixes (owner issue 132, 2026-11-12)
- Topic names: Learn, Progress, Revise and "Try next" show the topic's display name, which is the title of its pack (from `content/topics.yaml`); if no pack is loaded they show the tidied id (underscores to spaces, first letter capital). Never the raw id.
- Challenges (learning profiles) hold only learning goals paid by the rewards engine within the caps: today's goal, this week's goal and the streak goal (next streak milestone). The block puzzle daily challenges (combo, lines, score) stay in the puzzle profile only (`challenges_screen.dart`).
- Play lists each game once. The daily game is its own tile with a "Daily" badge, not a second tile. There is one tile per game, not per subject.
- Every game tile and every avatar has its own original art (`lib/ui/kit/ds_art.dart`, `DsGameArt`, `DsAvatarArt`); a test fails when a registered game or avatar has none.
