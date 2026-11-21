# Block Puzzle (game package `game_block_puzzle`)

Status: BUILT. The game lives once in `game-factory/games/block_puzzle/` (SH1, owner 2026-11-21); the standalone Block Puzzle app and Mind Ember are containers that show it and bring their own shop, profile, ads, theme and release setup. This file is the only copy of the game's behaviour; it was moved from the standalone app's `docs/SPEC.md`, so it also holds sections about the standalone app (shop, monetisation, store). Where a section is about the container, the container follows it; a hub follows its own spec for those parts.

The game asks its container only through `BlockPuzzleServices` (`lib/src/host/`). Narrator voice and ambience come from `game_core/assets/audio`.

---

# Game spec

Status: BACKFILLED on 2026-11-05 from the code and commit history; the game predates the spec stage. This file is the contract for the game and the single source of truth: it lives only here, there is no copy in game-factory. **Whenever the owner gives a behaviour instruction (feel, layout, offsets, rules), change this file in the same commit as the code.** Section 13 holds the exact values.

## 1. Pitch
Block Puzzle is a one-handed 8x8 block-drop puzzle for casual and young players: drag three pieces from a tray onto the board, fill rows and columns to clear them, chase a high score. Kid-friendly (child-directed ads, rating G).

## 2. Core loop
Second to second: drag a piece to the board, see a ghost preview, release to place. Minute to minute: clear lines, build combos, a new tray of three is dealt once all three are used. Session to session: beat the best score, claim the daily reward, daily challenges and achievements.

## 3. Rules and scoring
Pure Dart in `lib/game/rules/`.
- Board 8x8; a placed piece must fit entirely on empty cells. No rotation.
- A full row or column clears (rows and columns can clear together).
- Score per placement: piece size (cells), plus `round(10 * lines^2 * combo * stage^stageExponent)` when lines clear.
- Combo = consecutive placements that cleared lines, `min(streak + 1, maxCombo)` with `maxCombo = 8`; a placement with no clear resets it.
- `stage = min(1 + linesClearedTotal ~/ 5, maxStage)` with `maxStage = 13` (`GameState.linesPerStage = 5`) and `stageExponent = 1.25` (`GameState.stageExponent`); stage is 1 until 5 lines are cleared. Stage uses the lines cleared before the placement. Stage is only the scoring multiplier; nothing else is tied to it.
- Measured (seeded greedy bot, `test/game/start_and_score_test.dart`, 20 seeds, games reaching 60 lines): a 60-line game scores about 11,068 on average with `maxCombo = 8`, `maxStage = 13`, `stageExponent = 1.25` (1.0 gave ~6,850, 1.2 gave ~10,029). The test asserts the 10,000-12,000 band.
- Start of a game (not after Continue): a prepared board 70% full (45 of 64 cells, plus or minus 2) with no complete row or column (`lib/game/rules/start_board.dart`, from the game seed). The first tray is three 4-cell pieces, at least two of them Z or J (any rotation or mirror the catalogue defines), the third any 4-cell piece, and no piece (same shape and rotation) more than twice; only the first tray is drawn this way, later trays are unchanged. Each of the three is placeable on the start board and each clears 2 or more lines when placed (1 line is the fallback), in any order, independent of each other (all three use rows, or all use columns).
- Game over when none of the remaining tray pieces fits anywhere.
- Continue (code name "revive"): up to 3 per run, each one needs a rewarded ad (or Remove Ads); coins can never pay for Continue (owner, 2026-11-06); empties the two fullest rows, deals a fresh tray, resets the combo.
- Best score is saved locally (and to the Play Games leaderboard when enabled).
- **Boosts** (owner, 2026-11-06; code `lib/game/rules/boosts.dart`, state in `GameState`): five coin boosts that never give points and never change the combo, stage, lines-cleared total or Gold Rush, and never count for challenges or achievements (no rewards for using them). Cells emptied by Blast, Sweep or Hammer vanish without effect: a gem pays nothing, a Boom block does not blast, a golden block does not start a rush. Table in section 6; per-game caps hold whatever the stock source (stock, shop, ad refill). Only while a game is running (not on the game over panel; Continue is the rescue there).
  - `blast`: tap a cell, every filled cell in the 3x3 around it is emptied (clipped at the edges, no gravity, no chain). If nothing in the 3x3 is filled, nothing happens and nothing is spent.
  - `shuffle`: the whole tray is replaced by three new pieces from the game's seeded generator (`PieceGenerator.dealShuffle`: same dealing rules, every piece fits). It does not advance the tray counter that drives `specialEveryNthTray`; a special cell on the old tray is lost.
  - `undo`: takes back the last placement (one level). A snapshot is taken before each placement; Undo restores board, tray, score, best score shown, combo, streak, stage, lines total, piece count, max combo, theme rotation index (it follows the lines total) and Gold Rush, and takes back the gem coins that placement paid (balance not below 0). Undo is disabled (greyed) when there is no snapshot: at game start, right after Undo, and after any other boost or Continue.
  - `sweep` (Line Sweep): empties the fullest row or column; ties: rows before columns, lowest row first, then lowest column. Nothing happens on an empty board.
  - `hammer`: tap a filled cell to empty it (any kind of cell). An empty cell does nothing.
  - Stock: every install, new or existing, starts with 1 of each (`SaveData.items`, save version 3; the v2 to v3 migration adds 1 of each). Stock never goes below 0.

