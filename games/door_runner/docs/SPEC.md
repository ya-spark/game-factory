# Door runner (game package `game_door_runner`)

Status: BUILT (owner, 2026-11-21). The game lives once in `game-factory/games/door_runner/`; Scout, Ranger and Champion (and the web app) list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, UI in `lib/src/ui/`, the screen in `lib/src/door_runner_screen.dart`, test IDs in `DoorRunnerIds`.

### Goal and what stays
- A real runner: the runner stands in a lane at the bottom, a row of doors comes down the lanes, each door carries one
  answer option. The child steers to a lane or zaps a door. Plays short single-answer `mcq` items only
  (`sizes: shortOnly`, `minPool: 4`), Game mode only, free with ads (the open coin-lock question stays on the queue).
- Unchanged: `QuizSession`, `onAnswered`, `onScore`, `levelForSession`, `layoutDoors` (one right door plus wrong ones,
  seeded), `DoorRunnerRun` scoring (`scoreForAnswer`). The game score never moves a skill rung; only answers do.
- No title bar (rule of 2026-11-21): the game gets the whole play area; its controls are small overlays.

### Playing a question
1. A question starts: doors (2 to 4, one per lane) appear at the top and move down their lanes toward the runner line.
2. The child moves the runner (one lane per press or swipe) and the door in the runner's lane is the one that counts
   when it reaches the line, or sooner with a zap.
3. A pick is right or wrong. Right: the door turns green, score and streak update, next question after 0.9 s.
   Wrong: see the levels below. After the last question of the round (10 items, as the other games) the results screen.

| | Younger level (Foundation to Year 2) | Older level (Years 3 to 6) |
|---|---|---|
| Doors | 2 | 3 (4 in Champion) |
| Approach time | none: doors come down and wait just above the runner line | 12 s (Champion 8 s), faster with a streak: x(1 + 0.05 per right answer in a row, capped at x1.3) |
| Wrong door | door greys out (`Icons.block`), runner stays, doors keep waiting, try another; no penalty | door shows wrong, the right door is shown, streak resets, one heart is lost, next question |
| Hearts | none shown | 3; at 0 the round ends on the results screen (kind wording, no scolding) |
| Doors reach the runner | cannot happen (they wait) | the door in the runner's lane is picked, same as a zap (no separate timeout) |
| Read aloud | automatic on each question | on request (speaker button in the question dialog) |
| Streak | not shown | shown (flame chip) |

- The score is never taken away; a miss only resets the streak. A hint or timeout counts as a wrong answer for the
  evidence (existing rule); Scout ignores a timeout for the evidence.
- Reduce motion (system or Settings): doors do not scroll; they appear at the runner line, and play is steering plus
  zap only. The runner moves lane to lane with no animation.

### Controls
| Input | Action |
|---|---|
| Left, Right (also A, D) | Move the runner one lane (stops at the edge) |
| Up (also W) | Zap: pick the door in the runner's lane now, without waiting for it to arrive |
| Down (also S), held | Slow the doors to 40 percent while held. Down is only a slow-down: no hint and no "best choice" (decided 2026-11-21; a paid hint can be a later spec) |
| Space | Pause or resume |
| Enter or Q | Open the question dialog (pauses) |
| 1 to 4 | Zap that door directly, from any lane |
| Esc | Pause (never exits by itself) |
| Touch | Swipe left or right to move; tap a door to zap it; hold the slow zone (bottom bar) to slow |
| Tab, Enter | Every door and button is also a focusable, keyboard-activatable control |

- Zap on a wrong door follows the level's wrong-door rule above.
- Pause is also automatic when the app goes to the background. Resume gives a 3-2-1 count-in at the older level only.
- A key hint line under the field lists the keys; it is hidden when the window is compact (touch).

### Question dialog (no distractions)
- The question chip under the top strip always shows the question (two lines, ellipsis). Tapping it, Enter or Q opens a
  dialog and pauses the game.
- The dialog shows only the question in large text and the answers as large buttons (same text as on the doors, in the
  door order, each with its number). Choosing one acts as a zap on that door and closes the dialog. "Back to the game"
  closes it without choosing. A speaker button reads the question aloud (reader from `ServicesScope`).
