# scripts

Factory scripts. Python 3 standard library only (no pip dependencies).

## new_game.py

Generates a new game project from `template/flutter-game-template/`.

```bash
python3 scripts/new_game.py --id my_game --name "My Game" \
  --package com.yaspark.mygame --seed-color "#3366CC" --out ../game-my-game [--register]
```

- Validates inputs: `--id` snake_case, `--package` a valid Android package (>= 2 lowercase
  segments, no reserved words), `--seed-color` `#RRGGBB`, `--name` without quotes, `#` or
  backslashes (the Gradle config reader is line-based).
- Copies the template (skipping `.dart_tool`, `build`, `.idea`, `*.iml`,
  `android/local.properties`) and rewrites `app.config.yaml` (id, display name, package, seed
  color), the Dart package name and all `package:flutter_game_template/` imports, the Android
  `namespace` and the Kotlin `MainActivity` package and directory. Workflows end up in
  `<out>/.github/workflows` (the new repo root is the Flutter project).
- Puts the game name in the heading of `docs/SPEC.md`, then checks the copy carries every
  template feature (audio, share, tips, game over panel, parent gate and shop): the files, the
  `share:` config key, the test IDs in `lib/ui/test_ids.dart`, the four products in
  `products.yaml` and the `AD_ID` removal in the Android manifest. A missing one is a
  generator bug and stops the run.
- Placeholders a game fills in itself: voice line names in `lib/core/audio/voice_arbiter.dart`
  and the `assets/voice/` files, tips in `lib/game/tips.dart`, share card look in
  `lib/ui/share_card.dart`, the coin letters in `CoinIcon`, and the real AdMob and Play IDs
  (`PLACEHOLDER_*`).
- Refuses to write into a non-empty `--out`. Fails if any `flutter_game_template` string
  remains.
- Writes no secrets: `admob.release` and `play_games` values stay `PLACEHOLDER_*`.
- `--register` appends `id`, `repo: ya-spark/game-<kebab-id>`, `package`, `status: draft` to
  `registry/apps.yaml` (turning `apps: []` into list form) and refuses duplicate ids or
  packages.

- `--design <app_id>` (issue 02A): copies only that app's design files (`design/<app_id>/`, shared
  `tokens.json`, icons, its font) into `assets/design/` and `assets/fonts/`, writes the `pubspec.yaml`
  asset and font entries, the `assets/LICENSES.md` rows and `theme.design`. Default: the game id when
  it is one of `craft_lowteen`, `craft_preteen`, `craft_highteen`, `mind_1`, `mind_9` (craft and mind
  profiles); when the id is not one of those (a sample or a new app) the profile and audience pick the
  default look (craft child `craft_lowteen`, craft teen `craft_highteen`, mind `mind_1`). The plain puzzle
  profile has none and drops the three design tests (`design_theme_test`, `kit_test`, `themed_screens_test`).
  Generated games never contain `design/`.
- Flags: `--profile puzzle|craft|mind` (default `puzzle` = the plain template). `craft` and `mind`
  delete the Block Puzzle game (`lib/game/{flame,rules,layout.dart}`, game screen and game over
  panel, their tests and the bot), keep `lib/game/tips.dart` and `share_card.dart`, and put a hub
  placeholder (`home.hub`) on Home. `--audience child|teen|adult` (craft: child or teen, mind:
  adult; default child for craft, adult otherwise) sets `audience:`, `ads.child_directed`,
  `max_ad_content_rating` (G child, PG teen and adult) and `rewarded_enabled: false` for child and
  teen; `craft` and `mind` set `content.enabled: true`, mind also `rewards.stars.enabled: false`
  and `minigames.coin_price: 300`. `--ci on|off` (default `off`): off adds
  `if: ${{ vars.CI_ENABLED == 'true' }}` to the `check` job and the same condition to the manual
  emulator job in the generated `ci.yml` (the template file is untouched). `--repo owner/name`
  overrides the registry repo of `--register`.
- Writes `engine.lock` (see `template/flutter-game-template/scripts/engine_lock.py`).

## sync_engine.py

Keeps every game's copy of the engine identical (`docs/ENGINE.md` in the template).

```bash
python3 scripts/sync_engine.py ../game-craft-lowteen ../game-mind-1   # copy the engine
python3 scripts/sync_engine.py --check ../game-craft-lowteen          # exit 1 if behind or edited
```

Copies `lib/engine`, `test/engine`, `test/fixtures` and `tool/content_cli.dart`, rewrites the
package name, removes engine files the template dropped, copies `scripts/engine_lock.py` and writes
`engine.lock`. Tests: `scripts/tests/test_sync_engine.py`.

Tests: `python3 -m unittest discover -s scripts/tests`. CI (`template-ci` job `generator`)
also generates a sample game and runs analyze, format, tests, safety scripts and a debug APK
build in it.

## pipeline.py

Per-game stage tracking. State is one file per game, `registry/games/<id>.json`, with the nine
stages (spec, repo, coder, asset, test, build, listing, publish, monitor), each `pending`,
`in_progress`, `awaiting_approval`, `done`, `blocked` or `skipped`, plus PR link, note and date.

```bash
python3 scripts/pipeline.py init my_game --repo ya-spark/game-my-game --package com.activemindcraft.mygame
python3 scripts/pipeline.py status [my_game] [--json]
python3 scripts/pipeline.py next [--json]     # first actionable (game, stage, agent)
python3 scripts/pipeline.py set my_game spec awaiting_approval --note "SPEC.md written"
```

`pipeline.py more-games` prints the `more_games:` block (the "More games" list bundled in each
game's `app.config.yaml`) from `registry/games/*.json`, one entry per game with a package. New
entries are `hidden` with a TODO tagline. `/new-app` runs it so every other game lists the new one;
`/change-app` merges it into each game (keeping existing taglines and statuses). It never pushes.

A stage can only move to `in_progress`, `awaiting_approval` or `done` when all earlier stages are
`done` or `skipped`; `blocked` needs a note saying what is required; a note is cleared when the
status changes without a new one. `next` skips a game whose next stage is `blocked` or
`awaiting_approval`.

