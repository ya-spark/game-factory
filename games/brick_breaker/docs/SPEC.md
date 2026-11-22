# Brick breaker (game package `game_brick_breaker`)

Status: BUILT. The game lives once in `game-factory/games/brick_breaker/` (SH1, owner 2026-11-21); the Mind hub (Presto) is a container that lists it, brings its coins, ads, leaderboards, achievements and zen/daily features, and provides them through `GameHost` (`game_core/lib/host`) and the Mind kit (`game_core/lib/mind`). Rules in `lib/src/rules/`, the screen in `lib/src/brick_breaker_screen.dart`. Nothing is copied.

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

### 4.4 Brick breaker (free with ads)
World 100 x 150 units, fixed step 1/120 s. Paddle 20 wide (32 with the wide power-up), at y 140; ball
radius 2, launched by a tap or the Launch button at a small random angle from straight up. Drag moves the
paddle; the left and right buttons move it at 90 units/s. The paddle sends the ball off by where it lands
(up to 60 degrees from straight up); at least a quarter of the ball's speed stays vertical. Ball speed
`60 + 2 per level` units/s (60 to 98). **Lives:** 3; a lost ball re-sticks a new ball to the paddle.
**Levels:** 20, generated from `Random(7000 + level)`: 8 columns, `3 + (level - 1) / 3` rows (at most 8),
four patterns by `level % 4` (full rows, checker, pyramid, scattered 70 percent); from level 6 the top row
takes two hits, from level 13 every other row too. A brick is 10 points (a two-hit brick 5 for the first
hit and 10 for the break); a cleared level adds 50. Clearing level 20 wins the game.
**Power-ups:** 15 percent of broken bricks drop one (wide paddle for 10 s or slow ball at 70 percent speed
for 8 s), caught with the paddle; the paddle and ball change colour while active.
**Continue:** a rewarded Continue once per game over (not after a win): one life, a new ball, the same
level and score. **Stars:** best score 300 / 1000 / 2500. **Coins:** 1 per 50 points.


## Keyboard (K1, 2026-11-22)
- Left and right move the paddle while held, Enter or up launches the ball. Arcade frame (game_core `ArcadeFrame`): Enter starts and plays again, Space or Esc pauses a round (Resume or Leave; Esc or Space or Enter resumes), Esc on the menu leaves, on the results goes to the menu. No pause button on screen.
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).

## Button keys (B-09, 2026-11-22)
- Every button prints its shortcut key, for example "Next (Enter / Space)"; the key works. Rule: Enter and Space go forward, Esc leaves or closes (pauses in play), 1 to 4 choose, Backspace takes back, H hints, P pauses where Space is an action, L leaves a round.
- Launch prints "(Enter / ↑)"; Play, Play again, Done and Continue come from `ArcadeFrame`: "(Enter / Space)", "(Esc)", "(C)"; the pause screen prints "Resume (Esc / Space)" and "Leave game (L)" (L leaves a round).
