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

