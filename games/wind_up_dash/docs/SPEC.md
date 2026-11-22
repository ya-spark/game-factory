# Wind-up dash (game package `game_wind_up_dash`, id `wind_up_dash`; was Runner)

Status: BUILT 22 Nov 2026 (G-12; owner answered the five questions, see "Owner answers"). The game lives once in `game-factory/games/wind_up_dash/` (SH1, owner 2026-11-21); containers (the web, the paused apps) list it, bring coins, leaderboards and sound through `GameHost` (`game_core/lib/host`). Rules in `lib/src/rules/` (pure Dart), screen in `lib/src/wind_up_dash_screen.dart`, code art in `lib/src/ui/wind_up_art.dart`. This file is the only copy of the game's behaviour; the old hub text is kept at the end as history.

## Owner answers (22 Nov 2026)
1. Title **Wind-up dash**, id `wind_up_dash`, package `game_wind_up_dash`.
2. Yes: 5 courses, each unlocked by 1 star on the one before, plus an always-open free run; free checkpoint restart; no rewarded Continue on the web.
3. Space = jump in play; pause is P or Esc.
4. Keep the spring meter (10 stars = one brick bounce).
5. Star thresholds raised to 150 / 350 / 700.

## Idea
A toy wind-up car (no driver; a tin key turning on its back, round headlights, a spring bumper) is wound up on a floor and rolls by itself. One key (or a tap) hops it over toy bricks and over gaps between floor boards, and it picks up paper stars. No living being anywhere in the art or the text (toys, shapes, objects).

