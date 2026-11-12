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

## The host adapter (hub-owned, never synced)
Per game, `lib/games/<game>/host/` holds what the copied screens call "Services" and "ProfileStore",
mapped onto the hub:
- `services.dart`: `Services` (hub services, `HostConfig`, `HostAds`, leaderboard no-op, analytics, share) and `ServicesScope`.
- `profile_store.dart`: keeps only the game's own data (best score, boosts or power-ups, theme, control
  scheme, ghost, autosave, stats, achievements) in its own save (`game.<game>.save`). **Coins, Remove
  Ads, sound, volume, ambience, voice, vibration, left-handed mode, tips and the day streak are the
  hub's**, so one balance and one Remove Ads purchase serve every game. It reports each finished
  game's score through `onScore` so the Games tab shows stars and the best score.
- `ad_service.dart` (`HostAds`): rewarded ads only for the Continue (`revive`, adult profile, never
  with Remove Ads owned); any other placement answers "no ad" (so Blockfall's power-up refill ad
  and Block Puzzle's boost refill ad give nothing, and with Remove Ads owned the standalone's own rule
  grants them). No interstitials. No banner during play: the hub's banners show on the menu and results.
- `routes.dart`: `/shop` resolves to the hub's shop (`lib/host/host_routes.dart`); the games have no shop of their own.
- `<game>_host.dart`: the widget the Games tab opens.
- `test/games/<game>/host/fake_services.dart`: the standalone's `Services` test helper over the hub's fakes.

## Status
- Mind Ember: `block_puzzle` (free with ads) and `blockfall` (coin-locked, 300 coins) are copied,
  adapted, registered (`lib/ui/game_registry.dart`) and tiled in the Games tab. Rules, game and
  `theme_test` tests of Block Puzzle, and the rules and game tests of Blockfall, run in the hub
  (Blockfall's `test/ui/*` widget tests are not copied yet).
- Not yet: the standalone widget/e2e tests that need the standalone's own shop and ads (not copied),
  and Wingy in Presto.
