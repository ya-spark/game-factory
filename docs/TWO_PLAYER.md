# Two players on one device (R2 spec, DRAFT 2026-11-21)

Games: Tug of war, Memory match, Door runner, Blockfall (chosen by fit, owner 2026-11-21). The rules of each mode are in the game's own `docs/SPEC.md` ("Two players"); this page holds what they share. Status: Memory match, Tug of war and Door runner built, Blockfall DRAFT. Decisions marked **(default)** are my recommendation and stand until the owner changes them.

## Shared rules
1. **Choosing.** Each game's start screen has two buttons, "1 player" and "2 players" (the first is the default and has focus). The simultaneous modes (Tug of war head to head, Door runner race, Blockfall versus) need a keyboard each side, so they are offered only on windows 600 dp and wider; Memory match (turns) is offered everywhere, touch included. **(default)**
2. **Who is who.** Player 1 is amber, player 2 is green (`ColorScheme.primary` and `secondary` of the container, so the app's own theme decides the exact colours; never colour alone: each player also has a name tag "Player 1" / "Player 2" and a shape marker, a circle and a square). Names are not asked.
3. **Keys.** Player 1 uses the arrows, Enter and 1 to 4; player 2 uses W A S D, F and Z X C V (`docs/KEYBOARD.md`, remappable). Space pauses and Esc pauses, for both. In turn-based modes only the player whose turn it is can act; the other player's keys do nothing. The hints under the game show both players' keys, each in their colour.
4. **Same questions, same fate.** Both players get the same question, the same pieces, the same board layout, so a win is about play, not luck. The level is the active child's level for both players (the gentler rules if the child is on the younger level).
5. **No progress, no rewards.** A two-player round is play for fun: no stars, coins, achievements, streak, mastery or Constellation change, no leaderboard score, nothing written to the child's progress. Answers still use the item pool but are not recorded. **(default; open question 1)**
6. **Ads.** None during play; the results screen can show the frame's ad (`GameFrame`, `showAds` true there).
7. **Pause.** Either player can pause; the pause screen has Resume and Leave. Pausing stops every timer and every falling piece.
8. **Results.** A winner screen ("Player 2 wins!"), the final tally, **Play again** (swap sides: the other player starts or takes the left side) and **Leave**. A draw says "A draw!". Kind words for both, no "loser". The result is spoken by the screen reader.
9. **Accessibility.** Everything works from the keyboard; every state change is announced in a live region ("Player 1 scored", "Player 2's turn"); text holds at 200 percent; reduce motion removes shaking and flying score text.
10. **Test IDs.** Per player: `<game>.p1.score`, `<game>.p2.score`, `<game>.mode.one`, `<game>.mode.two`, `<game>.winner`, `<game>.again`; each game adds its own.
11. **Pure Dart rules.** Every mode's rules are a pure-Dart class in the game's `lib/src/rules/` (no Flutter), tested on the VM with a seeded random.

## Order of building (one game at a time, each green before the next)
1. Memory match (turns): BUILT 2026-11-21 (game-factory, local). Smallest, no new input model.
2. Tug of war (head to head): BUILT 2026-11-21 (game-factory, local). Same question for both, first right answer pulls.
3. Door runner (race): BUILT 2026-11-21 (game-factory, local). Two runners in one field.
4. Blockfall (versus): two wells, garbage rows, the largest.

## Open questions (my default stands until answered)
1. Should answers in a two-player round count toward the child's skills and rewards? Default no (rule 5): whose child is it, and a race rewards speed, not learning.
2. Tug of war: the "Play with a sibling" turn mode (two profiles, separate questions) stays as it is and "Head to head" is a second button next to it. Default yes.
3. Blockfall versus needs a window of at least about 900 dp wide (two wells with the hint rows); below that the button is hidden. Default yes.
