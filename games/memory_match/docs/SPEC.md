# Memory match (game package `game_memory_match`)

Status: BUILT. The game lives once in `game-factory/games/memory_match/` (SH1, owner 2026-11-21); apps and the web list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, the screen in `lib/src/memory_match_screen.dart`, test IDs in `GameIds` (game_core) and `lib/src/memory_match_ids.dart` where the game has its own. It asks its container only through `GameHost` (`game_core/lib/host`).

The text below was collected from the apps' docs when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## How to play (as shown to the child)
- Flip two cards at a time to find the matching pairs. Each pair is a question and its answer.
- Match every pair to finish the board.
- Tips:
  - Try to remember where each card is.
  - Younger levels have no timer. Older levels add a gentle clock.

## Rules and behaviour (from the app's engine notes at the move)
- Memory match (`memoryMatchGame`, view `lib/ui/minigames/memory_match_screen.dart`, rules

## Two players (R2 spec, DRAFT; shared rules in `game-factory/docs/TWO_PLAYER.md`)
- **Mode: turns on one board.** "2 players" on the start screen (touch and keyboard, any window). The players take turns: the active player turns two cards. A match: the pair stays face up in the active player's colour, they score 1 and go again. A mismatch: both cards turn back after the usual delay and the turn passes. The board is the same one item's pairs as in one player; with several boards in a round the starting player alternates each board.
- **Scoring and end.** Most pairs on the board wins it; the round is the item list as in one player; most boards won wins the round, equal boards is decided by total pairs, then "A draw!". No timer and no misses limit in this mode (the clock and `missesPerPair` are off).
- **Controls.** The active player's keys move that player's cursor (arrows or W A S D) and turn a card (Enter or F); touch taps work for the active player. A cursor is drawn only for the active player, in their colour with their shape marker. A banner over the board says "Player 1's turn" (live region); a matched card carries a coloured corner and a marker so colour is not the only cue.
- **Layout.** The board is centered (`GameFrame`); under it the two score chips (name tag, marker, pairs) with the active one highlighted and a pause button between; on a phone the chips sit above the board.
- **Pure rules.** `lib/src/rules/memory_match_turns.dart`: `MemoryTurnsRun` holds the board, whose turn it is, pairs per player, `flip(index)` returns the outcome (first card, match, mismatch, ignored) and passes the turn on a mismatch; a seeded board for tests.
- **Test IDs.** `match.mode.one`, `match.mode.two`, `match.p1.score`, `match.p2.score`, `match.turn`, `match.winner`, `match.again`.
- **Acceptance (one named test each).** Active player only: the other player's keys do nothing; a match keeps the turn and scores; a mismatch passes it after the delay; all pairs found ends the board with the right winner and the draw case; starting player alternates; pause freezes the mismatch timer; no progress is recorded (the session is not touched); screen reader announcements; 200 percent text; the phone layout.
