# Snake (game package `game_snake`)

Status: BUILT. The game lives once in `game-factory/games/snake/` (SH1, owner 2026-11-21); the Mind hub (Presto) is a container that lists it, brings its coins, ads, leaderboards, achievements and zen/daily features, and provides them through `GameHost` (`game_core/lib/host`) and the Mind kit (`game_core/lib/mind`). Rules in `lib/src/rules/`, the screen in `lib/src/snake_screen.dart`. Nothing is copied.

The text below was collected from the hub's spec when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## From the hub spec
### 4.2 Arcade frame (shared by Snake, Brick breaker, Stack tower and Runner)
Written for the hub (not copies); rules are pure Dart under `lib/engine/minigames/<game>/rules/`, the
random source is injected, and movement runs on a fixed step (`fixed_step.dart`). Views are in
`lib/ui/minigames/`; the shared frame is `arcade_parts.dart`.
- Flow: menu (how to play, best score, game settings, banner) -> play (no banner, no ads) -> results
  (score, stars out of 3, coins, optional Continue, Play again, Done, banner). Play again starts the next
  round at once; best score is kept per game on the device (`arcade.<game>.best`) and sent to the Games
  tab as the game's score.
- Coins: one coin per N points at the end of a round (N per game), at most 20 a round, paid to the hub
  wallet. A Continue pays only the difference.
- Continue (where a game has a game over): a rewarded ad (`RewardedPlacement.revive`), at most once per
  game over; with Remove Ads it continues at once; an ad that fails grants nothing. No interstitials.
- Accessibility: every control has a test ID (`TestIds.arcade(game, name)`), the field and score have
  semantics labels, arrow buttons exist beside every swipe or drag control, colours come from the theme
  (contrast 4.5 to 1), layouts hold at 150 percent text.

### 4.3 Snake (free with ads)
15 x 15 grid, one life, swipe (24 px) or arrow buttons; start length 3, heading right. At most two turns
wait in a queue and a turn straight back is ignored. A move is due every `0.20 s - 0.006 s per segment
over 3`, never under `0.08 s`. Food adds one segment and 10 points. The tail cell is free on a move that
does not grow. Walls end the game, or wrap round when the menu setting "Walls wrap round" is on (kept in
`arcade.snake.wrap`). Filling the board ends the game. No Continue (one life).
**Stars:** best score 50 / 150 / 300 (5, 15 and 30 pieces of food). **Coins:** 1 per 20 points.

## Related lines
- **New personal best**: one calm line ("New personal best in Snake: 120") in a snack bar, once per run, after the game screen has closed (never during play). It needs an

## Keyboard (K1, 2026-11-22)
- arrows (or W A S D) steer the snake. Arcade frame (game_core `ArcadeFrame`): Enter starts and plays again, Space or Esc pauses a round (Resume or Leave; Esc or Space or Enter resumes), Esc on the menu leaves, on the results goes to the menu. No pause button on screen.
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).
