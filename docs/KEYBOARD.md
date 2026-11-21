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
| Choose-one games (Tug of war, True or false, Cloze fix, Equation builder, Balloon pop, Shooter shell) | 1 to 4 answer, Enter start / next, Q read the question, Space pause, Esc pause or leave |
| Memory match | arrows over the cards, Enter turns a card (or goes on), Q reads, Space pause, Esc pause or leave |
| Door runner | left and right steer, up zaps, down slows while held, 1 to 4 pick a door, Enter or Q the question, Space or Esc pause |
| Blockfall | left and right move (held keys repeat), up rotates, down soft-drops while held, Enter hard-drops, Q holds, 1 to 3 power-ups, Space or Esc pause |

The two-player modes themselves (Tug of war head to head, Memory match turns, Door runner race, Blockfall two boards) are not built yet; the key map already gives player 2 its left-hand keys.

