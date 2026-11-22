# Flash review (game package `game_flash_review`)

Status: BUILT. The game lives once in `game-factory/games/flash_review/` (SH1, owner 2026-11-21); apps and the web list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, the screen in `lib/src/flash_review_screen.dart`, test IDs in `GameIds` (game_core) and `lib/src/flash_review_ids.dart` where the game has its own. It asks its container only through `GameHost` (`game_core/lib/host`).

The text below was collected from the apps' docs when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## How to play (as shown to the child)
- Look at the card, then flip it to see the answer.
- Tap "I knew it" or "Not yet". Cards you miss come back to practise later.
- Tips:
  - Try to answer in your head before you flip.
  - Be honest. "Not yet" just means more practice.

## From the app spec
- Scout (youngest level): the round uses Flash review cards (flip, then "I knew it" or "Not yet"), no timer and no failing wording. "I knew it" counts as a correct answer and "Not yet" as a wrong one for the clear rule.
- Younger level (Scout): Flash review cards; "I knew it" counts as correct, "Not yet" as wrong. Ranger and Champion: the Quick quiz, multiple-choice items only.

## Keyboard (K1, 2026-11-22)
- Enter starts and flips the card, then 1 or right is "I knew it" and 2 or left is "Not yet". Esc leaves the game.
- Space (the shared pause key) is the same as Enter on the start screen, flips the card and leaves on the results (U2, 2026-11-22; the game has no pause); the key hints print "Enter / Space" there.
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).

## Button keys (B-09, 2026-11-22)
- Every button prints its shortcut key, for example "Next (Enter / Space)"; the key works. Rule: Enter and Space go forward, Esc leaves or closes (pauses in play), 1 to 4 choose, Backspace takes back, H hints, P pauses where Space is an action, L leaves a round.
- Start, Flip the card and Done print "(Enter / Space)"; I knew it prints "(1 / →)", Not yet "(2 / ←)"; Q reads the card (the speaker button prints it); the back arrow prints Esc.
