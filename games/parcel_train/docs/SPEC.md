# Parcel train (game package `game_parcel_train`, id `parcel_train`)

Status: BUILT 22 Nov 2026 (G-15; rewrite of Snake). The game lives once in `game-factory/games/parcel_train/` (SH1). This file is the only copy of its behaviour; change it in the same commit as any behaviour change. Owner answers of 22 Nov 2026 are applied: title "Parcel train"; 5 courses unlocked by 1 star each, station goal, golden parcel, 3 bumpers, a derail restarts the course, Free ride always open with one life; tunnels kept; Games-tab best score and stars come from Free ride only; slower course speed (courses 0.26 s down to 0.12 s, Free ride 0.20 s down to 0.08 s).

A toy train (a small red engine with a round lamp and a chimney, no driver and no face) runs on a printed play mat. Every parcel it picks up couples a wagon that carries it. No living beings anywhere. Pure Dart rules in `lib/src/rules/` (`parcel_train_rules.dart`, `train_courses.dart`), saved data in `lib/src/parcel_train_progress.dart`, the screen in `lib/src/parcel_train_screen.dart`, code art in `lib/src/ui/parcel_train_art.dart`.

## Behaviour and feel
- **Grid logic:** fixed step; start length 3 (engine and 2 empty wagons), heading right; at most 2 turns wait in a queue; a turn straight back or a repeat is ignored; the tail cell is free on a move that does not grow; a parcel adds one wagon (carrying its colour) and 10 points; the first parcel of every round is 4 cells straight ahead of the engine.
- **Free ride:** 15 x 15 mat, no walls inside, one life. Interval `0.20 s - 0.006 s per segment over 3`, never under 0.08 s. A hit on the edge or a wagon ends the round (`TrainEnd.wall` / `self`); a full mat ends it (`filled`). Menu switch "Tunnel edges T" (key `arcade.parcel_train.wrap`): drive off one side, come out the other. Stars on the Games tab tile: best score 50 / 150 / 300. Coins 1 per 20 points, at most 20, paid at the end. `onScore(score)` once per round; best score `arcade.parcel_train.best`. Parcels: random free cell (injected random), never taken, never within 2 cells straight ahead of the head, never a nook.
- **Courses (5 fixed maps, ASCII in `train_courses.dart`):** `.` free, `#` toy-block stack, `f` fence, `~` pond, `1`/`2` tunnel mouths (pairs), `S` start (engine heading right, two free cells behind and four ahead), `G` station gate. (1) Playmat 13 x 13, no obstacles, goal 5, 0.26 s; (2) Block yard 13 x 13, four 2 x 2 stacks, goal 8, 0.24 s; (3) Tunnel town 15 x 13, two fence walls with two crossed tunnel pairs, goal 10, 0.22 s; (4) Pond loop 15 x 15, a 9 x 9 pond and a ring road, goal 12, 0.20 s; (5) Big station 15 x 15, two fence rows making a serpentine with a block in the middle lane, goal 15, 0.20 s. Course interval = base - 0.004 s per segment over 3, never under 0.12 s. Course parcels come from `Random(2011 x course number)` so a course can be learned; the choice depends on the route.
- **Parcels:** 4 colours in a fixed order (red, blue, green, purple); each colour has its own ribbon (cross, X, ring, bar), so colour is never the only cue. A parcel is never placed on the golden parcel, a tunnel mouth, the gate, an obstacle, the train, within 2 cells straight ahead of the head, or in a nook (fewer than 2 passable neighbours; the gate counts as solid). If no cell qualifies the rules relax, then the round is `filled`.
- **Golden parcel (courses):** one per course, in a corner (two perpendicular blocked sides: wall, edge, pond or gate), never a nook, chosen from the same seed at the start. Does not count for the goal, adds 30 points and no wagon.
- **Station gate:** a solid wall (striped barrier) until the goal count is reached, then it opens (bell, flag, "Station open"). Driving into the open gate ends the course (`TrainEnd.arrived`); the wagons unload one by one. Free ride has no station.
- **Bumpers:** 3 per course round. A hit (edge, fence, block, pond, closed gate, wagon, occupied tunnel mouth) with a bumper left: the train does not move, a bumper is used, it waits (steam, 3 px shake for 120 ms); the clock does not run; a turn key to a free direction frees it at once (blocked directions and a turn straight back are ignored while it waits). A hit with no bumper left is a DERAIL: `TrainEnd.derail`, tumble for 1 s ("Derailed! Try again, Enter"; Enter or Space skips the beat), then the course restarts from the beginning (parcels and bumpers reset, a fresh ready beat). Free ride has no bumpers.
- **Tunnels:** the head entering a mouth appears on the partner mouth with the same heading; the wagons follow through (the body keeps its order, the picture jumps from mouth to mouth). A partner mouth that holds a wagon is occupied (a bump). Free ride has none.
- **Course stars (0 to 3):** 1 = reach the open station; 2 = also the golden parcel; 3 = also no bumper used and no derail in that course session (derails count across restarts until Replay or leaving). Course k+1 opens when course k has at least 1 star; course 1 and Free ride are always open. Best stars per course: `arcade.parcel_train.courses` (list of 5 numbers).
- **Course score and coins:** 10 per parcel + 30 golden + 5 per bumper left on arrival; coins 1 per 20 points, at most 20, paid once at arrival, and a replay pays only the difference over that course's best score (`arcade.parcel_train.courseBest`). Courses never call `onScore` and never report a run: the Games-tab best and stars are Free ride's only.
- **Ready beat:** every round (and every restart) starts with the train still for 1 s ("All aboard!", toot); a turn pressed then is queued as the first turn.
- **Results:** course arrival: card with stars counting up, score, coins, "Course N is open" the first time, buttons Next course (Enter or Space), Replay (R), Menu (Esc); Left and Right choose between Next and Replay. After course 5 only Replay and Menu. Free ride: "Parcel train over" or "New best!", stars by best score, coins, Play again (Enter or Space), Menu (Esc).
- **No Continue and no Remove ads** anywhere (bumpers and the free restart replace a Continue; B-18). No title bar: the host shows "Game: Parcel train".
- **Saved data (`SharedPreferences`):** `arcade.parcel_train.best` (Free ride), `.wrap`, `.courses`, `.courseBest`. The old Snake keys `arcade.snake.best` and `arcade.snake.wrap` move to the new ones the first time the screen loads (`TrainProgress.migrate`: the higher best wins). The web's `amc.best.snake` moves by `renamedGameIds` in game_core (`snake` to `parcel_train`).
- **Question and skill contracts:** no question contract (an arcade game); trains `CognitiveSkill.spatial` (`gameSkill['parcel_train']`).
- **Sound hooks** (`onSound(name)`; no sound files here): `chug` (every 2 cells), `toot` (ready beat, gate open), `parcel`, `couple`, `golden`, `bump`, `derail`, `gate_open`, `arrive`, `unload` (one per wagon), `finish`, `ui_tap` (pad). A rising pitch on a streak is the container's job (hooks fire on every parcel).