- Nothing moves behind it. Closing it resumes (count-in at the older level).

### Layout and placements
```
Expanded window (1024 px and wider)            Compact / medium window
+------------------------------+-----------+   +--------------------------------+
| x  ||   hearts  score  streak |           |   | AD STRIP (50 px, placeholder)  |
| [?] question ........ (chip) |  AD RAIL  |   | x  ||   hearts  score  streak   |
|  +------------------------+  |  300 px   |   | [?] question ........ (chip)   |
|  |  lanes, doors fall     |  | placehold |   |  +--------------------------+  |
|  |        runner          |  |  (no ad   |   |  | lanes, doors fall        |  |
|  +------------------------+  |  request) |   |  |        runner            |  |
| key hints                    |           |   |  +--------------------------+  |
+------------------------------+-----------+   | [ hold here to slow ]          |
                                               +--------------------------------+
```
- Play column is at most 760 px wide and centred; the rail is fixed at 300 px at the right.
- The top strip: exit (left), pause button next to it (same place as Wingy), then hearts, score and streak on the right.
- The ad slot is a placeholder only: no ad request, no `AdService` call, nothing overlaps play, it never takes input.
  Banners on a play screen still need the owner's Families and child-directed decision before anything real goes in.
- Responsive: expanded (>= 1024 px) uses the rail; below that the slot is the slim strip at the top. The app keeps its
  phone layout otherwise (existing app); the local breakpoint is replaced by `lib/ui/layout/responsive.dart` at R2.