## 4. Content
Piece catalogue in `lib/game/rules/piece.dart` (weighted). Dealing (`piece_generator.dart`):
- Big pieces (6 or more cells, `PieceGenerator.bigPieceCells = 6`: the 2x3 rectangle and the 3x3 square) are never in the prepared start tray (it stays three 4-cell pieces). Every other dealing rule is unchanged, including "every dealt piece fits" and the kind-deal rules. In the deal pool a 4-cell shape weighs `fourCellWeight = 3`, a big piece its catalogue base weight (3 per orientation, so the rectangle weighs 3 + 3 and the square 3), every other shape 1.
- Catalogue (each with its distinct rotations; weight = base weight per orientation, 4-cell shapes then get the `fourCellWeight` preference): dot 2; bars 2/3/4/5 = 4/4/2/1; squares 2/3 = 4/3; corners 3/5 = 4/1; L 3, J 4 (mirror of L), T 3, S 2, Z 3 (mirror of S); plus (5 cells) 1; diagonals of 2 and 3 cells (cells touch only at corners, not edge-connected) 1 each; **2x3 rectangle** (6 cells, `rect23`, two orientations: 2 rows by 3 columns and 3 rows by 2 columns) 3 per orientation. The rectangle is a normal piece: any colour, special cells allowed, ghost preview and drag snap per cell. The ghost preview and drag snap work per cell, so diagonal pieces behave like any other; special cells can sit on any cell of a piece with at least 2 cells, diagonals included.- Every dealt piece fits the board whenever any piece fits; a dead piece is only dealt when the board is almost full.
- One fixed piece preference for the whole game: 4-cell pieces have weight `fourCellWeight = 3`, every other shape 1. It is soft: a 4-cell piece that fits nowhere is not dealt.
- Difficulty rises through how kind the deal is, by lines cleared in the game: below `kindUntilLines = 20` every deal is kind (all three pieces can be played one after another and at least one clears a line; 50 tries, then the clear-a-line part is dropped, then 50 more tries, then plain). From 20 to `plainFromLines = 60` half of the deals (random) are kind. From 60 the deal is plain (each piece still fits on its own).
- While the board is at most half full, pieces smaller than 3 cells are not dealt.

**Special blocks and Gold Rush** (code: `CellKind` in `piece.dart`, kinds stored next to the colour in `Board`; dealing in `piece_generator.dart`; effects in `Board.place` and `GameState.place`)
- Cell kinds: `normal`, `gem`, `boom` ("Boom block"), `gold` ("golden block"). A kind travels with the piece cell onto the board and is cleared with the cell.
- Dealing: every `specialEveryNthTray = 4`th dealt tray (the prepared start tray is tray 1) has exactly one special cell, on a random piece of at least 2 cells. Kind weights: gem 3, boom 2, gold 1, from the game's seeded generator. The start board and the first tray never have special cells. Every dealt piece still fits and the difficulty rules are unchanged.
- Effects resolve when a line containing the special cell clears:
  - Gem: `gemPoints = 50` added to the line base before the combo and stage multipliers (`(10 * lines^2 + 50 * gems) * combo * stage^1.25`), plus 1 coin (same coin balance as shop and daily reward).
  - Boom block: after the line clear, every filled cell in the 3x3 area around it is emptied (clipped at the edges, no gravity, no chain reaction). Each extra emptied cell scores `blastCellPoints = 5` (flat). Gems emptied by a blast still pay.
  - Golden block: starts Gold Rush.
- Gold Rush: for the next `rushPlacements = 5` placements all points of the placement (cells, line bonus, gem, blast) are doubled (`rushMultiplier = 2`), after the combo and stage multipliers. The placement that clears the golden block is not itself doubled. Another golden block during a rush adds `rushExtend = 5` placements, capped at `rushCap = 15`. A new game starts with no rush.
- Look: each kind is an overlay on top of the current skin in every theme (gem = bright faceted gem, Boom block = friendly star-burst, golden = gold sheen with a star). The blast is a 0.5 s cartoon star burst on each emptied cell (grows and fades, no flashing). During a rush the board has a soft golden shimmer (slow sway, no flashing) and a chip "GOLD RUSH x2 · N" shows the placements left. Test ID `game.rush`: Semantics value = placements left (0 when off). The HUD row with the streak, combo, Gold Rush chip is a `Wrap` (centred, 14 dp gaps, 2 dp between lines): when it does not fit it breaks onto a second line and never overflows (test at 360 dp wide with all of them showing).
- The 60-line simulation band above measures a game without special blocks (the test deals none, `PieceGenerator(random, 0)`).

