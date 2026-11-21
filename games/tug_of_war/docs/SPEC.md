# Tug of war (game package `game_tug_of_war`)

Status: BUILT. The game lives once in `game-factory/games/tug_of_war/` (SH1, owner 2026-11-21); apps and the web list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, the screen in `lib/src/tug_of_war_screen.dart`, test IDs in `GameIds` (game_core) and `lib/src/tug_of_war_ids.dart` where the game has its own. It asks its container only through `GameHost` (`game_core/lib/host`).

The text below was collected from the apps' docs when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## How to play (as shown to the child)
- Answer a question. A right answer pulls the rope towards you; a wrong or slow one lets it slip back.
- Bring the rope all the way to your end to win the round.
- If you see Play with a sibling, two players can take turns on one device, each with their own questions.
- Tips:
  - Read every answer before you choose.
  - On the youngest level a wrong answer never pulls the rope back.
  - Take a breath between questions. A wrong answer is just a chance to learn.

## From the app spec
- Levels: Foundation to Year 6 see every game above except Tug of war, Equation builder and Word search and
- **Start:** a "Play with a sibling" button on the Tug of war start screen. Shown only when Tug of war is
- Family Tug of war shows it once for the first player and marks both players seen. Review rounds (Today's review, Practise my mistakes) open games as normal first plays. Reading rules earns no coins, stars or achievements. Parent area is unchanged. Test IDs: `rules.dialog`, `rules.gotIt`, `rules.button`, `rules.<game id>`.
