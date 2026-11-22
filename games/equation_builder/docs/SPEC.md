# Bridge builder (game package `game_equation_builder`, id `equation_builder`)

Status: REWRITTEN as Bridge builder (U3, owner 2026-11-22). The game lives once in `game-factory/games/equation_builder/` (SH1); apps and the web list it in their registry and bring content, theme and services. It asks its container only through `GameHost` (`game_core/lib/host`).

**Name.** The child sees "Bridge builder" (title, start screen, how to play, catalogue and web cards). The package, the folder and the game id `equation_builder` are kept on purpose: saved progress and best scores are keyed by the id.

Rules code and the accepts declaration are unchanged from the earlier Equation builder: `lib/src/rules/equation_builder_rules.dart`. New pure-Dart rules for the bridge: `lib/src/rules/bridge_rules.dart`. The screen is `lib/src/equation_builder_screen.dart`, the art `lib/src/ui/bridge_art.dart` (drawn in code; no asset files), test IDs `EquationBuilderIds` here and `GameIds` in game_core.

## How to play (as shown to the child)
- The toy robot is stuck at a gap. Build a sum from the tiles so that it equals the number on the sign.
- Drag a tile into a slot, or tap a tile and then a slot. Any sum that works lays a plank and the robot rolls across.
- Tips:
  - Start with the biggest tile that fits.
  - A sum that is not right falls back and you can try again.

## Idea and look
- A little wind-up toy robot (orange body, one wheel, a key on its back; no person, no animal) rolls along a bridge and stops at a gap. A hanging sign shows the target ("make 12"). The gap has slots; the child fills them with number tiles (blue) and sign tiles (orange). A sum equal to the target lays the planks (they turn green), the robot rolls across and looks happy. A wrong sum wobbles, the planks fall back, the slots empty, the robot looks puzzled. No penalty and no lost life.
- Cartoon look: thick dark outline (`bridgeInk` 0xFF2B2A4C), bright flat colours, toy-block tiles with a drop shadow. Drawn with `CustomPainter` (`BridgeScenePainter`, `paintToyRobot`).
- Stages: every 3 gaps (`gapsPerStage`) is a stage. The scenery follows the stage: river (stage 1), canyon (2), sky (3), then round again. The last gap of a stage (and the last round) shows a flag; when it is crossed the stage ends with 1 to 3 stars at the flag and the button reads "Next stage" (or "See results" on the last round).
- Stage stars: all gaps of the stage right on the first go = 3; at least half = 2; otherwise 1 (the stage is finished). Stage stars are a game reward on screen only; skill stars and coins still come from `QuizSession.answer`.

## Rules (exact values)
- Item: a `numeric` item whose answer is a whole number from 0 to 999 (`accepts`, minPool 4, unchanged; FORMAT-CONSTRAINTS size class unchanged). Any sum equal to the target is right (`equationHitsTarget`, usual order of operations, × and ÷ before + and −, no division by zero).
- A sum needs at least 3 tiles (number, sign, number). One number alone never counts, even if it equals the target. Tiles are read left to right from the filled slots (empty slots are skipped).
- Tiles (`buildEquation`, unchanged): younger = the 3 solution tiles + 1 extra number, plus and minus only; older = + 2 extra numbers and 1 extra sign (× added; ÷ too for harder); harder older = 3 extra numbers. Each tile is used once.
- Slots: younger 3, older 5 (`BridgeSettings.slots`).
- Placing: a slot gets a tile by drag-and-drop onto it, by tapping a tile (it lifts and is highlighted) and then a slot, or by keyboard. A tile dropped on a filled slot replaces it (the old tile goes back to the bank). Tapping a placed tile or a filled slot takes it back.
- Judging: after each placement a sum of 3 or more tiles that hits the target is right at once; a full board that misses is wrong. The "Lay plank" button judges a partial sum (3 or more tiles); "Clear" empties the slots.
- Wrong: the planks wobble and fall away (800 ms, skipped with reduced motion), the slots empty, the hint line says "Not yet. The planks fell back. Try again!", the streak resets. The round is then not a first pass (`QuizSession.answer(correct: false)` is sent when the round is finally solved) but nothing is lost.
- Right: the deck is laid (0.64 s) and the robot rolls across (to the far bank; beside the flag at a stage end). Score: `scoreForAnswer` (10, plus 2 per streak step to 5 for older) for every solved round. `onAnswered` is called once per round; `onScore` once at the end.
- Timer (older only, never in study mode): 60 s per bridge (40 s harder), shown as a clock and a thin bar, stopped while paused. When it runs out the game lays a working sum in the slots, the robot crosses, the round counts as not right (`timedOut: true`) and the feedback says "Time's up. A working sum was ...". Younger levels and study mode have no timer.
- Modes: Play and Study both work (study = no timer, same rounds). Younger = years 0 to 2 (`levelForSession`).
- Best score: kept by the container through `onScore` (the id is unchanged).
- Reduced motion (host setting or system): no wobble, the plank and robot jump to the end state.

