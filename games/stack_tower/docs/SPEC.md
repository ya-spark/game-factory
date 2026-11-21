# Stack tower (game package `game_stack_tower`)

Status: BUILT. The game lives once in `game-factory/games/stack_tower/` (SH1, owner 2026-11-21); the Mind hub (Presto) is a container that lists it, brings its coins, ads, leaderboards, achievements and zen/daily features, and provides them through `GameHost` (`game_core/lib/host`) and the Mind kit (`game_core/lib/mind`). Rules in `lib/src/rules/`, the screen in `lib/src/stack_tower_screen.dart`. Nothing is copied.

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

### 4.5 Stack tower (coin-locked, 300 coins)
World 100 units wide, fixed step 1/120 s. The base block is 40 wide, centred. A block as wide as the one
below slides across from a random side and turns round at the edges, at `40 + 2.5 per block` units/s (at
most 120). Tap or the Drop button drops it: the overlap with the block below stays and the overhang is
cut off (shown for a moment); no overlap ends the game. A drop within 1.2 units of the block below is
perfect: it snaps, keeps the full width and adds to the streak. **Score:** 10 a drop, plus 5 times the
streak (the streak counts up to 10) for a perfect drop; a drop that is not perfect resets the streak.
The view scrolls up with the tower. **Continue:** a rewarded Continue once per game over: the missed block
slides in again over the same tower, the streak restarts. **Stars:** best score 200 / 600 / 1500.
**Coins:** 1 per 25 points. Opens with 300 coins, permanent on this device.