## Look (code art, `parcel_train_art.dart`)
Thick dark outline (`trainInk` 0xFF2B2A4C), flat bright colours, drop shadow. Five mats (green rug, wooden floor, kitchen tile, blue felt table, map cloth; Free ride uses the rug) fill the whole box; the field sits in a wooden tray with a 6 px frame. Rails (sleepers and two steel lines, straight or curved) are drawn under every cell the train has passed. Walls are toys: block stacks with studs, picket fences, a blue pond with waves, tunnel hills with a dark arch (one dot or two dots tell the pair), the station house with a striped barrier (closed) or a waving flag (open). The picture slides between cells from the logic state (never shows the head inside a wall); wagons swing on turns; chimney smoke every 4 cells; a picked parcel flies onto a spring-coupled new wagon; "Nice!" every 5 parcels; sparks on the golden parcel; steam and shake on a bump; tumble on a derail; confetti and unloading on arrival. Reduced motion (`GameHost.reduceMotion` or the system setting) removes the shake, smoke drift, tumble, confetti and the waving flag.

## Layout (W7, responsive)
No title bar. The field is the largest cell-aligned rectangle (cell at least 24 dp on 360 x 640 and larger; a course is at most 15 x 15) in the room left by: a 52 dp top row (Esc and P buttons, HUD chips) on a phone and a wide window; a pad row of four 56 dp buttons under it on windows narrower than 600 dp; a key-hint line (36 dp) on windows 600 dp wide and 460 dp tall or more; and, in short landscape (height under 460, width 600 or more), a left column (buttons and icon-only HUD) and a right column (the pad as a cross). The page never scrolls. The menu is centred, at most 560 dp wide (760 in short landscape, two columns), five course chips wrap.

