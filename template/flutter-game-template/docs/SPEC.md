# Game spec

> Template. Filled in by the spec agent after the Q&A with the user.

## 1. Pitch
One paragraph: what the game is, who it is for.

## 2. Core loop
What the player does second-to-second, minute-to-minute, session-to-session.

## 3. Rules and scoring
Pure-Dart rules (lives in `lib/game/rules/`). List every rule, edge case and the scoring formula.

## 4. Content
Levels / pieces / modes. Difficulty curve.

## 5. Retention
Daily reward cycle, streaks (+freeze), daily challenges, achievements. Which are enabled.

## 6. Monetization
Ads: banner placement, interstitial triggers, rewarded placements. IAP: see `products.yaml`.

## 7. Screens
Menu, game, shop, settings, daily reward, ... with test IDs (`lib/ui/test_ids.dart`).

## 8. Art and audio
Style, palette, asset list (every asset must be in `assets/LICENSES.md`).

## 9. Play Games
Leaderboards / achievements to create (IDs go in `app.config.yaml`).

## 10. Store listing
Title, short description, full description, category, content rating notes.

## 11. Out of scope
Explicitly not doing: backend, Firebase, multiplayer, ...

## 12. Acceptance criteria
Testable statements the test agent turns into tests.
