# game_door_runner

Door runner: the runner stands in a lane and the doors come down, each carrying an answer. One game
in `game-factory/games/`; apps and the web are containers that list it (SH1, owner 2026-11-21).

- Spec: `docs/SPEC.md` (the only copy). Public API: `lib/door_runner.dart` (`doorRunnerGame`,
  `doorRunnerGameFor(harder:)`, `DoorRunnerIds`).
- A container depends on this package and on `game_core` at one pinned commit of `game-factory`:

      dependencies:
        game_door_runner:
          git: {url: https://github.com/ya-spark/game-factory.git, path: games/door_runner, ref: <sha>}
      dependency_overrides:
        game_core:
          git: {url: https://github.com/ya-spark/game-factory.git, path: game_core, ref: <sha>}

  and provides a `GameHost` (`GameHostScope`) above its games. The override keeps one `game_core` for the
  whole app; this package declares `game_core: ^1.0.0` and `pubspec_overrides.yaml` points it at
  `../../game_core` for work inside this repo.
- Previews: `DOOR_PREVIEW=1 flutter test --update-goldens test/door_runner_ui_test.dart` writes images to
  `test/previews/` (git-ignored).