## Keyboard (K1; every button shows its key)
| Key | Menu | Ready beat or run | Derail beat | Results |
|---|---|---|---|---|
| Enter or Space | Play ("Play  Enter") | Space pauses; Enter does nothing | skip the beat | Next course / Play again |
| Arrows, W A S D | | steer (in the ready beat: queued first turn; after a bump: turn away) | | Left / Right choose Replay or Next |
| 1 to 5 | open that course (if open) | | | |
| F | Free ride | | | |
| H | How to play (Enter or Esc closes it) | | | |
| T | Tunnel edges on or off | | | |
| R | | | | Replay |
| P, Space or Esc | Esc leaves | pause (P, Space, Esc or Enter resume) | | Esc: menu |
| Q | | reads where the next parcel is | | |

Keys come from the shared key map (`GameKeysScope`): W A S D are the left hand's keys and play in a one-player game. F, H, T, R, P and the digit 5 are read by the screen itself before the map (F is also the map's left-hand Action key, so the screen takes it first). Pointer: swipe on the field (24 px), the pad buttons, a pause button. Tab reaches every button.

## Screen reader
Field "Parcel train, Course 1, Playmat, 3 of 5 parcels, 3 bumpers left, steer with the arrow keys"; every button labelled with its key; one live region says "Course 2, Block yard, start", "Parcel 4 of 8", "Golden parcel taken", "Station open", "Bumped, 2 bumpers left", "Tunnel", "Derailed. Starting again", "Arrived. 2 stars", and Q's "Parcel: 3 cells right, 2 cells up".

## Test map
- `test/parcel_train_rules_test.dart` (pure Dart): all the old Snake cases (start, turn queue, grow and points, wall or wrap, self hit and free tail, speed curve and cap, deterministic update, filled, coins and stars); five course maps (parse, at most 15, start and gate, every free cell reachable through tunnels); parcel placement (4 ahead, never 2 ahead or in a nook, golden in a corner, 40 seeds; colours in order); station gate (closed is a wall, opens at the goal, arrival ends the round, closed gate costs a bumper); bumpers (use one and wait, blocked turns ignored, the 4th hit derails); tunnels (head and body through the pair, occupied mouth bumps); course stars, unlock chain, score; fairness: a BFS bot that never hits clears all 5 courses over 20 seeds with 3 and with 0 bumpers, takes the golden parcel and gets 3 stars (course seed too); purity (no Flutter imports in `lib/src/rules`); the renamed id.
- `test/parcel_train_screens_test.dart`: Flow (menu, Enter and Space and F, ready beat, run, a parcel picked, four bumps and the derail restart, arrival results and Next course, Replay, Free ride results), Input (arrows, W A S D, pad, swipe, Space and P and Esc pause, digits, H and Enter, T, Q), Progression (unlock, saved stars, old Snake keys move, higher stars kept), Juice and reduced motion (hooks fire, no exception), Semantics, Keys shown, Layout (360x640, 390x844, 844x390, 1024x768, 1280x720, 1440x900, 1920x1036 at text 1.0 and 1.5: no overflow, no title bar, cell at least 24, buttons at least 44, pad and hints per class), every course opens.
- `test/parcel_train_smoke_test.dart`: the screen builds under the host contract.
- Not testable on the VM: the look of the art, the feel of the speed, sound, the exact shake. Browser check by the builder (22 Nov): Playwright Chromium at 390x844, 844x390, 1280x720.

## From the hub spec
### 4.2 Arcade frame (shared by Snake (the old name), Brick breaker, Stack tower and Runner)
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

### 4.3 Snake (the old name) (free with ads)
15 x 15 grid, one life, swipe (24 px) or arrow buttons; start length 3, heading right. At most two turns
wait in a queue and a turn straight back is ignored. A move is due every `0.20 s - 0.006 s per segment
over 3`, never under `0.08 s`. Food adds one segment and 10 points. The tail cell is free on a move that
does not grow. Walls end the game, or wrap round when the menu setting "Walls wrap round" is on (kept in
`arcade.snake.wrap`). Filling the board ends the game. No Continue (one life).
**Stars:** best score 50 / 150 / 300 (5, 15 and 30 pieces of food). **Coins:** 1 per 20 points.

## Related lines
- **New personal best**: one calm line ("New personal best in Snake (the old name): 120") in a snack bar, once per run, after the game screen has closed (never during play). It needs an

