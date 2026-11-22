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
- Levels: Foundation to Year 6 see every game above except Tug of war, Bridge builder and Word search and
- **Start:** a "Play with a sibling" button on the Tug of war start screen. Shown only when Tug of war is
- Family Tug of war shows it once for the first player and marks both players seen. Review rounds (Today's review, Practise my mistakes) open games as normal first plays. Reading rules earns no coins, stars or achievements. Parent area is unchanged. Test IDs: `rules.dialog`, `rules.gotIt`, `rules.button`, `rules.<game id>`.

## Two players: Head to head (R2, BUILT 2026-11-21; shared rules in `game-factory/docs/TWO_PLAYER.md`)
- **Mode.** A second button next to "Play with a sibling" (that turn mode, with two profiles and their own questions, is unchanged): **Head to head**, windows 600 dp and wider. Both players see the same question and the same options at the same time and race to answer on their own keys: player 1 presses 1 to 4, player 2 presses Z X C V (the options are numbered 1 to 4 in the same order for both; each option shows both keys).
- **Rope.** The marker starts in the middle. The first player to press the right option pulls the rope one step toward their end and the question ends. A wrong press locks that player out of this question (their keys grey out, a small "try the next one" cue); the other player may still answer. Older levels: a wrong press also pulls the rope one step toward the opponent (`pullsBack`); younger level: a wrong press only locks that player out and never pulls. When both players are locked out, or the timer ends (older levels, `secondsPerQuestion`), the question ends with no pull and the right answer is shown. The next question follows after a short pause (Enter from either player skips it).
- **Rounds.** Reaching an end of the rope (`reach` steps: 3 younger, 4 older, 5 harder) wins the round for that player; the rope returns to the middle; first to 2 rounds wins (`familyRoundsToWin`). Questions that run out end the game: most rounds wins, then the rope position, then "A draw!".
- **Controls.** Pick: 1 to 4 / Z X C V. Space or Esc pause. Q is unused. No question dialog.
- **Layout.** The question across the top, the options in the middle each carrying both players' key caps (amber left, green right); the rope across the bottom with a marker per player end; under it the two round tallies. Centered, max 780 wide.
- **Pure rules.** `lib/src/rules/tug_head_to_head_rules.dart`: `HeadToHeadRun` reuses `TugOfWarRun` for the rope (positive toward player 1 on the right, negative toward player 2 on the left, matching the keyboard) and adds the two players, per-question lock-outs, `press(player, correct)` returning ignored, pulled or locked, `timeUp()`, `roundWinner`, `winner` and `decideWhenOut()`. View: `lib/src/tug_head_to_head_screen.dart` (`TugOfWarHeadToHeadScreen`); the button is added to the start screen by `TugOfWarScreen(offerHeadToHead: true)` (the registry entry does).
- **As built.** Start screen: a Head to head button on windows 600 dp wide and up, beside the container's sibling button. Its own intro shows both players' keys and starts with Enter. Options are not tappable (two keyboards' worth of play). Between questions the answer stays 1.6 s (Enter skips it). Play again restarts the game (no starter to swap). The rope and the key caps are mirrored so player 1 (circle, right-hand keys) is on the right and player 2 (square, left-hand keys) on the left.
- **Test IDs.** `TugIds` in `lib/src/tug_of_war_ids.dart`: `tug.mode.headtohead`, `tug.p1.score`, `tug.p2.score`, `tug.p1.locked`, `tug.p2.locked`, `tug.winner`, `tug.again`, `tug.leave` and the screen's own ids.
- **Acceptance (one named test each).** First right answer pulls toward that player; a wrong press locks only that player; both locked ends the question; older wrong press pulls back and younger does not; the timer ends the question; two rounds win the game; questions running out decides by rounds then rope; both players' keys in the same frame resolve in the order the keyboard reports them (the first press wins); nothing is written to the session; pause stops the timer; 200 percent text.

## Keyboard (U2, 2026-11-22)
- Head to head: Space starts from the intro, goes on between questions and plays again from the results (the same as Enter); while a question is open Space pauses. The choice-game kit does the same (Next after a result, start, leave).

## Button keys (B-09, 2026-11-22)
- Every button prints its shortcut key, for example "Next (Enter / Space)"; the key works. Rule: Enter and Space go forward, Esc leaves or closes (pauses in play), 1 to 4 choose, Backspace takes back, H hints, P pauses where Space is an action, L leaves a round.
- Choice-kit screens (`ChoiceGameScreen`): Start, Next / See results and Done print "(Enter / Space)"; each answer shows its number cap 1 to 4; the exit control prints L and the pause control Esc; the pause screen prints "Resume (Esc / Space)" and "Leave game (L)"; the hint row adds L leave. Esc on the start and results screens leaves; in play it pauses. The start screen's Head to head button prints H and H starts it. Head to head: Start and Play again print "(Enter / Space)", Leave prints "(Esc / L)", L leaves from anywhere.
