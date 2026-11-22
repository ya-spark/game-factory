# Runner (game package `game_runner`)

Status: BUILT. The game lives once in `game-factory/games/runner/` (SH1, owner 2026-11-21); the Mind hub (Presto) is a container that lists it, brings its coins, ads, leaderboards, achievements and zen/daily features, and provides them through `GameHost` (`game_core/lib/host`) and the Mind kit (`game_core/lib/mind`). Rules in `lib/src/rules/`, the screen in `lib/src/runner_screen.dart`. Nothing is copied.

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

### 4.6 Runner (coin-locked, 300 coins)
Side-scrolling, fixed step 1/120 s, one tap (anywhere on the track, or the Jump button) to jump. The
runner is a 4 unit square shape, auto-running at `32 + distance/50` units/s, at most 60 (reached at 1400
units). The jump is one fixed arc (launch 70 units/s, gravity 180 units/s squared: 0.78 s in the air,
13.6 units high); no double jump. **Track:** generated from the round's seed, lazily, 600 units ahead. The
first hazard is at 90 units. A hazard is a gap in the ground (45 percent; 10 units up to `0.45 x` the
distance a jump covers at the speed there) or a block (4 to 6 wide, 4 to 6 high). Free ground between
hazards is at least a full jump plus 0.3 s at the speed there, plus 0 to 30 units at random. **Fair:**
a jump timed to put the top of the arc over the middle of each hazard always clears it; a test plays that
bot over 40 seeds for 6000 units and checks the size and spacing limits. Hitting a block, or standing
with the centre over a gap, ends the run. **Score:** 1 point per 10 units of the furthest distance.
**Continue:** a rewarded Continue once per game over: the runner starts again on the ground 20 units before
the hazard that stopped it; the score is kept. **Stars:** best score 100 / 250 / 500 (1000, 2500 and 5000
units). **Coins:** 1 per 25 points. Opens with 300 coins, permanent on this device.


## Keyboard (K1, 2026-11-22)
- Up or Enter jumps. Arcade frame (game_core `ArcadeFrame`): Enter starts and plays again, Space or Esc pauses a round (Resume or Leave; Esc or Space or Enter resumes), Esc on the menu leaves, on the results goes to the menu. No pause button on screen.
- Keys come from the shared key map (`docs/KEYBOARD.md` in game-factory; remappable; W A S D and Z X C V also play in a one-player game). Tab and Enter or Space press any button. Key hints show under the game on windows 600 dp and wider.
- Tests: the keys are covered by a widget or unit test where the screen can be built on the VM (see `test/`).

## Button keys (B-09, 2026-11-22)
- Every button prints its shortcut key, for example "Next (Enter / Space)"; the key works. Rule: Enter and Space go forward, Esc leaves or closes (pauses in play), 1 to 4 choose, Backspace takes back, H hints, P pauses where Space is an action, L leaves a round.
- The Jump button prints "(↑ / Enter)" and the hint row says "jump" for both keys (B-16). Play, Play again, Done, Continue and the pause screen come from `ArcadeFrame` (see Brick breaker). Space-vs-pause is unchanged (rewrite spec decides).
