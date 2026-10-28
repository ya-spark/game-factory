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
