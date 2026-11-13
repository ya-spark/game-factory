# Learning engine: minigames, rewards and access (issue 1C1)

> Also see "Shared minigames: Equation builder, Cloze fix, Word grid (issue M4b)" at the end.

Code lives in `lib/engine/` (pure Dart, no Flutter except the screens in `lib/ui/`). Content, release
and the item selector are described in `CONTENT_FORMAT.md`.

## Minigame framework (`lib/engine/minigames/`)

- `MiniGame`: `id`, `title`, `itemTypes`, `minPool` (open items of the child's subject and year
  needed before the game appears), `modes` (`game`, `study`), `access` (`free_with_ads` or `coins`),
  `coinPrice`, and `build(MiniGameContext)` which returns the game's screen (a `Widget` in the app).
- `QuizSession`: the one scoring path for every minigame. `QuizSession.start(...)` picks items with
  the `ItemSelector` from the open items and returns `null` when fewer than `minPool` match.
  `answer(correct:)` records the answer per child (`ChildProgress.record`), awards stars and coins and
  returns an `AnswerResult` (stars, coins, topic completed, explanation). The caller saves
  `session.progress` after each answer (`ProfileStore.setChildProgress`) and adds `result.coins` to
  the wallet. `report` summarises the round.
- `MiniGameRegistry`: the per-app list of `RegistryEntry` (game, optional own modes, year range).
  `offers(...)` returns the games to show for a child: right mode and year, enough open items, each
  marked `locked` with its `price`. Open items come from `OpenItems.compute` (built-in release and
  Full Unlock rules from 1B).
- Quick quiz (`lib/ui/quick_quiz_screen.dart`, `quickQuizGame`): plain multiple choice and true or
  false, Game and Study mode, shows the explanation after every answer, always free.
- Memory match (`memoryMatchGame`, view `lib/ui/minigames/memory_match_screen.dart`, rules
  `lib/engine/minigames/memory_match/rules/`): flip cards to find pairs; one `pairs` item is one board;
  needs 3 open `pairs` items. `MatchLevel` (younger: up to 3 pairs, no timer, never fails; older: up to 6
  pairs, gentle clock; hard: up to 8 pairs, tighter limits, for Craft Champion). Pass `hard: true` to the screen.
- Sort into bins (`sortBinsGame`, view `lib/ui/minigames/sort_bins_screen.dart`, rules
  `lib/engine/minigames/sort_bins/rules/`): drag (or tap a bin) to sort items; one `category` item is one round;
  needs 3 open `category` items. `SortLevel` (younger: 2 bins, no timer, never fails; older: 3 bins and a
  gentle clock; hard: 4 bins). A wrong drop keeps the item.
  Both are not in the template's `appGames`: a Craft app adds `RegistryEntry(memoryMatchGame)` / `RegistryEntry(sortBinsGame)`
  itself. Both score through `QuizSession` (one answer per board or round, stars on first pass). Test IDs:
  `match.*` and `sort.*` in `test_ids.dart`. Level comes from the theme's `InterfaceLevel` unless `level:` is given.

- Series builder (`seriesBuilderGame`, view `lib/ui/minigames/series_builder_screen.dart`, rules
  `lib/engine/minigames/series_builder/rules/`): tap the shuffled tiles in the right order; one `series` item is
  one round; needs 3 open `series` items. `SeriesLevel` (younger: up to 5 tiles, a wrong tile is greyed, no timer,
  never fails; older: up to 8 tiles and a gentle clock; hard: up to 10 tiles). Longer series play a window of the steps.
- Word builder (`wordBuilderGame`, view `lib/ui/minigames/word_builder_screen.dart`, rules
  `lib/engine/minigames/word_builder/rules/`): build the answer from letter tiles with a hint; one `word` item, or
  one `cloze` item (a word per gap), is one round; needs 3 open `word` or `cloze` items. The item's listed answers
  are accepted exactly (case and spaces ignored); the correct spelling is shown after a miss. `WordLevel` (younger:
  wrong letters greyed, the word completes by itself, no timer; older: free building with Check, Undo and Clear and a
  gentle clock; hard: two decoy letters and tighter limits). Tiles come from the item's `letters` (else the answer).
  Both new games take `hard: true` (Craft Champion), report their score through `onScore`, and are added to a Craft
  app's registry by the app (`RegistryEntry(seriesBuilderGame)`, `RegistryEntry(wordBuilderGame)`). Test IDs:
  `series.*` and `wordb.*`.

