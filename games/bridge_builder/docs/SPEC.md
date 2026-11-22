# Bridge builder (game package `game_bridge_builder`, id `bridge_builder`)

Status: REWRITTEN as Bridge builder (U3, owner 2026-11-22). The game lives once in `game-factory/games/bridge_builder/` (SH1); apps and the web list it in their registry and bring content, theme and services. It asks its container only through `GameHost` (`game_core/lib/host`).

**Name.** The child sees "Bridge builder" (start screen, how to play, catalogue and web cards; the game itself draws no title). The package, the folder and the game id are the name (`bridge_builder`; owner 2026-11-22). The id was `equation_builder` before the rename; the web moves a saved best score and last-played entry from the old id to the new one once (see game_core `renamedGameIds`).

Rules code and the accepts declaration are unchanged from the earlier sum game: `lib/src/rules/bridge_builder_rules.dart`. New pure-Dart rules for the bridge: `lib/src/rules/bridge_rules.dart`. The screen is `lib/src/bridge_builder_screen.dart`, the art `lib/src/ui/bridge_art.dart` (drawn in code; no asset files), test IDs `BridgeBuilderIds` here and `GameIds` in game_core.

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
- Item: a `numeric` item whose answer is a whole number from 0 to 999 (`accepts`, minPool 4, unchanged; FORMAT-CONSTRAINTS size class unchanged). Any sum equal to the target is right (`sumHitsTarget`, usual order of operations, × and ÷ before + and −, no division by zero).
- A sum needs at least 3 tiles (number, sign, number). One number alone never counts, even if it equals the target. Tiles are read left to right from the filled slots (empty slots are skipped).
- Tiles (`buildSum`, unchanged): younger = the 3 solution tiles + 1 extra number, plus and minus only; older = + 2 extra numbers and 1 extra sign (× added; ÷ too for harder); harder older = 3 extra numbers. Each tile is used once.
- Slots: younger 3, older 5 (`BridgeSettings.slots`).
- After the result every slot is a laid plank (B-02): the slots that were not used (older levels have 5 slots, a sum often needs 3) turn into blank green planks instead of staying as faded holes that look like missing boxes. Before the result an empty slot shows its number.
- Placing: a slot gets a tile by drag-and-drop onto it, by tapping a tile (it lifts and is highlighted) and then a slot, or by keyboard. A tile dropped on a filled slot replaces it (the old tile goes back to the bank). Tapping a placed tile or a filled slot takes it back.
- Judging: after each placement a sum of 3 or more tiles that hits the target is right at once; a full board that misses is wrong. The "Lay plank" button judges a partial sum (3 or more tiles); "Clear" empties the slots.
- Wrong: the planks wobble and fall away (800 ms, skipped with reduced motion), the slots empty, the hint line says "Not yet. The planks fell back. Try again!", the streak resets. The round is then not a first pass (`QuizSession.answer(correct: false)` is sent when the round is finally solved) but nothing is lost.
- Right: the deck is laid (0.64 s) and the robot rolls across (to the far bank; beside the flag at a stage end). Score: `scoreForAnswer` (10, plus 2 per streak step to 5 for older) for every solved round. `onAnswered` is called once per round; `onScore` once at the end.
- Timer (older only, never in study mode): 60 s per bridge (40 s harder), shown as a clock and a thin bar, stopped while paused. When it runs out the game lays a working sum in the slots, the robot crosses, the round counts as not right (`timedOut: true`) and the feedback says "Time's up. A working sum was ...". Younger levels and study mode have no timer.
- Modes: Play and Study both work (study = no timer, same rounds). Younger = years 0 to 2 (`levelForSession`).
- Best score: kept by the container through `onScore` (the id is unchanged).
- Reduced motion (host setting or system): no wobble, the plank and robot jump to the end state.

