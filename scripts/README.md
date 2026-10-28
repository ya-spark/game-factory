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
- Refuses to write into a non-empty `--out`. Fails if any `flutter_game_template` string
  remains.
- Writes no secrets: `admob.release` and `play_games` values stay `PLACEHOLDER_*`.
- `--register` appends `id`, `repo: ya-spark/game-<kebab-id>`, `package`, `status: draft` to
  `registry/apps.yaml` (turning `apps: []` into list form) and refuses duplicate ids or
  packages.

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

A stage can only move to `in_progress`, `awaiting_approval` or `done` when all earlier stages are
`done` or `skipped`; `blocked` needs a note saying what is required; a note is cleared when the
status changes without a new one. `next` skips a game whose next stage is `blocked` or
`awaiting_approval`.