### Look (owner, 2026-11-21: like Wingy and Block Puzzle, not plain boxes)
- A glowing scene, drawn in Flutter code (`door_runner_field.dart`) from a Figma design (file "Door runner UI", components Door
  and Runner). Gradient sky in three worlds (dusk, aurora, ember: Wingy's palettes, changing as the run goes on), twinkling
  stars, a moon with halo, hills and castle silhouettes, and a perspective floor with one lane per door, lane lines, cross
  lines that scroll toward the runner (faster with the streak, slower while Down is held) and a dashed cyan runner line.
- Doors come out of the horizon and grow as they approach: stone arch, glowing panel (lilac idle, grey with a block icon wrong,
  green with a check right), label plaque and a key number; knob and highlight. Glow shadow on every door except a wrong one.
- The runner is a round glowing critter (no person): halo, eyes, cheeks, smile, feet that bob; a fading trail behind it.
- Controls: round glowing exit and pause buttons, the score in a glowing pill with a streak chip, glowing hearts, a glass
  question chip, chunky gradient buttons in the dialog, glass slow zone, key caps for the hints, a letter-spaced PAUSED and TAP TO
  RUN, and a big glowing 3-2-1.
- Effects: floating "+N" on a right answer, a sparkle burst on the door, a screen shake on a wrong one (not in reduced motion).
- Colours are fixed for the scene (as in Wingy), not from the container's theme; text uses Roboto, bold and extra bold.
- Previews: `DOOR_PREVIEW=1 flutter test --update-goldens test/ui/minigames/door_runner_ui_test.dart` writes images to
  `test/ui/minigames/previews/` (not committed).

### Test IDs (`DoorRunnerIds`, `lib/src/door_runner_ids.dart`; the key strings are the contract)
`door_runner.screen` (the screen), `.frame` (the play frame), `.exit`, `.pause`, `.resume`, `.quit`, `.hearts`, `.score`, `.streak`, `.question` (chip),
`.question.dialog`, `.question.speak`, `.question.back`, `.answer.<i>` (dialog buttons), `.door.<i>`, `.runner`,
`.lane.<i>`, `.slow` (touch zone), `.keys` (hint line), `.ad_slot`, plus the shared intro and results IDs (`mgIntro`,
`mgStart`, `mgResults`, `mgStars`, `mgDone`).

### Rules (pure Dart, `lib/src/rules/`)
- `DoorRunnerState`: lane, approach (0 to 1), speed factor, hearts, phase (approaching, waiting, answered, paused),
  all driven by `tick(dt)` and commands (`moveLeft`, `moveRight`, `zap`, `slow(bool)`, `pause`, `resume`); no Flutter,
  no timers, seeded `Random`. The screen only maps keys, touches and a ticker to these commands.
- Per level numbers come from `DoorRunnerSettings.forLevel` (extended with approach seconds, hearts, ramp cap).

### Acceptance criteria and tests (one named test each)
1. Left and right move one lane and stop at the edges (rules test, key test).
2. Up zaps the door in the runner's lane at once; wrong zap follows the level rule (rules test).
3. Down held slows to 40 percent and releasing restores the speed (rules test).
4. Space and the pause button pause and resume; the doors do not move while paused (widget test).
5. The question dialog opens from the chip, Enter and Q, pauses, shows the question and the answers; choosing acts as a
   zap; Back closes without a pick (widget test).
6. Younger: no hearts, doors wait, wrong door greys out and can be retried. Older: 3 hearts, miss on timeout, round ends
   at 0 hearts (rules and widget tests).
7. Layout: the rail shows at 1024 px and wider, the top strip below; the ad slot is never tappable and calls no ad
   service (widget test).
8. Reduce motion: doors sit at the line (widget test).
9. Every control has its test ID (test over the IDs above).
10. Seeded bot test plays a full round of 10 items to the results screen at both levels.
11. Off-device checklist (cannot be tested on the VM): feel and speed, touch swipe, background pause, read aloud.

### What the container provides (`GameHost`, from `game_core`)
- Read-aloud (a recorded clip first, speech as the fallback), the auto-read setting (younger level), the reduce-motion setting
  and ad banners for the start and results screens only (`GameBannerSlot.preGame`, `postGame`). With no host the game works
  without them. The play screen's ad slot is a placeholder in every container.
- The container supplies the items (a `QuizSession` from its content), saves progress through `onAnswered`, keeps the best
  score from `onScore`, and decides access (free with ads or coins), ages and order in its registry.

## Two players: Race (R2 spec, DRAFT; shared rules in `game-factory/docs/TWO_PLAYER.md`)
- **Mode.** "2 players" on the start screen, windows 600 dp and wider. Both runners are in the same field and run the same doors: the same question, the same doors. Player 1 is the amber runner, player 2 the green runner with a square marker; both may stand in the same lane (the runners are drawn side by side in it).
- **Playing a question.** The doors come down their lanes as in one player. Each player steers with their own keys (player 1: left and right arrows, up to zap, 1 to 4 to pick a door; player 2: A and D, W to zap, Z X C V to pick) and the door in a player's lane is theirs when it reaches the line, or sooner with a zap. The first player to pick the right door scores a point and the question ends (the door turns green with their marker). A wrong pick locks that player out of this question (their runner greys, no heart is lost); the other player may still answer. Both locked or the doors arriving with no pick ends the question with no point and the right door shown.
- **No slow, no question dialog.** Down (slow) and Q are not used in this mode (they would help both players); the doors approach at the older level's pace and, at the younger level, wait just above the line as now.
- **Race.** First to **5** right answers wins (7 at the harder level); questions running out decides by points, then "A draw!". No hearts.
- **Layout.** The same field centered (max 760); a score chip per player in the top strip (name tag, marker, points) replacing hearts and streak; the key hints show both players' keys in their colours. Pause stays top-left.
- **Pure rules.** `lib/src/rules/door_runner_race.dart`: `DoorRaceState` holds two lanes, per-question lock-outs, `pick(player)` and `arrive()` resolution, points and the winner; `DoorRunnerState` is reused for door layout and timing.
- **Test IDs.** `door_runner.mode.one`, `door_runner.mode.two`, `door_runner.p1.score`, `door_runner.p2.score`, `door_runner.p1.runner`, `door_runner.p2.runner`, `door_runner.winner`, `door_runner.again`.
- **Acceptance (one named test each).** Each player's keys steer only their runner; first right pick scores and ends the question; a wrong pick locks only that player; both locked ends it; two runners in one lane; 5 points win and the draw case; down and Q do nothing; no progress recorded; pause freezes the doors; 200 percent text.
