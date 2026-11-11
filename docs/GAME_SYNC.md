# Game sync: standalone games inside the Mind hubs

Decision (owner, 2026-11-11, `game-studio/docs/DECISIONS.md`): Block Puzzle, Blockfall and Wingy stay
standalone apps and are **copied** into the Mind hubs (Ember: Block Puzzle, Blockfall; Presto: Wingy).
The standalone app is the source of truth.

## How a fix reaches a hub
1. Fix the standalone game (its `docs/SPEC.md` first when behaviour changes) and push its `main`.
2. One sync issue in `game-studio`: run
   `python3 game-factory/scripts/sync_game.py apps/game-block-puzzle apps/game-mind-1 block_puzzle`,
   run the hub's checks, push the hub's `main`, move the pins.
3. `--check` reports a copy that is behind the source commit or edited locally (exit 1). Never edit
   files under `lib/games/<game>/` or `test/games/<game>/` in a hub; change the source and sync.

## What the script does
- Copies the files listed per game in `GAMES` (in `sync_game.py`) to `lib/games/<game>/`,
  `test/games/<game>/`; assets keep their path. Dart is formatted, so the hub's format check passes.
- Rewrites every import: inside the copy stays relative, a standalone-only file (its own services,
  profile, shop, ads) maps to `lib/games/<game>/host/<file>` (the hub's adapter, never synced), any
  other import is an error.
- Rewrites `'lib/...'` path literals in copied tests so source-purity tests look at the copy.
- Writes `lib/games/<game>/game.lock` (source commit, hash, file list).

## Status
- `block_puzzle` in Mind Ember, stage 1: rules, Flame game, themes, audio, save data, retention
  engines, three screen widgets and the game's own tests (all passing in the hub).
- Not yet: the host adapter (coins, Remove Ads, ad pacing, theme) and the copied game screens, the
  tiles in the hub registry, Blockfall in Ember and Wingy in Presto. `theme_test.dart` (widget test on
  the standalone's own `Services`) is excluded until the adapter exists.