## 5. Retention
Daily reward cycle, streaks (+ freeze), daily challenges, achievements: all ON (`retention` in `app.config.yaml`).

## 6. Monetization
Banner on the game screen; interstitials paced by `ads` in `app.config.yaml` (min 180 s apart, every 2nd game over, max 6 per session, none in the first 60 s); rewarded ad for Continue. IAP in `products.yaml`: `remove_ads_all` (non-consumable, "Remove Ads", removes **all** ads), `coins_500` "Coin Pack", `coins_1500` "Big Coin Pack", `coins_4000` "Coin Chest" (consumable). The retired id `remove_ads` is never sold; a saved `remove_ads` entitlement or restore still counts as owned.
- **Remove Ads removes all ads**: no banner, no interstitial and no rewarded ad; Continue is granted at once (up to 3 per run).
- Shop order: Remove Ads, then coin packs in ascending size; products the store does not return stay hidden, or "Store unavailable". Coin pack text is "Coins for boosts and streak freezes."; wording never pressures children. After the coin packs comes a **Boosts** section (`shop.boosts`) that is shown even when the store is unavailable.
- **Boosts (coin sinks)** (owner, 2026-11-06). Prices in coins and the hard cap of uses per game:

| id | Name | Effect | Price | Max uses per game |
|---|---|---|---|---|
| `blast` | Blast | Tap a cell: every filled cell in the 3x3 around it is emptied | 50 | 2 |
| `shuffle` | Shuffle | Replace the whole tray with three new pieces | 40 | 2 |
| `undo` | Undo | Take back the last placement (one level) | 30 | 3 |
| `sweep` | Line Sweep | Empty the fullest row or column | 60 | 1 |
| `hammer` | Hammer | Tap a filled cell to empty it | 25 | 3 |

  - Use: a button with stock above 0 uses it. `shuffle`, `sweep` and `undo` apply at once. `blast` and `hammer` arm a targeting mode: the button is highlighted, a "Tap a cell" chip with Cancel (`game.item.cancel`) shows at the bottom of the play area, `blast` previews the 3x3 area under the finger (`hammer` the one cell), and tapping a cell applies it. A boost is spent only when applied; Cancel or tapping the button again spends nothing. While targeting, pieces cannot be dragged. When the per-game cap is reached the button is greyed (a tap says "used up this game"); a refill never lifts the cap.
  - Empty-stock sheet (`game.item.sheet`) for a button with 0 stock: "Buy with coins" (`game.item.refill.coins`, price with the coin icon; disabled with "Not enough coins" when short; no parent gate), "Watch ad for +1" (`game.item.refill.ad`), and, when coins are short, "Get coins" (`game.item.refill.shop`, opens the Shop). Ad refill: +1 of that boost, at most 3 ad refills per game across all boosts (`Boosts.maxAdRefillsPerGame`, ad placement `boostRefill`). With Remove Ads owned there is no ad: the button reads "Get +1 free (N left)" and grants at once within the same cap. An ad that does not reward grants nothing.
  - Shop "Boosts" section after the coin packs: one row per boost with name, one-line description, price with the coin icon, `shop.item.<id>.buy`, and the current stock (`shop.item.<id>.count`). Coins only; refuses with "Not enough coins." when short.
- Coins are drawn with the code-made `CoinIcon` (gold coin, darker rim, inner ring, shine, letters MC; Semantics label "coins"); `Icons.monetization_on` is not used.
- **Parent gate** (`ParentGate` dialog, "Ask a grown-up") before every real-money purchase (not Restore, not spending coins): typed answer to a multiplication with factors 6 to 9, new numbers after each wrong answer; 3 wrong in a row close the dialog and lock purchases for 60 s. Test IDs `gate.dialog`, `gate.answer`, `gate.submit`, `gate.cancel`.
- Ads are child-directed with max content rating G. Release AdMob IDs are in `app.config.yaml`; debug uses Google's test IDs.

## 7. Screens
Home, game, game over (overlay), daily reward, challenges and achievements, shop, settings. Every interactive widget has a key in `lib/ui/test_ids.dart`. Screens use named routes so each is deep-linkable.

**Boost row on the game screen** (`lib/ui/boost_widgets.dart`, `lib/ui/game_screen.dart`): one row of five round 48 dp buttons (Blast, Shuffle, Undo, Line Sweep, Hammer; icons drawn in code, no assets) with a small count badge each. Test IDs `game.item.<id>`, `game.item.<id>.count`, `game.item.row`, `game.item.chip`, `game.item.cancel`, `game.item.target` (touch layer while targeting), `game.item.sheet`, `game.item.refill.coins`, `game.item.refill.ad`, `game.item.refill.shop`; shop: `shop.boosts`, `shop.item.<id>.buy`, `shop.item.<id>.count`. The row is an overlay in the free strip above the board (centred in the space between the top of the play area and the board frame), so the board, tray and every offset in section 13 do not move; it fits at 360 x 640 dp clear of the board and the banner. It is always visible, from the first moment of the first game (owner, 2026-11-09: no wait for 3 placements). A disabled button (cap reached, Undo with nothing to take back, game over) is greyed.