Adding a minigame: create a `MiniGame`, add a `RegistryEntry` to the app's registry, build its screen
from `ctx.session`, call `ctx.onAnswered` after each answer. Never score outside `QuizSession`.

## Rewards (`lib/engine/rewards/`, `rewards:` in `app.config.yaml`)

Per child, stored in `ChildProgress.rewards`.

- **Stars** are progress only and are never spent: `stars.per_first_pass` (1) for an item passed the
  first time (never again for the same item), `stars.topic_bonus` once when the last item of a topic is
  passed, `stars.streak_bonus` once a day on the first pass of a day with a streak of 2 days or more.
  `stars.enabled: false` (Mind hubs) turns stars off.
- **Coins** are bought by a parent plus a small earned trickle, capped at `coins.weekly_cap_per_child`
  (60) per child per week (weeks start on Monday). Events: finishing a topic (`topic`), a streak
  milestone (`streak_milestones`), a daily goal (`daily_goal_items` passes) and a weekly goal
  (`weekly_goal_items` passes). Each milestone pays once; a payout is cut to what is left of the cap
  and is not retried later. `RewardsEngine.grantCapped` cuts coins from any other earner to the same cap. In Craft apps
  (`content.enabled` and stars on) `ProfileStore` routes the daily reward and the daily challenges
  through it, against the active child's cap (issue 2B1); Mind hubs keep them as uncapped coin earners. Learning content is never bought with coins.

## Access (`minigames:` in `app.config.yaml`)

Each minigame is `free_with_ads` (always playable) or `coins` (locked until unlocked). A locked game
shows its price (`minigames.coin_price`: 200 in Craft apps, 300 in Mind hubs). Unlocking spends coins
and is permanent and saved per device (`SaveData.unlockedGames`,
`ProfileStore.unlockGame`); `MiniGameRegistry.tryUnlock` is the pure rule. Quick quiz and Study mode
are always free. Other prices: avatars 40, colour themes 60, streak freeze 100; coin packs stay 500,
1500 and 4000.

## AI tutor (`lib/engine/ai/`)

`AiTutorService` (`isAvailable`, `explain`) with `NoAiTutorService`, which is never available.
`ai.enabled: false`. No vendor code and no AI feature ships.

## Reading aloud (`lib/core/speech/`, `speech:` in `app.config.yaml`)

`SpeechService` (`isAvailable`, `speak`, `stop`) with `TtsSpeechService` (`flutter_tts`, pinned
exactly, imported only in `tts_speech_service.dart`; `en-AU` preferred, device default otherwise),
`NoopSpeechService` and `FakeSpeechService`. `ReadAloud` reads an item: its recorded `audio` file
first (through a `RecordedClipPlayer` the app supplies), text-to-speech as the fallback or when
the clip is missing or fails. Quick quiz has a speaker button (`quiz.speak`) that reads the
prompt and the numbered options, and a "Read the explanation" button after each answer
(`quiz.speakExplanation`); explanations are never read on their own. `speech.auto_read: true`
reads each new question once on its own (Scout sets it for the younger level). The speaker button
has a tooltip, which is its screen-reader label.

## Compliance profiles and ads (`audience:` in `app.config.yaml`)

| | child (Scout, Ranger) | teen (Champion) | adult (Mind) |
|---|---|---|---|
| Ad treatment | child-directed, max rating G | child-directed, max rating G or PG | not child-directed |
| Banner | menu, pre_game, post_game | same | same |
| Rewarded (Continue) | no | no | yes (optional) |
| Interstitial | never | never | never |
| Parent gate (purchases, coin spends) | yes | yes | no |
| Play Games sign-in | none | optional | optional |

