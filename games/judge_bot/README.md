# game_judge_bot

Judge bot (was True or false): one of the games in `game-factory/games/`; apps and the web are containers that list it (SH1, owner 2026-11-21).

- Spec: `docs/SPEC.md` (the only copy). Public API: `lib/judge_bot.dart` (`JudgeBotScreen`, `judgeBotGame`, rules, ids, art colours).
- Own screen (not the choice kit): `lib/src/judge_bot_screen.dart`; rules in `lib/src/rules/judge_rules.dart` (pure Dart); code art in `lib/src/ui/judge_art.dart`.
- A container depends on this package and on `game_core` at one pinned commit of `game-factory` (see `../door_runner/README.md` for the pubspec lines) and provides a `GameHost`.