**Home scene and background** (`lib/ui/home_hero.dart`, `lib/ui/theme_background.dart`)
- Above the title, a code-drawn band 160 dp tall (no assets, no gestures, test ID `home.hero`) replaces the emoji row: two lanes of 4-cell catalogue pieces (5 per lane, 10 objects) drift, one right to left (22 u/s) and one left to right (15 u/s), with a gentle bob. Pieces use the current theme's block skin (theme at the saved `themeIndex`) and restyle when it changes. About every 6 s a lane completes with a 1 s sparkle (alternating lanes).
- One `CustomPainter`, one ticker; it stops while the home route is covered and while the app is in the background.
- The home background is the current theme's background at the saved `themeIndex`, with the same 1.5 s cross-fade when it changes. The title is white with a dark shadow. Other menu screens keep the plain gradient.

**Sharing** (`lib/core/share/`, `lib/ui/share_card.dart`)
- `ShareService` (`shareScore`, `shareAchievement`, `shareApp`); `SystemShareService` opens the Android share sheet through `share_plus`, imported only in that file and pinned to the exact version `13.3.1` (same as game-wingy; an exact pin so a share plugin update never changes behaviour or permissions unreviewed). `FakeShareService` records the texts in tests. No Facebook or Instagram SDK. The app sends nothing itself; the player starts sharing and picks the target app.
- Share card: a widget drawn in code and rendered to a PNG through a `RepaintBoundary` (360x450 at 3x): game name, big score (or achievement title), best score, and the current look (the current theme's background and one block of each colour in its skin). No player name, no id, no store text.
- Texts (the game name always appears; the link, when there is one, follows on a new line): score `This is my high score in {game}: {score}. Can you beat it?`; achievement `I unlocked "{title}" in {game}! Can you beat it?`; Settings "Share app" `Try {game}! Can you beat my score?` with the same link.
- Config in `app.config.yaml` (replaces `share.app_link_enabled`): `share: link_mode: internal_test | store | off` and `internal_test_url`. `internal_test` (default) uses `internal_test_url` (`https://play.google.com/apps/internaltest/4699568684837272672`); `store` uses `https://play.google.com/store/apps/details?id=<package_name>`; `off` adds no link and hides "Share app". `internal_test` with an empty URL behaves like `off`. The owner switches to `store` when the game is public. Loader: `AppConfig.shareLink` (null = no link).
- Buttons: game over, small ghost Share icon button at the top left of the panel (`game.over.share`); each unlocked achievement has a share icon (`achievement.share.<id>`); Settings "Share app" (`settings.shareApp`) is visible unless the mode is `off` (no link).

**Tips** (`lib/game/tips.dart`, `lib/core/tips/tip_service.dart`, `lib/ui/tip_dialog.dart`)
- 15 tips (at most 80 characters, unique, none mention other games). `TipService` (pure Dart) deals them from a shuffled bag so a tip never repeats back to back, and gives a tip of the day from the day index.
- The only place a tip appears is **one dialog on the home page, once per day**, opened when the home page is first shown that day (`tip.home` is the dialog; saved `tipHomeDay`, set when it opens). It shows the tip of the day, a "Don't show tips again" checkbox (`tip.dontShow`) and Close (`tip.close`). Close alone just closes it; checkbox + Close turns tips off everywhere. It is not shown again the same day, and never when tips are off. The home layout holds no tip card, so the buttons are not pushed down.
- The dialog opens only while the home page is the page on top and no run is on screen (`Services.inRun`, set by the game screen), checked again after the save that marks the tip as shown. A blocked tip is never queued; the next time Home is shown it is tried again (still once per day).
- Never a tip in a game or on the game over screen: no game-over tip, no pause tip (no pause screen), no first-time special-block hints.
- Settings "Show tips" switch (`settings.tips`, on by default) is the same saved profile value (`tipsOff`).
- Test fakes turn tips off by default (`buildFakeServices(tips: true)` turns them on).

**More games** (`lib/ui/more_games_screen.dart`, `moreGames.screen`, `moreGames.back`)
- Title "More games", header "More from Active Mind Craft". One card per listed game (`moreGames.card.<id>`): a 48 dp rounded tile (12 dp radius) drawn in code (no asset), the name, the tagline, and "Get it" (`moreGames.get.<id>`, status `live`) or the text "Coming soon" (`coming_soon`, no button). "Get it" asks the parent gate first (the same "Ask a grown-up" dialog and lockout as purchases), then `ExternalLinkService.openStorePage(package)` (`market://details?id=<package>`, fallback `https://play.google.com/store/apps/details?id=<package>`). Cancelling the gate opens nothing.
- Never coins, items or any reward for opening or installing another game (Play bans incentivised installs). Not shown on game over, Continue or in play, and never in place of an interstitial.
- Entry points: a "More games" row in Settings (`settings.moreGames`, `Icons.apps`, below the tips switch) and a round icon in the Home top-right icon row (`home.moreGames`, see "Behaviour and feel"). No other entry points.
- The list is bundled: `more_games:` in `app.config.yaml` (`id`, `package_name`, `name`, `tagline`, `status` = `live` | `coming_soon` | `hidden`), loaded into `AppConfig.moreGames`; `AppConfig.visibleMoreGames` drops `hidden` entries and this game's own `package_name`, so the same list is copied to every game. With nothing to show, the Settings row and the Home icon are not shown. No network call, so the privacy policy and Data safety do not change. All entries start `hidden`; the owner flips an entry to `live` when that game is public. Taglines are under 60 characters, name no other studio and use no pressure wording.
- `ExternalLinkService` (`lib/core/links/`): `openStorePage(packageName)`; `UrlExternalLinkService` is the only file that imports `url_launcher`; `FakeExternalLinkService` records the packages in tests. The Android manifest `<queries>` lists the `market` and `https` VIEW intents.

- Third-party: `url_launcher` 6.3.3 (exact pin, so a plugin update never changes behaviour or permissions unreviewed): opens Play Store pages for "More games"; imported only in `lib/core/links/url_external_link_service.dart`; sends nothing itself.

## 8. Art and audio
Dark teal theme (seed `#2EC4B6`), rounded glossy blocks, kid-friendly colourful menu pages. Narrator voice clips (`assets/voice/`) on clears, combos, new best and game over. Every asset is listed in `assets/LICENSES.md`.

**Sound (exact values)**
- Voice priorities. High: `game_over`, `better_than_the_best`. Normal: `awesome`, `combo`, `excellent`, `fantastic`, `great`, `incredible`, `nice`, `unbelievable`, `unstoppable`, `well_done`, `you_did_it`. Low: `get_ready`, `go`, `careful`.
- A playing clip is never stopped by a new line. A high line waits for the clip and then plays (the newest waiting high line wins). A normal or low line that arrives while a clip plays is played only if the clip ends within 1 s, otherwise dropped.
- Background sound (`assets/ambience/`): loops at volume 0.25 (voice 1.0), 0.1 while a voice clip plays, both scaled by Master volume. Starts when the game screen opens, pauses when the app goes to the background, stops when leaving the game screen, keeps playing under game over. Voice and ambience use `mixWithOthers` (no Android audio focus).
- Settings: **Sound** switch (master mute, on top), **Master volume** slider 0-100 % (default 100 %, test ID `settings.volume`), **Background sound** picker Off / Morning birds (default) / Heartbeat (`settings.ambience`), with a play/stop preview button beside the picker (`settings.ambience.preview`) that loops the track until stopped; picker text is ink-coloured on the white panel; a saved Before sunrise falls back to Morning birds, **Voice** switch, default on (`settings.voice`). No Effects switch (no effect sounds). All saved in the profile and applied immediately.
- **Hand** choice Right (default) / Left (`settings.hand`), saved in the profile. There is no pause button or side buttons during play; Left only mirrors the back button to the right side (header row reversed). Board, tray, score and game over screen are unchanged.

**Themes** (code: `lib/game/themes/block_theme.dart`, `lib/game/rules/theme_rotation.dart`)
- One theme = background + block skin + 8 colours + empty-cell and grid-line colours, all drawn in code (no assets). The board stores only a colour index per cell; the pure-Dart rules do not know themes. Cell pictures are cached per (theme, colour).

| id | Skin | Background |
|----|------|------------|
| `gems` | glossy gems (the original look) | midnight-teal gradient (the original) |
| `cakes` | cream-iced biscuit cells with sprinkles | chocolate-brown with a soft wafer pattern |
| `wood` | warm wooden tiles with grain lines | forest-green gradient |
| `candy` | glossy gumdrop sweets | pastel pink-sky gradient |
| `ocean` | pearly shell tiles | deep-blue gradient with soft bubbles |
| `space` | round planet tiles with rings and craters | dark purple starfield |

- Colours: 8 per theme (`Piece.colorCount = 8`). Each dealt piece gets a random colour index from the game's seeded generator (not a fixed colour per shape). Every colour index also has its own small mark (dot, ring, bars, diamond, triangle, cross, two dots), so colours stay distinct for colour-blind players.
- Block tile and contrast (look): in every skin except Gems (already a filled tile, unchanged) each cell is first drawn on a base tile (`paintBaseTile` in `lib/game/themes/block_theme.dart`): rounded square filling the whole cell (0.5/64 gap per side = 1 px grid gap, corner radius 16 % of the cell, at most 18 %), filled with the dark shade (lightness -0.3) of the cell's own colour, with a 1.5/64 outline at 45 % black (`0x73000000`) and a 1/64 inner edge on the top and left at 35 % white (`0x59FFFFFF`). The motif (gumdrop, shell, planet, icing, wood face) is drawn on top and is at least 80 % of the tile width (planet disc 83 %). Dragged piece, ghost and tray use the same skin. Every palette colour has a WCAG contrast of at least 3:1 against the theme's empty cell colour and, in Cakes, Candy, Ocean and Space, against `backgroundTop`. Gems and Wood have bright mid-tone backgrounds no on-theme colour can reach 3:1 against, so only the empty cell check applies there. Colour-blind marks stay. Adjusted colours: Candy darkened (raspberry `#C4155A`, orange `#A84F00`, lemon `#7A5B00`, lime `#106A36`, blue `#1565B0`, grape `#6D32C4`, cherry `#BE2424`, mint `#0B6B68`); Cakes chocolate `#D2956A` and cherry `#FF7A8A`; Wood walnut `#B07B40`, cherry wood `#C4724A`, dark `#A07C5A`; Ocean lilac `#D6CAF8` and blue `#A3CEFF`. Test: `test/ui/block_contrast_test.dart`.
- Change rule: no picker, no setting. The theme changes every time 10 more lines are cleared: `ThemeRotation.themeEveryLines = 10`, index `(start + linesClearedTotal ~/ 10) % 6`, in table order, wrapping. This is independent of the scoring stage (every 5 lines).
- The rotation index is saved in the profile (`themeIndex`); a new game starts from the index the last game reached. A new install starts at `gems`.
- Transition: a 1.5 s cross-fade (`PuzzleView.fadeSeconds`) of the background and all cells; no flashing, input is never blocked. Cells on the board, the tray and the ghost preview are redrawn in the new theme at once (they keep their colour index).
- HUD text colour: each theme has `hudText` (and `hudSubtle` for the "SCORE" label) and `backgroundTop` (top colour of its background gradient). The game screen's HUD text drawn on the background (score digits, SCORE label, streak line, combo, GOLD RUSH chip text, best-score number) uses the current theme's colours; text inside dark pills/buttons is unchanged. Dark themes keep white (`hudSubtle` teal-grey `0xFF7FB7BD`); Candy uses dark plum `0xFF5B2A55` / `0xFF6E3A68`. The colours blend during the 1.5 s cross-fade. Rule: contrast of `hudText` and `hudSubtle` against `backgroundTop` is at least 4.5 (WCAG), checked by a test for every theme. Test ID `game.score_label` is the SCORE label.
- Test hook: the invisible `game.theme` test ID carries the current theme id as its Semantics value.

## 9. Play Games
Sign-in, high-score leaderboard and cloud save, off until `play_games.enabled` in `app.config.yaml`.

## 10. Store listing
See `store/google-play/` (listing text, privacy policy, data safety).

## 11. Out of scope
Backend, Firebase, multiplayer, piece rotation, iOS and web builds.

## 12. Acceptance criteria
- Placing a piece on empty cells updates the board and score; an illegal placement is rejected.
- Filling a row or column clears it and awards the line bonus with the combo multiplier.
- A dealt tray always contains a piece that fits while any move exists.
- The game ends when no remaining piece fits; a Continue is offered up to 3 times per run.

Game over screen layout:
- Player-facing wording is "Continue" (code and test IDs still say "revive"); the label is the constant `continueLabel` in `lib/ui/game_screen.dart`. Text: `Continue · N left`, details line `Continues left: N`.
- The card is **vertically centred** in the safe area (`Alignment.center`, 16 dp side padding, 8 dp above and below; owner, 2026-11-06), after the slide-up has finished. The panel (`lib/ui/game_over_panel.dart`) is the same file in every game and the template (Blockfall is the reference); game-specific wording lives only in the callers. It has one optional extra row, `extraButton`, between the Play again / Home row and Continue (14 dp gaps): Wingy uses it for Dash Refill, the other games leave it empty.
- Order top to bottom inside the panel: small ghost Share icon button at the top left; title, score, best score; **Play again** and **Home** side by side; **Continue** last, at the bottom: gold primary, font 22, padding 28x16, hidden when no continue is left.
- Play again: secondary style (regular, 16) while Continue is offered; when Continue is unavailable it takes the large gold style (22, 28x16).
- Continue button: with Remove Ads owned it continues at once (no ad, no coins); otherwise pressing it starts the rewarded ad directly (no choice sheet). A continue is granted only when the ad reports the reward as earned; if the ad fails to load, is not ready or is closed early, nothing is granted, the panel stays open and shows "No ad available right now. Try again in a moment.". Never a fallback to coins or a free continue. The button is hidden after the 3rd continue of a run.
- Test IDs: `game.over.revive` (Continue), `game.over.retry` (Play again), `game.over.home`, `game.over.share`, `game.over.dialog`, plus `game.over.panel` and `game.over.view`.
- No tip is ever shown on the game over screen.
- A drag follows the finger with the offsets in section 13 and the ghost preview shows where it will snap.
- Debug builds use test ad IDs; release builds do not (CI `ad_safety_check.sh`).
- Boosts: arming and cancelling Blast or Hammer spends nothing; a boost is spent only when applied; none changes score, combo, stage or rush; Undo restores everything including gem coins; per-game caps (2/2/3/1/3) and the 3 ad refills per game hold; every install starts with 1 of each; the new pieces (3x3 square, 2x3 and 3x2 rectangle) fit their tray slot at 360 x 640 dp; the start tray never has a piece of 6 or more cells; the 60-line band (10,000 to 12,000) still holds (measured about 11,461 with the rectangle and `square3` at weight 3).
- Without Remove Ads, Continue calls the rewarded ad directly (no choice sheet) and spends no coins even with 1000 coins; an ad not earned grants nothing, keeps the panel open and the coin balance unchanged; with Remove Ads it continues with no ad call; the limit of 3 per run holds.
- More games: the Home icon and the Settings row open the screen; a `live` card shows "Get it", which asks the parent gate before the store page opens (Cancel opens nothing); `coming_soon` has no button; `hidden` entries and this game itself are absent; with nothing listed neither entry point shows; the screen has no coin or reward text (`test/ui/more_games_test.dart`).
- More games on Home at 360 x 640 dp: the icon row (More games, Shop, Settings) is 48 dp targets 8 dp apart at the top right and overlaps no Home element; Play is 240 x 60 and Daily reward / Challenges are 116 x 52 side by side, with no scrolling.

## 13. Behaviour and feel (owner decisions, exact values)
Code: `lib/game/layout.dart` and `lib/game/flame/block_puzzle_game.dart`. `cell` = board cell size.

**Home screen fits without scrolling** (owner, 2026-11-06). Code: `lib/ui/home_screen.dart`, `homeLayout` and `HomeGrid` in `lib/ui/widgets.dart`.
- At normal text size the whole Home fits with no scrolling on a 360 x 640 dp window, and on taller ones.
- Order (layout v2, owner 2026-11-06, replaces the 2 x 2 grid): a **top-right icon row**, then hero, title, stat chips, **Play** (240 x 60 dp, icon 30, label 24), then **Daily reward and Challenges side by side** in one row (each 132 x 52 dp, 8 dp apart, 272 dp in all (owner 2026-11-09: widened from 116 / 240 so the label does not touch the rounded ends), 6 dp inner padding each side (9 dp in Block Puzzle, whose border does not inset the content), icon 22, label 15 sp scaled down with `FittedBox` and never wrapping, badges unchanged). If `retention` hides one of the two, the other spans the full 272 dp; if both are hidden the row is gone.
- **Top-right icon row** (`HomeIconButton` in `lib/ui/widgets.dart`): inside the safe area, 8 dp from the top and right edges, 8 dp between icons, in this order from the right: Settings (`home.settings`, `Icons.settings`), Shop (`home.shop`, `Icons.shopping_basket`), and More games (`home.moreGames`, `Icons.apps`) when at least one other game is listed. Each is a round gradient button, 44 dp visual with a 2 dp white border and a white 24 dp icon, 48 dp tap target (the key sits on the 48 dp target), Semantics labels "Settings", "Shop", "More games". Shop and Settings keep their old colours. The title never overlaps the row at 360 dp wide.
- `MenuButton` default size is 240 x 52 dp (primary 240 x 60) everywhere it is used.
- `HomeHero` is 160 dp when there is room and shrinks down to 96 dp when the space is short. Spacing between groups is 10 dp, and 8 dp when space is short (`homeLayout`).
- A `SingleChildScrollView` stays only as a safety net (very small windows, text scale above 1.3).
- Test IDs are unchanged (`home.shop` and `home.settings` now sit on the icon buttons). Tests: `test/ui/home_fit_test.dart`.

**Drag and drop**
- Pressing anywhere from 0.25 cell above the tray down to the bottom of the screen, across the full width, picks the tray slot under the press. Thumbs press below the piece, not on it (`traySlotAt`).
- Vertical offset: the dragged piece's bottom edge floats **2.5 cells** above the finger, wherever the press landed (`dragLift = cell * 2.5`).
- Horizontal offset: the press keeps its horizontal distance from the piece centre for the whole drag, so a press left of the piece keeps the piece to the right of the finger and it never jumps (`_grabX`).
- Release snaps to the nearest **legal** placement, not the nearest cell (`snapToLegalCell` in `lib/game/rules/snap.dart`, pure Dart). With the piece's top-left in unrounded cell units `(fy, fx)` (`PuzzleLayout.topLeftInCells`), candidates are all `(r, c)` with Euclidean distance `<= snapTolerance = 1.0` cell for which `Board.canPlace` is true. The nearest wins; ties go to the candidate that clears more lines, then the smaller row, then the smaller column.
- No legal candidate within 1.0 cell: the drop is a cancel and the piece returns to the tray.
- The ghost preview and the drop call the same function, so the translucent ghost always shows exactly where the piece will land, including on near-misses.
- **Clear preview (owner, 2026-11-09):** while a piece is dragged and has a legal landing cell, every row and column the drop would complete is highlighted over the board (gold fill `0x66FFD54F` and a 3 px gold edge `0xE6FFD54F`), under the ghost, so the player can decide before letting go. Always on. Logic: `Board.linesCompletedBy`.
- **Autosave and resume (owner, 2026-11-09):** the running game (board with special cells, tray, score, combo, stage lines, Gold Rush, boost uses, ad refills, revives, theme start) is saved after every change (`SaveData.game`, `GameState.toJson`) and cleared when the game ends. Opening the game screen resumes it silently with a light "Game resumed" snack bar; a corrupt save is dropped and a new game starts. Undo history is not saved. Back needs no pause (the game is turn-based and already saved).

- **Remove Ads offer (owner, 2026-11-09):** until `remove_ads_all` is owned, a small white "Remove ads" pill (`RemoveAdsPill`) shows on the game over panel under the best score (`game.over.removeAds`) and opens the Shop; it disappears once owned. It is **not** on Home (owner, 2026-11-09). In the Shop, Remove Ads is the first item, above the coin packs.
- **Power description before buying:** the boost refill sheet shows the boost's description (`game.item.description`) under its title, above the Buy / Watch ad buttons. The Shop already lists each description.

**Layout** (portrait)
- Side margin 4% of width; top padding `min(6% of height, 60)`.
- The board sits **1.5 cells below the vertical centre** (`boardDropCells`) so the top rows stay in thumb reach, but never so low that the tray leaves the screen.
- Tray under the board with a 0.5 cell gap; tray pieces are drawn at `min(0.62 cell, slotWidth / 5.5)`; three slots share the board width.
- A free strip of **0.7 cell** (`bottomGapCells`) stays under the tray for thumbs. On short screens the whole board shrinks instead of squeezing it.

**Game over**
- Overlay pinned to the top of the screen, no dimming of the board. All content sits in a panel (`game.over.panel`): rounded card (radius 24), solid dark surface `#1E1535` at about 90 % opacity (`0xE6`), thin light border (white at 33 %), soft shadow. Text and buttons keep at least 4.5:1 contrast against the panel (white on the dark surface; secondary buttons use `#7B3FD6` to `#B02F78` with white text; gold buttons use dark brown text).
- **Eases in, never abrupt (about 1 s):** (a) the moment the run ends, input is locked, the board freezes and the game over voice line starts; (b) 0.3 s hold while the scene dims to about 40 % black; (c) the panel fades 0 to 100 % and slides up 24 px over 0.7 s (ease-out cubic); (d) the buttons (and the eye button) are tappable only once the panel has settled, at 1 s. `game.over.panel` exists from the first frame of (c). With reduce motion (system animations off) there is a single 0.2 s fade, no hold, no slide. The score shown never changes during the transition.
- **Show best move (owner, 2026-11-09):** a small "Show best move" button (`game.over.bestMove`) under the best score opens a dialog (`bestMove.dialog`) that replays the **last tray of three** from the board as it was when that tray was dealt (`GameState.trayStartBoard` and `trayStartPieces`): the order and cells with the **most lines cleared** (then the most pieces placed, then the emptiest board), one step at a time with Back / Next (`bestMove.next`), the piece outlined in white and the lines it completes shaded gold. Solver: `BestMoveSolver` (pure Dart, 8x8 bit masks, special cells ignored). Shows "No better placement was possible" when nothing fits.
- **View board:** a small eye button (`game.over.view`) at the top right of the panel. Tapping it fades the panel out in 0.2 s so the whole final board is visible; a tap anywhere, or the eye button (which stays visible), brings the panel back. The board stays visible and still, and nothing else changes while the panel is hidden (scores and rewards are already final).

**HUD text legibility:** on the Gems and Ocean themes the HUD texts (score, SCORE label, streak, combo, gold rush, best) carry a soft dark text shadow (2 px blur, 40 % black, 1 px down) so contrast stays at least 4.5:1 without changing the layout. Other themes have no shadow.

**Piece dealing feel**
- See section 4 (steady 4-cell preference, kindness falls with lines cleared, no tiny pieces on a roomy board).

**Rescaled goals (~3x, after the faster stage step):** achievements `score_1000` "Fifteen Thousand" (15,000) and `score_5000` "High Roller" (75,000), ids kept; daily "Score N points" targets 5,000 / 10,000 / 15,000. Saved best scores are not migrated.
- **Play and Back (owner, 2026-11-09):** Home always shows only Play. Play with an unfinished game saved asks **Resume** or **New game** (`home.resume.dialog`, `home.resume.resume`, `home.resume.new`; dismissing the question stays on Home); with nothing saved it starts a new game directly. Back (the Android button and the arrow, `game.back`) opens a **Paused** dialog with **Resume** (`game.pause.resume`) and **Exit** (`game.pause.quit`); Exit leaves (the game is already saved). A game that is over just leaves. The "Game resumed" note stays.
