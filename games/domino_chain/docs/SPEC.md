# Domino chain (game package `game_domino_chain`, id `domino_chain`)

Status: REWRITTEN as Domino chain (G-13 / B-03, owner start 22 Nov 2026). It replaces Series builder (id `series_builder`; tap the tiles one after the other). The game lives once in `game-factory/games/domino_chain/` (SH1); apps and the web list it in their registry and bring content, theme and services. It asks its container only through `GameHost` (`game_core/lib/host`). Model: Bridge builder.

**Name.** The child sees "Domino chain" (start screen, how to play, catalogue and web cards; the game draws no title). Package, folder and id are the name (`domino_chain`). The id was `series_builder`: the web moves a saved best score and last-played entry once (`renamedGameIds` in game_core and in the web overlay). No app wording (Craft, Scout, Ranger, Champion, Mind, Ember, Presto) in anything a visitor sees; the internal enum value `SeriesLevel.hard` has no text.

Files: rules `lib/src/rules/domino_chain_rules.dart` (levels, `DominoChain` from a `series` item, stages, scores) and `lib/src/rules/domino_rules.dart` (`DominoBoard`: slots, place, swap, take back, Go verdict, hints); screen `lib/src/domino_chain_screen.dart`; art `lib/src/ui/domino_art.dart` (drawn in code); test IDs `DominoChainIds` here and `GameIds` in game_core.

## How to play (as shown to the child)
- Put the steps in the right order. Drag the dominoes into the row, or tap a domino and then a slot. Then press Go.
- The chain topples and stops at the first domino that was not next. Swap it and press Go again.
- Tips: find the first step before you start; use a hint if you are stuck; older levels add a gentle timer.

