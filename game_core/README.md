# game_core

The shared foundation of every game: the content and quiz engine (pure Dart, no Flutter, no vendor
SDK). Decision SH1 (owner, 2026-11-21): a game is a folder in `../games/<game>/`; apps and the web
are containers that list games, bring content, theme, real services and a shell. Nothing is copied.

- `lib/engine/`: content packs, quiz session, rewards, mastery, skills, stats, minigame contracts.
- `lib/cli/content_cli.dart` and `bin/content_cli.dart`: the content tool, run with
  `dart run game_core:content_cli COMMAND` from a project root.
- `test/`: engine tests; `test/fixtures/topics.yaml` is a snapshot of the topic list so the tests
  run on their own (refresh it from `game-content/topics.yaml` when topics change).

Use it from a container with a git dependency on one commit of `game-factory`:

    game_core:
      git: {url: https://github.com/ya-spark/game-factory.git, path: game_core, ref: <sha>}

Local work: an uncommitted `pubspec_overrides.yaml` with `dependency_overrides: game_core: {path: ...}`.
Tests that need an app's save data, profile or config stay in the app (they test the app's core).