## Screens and layout
- Start screen (title, small scene, how to play, Start), play, results (score, right count, stars, Done). The frame is `GameFrame` (centred, max 780 wide; ad rail or strip only outside play via the container); no title bar inside the game: `GameTopBar` (exit, name, score, read aloud, pause) and `PauseOverlay` (Resume, Leave).
- The scene is a stack: the painted backdrop and robot, the sign, and the slot row laid over the gap. Scene height is 0.52 of its width, between 190 and 320 dp. Slots are at most 60 dp (down to about 44 dp at 320 wide with 5 slots). Tiles are 68 dp (younger) or 60 dp, in a wrapping row under the scene. Everything scrolls at large text sizes. Checked at 390, 800 and 1440 wide with text scaled 1.5.
- Read aloud: the speaker button reads "Make N with the tiles..." through `GameReadAloud` (and automatically for the container's auto-read setting).

## Keyboard
Uses `GameKeyboard` and the shared map (docs/KEYBOARD.md; every key is remappable in Controls). Key hints show on windows 600 dp and wider. A highlighted cursor (tertiary colour, 5 px) appears on the chosen tile once a key is used.

| Key | Start | Play | After a result | Results |
|---|---|---|---|---|
| Left / Right | | choose the tile (wraps) | | |
| Enter or Up | start | place the chosen tile in the next empty slot (or take it back if it is placed) | Next | leave |
| 1 to 4 | | choose that tile and place it | | |
| Backspace, Delete or Down | | take back the tile placed last | | |
| Q | | read the target aloud | | |
| Space | start | pause (again resumes) | Next | leave |
| Esc | leave | pause (the pause screen offers Resume and Leave); on the pause screen it resumes | leave | leave |

Backspace and Delete are not in the shared map; the screen reads them in a `Focus` above `GameKeyboard`. Tab reaches every button, tile and slot (they are `InkWell`s with the Material focus ring); Enter or Space presses the focused one.

## Accessibility
- Every tile ("7 tile", "plus tile", "..., selected", "..., in slot 2"), slot ("Slot 1 of 3, empty" or with its tile) and the sign ("Sign: make 12") has a screen-reader label; the hint line and the feedback are live regions; the result names the laid sum ("Plank laid! 3 + 4 = 7") and the stage stars; the timer reads "Time left m:ss". The painted scene has one image label that changes when the robot crosses.
- Colours: dark ink on cream, yellow, orange and green planks; white on the blue number tiles (contrast above 3:1 for the large tile text). Nothing relies on colour alone: tiles are labelled, wrong sums say so in text.

## Test map (names in `test/`)
- `bridge_rules_test.dart`: settings per level, stages and scenery, stage stars, board place/remove, verdicts (any sum, single number, full miss), seeds, purity.
- `equation_builder_rules_test.dart` (unchanged): evaluation order, any equal sum counts, target from whole-number items, every puzzle solvable, younger tiles, seed.
- `equation_builder_screens_test.dart`: Flow (title and how to play, four bridges to results with score, stage flag and stars, single number is not a sum), Input (drag, tap, take back, Clear; keyboard arrows, Enter, 1 to 4, Backspace; Space Next and pause; Esc; hints; labels), Levels (older five slots and timer, timeout lays a working sum, study has no timer, pause stops the timer), Layout (390, 800, 1440 wide at 1.5 text scale, centred).
- Not testable on the VM (left for the owner's check on a device or in the browser): the look and feel of the art and the wobble and roll animation, read-aloud audio.

## Art
Drawn in code for now. The owner's Figma limit blocked the kit on 22 Nov 2026 (a blank file "Bridge builder kit" was created but writes were refused), so a ready-to-run prompt is in `game-studio/docs/art-prompts/bridge-builder-figma-prompt.md`; when the owner hands the Figma result back, the painters can be replaced by exported SVG (and listed in `assets/LICENSES.md`). No living beings in the art (studio rule, 2026-11-22).
