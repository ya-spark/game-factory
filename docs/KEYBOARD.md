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
