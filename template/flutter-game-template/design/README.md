# Design files

Handoff from the Figma design phase (owner and Claude, 2026-11-10). Automatic runs cannot open Figma, so
everything they need is committed here as files. Issue 02 builds the themes, modes and navigation from them.

- **Figma file:** https://www.figma.com/design/ymFJswpzJer3Uicm5VfBKd (pages "Palettes" and "Screens")
- **Shared tokens:** `tokens.json` (spacing, type scale, sizes, motion, accessibility, mastery rule, art rules)
- **Per app:** `<app_id>/tokens.json` (colours and radii per mode, font, interface levels) and `<app_id>/art/` (hero scenes, mascot)
- **Icons:** `icons/*.svg`, 24 x 24, drawn with `currentColor` so they take the theme colour
- **Fonts:** `fonts/` (open licence, see below)

Issue 02A (done): `scripts/new_game.py` copies only the game's own `<app_id>` folder, the shared `tokens.json`, the icons and
its font into `assets/design/` and `assets/fonts/`, and writes the `pubspec.yaml` and `assets/LICENSES.md` entries. The
generated game has no `design/` folder. The app loads the JSON at start-up. See `docs/DESIGN_SYSTEM.md`.

## The five apps

| App | `app_id` | Modes | Font | Look |
|---|---|---|---|---|
| Craft Scout Games | `craft_lowteen` | game, study | Nunito | Warm cream and sky blue, sunny hills, friendly blob character; Study is pale blue and calm |
| Craft Ranger Games | `craft_preteen` | game, study | Nunito | Deep navy, teal and orange, starry mountains; Study is light and quiet |
| Craft Champion Games | `craft_highteen` | game, study | Plus Jakarta Sans | Near-black with violet and lime, neon geometry, no character; Study is neutral and exam-ready |
| Mind Ember Games | `mind_1` | default | Plus Jakarta Sans | Warm charcoal with glowing orange, floating blocks |
| Mind Presto Games | `mind_9` | default | Plus Jakarta Sans | Midnight blue with cyan and magenta speed streaks |

Every text and button colour pair in the tokens passes 4.5 to 1 contrast (lowest 4.87 to 1). The issue 02 contrast test must
keep it that way. Bright buttons use dark `on-primary` text (Ranger Game, Ember, Presto) rather than white.

## Token format

`<app_id>/tokens.json` has `modes` (`game` and `study`, or `default`), and each mode has `color` (`bg`, `surface`,
`surface-alt`, `text`, `text-muted`, `primary`, `on-primary`, `accent`, `on-accent`, `alt`, `border`, `success`, `coin`,
`on-coin`) and `radius` (`button`, `card`). Scout and Ranger also have `levels` (younger and older: text scale, minimum
touch size, timers, voice first). Hex values are `#RRGGBB`. Figma only allows one mode per variable collection on this plan,
so the Figma file has one collection per look ("Theme / Scout Game" and so on) with identical variable names.

## Screens designed in Figma

Game mode Play (Scout, Ranger, Champion), Mind home (Ember, Presto), and Study mode Learn (Scout, Ranger, Champion):
top bar with the Game and Study toggle and coin chip, hero scene with streak and star chips, "try next" card, daily
challenge or goal card, game tiles, topic cards, an extra pack card, bottom bar (Game: Play, Challenges, Shop; Study: Learn,
Progress, Revise).

Not designed yet (follow the same patterns; issue 02 builds them from the tokens): Shop, Challenges, Progress, Revise,
the parent area and the settings screens. A design pass for them can follow once the theme system exists.

## Card content (owner, 2026-11-10)

- **Game card:** art with a badge (Daily, New, Popular), stars (0 to 3), a thin progress bar with a note such as "24 questions open"
  (Scout) or "12 of 24 passed" and best streak (Ranger, Champion), best score only in the Mind apps, a lock and coin price when
  locked. Coin prices belong to games only.
- **Content (topic) card:** subject badge, items passed of total, progress bar, a mastery chip (Learning, Getting there, Mastered, shown with
  a coloured dot) and a "to revise" chip. Accuracy ("74% correct") is shown for Ranger and Champion only, never in Scout.
- **Pack card:** "Preview free" and a locked "Full pack" chip. **No price on the card**; the price shows only after the parent gate.
- **Suggested next:** a card at the top of Play and Learn (and "Continue" in the Mind apps).
- Mastery rule (suggested, in `tokens.json`): Mastered at 90 percent of items passed with 80 percent correct; Learning below 40 percent passed.

New data this needs: accuracy per topic, items passed per game, best score per game, the topic with the most items to revise.

## Art rules

- **No human figures, faces or silhouettes** in any art (owner, 2026-11-10). Characters are friendly shapes only.
- All art is original, drawn for this project (SVG written by the studio); no stock or AI-generated images.
- Hero scenes are SVG (390 x 208, scale to fill), not WebP: they are small, scale to any screen and need no export step. If a
  raster is wanted later it can be rendered from the SVG.
- Keep the wording non-pressuring for children (no countdown pressure, no "you will lose").

## Fonts

| File | Font | Licence |
|---|---|---|
| `fonts/Nunito-Variable.ttf` | Nunito (variable weight), https://github.com/googlefonts/nunito | SIL Open Font Licence 1.1, `fonts/OFL-Nunito.txt` |
| `fonts/PlusJakartaSans-{Regular,Bold,ExtraBold}.ttf` | Plus Jakarta Sans, https://github.com/tokotype/PlusJakartaSans | SIL Open Font Licence 1.1, `fonts/OFL-PlusJakartaSans.txt` |

Nunito is one variable file: select weights with `FontVariation('wght', 400 | 700 | 800)` (check on a device that the weight applies).
The type scale in `tokens.json` uses weights 400, 700 and 800.

## How these files were made

Colours come from the approved Figma designs. `tokens.json`, the icons, the mascot and the scenes were written by a generator
script in the studio session (not part of the repo). To change a look, change it in Figma, then update the matching token values
and art here in one commit and tell issue 02's owner.