`AudiencePolicy` (in `app_config.dart`) derives the rules and the config parser enforces them
(for example `play_games.enabled` is forced off in a `child` app, `rewarded_enabled` off outside
`adult`, child-directed on for `child` and `teen`). `AdService.buildBanner(AdPlacement)` takes
`menu`, `pre_game` or `post_game`: there is no in-play placement, and no interstitial code exists.
`AdService.showRewarded(RewardedPlacement.revive)` is the only full-screen ad.

CI checks: `scripts/profile_check.sh` (self-test `scripts/test_profile_check.sh`) rejects unsafe
configs; `scripts/ad_safety_check.sh` (self-test `scripts/test_ad_safety_check.sh`) also rejects
any interstitial, rewarded ads in a `child` or `teen` app, a banner built outside the ad service
and a shop without the parent gate in a `child` or `teen` app.
`ads.interstitial_*` pacing keys and `lib/core/ads/ad_frequency.dart` are legacy and unused.

## Tests
`test/ui/quick_quiz_speech_test.dart` (recorded audio first, text-to-speech fallback, auto-read,
explanations on request, labels), `test/core/profiles_ads_test.dart` (profile rules, no in-play
placement, no interstitial).

`test/engine/minigames_test.dart` (scoring, star rules, weekly cap per child, access, minimum pool,
config, AI tutor) and `test/ui/quick_quiz_test.dart` (both modes, 150 percent text, screen-reader
labels).

## Generator profiles and the engine in each game (issue 1C3)
`scripts/new_game.py --profile puzzle|craft|mind` (factory repo). `puzzle` is the plain template
(the Block Puzzle game). `craft` and `mind` generate without the puzzle game: Home shows a hub
placeholder (`home.hub`), `content.enabled` is true, and `audience:` and the ad switches follow
`--audience` (craft: `child` or `teen`; mind: `adult`). Mind also sets `rewards.stars.enabled: false`
and `minigames.coin_price: 300`. A new repo's `check-code.yml` only runs when the repository variable
`CI_ENABLED` is `true` (`--ci on` leaves it unguarded); the owner turns it on after the first
working build.

### The engine is vendored
The engine is `lib/engine`, `test/engine`, `test/fixtures` and `tool/content_cli.dart`. Every
game holds its own copy with `package:<game>/` imports. **Never edit it in a game**: change it in
the factory template, then sync. `engine.lock` holds a SHA-256 of those files (names and bytes,
package name normalised); `python3 scripts/engine_lock.py check` (a CI step) fails when a game's
engine differs from its lock.

### Running a sync (one `[change]` issue per sync)
1. In `game-factory`, change the engine in `template/flutter-game-template`; format, analyze, test.
2. Push the factory `main`; update its pin in `game-studio`.
3. Open one `[change]` issue in `game-studio` listing the games, e.g. "Sync the engine into
   craft_lowteen, craft_preteen".
4. The run does, per game: `python3 game-factory/scripts/sync_engine.py apps/game-<id>`; then in
   that repo `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`; pushes the
   game's `main` and moves the pin. A game that fails its checks is left alone and reported.
5. `python3 game-factory/scripts/sync_engine.py --check apps/game-<id> ...` lists games behind the
   template or edited locally (exit 1). Run it before and after.

## Modes, shell and card data (issue 2B1)

- Each child has a `mode` (Game by default, remembered) and a parent `lockedMode`; `ProfileStore.setChildMode`
  refuses while locked. The theme follows the active child's mode and level (`AppTokens.levelForYear`).
- `lib/ui/app_shell.dart` is the home of a learning game with a design: top bar (mode toggle, coins),
  tabs by mode (Game: Play, Challenges, Shop; Study: Learn, Progress, Revise; Mind: Games, Challenges, Shop).
  Study pages (Learn, Progress, Revise) are in `lib/ui/tabs/study_tab.dart` (2B2). A learning game without a design keeps `HomeScreen`.
