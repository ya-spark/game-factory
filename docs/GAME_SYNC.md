# Game sync: retired (SH1, owner 2026-11-21)

The standalone games (Wingy, Block Puzzle, Blockfall) are no longer copied into the Mind hubs. Each game
is one package in `game-factory/games/<game>/`; the standalone app and the hub are both containers that
show it and provide a `<Game>Services` (profile, ads, share, leaderboard, analytics, config) through
`<Game>ServicesScope`. A fix to a game is made once, in the package, pushed to `game-factory` `main`, and
reaches every container when its `ref` moves.

`scripts/sync_game.py`, `game.lock` and the hub copies (`lib/games/<game>/`) are gone. What stays in a hub is
its adapter (`lib/host/<game>/`: coins, Remove Ads, ad pacing, share and analytics come from the hub) and
the tests of that adapter. Rules that still hold for a hub adapter (from the old sync):
- Rewarded ads only for the Continue (`revive`, adult profile, never with Remove Ads owned); any other
  placement answers "no ad". No interstitials (the adapter answers `maybeShowInterstitialAfterGameOver`
  with a no-op, the one name `scripts/ad_safety_check.sh` allows there). No banner during play.
- `/shop` resolves to the hub's shop.
- Coins, Remove Ads, sound, volume, ambience, voice, vibration, left-handed mode, tips and the day streak
  are the hub's, so one balance and one Remove Ads purchase serve every game.

See `docs/FEATURE-SPECS.md` item SH1 in game-studio and `games/<game>/README.md`.