## Rules (kept from Runner, renamed)
- Fixed step 1/120 s (`dashStep`). Auto-run at `start + distance/50` units/s, at most 60 (free run `start` = 32; courses below).
- One fixed jump arc: launch 70, gravity 180, 0.78 s in the air, 13.6 units high; no double jump. The car is 4 units wide and 3 tall; its position is the middle.
- Track from a seed, lazily in the free run, in full for a course. First hazard at 90 units. Gap (45 percent in a mix; width 10 up to 0.45 of a jump's reach at the speed there) or block (4 to 6 wide, 4 to 6 high). Free ground between hazards is at least a full jump plus 0.3 s at the speed there, plus 0 to 30 units (0 to 6 on course 4).
- **Fair:** a jump timed to put the top of the arc over the middle of each hazard always clears it. A bot test plays that over 40 seeds for 6000 units and over every course, with and without a full spring.
- Hitting a block, or standing with the centre over a gap, is a crash. **Coyote time:** the fall starts only after the centre has been over a gap for 0.08 s, and a jump pressed in that time still jumps. **Input buffer:** a jump pressed up to 0.1 s before landing fires on landing. Both only help; the bot never needs them.
- Score = 1 point per 10 units of the furthest distance + 5 per star picked up. Coins 1 per 25 points, at most 20 a round, paid at the end of a round (a course replay pays only the difference over its best). Games tab stars from the free run best: 150 / 350 / 700.

## Courses (5 fixed tracks; seed = 1009 x course number)
| # | Name | Length | Start speed | Hazards |
|---|---|---|---|---|
| 1 | Playroom floor | 600 | 32 | bricks only |
| 2 | Kitchen counter | 900 | 36 | gaps only |
| 3 | Toy shelf | 1200 | 40 | bricks and gaps |
| 4 | Night desk | 1600 | 46 | both, closer pairs (still fair) |
| 5 | Toy city roof | 2000 | 52 | both |

- No hazard in the last 40 units. A checkpoint flag every 300 units (not at the finish); no hazard from 20 units before a flag to 50 after it.
- **Checkpoints:** a crash puts the car back on the ground on the last flag (the start before the first flag), for free: the stars picked up since that flag are put back, the spring meter is as it was there, the crash count goes up, the furthest distance is kept. After 3 crashes on one checkpoint a gentle hint shows once per course: a dotted line where to jump for the next hazard.
- **Stars:** a paper star hangs over the middle of every hazard at the top of the jump arc (the reward for a well timed hop), plus a line of 3 on the ground in the middle of every second free span. About 1 star per 25 units. Pick-up: the car (a circle of 2.2 around its middle) touches the star (a circle of 2).
- **Course stars (0 to 3):** 1 = reach the flag; 2 = also at least 70 percent of the stars; 3 = at least 90 percent. Crashes never lose stars. Course k+1 opens when course k has 1 star; the free run is always open. Kept on the device (`arcade.wind_up_dash.courses`, five numbers; `courseBest`, five scores).
- **Spring meter:** 10 stars fill it (a bulb per 2 stars, 5 bulbs). A full meter absorbs ONE block hit: the car is thrown back 6 units and hops (so it clears the brick), the meter empties and the bumper stops glowing. A gap, or a block hit with an empty meter, is a crash. The free run keeps the meter too.
- Free run: the old endless game (daily seed is the host's, shown as "Today's track" on the web with no extra rules): the first crash ends it, results card, `onScore` once with the score, best score kept (`arcade.wind_up_dash.best`; the old `arcade.runner.best` and the web's `amc.best.runner` move over by `renamedGameIds` and `DashProgress.migrate`). The paused apps' rewarded Continue (`grantContinue`) stays in the rules but the screen has none: on the web there is no Continue and no Remove ads.

## Screens and flow
- **Menu:** the car with its key turning, a big "Play  Enter / Space" button, five course chips (name, 0 to 3 stars, or a padlock and "Finish course N first"), "Free run  F", "How to play  H" (one dialog: "Space or tap to jump. Collect stars. Do not fall in gaps or hit bricks. P or Esc pauses."), best score with its stars, Esc leaves. Left and Right move the highlighted course (Play starts it); Play starts the first open course without a star.
- **Ready beat:** every round starts with 0.8 s of winding (key turns, 3 clicks, "Ready" then "Go!") with the car still. Enter, Space or a tap skips it.
- **Run:** HUD (stars counter, spring meter with "Bounce ready" when full, score, course progress bar with a tick per flag), Jump button (bottom right, shows "Space"), pause and leave overlays (P and L), key hint row on boxes 600 wide and 520 tall or more ("Space or tap jump", "P Esc pause", "L menu"). Banners: "Nice!" every 250 units, "Close!" for a clean pass within 1 unit over a brick, "Checkpoint N", "Bounce ready", "Boing!".
- **Crash:** shake 250 ms (4 px), the car breaks into 4 parts (wheel, key, bolt, bumper), "Try again  Enter" for 1 s (courses; Enter skips), then back at the checkpoint with the ready beat. No result screen in a course. The free run goes to its results after the beat.
- **Flag:** the car rolls on under a checkered banner with confetti, then the results card: 0 to 3 stars counting up, score, percent of stars, coins, "Course N+1 is open", buttons Next course (Enter or Space), Replay (R), Menu (Esc); Left and Right choose. Free run results: score, stars out of 3, coins, Play again (Enter or Space), Menu.
- **Pause:** P or Esc (also when the app loses focus); Resume (P, Esc, Enter or Space), Leave (L). Space never pauses in play.

## Keys (K1; remappable through the shared map; the key is shown on every button)
| Key | Menu | Ready or run | Crash beat | Results |
|---|---|---|---|---|
| Enter or Space | Play | jump (skips the ready beat) | skip the beat | Next course / Play again |
| Up, W | | jump | | |
| Left / Right | choose a course | | | choose Next / Replay |
| 1 to 5 | open that course (if unlocked) | | | |
| F | Free run | | | (course results) Free run; R replay |
| H | How to play | | | |
| P or Esc | Esc leaves | pause | | Esc: menu |
| L | | leave to the menu | | |
| Q | | read the next hazard | | |
Pointer: tap anywhere on the play area to jump, plus the Jump button (76 dp). Tab reaches the menu buttons; Enter or Space presses the focused one; Enter or Esc closes the how-to dialog.

## Layout and art
- No title bar (the host shows "Game: Wind-up dash"). The world view is 36 units tall and 40 to 90 units wide (the box decides); the car is 4 units, at least 36 dp on a phone. The ground sits 26 units below the top of the strip, so the 13.6-unit jump and the HUD fit; on a tall phone the sky and floor boards fill above and below. Never reads `MediaQuery.size`; the page never scrolls (`scrollHeight <= innerHeight`). Menu and results cards are at most 560 and 440 dp wide; short landscape (height under 460) shrinks the HUD to icons and puts the menu in two columns.
- Art is drawn in code (`wind_up_art.dart`, toys only): thick dark outline `0xFF2B2A4C`, flat bright colours, red car (contrast with every floor), gold stars `0xFFFFC83D`, bricks in 4 colours with studs, floor boards with the gap as a dark slot, five backdrops with 3 parallax layers at 0.2 / 0.5 / 1.0 of the speed (playroom, kitchen counter, toy shelf, night desk, toy city roof). Reduced motion removes shake, parallax and the tumble. Tile art `design/game_art/wind_up_dash.svg` in the template. Figma art may replace the painters later (prompt file in the studio repo).
- Juice: key and wheels turn with speed, squash and stretch on takeoff and landing, dust on landing, speed lines above 50 units/s, star spark, spring bulbs and a glowing bumper, confetti at the flag.
- Sound hooks (names only, `onSound`; silent unless a container plays them): `jump`, `land`, `star`, `spring_full`, `bounce`, `crash`, `checkpoint`, `finish`, `wind_click`, `ui_tap`.
- Screen reader: field "Toy car, running, Course 2, Kitchen counter, 12 stars, score 140, jump with Space"; HUD label with stars, spring and progress; polite live region ("Course 2, Kitchen counter, start", "Checkpoint 2 reached", "Star 12", "Spring ready, one bounce stored", "Finished. 2 stars. 78 percent of stars"), "Crashed in a gap. Back at checkpoint 1"; Q reads "Gap ahead, 18 units". Text scale 1.5 keeps HUD and buttons without overflow.

## Question and skill contracts
No question contract (an arcade game: no items, no `minPool`, no Study mode). Skill: `CognitiveSkill.speed` under the key `wind_up_dash` (was `runner`).

## Test map
- `test/wind_up_dash_rules_test.dart` (pure Dart): Track (seed determinism, fair limits, bot over 40 seeds, not jumping dies, fixed arc, speed curve, score and Continue); Courses (lengths, start speeds, seeds, mixes, fairness, no hazard on a flag, the bot clears all 5 with and without a full spring, 0.05 s late still clears, unlock chain); Stars (star on every hazard arc top, ground lines, density, bot picks all hazard stars, 5 points, course stars 70 and 90 percent, thresholds 150/350/700, coins and payout difference); Spring meter (10 stars, bulbs, one bounce and hop, second hit crashes, never saves from a gap); Checkpoints (restore position, star set, meter, crash count, furthest distance, hint count); Input buffer and coyote time (fires on landing, forgotten if early, coyote on and off, bot unchanged); Events (jump, land, star, flag, finish; close call); Progress and migration (`arcade.runner.best`, `renamedGameIds`, `amc.best.runner`, skill key); purity of `lib/src/rules/`.
- `test/wind_up_dash_screens_test.dart`: Flow (menu, Play by Enter and Space, ready beat, crash to checkpoint and Enter skip, hint after 3, flag to results and Next course, free run to results, best kept), Input (Space jumps and never pauses, Up/W/tap/Jump button, P and Esc pause, 1 to 5 and F, Enter closes how-to, Left/Right, keys printed), Progression (locked chips, unlock, saved stars, old best carried), Juice (reduced motion, star and spring sounds), Semantics, Layout (360x640, 390x844, 844x390, 1024x768, 1280x676, 1440x856, 1920x1036 at text 1.0 and 1.5: no overflow, no title bar, buttons at least 44 dp, no scroll, results at most 440 wide).
- `test/wind_up_dash_smoke_test.dart`: the package builds under the host contract.
- Not testable on the VM: the look of the art, feel of the hop, sound, shake. Checked in a real browser (Playwright Chromium, build_game.sh) by the builder, see the studio queue file.

## From the hub spec (history)
### 4.6 Runner (coin-locked, 300 coins)
Side-scrolling, fixed step 1/120 s, one tap to jump. Auto-run at `32 + distance/50` units/s, at most 60 (reached at 1400 units). One fixed jump arc (launch 70, gravity 180). Track generated from the round's seed; first hazard at 90 units; gap or block hazards; free ground at least a full jump plus 0.3 s; fair by a bot test over 40 seeds for 6000 units. Score 1 point per 10 units; Continue (rewarded ad, once per game over) restarts 20 units before the hazard. Stars 100 / 250 / 500 (now 150 / 350 / 700). Coins 1 per 25. Opens with 300 coins (apps).