- `lib/ui/game_registry.dart` (`appGames`) is the app's minigame list: add each game there.
- Card data: `TopicResult.accuracy`, `ChildProgress.games` (passed and best score per game),
  `masteryOf` (rule from `design/tokens.json`), `ChildProgress.topicToRevise` (for "try next").
- Shop: `shopItems` (avatars and colour themes, coins), `ProfileStore.buyItem` / `equipItem`.
  The chosen colour theme is stored per child; applying it to the theme comes with 2B2.

## Shared minigames: Door runner and Balloon pop (issue M1)

- Rules (pure Dart): `lib/engine/minigames/door_runner/rules/` and `balloon_pop/rules/`, with the
  shared `MiniGameLevel` and `scoreForAnswer` in `minigame_level.dart`. The random source is injected.
- Views: `lib/ui/minigames/`. `ChoiceGameScreen` is the shared start, play and results screen (scoring
  through `QuizSession`, timer, read aloud, banners on the start and results screens only); each game only
  supplies its options and draws its field (doors, balloons) in code with `ThemeTokens` colours.
- Door runner plays `mcq`; Balloon pop plays `mcq` and `numeric` (the answer plus nearby numbers as
  balloons). Both are Game mode only, free, `minPool` 4, and are in `appGames`. Champion uses
  `doorRunnerGameFor(harder: true)` / `balloonPopGameFor(harder: true)`.
- Level comes from the items' year: Foundation to Year 2 is younger (no timer, no failing, a wrong pick is
  greyed out and the child tries another, so no first-pass star after a wrong try); Year 3 and up is older
  (gentle timer, a miss or time out shows the answer and moves on, streak bonus).
- `MiniGameContext.onScore` reports the game's own score; the Play tab stores the best one per game.
- Not yet: item pictures (`image`) are not shown in these games, since the UI has no pack image loader.

## Shared minigames: Equation builder, Cloze fix, Word grid (issue M4b)

All three are free with ads, play in Game and Study mode, appear only when `minPool` (4) items of their
types are open, and use `...For(harder: true)` for Champion. Rules are pure Dart under
`lib/engine/minigames/<game>/rules/`; views are in `lib/ui/minigames/`. Study mode has no timer and lets
the child retry after a wrong try.

- **Equation builder** (`equationBuilderGame`, `equation_builder_screen.dart`): plays `numeric` items
  whose answer is a whole number from 0 to 999. The game builds the tiles from a known solution plus
  distractors (younger: + and −; older: adds ×; harder: adds ÷). `evaluateTokens` computes with the usual
  order; `equationHitsTarget` accepts **any** expression that equals the target. It reuses
  `ChoiceGameScreen` (timer, score, results), with the equation field as the play field.
- **Cloze fix** (`clozeFixGame`, `cloze_fix_screen.dart`): plays `cloze` items (first gap blanked, other
  gaps filled, wrong words borrowed from other items' gaps) and `mcq` items whose topic or id contains
  `grammar` or `punctuation` (choose the corrected sentence). `clozeFixPlays` is the filter.
- **Word grid** (`wordGridGame`, `word_grid_screen.dart`): builds a word search or a crossword from the
  `word` items of the round (`answer` 3 to 10 letters only; spelling is matched exactly as listed, in any
  case). The child picks which on the start screen. Word search: tap the first and last letter, or drag;
  seeded placement, overlaps only on equal letters. Crossword: tap a clue, then its letters in order.
  The grid always holds a prefix of the round's items, so answers are recorded in round order when the
  round ends (found cleanly: right; not found or needed retries: not a first pass).
- Test IDs: `mgTile`, `mgSlot`, `mgCheck`, `mgClear`, `mgUndo`, `mgGiveUp`, `mgStartAlt`, `mgCell`,
  `mgClue`, `mgLetter`, `mgGrid` in `lib/ui/test_ids.dart`.
- Tests: `test/engine/minigames/m4b_rules_test.dart`, `test/ui/minigames/m4b_screens_test.dart`.
