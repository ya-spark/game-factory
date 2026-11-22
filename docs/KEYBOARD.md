# Keyboard play (R2, owner rules 2026-11-21)

One key map for every game and app, in `game_core` (`lib/kit/keys/`, import `package:game_core/kit/keys/keys.dart`).

## What a game does
1. Wrap the play area in `GameKeyboard(twoPlayer: ..., onInput: (GameInput i) {...})`. `i.action` is a `GameAction`
   (`left right up down action pick1..pick4 pause question exit`), `i.player` is 1 or 2, `i.repeat` is true while a key is held.
   `onRelease` reports key-up for games where holding a key means holding a direction.
2. Single-player games (`twoPlayer: false`): both hands work, so the left-hand keys (W A S D, F, Z X C V) also play and report player 1.
   Two-player games (`twoPlayer: true`): arrows and the right side are player 1, W A S D and the left side are player 2; pause,
   question and exit are shared. Chosen two-player games: Tug of war, Memory match, Door runner, Blockfall.
3. Show the keys with `KeyHints(actions: [...], player: 1)` (it prints the player's real keys, so a remapped key reads right).
4. A game that needs a different key than the default says so in its own `docs/SPEC.md`; it still goes through `GameAction`.
5. Every button must also work from the keyboard (Tab order follows the screen, the focus ring is visible, Enter or Space presses).

## What a container does
- Load once: `final keys = await loadGameKeyMap(PrefsGameKeyStore(await SharedPreferences.getInstance()));`, then
  wrap the app in `GameKeysScope(keys: keys, ...)` (the template does it in `main.dart` and `app.dart`).
- Settings has a Controls row that opens `ControlsScreen` (the template: `TestIds.settingsControls`).

## Rules of the map
- Defaults: player 1 arrows, Enter (action), 1 to 4; player 2 W A S D, F, Z X C V; Space pauses, Q asks, Esc exits.
- Every slot always has a key and no key is used twice: assigning a key another slot uses swaps the two.
- Escape (exit), Tab, Shift, Ctrl, Alt, Meta and Caps Lock cannot be bound. Ctrl, Alt and Meta shortcuts pass through to the browser.
- Saved on the device only (`game_keys_v1`); a damaged save falls back to the defaults; going back to the defaults clears it.
- The look of the Controls screen and the game frame follows the Figma board (`docs/art-prompts/r2-layout-figma-prompt.md` in game-studio).

## Esc, Space and the frame (rolled out to the four two-player games)
- **Esc pauses a round** (the pause screen has Resume and Leave; Esc or Space again resumes); on the start and results screens Esc leaves. The shared `exit` action is bound to Esc and cannot be remapped.
- **No title bar.** A game draws `GameTopBar` (exit, name, pause) over the stage and `PauseOverlay` (Resume, Leave); both are in `game_core` (`kit/layout/game_chrome.dart`).
- **Frame.** A game's screen is `GameFrame(showAds: <not in play>, phoneBanner: null, child: ...)` inside `GameKeyboard`; key hints (`KeyHints`) show on windows 600 dp and wider.
- **Flame games:** pass `autofocus: false` to `GameWidget`, otherwise Flame's own focus node swallows every key before `GameKeyboard` sees it.

| Game | Keys (player 1; the left hand also plays in a one-player game) |
|---|---|
| Choose-one games (Tug of war, True or false, Cloze fix, Balloon pop, Shooter shell) | 1 to 4 answer, Enter start / next, Q read the question, Space pause, Esc pause or leave |
| Bridge builder (id `bridge_builder`) | left and right choose a tile, Enter or Space places it in the next slot (or takes it back; B-01: Space selects, it does not pause), 1 to 9 place that tile, Backspace or Down takes the last tile back, Q reads the target, Space or Enter is Next after a result, Esc pauses or leaves |
| Domino chain (id `domino_chain`) | left and right choose a domino, Enter places it in the next slot (or takes it back), 1 to 4 place that domino, Backspace, Delete or Down takes the last one back, H hint, Space is Go when every slot is full (else pause), Space or Enter is Next after a solve, Q reads the steps, Esc pauses or leaves; every button shows its key |
| Memory match | arrows over the cards, Enter turns a card (or goes on), Q reads, Space pause, Esc pause or leave |
| Door runner | left and right steer, up zaps, down slows while held, 1 to 4 pick a door, Enter or Q the question, Space or Esc pause |
| Blockfall | left and right move (held keys repeat), up rotates, down soft-drops while held, Enter hard-drops, Q holds, 1 to 3 power-ups, Space or Esc pause |
| Parcel train (id `parcel_train`) | arrows and W A S D steer (queued in the ready beat), Enter or Space starts and goes on, Space or P or Esc pauses (any of them or Enter resumes), 1 to 5 open a course, F Free ride, H how to play, T tunnel edges, R replay, Left and Right choose Next or Replay, Q reads where the parcel is; every button shows its key; the screen reads F H T R P and 5 itself (F is the map's left-hand Action key) |

## U2: Space goes on (2026-11-22)
- Space (the shared pause key) does what Enter does in the non-play states: after an answer or round result it is Next (or See results), on the intro or start screen it starts, on the results screen it leaves. In play it still pauses, and it never both pauses and goes on: while a result or Next shows, Space is Next. Enter keeps working.
- In code: accept `GameAction.pause` where the code accepts `GameAction.action` for next, start and leave, only in the non-play states, with `!i.repeat`. Pass `spaceGoesOn: true` to `KeyedBody` or `KeyHints` for those states, so the action chip reads "Enter / Space".
- Done in: the choice-game kit (Tug of war, True or false, Cloze fix, Balloon pop, Shooter shell), `ArcadeFrame` menu and over screens, Series builder, Sort into bins, Word builder, Flash review, Word grid, Memory match (one and two players), Door runner (race and wrong-answer Next), Tug of war head to head, Ball sort, Merge, Mahjong, Sudoku, Solitaire, Blockfall (choice and versus). Bridge builder already did it.

## K1: every game has keys (2026-11-22, for the web)
- `ArcadeFrame` (Runner, Stack tower, Brick breaker) takes the keys: Enter start or play again, Space and Esc pause (Resume, Leave), the game registers `run.onInput` and `run.onRelease` for its own keys and `hintActions` for the hints.
- `KeyedBody(onInput:, hints:, words:, child:)` (game_core, `kit/keys/keyed_body.dart`) is `GameKeyboard` plus the hint row for every other screen. Untimed games have no pause: Esc goes back.
- A highlighted cursor (tertiary colour, 4 px) appears once a key is used, so touch play looks as before.
- Digits 5 to 9 and letters are not in the map: a game that needs them reads them in a `Focus` above `KeyedBody` (Sudoku does).
- Each game's own keys are in its `docs/SPEC.md`, section "Keyboard".

The two-player modes themselves (Tug of war head to head, Memory match turns, Door runner race, Blockfall two boards) are not built yet; the key map already gives player 2 its left-hand keys.


## B-09: every button shows its key (2026-11-22)
Every button in every web game prints the key that presses it, for example "Next (Enter / Space)", and the key works. The rule for all games:

| Key | What it does |
|---|---|
| Enter and Space | The main forward button: Start, Play, Next, See results, Play again, Done, Got it. In play Space pauses unless the game uses Space as an action (Bridge builder: select; Domino chain: Go), then P pauses. |
| Esc | Leave or close: leaves from start and results screens, closes a dialog, pauses a round (and resumes from the pause screen). |
| 1 to 4 (5 to 9 where a game has more) | Choices: answers, doors, balloons, bins, tiles, levels. |
| Backspace | Back one step: undo, take the last tile or letter back, erase. |
| H | Hint. |
| P | Pause where Space is an action. |
| L | Leave a round from anywhere (the exit button and "Leave game" print it). Not used in the word games, where letters are typed. |
| Q | Read the question aloud. |
| A-Z | In the word games, typing a letter picks that letter. |

How it is built (game_core, `lib/kit/keys/key_labels.dart`):
- `keyedLabel(context, 'Next', GameAction.action, alsoSpace: true)` or `KeyedText(...)` print the player's real key (a remapped key reads right); `withKey('Undo', 'Backspace')` prints a fixed key.
- Keys that are not in the map (Backspace, H, L, R, letters) go in `GameKeyboard(shortcuts: {...})` or `KeyedBody(shortcuts: ..., extraHints: [('H', 'hint')])`; a shortcut is tried before the map, so only register one while its button shows.
- Icon buttons: `KeyedIconButton` (key text beside the icon) and `KeyedBackButton` (app bars: set `leadingWidth: KeyedBackButton.width`); `GameTopBar` prints L and Esc, `PauseOverlay` prints "Resume (Esc / Space)" and "Leave game (L)".
- Choice buttons wrap their label in `ChoiceLabel(index: i, child: ...)` (a key cap 1 to 4).
- Shared screens already do it: `ChoiceGameScreen`, `ArcadeFrame` (Play, Play again, Done "(Esc)", Continue "(C)", L leaves a round), `CalmResults`, `MiniGameSummary`.
- A dialog needs its own `GameKeyboard` (a dialog is a new route; the game's keyboard does not see its keys) or an autofocused primary button (the web how-to dialog: "Got it (Enter / Esc)").
- Not changed on purpose: Space-vs-pause in Runner, True or false, Stack tower and Parcel train (their rewrite specs decide). Blockfall, Block puzzle and Wingy are app games (apps paused) and not on the web; they are not part of B-09 yet. Setting switches (Hints, Show mistakes, Winnable deals) and level chips on menus are reached with Tab and Space or Enter.
- The audit of every game's screens and buttons is in `docs/queue/B-09-shortcut-keys.md` in game-studio.