## Idea and look
- The steps of a `series` item are dominoes lying shuffled in a tray (cream faces, a coloured top band cycling blue, orange, teal, purple; dark ink text). The child puts them in numbered slots on a table, Go enables when every slot is full. Go: the first domino nudges, then each domino tips over to the right. Right: it runs to the last domino, 400 ms pause, a toy flag pops with 1 to 3 stars. Wrong: the chain stops at the first wrong domino, which wobbles red with a "?" tag, a spark and a dust puff; earlier dominoes stay tipped (green), the broken one and the rest stand. The message says "Slot 3 was not the next step. Try swapping it." (never the answer). No penalty, no lost life, no limit on tries.
- A tipped domino is drawn flattened and leaning right (a parallelogram, never taller than at rest), so the text stays readable and the row never grows past the table.
- Cartoon look: thick dark outline (`dominoInk` 0xFF2B2A4C, the same value as Bridge builder's ink), flat bright colours, drop shadow. Right = green 0xFF2E9E5B, broken = red 0xFFD64545 with a white "?" tag. Colour is never the only cue (tag and text).
- Art kit, all drawn in code (`CustomPainter`): domino face (rest, tipped, broken; short and long), table backdrops by stage (playroom floor, toy shelf, window sill), toy flag with a pop, spark and dust sprites, "?" tag, Go lever. No mascot (decided). No living beings anywhere. Figma art comes later (prompt: `game-studio/docs/art-prompts/domino-chain-figma-prompt.md`); the painters are swapped for exported SVG then.

## Rules (exact values)
- Item: a `series` item with at least 2 steps (`dominoPlayable`; the content has 3 to 7). `minPool` 1 (was 3). Sizes: `any`.
- Levels (`SeriesLevel.forSession`, year 0 to 2 younger): younger up to 4 dominoes, 2 hints, no timer; older up to 7, 1 hint, timer 8 s per domino for the whole chain (cap 60 s); hard (internal flag) 7 dominoes, 5 s per domino, no hints. Study mode: no timer, 2 hints, same rounds. A longer series plays a window of consecutive steps.
- Chain (`DominoChain.fromItem`): one domino per step, text as authored; the tray order is a seeded shuffle that never starts in order (unless all texts are equal); equal texts are interchangeable. Size class by the longest step: `short` (all up to 24 characters) or `long` (wide dominoes, up to 3 label lines).
- Rounds: a stage is 2 chains (the last stage of a session may be 1); a session is up to 6 chains (`dominoChainCount`), never more than the pool, each chain a different item. Backdrop cycles floor, shelf, sill by stage.
- Placing: drag a domino from the tray (or from a slot) onto a slot; tap a tray domino (it lifts) then a slot; tap a placed domino or a filled slot to take it back; dragging a placed domino onto another slot swaps them. The tray keeps a dashed ghost where a domino was.
- Go: only when every slot is full. Right: all dominoes tip, the flag pops, the chain counts as solved. Wrong: stop-and-show; any edit (place, take back, swap) clears the stop, Go is enabled again.
- Topple timing: 150 ms ready nudge, each domino tips for 350 ms with a 120 ms overlap into the next (230 ms apart); right: 400 ms pause then the flag pops (300 ms); wrong: 500 ms wobble of the broken domino. Seven dominoes run 2.6 s. Space, Enter or Go again while it runs skips to the end.
- Hints: the Hint button (key H) lights the next slot that is not right and the domino that belongs there (yellow outline) and says "Hint: slot 2 comes next". A hint makes the chain not a first try.
- Scoring and `onAnswered`: `QuizSession.answer` is called ONCE per chain when it is solved (or at time up): `correct` = the first Go was right, no hint used, no time out (study: always true once solved); `hinted` and `timedOut` are passed on. Game score (`onScore` once at the end): 10 for a first-try chain (older: +2 per streak step, to 5), 6 for a second try or a hint, 3 after that, 0 at time up. Stage stars at the flag of the last chain of a stage: all chains first try 3, at least half 2, else 1. The flag of each chain shows 1 to 3 stars (first try 3, second 2, later 1). On screen only; skill stars and coins come from `QuizSession.answer`.
- Timer (older, not study): a clock and a thin bar in the HUD, stopped while paused and when Go is right. Time up: editing stops, the game puts the right order in the slots and topples it, the chain counts as not right (`timedOut`) and says "Time's up. This is the right order."
- Reduced motion (host setting or system `disableAnimations`): Go shows the end state at once: right = all dominoes tipped and the flag up, wrong = the broken domino red with "?" and the message; no wobble, no spark.
- Modes: Play and Study both work. Best score: kept by the container through `onScore`.

## Screens and layout
- Start screen (small picture, how to play, Start with its key), play, results (right first time, score, best streak, stars, Done). The frame is `GameFrame` (centred, max 780 wide; ad rail or strip only outside play).
- **No title bar** (owner rule 2026-11-21): the host shows "Game: Domino chain". Exit (top left), read aloud and pause (top right) are 44 dp round overlay buttons. The HUD (Chain N of M · Stage S, Score, clock and bar for older levels) is 44 dp (56 at text scale over 1.2).
- **Fits the window** (W7): the play area is the window less the web bar. Portrait: HUD, the table (a sign with the prompt, the flag, the numbered slot row over the stage backdrop), one message line (live region: the instruction, the last message, or "Selected: <full text>"), the tray, then Hint and Go (Next after a solve) fixed at the bottom. Short landscape (height under 460 and wider than 1.3 times the height): table and message left, tray and buttons right. `_fit` picks the biggest domino size that fits (short 120x92 down to 44x64, long 190x92 down to 96x64; sizes grow with text scale up to 1.5), the rows wrap, and only when even the smallest does not fit does the middle part scroll inside itself (the buttons stay in view). Label text starts at 20 sp and steps down to 12 sp with the domino; the full text is always the screen-reader label, a tooltip on long ones and the "Selected" caption.
- Key hints show on windows 600 dp wide and at least 520 dp tall. Never reads `MediaQuery.size` for the stage (it uses the box).
- Every button names its key: "Start (Enter)", "Go (Space)", "Hint (H): 2", "Next chain (Enter)", "Done (Enter)", "Leave the game (Esc)" (tooltips on the round buttons).

## Keyboard
Uses `GameKeyboard` and the shared map (docs/KEYBOARD.md; remappable). Backspace, Delete and H are read in a `Focus` above `GameKeyboard`. A visible cursor (5 px, tertiary) appears after the first key.

| Key | Start | Play (arranging) | After Go (wrong) | After a solve | Results |
|---|---|---|---|---|---|
| Left / Right | | choose a tray domino (a slot when one is held) | same | | |
| Enter or Up | start | place the chosen domino in the next empty slot (or the chosen slot when held); on a placed one, take it back | back to editing | Next | leave |
| 1 to 4 | | choose that tray domino and place it | same | | |
| Backspace, Delete or Down | | take back the domino placed last | same | | |
| H | | hint | hint | | |
| Space | start | Go when every slot is full, else pause (again resumes) | Go when full | Next | leave |
| Q | | read the prompt and the steps | same | | |
| Esc | leave | pause (Resume, Leave); on the pause screen it resumes | pause | leave | leave |

Tab reaches every domino, slot, Go and Hint (focus ring); Enter or Space presses the focused one.

## Accessibility
- Dominoes "Step text, domino, in the tray", "..., in slot 2", "..., selected"; slots "Slot 2 of 5, empty" or "Slot 2 of 5, <text>" (a broken slot adds "was not the next step"); the sign "Sign: <prompt>"; Go "Go, topple the chain" (disabled: "Go, fill all 5 slots first"); the flag "Flag up: N of 3 stars". Live regions: "Placed X in slot 2", "Took back X", the stop note "The chain stopped at slot 3: <text> was not the next step. Slots 1 and 2 were right.", "The chain toppled all the way. Flag up. 3 stars.", "Hint: slot 2 comes next", and "Time left m:ss" every 10 s. The painted scene has one image label that changes with the state.
- Contrast: dark ink on cream (more than 7:1), red or green plus tag and text for results.

## Test map (names in `test/`)
- `domino_chain_rules_test.dart` (pure Dart, purity test): levels, hints and time; chains capped, windowed, shuffled, never in order; same seed same chain; size class at 24 characters; equal texts; board place, take, swap, take last; Go verdict (first wrong, all right, incomplete); hints; scores (10 / 6 / 3, streak); skill answer rule; chain counts for pool 1, 2, 5 and the cap of 6; stages; stage stars; no item twice.
- `domino_chain_screens_test.dart`: Flow (how to play, no title bar, registry entry; wrong Go shows the broken slot and message, fix and Go again, two chains to results with score 16; pool of one; cap of six), Input (tap then slot, take back, drag, swap, selected caption; keyboard arrows, Enter, 1 to 4, Backspace, Q, Space as pause then Go then Next, Esc, H; Space and Enter start; Esc leaves from the intro; every button names its key), Levels (younger tap and hint, a hint is not a first try, older timer and time up, study, pause stops the timer), Reduced motion, Semantics, Layout (360x640, 390x844, 844x390, 1024x768, 1280x720, 1440x900, 1920x1080 less the 44 px web bar; younger and older, short and long items; text scale 1.0 and 1.5: no overflow, no title text, exit and pause 44 dp, every domino at least 44 by 64, Go in view, no scroll at 1.0 except six long dominoes on a 640 dp phone).
- Done by hand in a real browser (22 Nov 2026, Chromium, a harness page hosting the screen): played a wrong then a right chain at 390x844, 844x390 and 1280x720, younger and older, looked at the screenshots, checked the page does not scroll.
- Not testable on the VM: the look of the art, the feel of the topple, sound (there is none yet), read-aloud audio.
