# Flutter game template

Flutter + Flame Android game template of the game-factory. Sample game: **Block Puzzle**
(8x8 grid, three pieces, drag and drop). Game repos are generated from this folder.

```
lib/core/        service interfaces + v1 implementations (ads, billing, saves, retention, ...)
lib/core/retention/   daily reward, streaks (+freeze), daily challenges, achievements (pure Dart)
lib/game/rules/  pure-Dart game rules (no Flutter/Flame/Android imports)
lib/game/flame/  Flame renderer + drag and drop
lib/ui/          menus, shop, settings, daily reward, challenges; test IDs in test_ids.dart
app.config.yaml  package name, display name, theme, platforms, AdMob IDs (placeholders), pacing
products.yaml    in-app products (remove ads, coin pack)
store/google-play/  listing, privacy policy, data safety drafts
.github/workflows/  ci.yml, release.yml (copy into each game repo)
```

## Commands

```bash
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
bash scripts/ad_safety_check.sh
flutter test integration_test -d <emulator>   # bot plays the first moves
flutter run                                   # debug: TEST ads only
```

## Rules

See the factory repo's `CLAUDE.md`. In short: interfaces only (no vendor SDK in game/UI code),
test IDs on every interactive widget, test AdMob IDs in debug, no secrets in the repo.

## Stubs

Play Games sign-in, saved games, achievements and leaderboards are **stubs** that fall back to
local storage (`PlayGamesIdentityStub`, `PlayGamesCloudSaveStub`, `PlayGamesLeaderboardStub`).
Analytics and remote config are no-ops.
