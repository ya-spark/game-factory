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
