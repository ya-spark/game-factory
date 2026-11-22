# True or false (game package `game_true_false`)

Status: BUILT. The game lives once in `game-factory/games/true_false/` (SH1, owner 2026-11-21); apps and the web list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, the screen in `lib/src/true_false_screen.dart`, test IDs in `GameIds` (game_core) and `lib/src/true_false_ids.dart` where the game has its own. It asks its container only through `GameHost` (`game_core/lib/host`).

The text below was collected from the apps' docs when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## How to play (as shown to the child)
- Read each statement, then choose True or False.
- After each answer you often see why.
- Tips:
  - Read the whole statement before you answer.
  - Look for words like always, never and only.

## Button keys (B-09, 2026-11-22)
- Every button prints its shortcut key, for example "Next (Enter / Space)"; the key works. Rule: Enter and Space go forward, Esc leaves or closes (pauses in play), 1 to 4 choose, Backspace takes back, H hints, P pauses where Space is an action, L leaves a round.
- Choice-kit screens (`ChoiceGameScreen`): Start, Next / See results and Done print "(Enter / Space)"; each answer shows its number cap 1 to 4; the exit control prints L and the pause control Esc; the pause screen prints "Resume (Esc / Space)" and "Leave game (L)"; the hint row adds L leave. Esc on the start and results screens leaves; in play it pauses. (Space-vs-pause is decided by the rewrite spec; unchanged here.)