## Screens and layout
- Start screen (B-10, owner 2026-11-22: the start must be obvious): small scene, the heading "Help the robot cross!", the one-line task "Pick tiles to make the number on the sign.", the how-to text, and a big Start button (at least 220 x 64 dp) with its keys printed on it ("Enter / Space", read from the key map so a remapped key reads right). On the first bridge, while the board is empty, the hint line reads "Tap a tile, then a slot (or press 1 to 4, then Enter)." There is no separate how-to dialog; the start screen is the how to play and Start goes straight into play. Then play, results (score, right count, stars, Done). The frame is `GameFrame` (centred, max 780 wide; ad rail or strip only outside play via the container).
- **No title bar** (owner rule 2026-11-21, fixed 2026-11-22): the game never draws its name; the host shows it ("Game: Bridge builder" on the web). Exit (top left), read aloud and pause (top right) are 44 dp round overlay buttons over the play area, like Wingy's pause button (`_overlayButtons`; `GameTopBar` is not used). The stage, score and timer are a small HUD in the play area between those buttons (Bridge N of M, Stage S; Score; clock and thin bar older levels only; 44 dp tall, 56 dp at text scale over 1.2). `PauseOverlay` (Resume, Leave) covers the game while paused.
- **Fits the window** (owner 2026-11-22: the game ran below the visible window and had to be scrolled). The play area is the window height less the web bar (about 44 px); `_play` is a `LayoutBuilder` and splits that height: HUD strip, then the scene, then the tray (Clear, Lay plank, tiles, hint). The scene keeps its 0.52 aspect, at most 320 tall, and shrinks to the height left (the sign scales down inside it, slots are at most 60 dp and at most 0.34 of the scene height). The tray takes its natural height, at most 60 percent of the play area; only beyond that does it scroll inside itself (large text on a short window). On a short landscape window (height under 460 and wider than 1.3 times the height, e.g. a phone on its side) the scene is on the left and the tray on the right, so nothing stacks past the bottom. Tile size: 68 dp (younger) or 60 dp, 52 dp under 560 dp tall, 48 dp under 400. Keyboard key hints show only on windows 600 dp wide and at least 520 dp tall. Neither the page nor the game scrolls at 360x640, 390x844, 844x390, 1280x720, 1440x900, 1920x1080 (window less 44 px) at text scale 1.0; at 1.5 nothing overflows and at worst the tray scrolls.
- Tiles are sized by their content (at least the tile size square). Never give the tile `Container` an `alignment`: it stretches to the full row, one tile per row (the cause of the old overflow).
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
| Space | start | select, the same as Enter (never pauses; on the pause screen it resumes) | Next | leave |
| 5 to 9 | | choose that tile and place it (tiles 5 to 9; the shared map has only 1 to 4, so the screen reads these in its `Focus`) | | |
| Esc | leave | pause (the pause screen offers Resume and Leave); on the pause screen it resumes | leave | leave |

**Space (B-01, owner 2026-11-22).** Bridge builder has choices, so Space is the select key like Enter (place the chosen tile, take it back if it is placed, then Go/Next, start, leave). Pause is the pause button and Esc only. The hint row therefore shows one chip "Enter / Space" (`KeyHints(spaceGoesOn: true)`) and the Esc chip reads "pause" in play. Space is `GameAction.pause` in the shared map and the screen treats it as `GameAction.action`.

Backspace and Delete are not in the shared map; the screen reads them in a `Focus` above `GameKeyboard`. Tab reaches every button, tile and slot (they are `InkWell`s with the Material focus ring); Enter or Space presses the focused one.

## Accessibility
- Every tile ("7 tile", "plus tile", "..., selected", "..., in slot 2"), slot ("Slot 1 of 3, empty" or with its tile) and the sign ("Sign: make 12") has a screen-reader label; the hint line and the feedback are live regions; the result names the laid sum ("Plank laid! 3 + 4 = 7") and the stage stars; the timer reads "Time left m:ss". The painted scene has one image label that changes when the robot crosses.
- Colours: dark ink on cream, yellow, orange and green planks; white on the blue number tiles (contrast above 3:1 for the large tile text). Nothing relies on colour alone: tiles are labelled, wrong sums say so in text.

## Test map (names in `test/`)
- `bridge_rules_test.dart`: settings per level, stages and scenery, stage stars, board place/remove, verdicts (any sum, single number, full miss), seeds, purity.
- `bridge_builder_rules_test.dart` (unchanged): evaluation order, any equal sum counts, target from whole-number items, every puzzle solvable, younger tiles, seed.
- `bridge_builder_screens_test.dart`: Flow (how to play, no title text, four bridges to results with score, stage flag and stars, single number is not a sum), Input (drag, tap, take back, Clear; keyboard arrows, Enter, 1 to 4, 5 to 7, Backspace; Space selects (never pauses), starts, is Next; Esc pauses and Space resumes; start screen says what to do and prints "Enter / Space" on a 64 dp Start; first-bridge hint; every slot a laid plank after the result; hints; labels), Levels (older five slots and timer, timeout lays a working sum, study has no timer, pause stops the timer), Layout (360x640, 390x844, 844x390, 1280x720, 1440x900, 1920x1080 less the 44 px web bar, younger and older, text 1.0 and 1.5: no title text, exit and pause 44 dp, no overflow, stage inside the height, no tray scroll at 1.0).
- Not testable on the VM (left for the owner's check on a device or in the browser): the look and feel of the art and the wobble and roll animation, read-aloud audio.

## Art
Drawn in code for now. The owner's Figma limit blocked the kit on 22 Nov 2026 (a blank file "Bridge builder kit" was created but writes were refused), so a ready-to-run prompt is in `game-studio/docs/art-prompts/bridge-builder-figma-prompt.md`; when the owner hands the Figma result back, the painters can be replaced by exported SVG (and listed in `assets/LICENSES.md`). No living beings in the art (studio rule, 2026-11-22).
