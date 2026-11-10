# Learning engine: minigames, rewards and access (issue 1C1)

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
  and is not retried later. `RewardsEngine.grantCapped` cuts coins from any other earner to the same cap. Not done yet:
  routing the template's daily reward and challenges through it in Craft apps (they still pay
  uncapped and per device); Mind hubs keep them as uncapped coin earners. Learning content is never bought with coins.

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
and `minigames.coin_price: 300`. A new repo's `ci.yml` only runs when the repository variable
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
