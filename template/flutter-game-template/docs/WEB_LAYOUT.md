# Web layout (new apps and games)

Owner, 2026-11-21: the web version of a game is laid out for the web, not as a stretched phone screen. This
applies to **new apps and new games from now on**; the existing apps are not changed.

## Rule
- Every new screen is built with the helpers in `lib/ui/layout/responsive.dart`, never a hard-coded width.
- Three window classes: **compact** (under 600, one column, as on a phone), **medium** (600 to 1023, content
  centred up to 720 wide, two columns where it helps) and **expanded** (1024 and up, content up to 1120 wide
  with a side panel).
- Wrap a screen body in `ResponsiveBody`. Use `TwoPane` for a main area plus a side panel (rules, summary, next
  step): under it on a phone, beside it on a wider window. Use `gridColumns(width)` for card grids.
- A play field (a board, a gallery of targets) keeps its own aspect ratio and is centred; it is not stretched to
  fill a wide window. Controls stay within reach of the field.
- The app keeps the phone layout: the same screens in `compact`. Nothing here changes the app's behaviour.
- Mouse and keyboard are first-class on the web: every control reachable by Tab, visible focus, hover states
  where a button is a card, no hover-only information (K1 in the studio queue).

## Check before a new screen is done
1. Open it at 390, 800 and 1440 pixels wide: nothing clipped, no line of text wider than about 75 characters, no
   huge empty gutters.
2. A widget test pumps the screen at those widths (see `test/ui/responsive_test.dart` for the pattern).
3. The screen still passes at large text sizes on a phone.

## The game frame (R2, `game_core` `GameFrame`)
A game is wrapped in `GameFrame` (`package:game_core/kit/layout/game_frame.dart`): the game is centered, at most 780 wide (the stage), and the ad is beside or above it, never over it.
- Under 600 dp: the game fills the width; an anchored banner at the bottom on the menu and results (`phoneBanner`: `menu` or `postGame`).
- 600 to 1023 dp: a 728 x 90 strip on top, the stage centered below it.
- 1024 dp and up: the stage and a right rail (300 x 600, or 160 x 600 when the window is under about 1044 wide; left out when the window is shorter than the ad), the pair centered.
- `showAds: false` while a round is played: nothing is shown and no space is kept. A container with no ad (`GameHost.adUnit` returns null) gets the stage alone, centered.
- The breakpoints (`WindowClass`) are one copy in `game_core`; `lib/ui/layout/responsive.dart` re-exports them.

