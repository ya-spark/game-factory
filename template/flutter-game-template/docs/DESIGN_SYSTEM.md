# Design system

One theme system for the five apps (Craft Scout, Ranger, Champion, Mind Ember, Mind Presto), built from
the committed design files in `design/` (see `design/README.md`). Issue 02A built the theme and the shared
widgets; issue 02B adds the modes, navigation and screens.

## Where the design comes from

- Source of truth: `design/tokens.json` (shared: spacing, type scale, sizes, motion, accessibility) and
  `design/<app_id>/tokens.json` (colours and radii per mode, font, interface levels). Figma is the editor; the
  files are what code reads.
- **Loaded from the bundled assets at start-up, not generated at build time** (`lib/ui/theme/design_loader.dart`).
  The JSON stays the single source of truth and `scripts/new_game.py` only copies it. No network.
- A generated game holds only its own files, in `assets/design/` (`tokens.json`, `<app_id>/tokens.json`,
  `<app_id>/art/`, `icons/`) and `assets/fonts/` (its font and licence text). The template itself keeps all five
  under `design/`, which tests read directly.

## How an app picks its theme

`app.config.yaml`: `theme.design: <app_id>` (`craft_lowteen`, `craft_preteen`, `craft_highteen`, `mind_1`,
`mind_9`). `new_game.py` sets it when the game id is one of those (craft and mind profiles) or when `--design
<app_id>` is given. The plain `puzzle` profile has no design id and keeps today's seed-colour look. `main.dart`
loads the `DesignBundle`; `GameApp(design: ...)` applies it.

- **Mode:** `game` and `study` (Scout, Ranger, Champion) or `default` (Mind). `buildDesignTheme(mode: ...)` returns one
  `ThemeData` per mode; a mode the app lacks falls back to its only mode. Until 02B the app uses its first mode.
- **Level (Scout and Ranger):** `InterfaceLevel.younger | older` is an input of `buildDesignTheme(level: ...)`.
  `InterfaceLevel.forYear(year)` maps the child's year (younger: up to Year 2). It scales text (`text_scale`) and
  raises the minimum touch size (`min_touch`). 02B passes the profile's year.
- **Fonts:** Nunito (Scout, Ranger) is one variable file; weights go through `FontVariation('wght', w)` and
  `fontWeight` (`designTextStyle`). Plus Jakarta Sans (Champion, Mind) has Regular 400, Bold 700, ExtraBold 800
  files, mapped by the `pubspec.yaml` weights the generator writes.

## Theme API (`lib/ui/theme/`)

| File | What |
|---|---|
| `design_tokens.dart` | Pure Dart: parses the JSON into `SharedTokens` / `AppTokens`; `contrastRatio`, `contrastPairs` |
| `app_theme.dart` | `buildDesignTheme(...)` and `ThemeTokens` (a `ThemeExtension`): colours by token name (`bg`, `surface`, `surfaceAlt`, `text`, `textMuted`, `primary`, `onPrimary`, `accent`, `onAccent`, `alt`, `border`, `success`, `coin`, `onCoin`), radii, `sp('md')` spacing, `size('card_art_height')`, `styles['title']`, `minTouch`, `duration()` |
| `design_loader.dart` | `DesignBundle.load(appId)`, asset paths for scenes, mascots and icons |
| `design_scope.dart` | `DesignScope` (theme + text options for a subtree), `DesignPrefs` |

Widgets read `ThemeTokens.of(context)`; never hard-code a colour, radius or size.

## Accessibility (built into the shared widgets)

- **Text** follows the phone's size setting. The large-text option (`DesignPrefs.largeText`) multiplies it by 1.3.
  Layouts must not break at 150 percent (tests run the kit, the gallery and the existing screens at 1.5).
- **Contrast** of at least 4.5 to 1 for every text and button pair (`contrastPairs`), enforced by
  `test/ui/theme/design_theme_test.dart` over every token pair of every app and mode.
- **Reduce motion** (`DesignPrefs.reduceMotion`, or the phone's setting): no shaking or flashing, no parallax,
  transitions at most `fast_ms` (page transitions are instant, the tab pill does not animate).
- **Screen readers:** every shared control has a label (a coin chip says "12 coins", a bar says "50 percent").
- **Touch targets** are at least `min_touch` (48), more for the younger level (56).

## Shared widgets (`lib/ui/kit/`)

Every widget takes an `id` and keys itself `ds.<kind>.<id>`; the builders are in `lib/ui/test_ids.dart`
(`TestIds.dsButton(id)` and so on).

| Widget | Use it for |
|---|---|
| `DsButton` (primary, secondary, ghost; disabled when `onPressed` is null) | Every button. One primary per screen |
| `DsIcon` | A design icon (`coin`, `star`, `flame`, ...) coloured by the theme |
| `DsCoinChip`, `DsStatChip` | Coins; streak and stars |
| `DsMasteryChip`, `DsLabelChip` | Learning / Getting there / Mastered (dot and word); "to revise", "Preview free", badges |
| `DsProgressBar` (thick, `thin: true`) | Progress. Announces the percentage |
| `DsTopBar` | Title, a slot for the mode toggle (the toggle is 02B), coin chip |
| `DsBottomBar` + `DsTab` | Exactly three tabs with an active pill |
| `DsCard` | Any grouped content |
| `DsGameTile` | A game: art slot, badge, stars, thin progress and note, or lock and coin price. **Coin prices belong to games only** |
| `DsTopicCard` | A topic: badge, passed of total, progress, mastery, "to revise". Accuracy only with `showAccuracy` (off for Scout) |
| `DsPackCard` | A pack: "Preview free", locked "Full pack". **No price**; the price shows only behind the parent gate |
| `DsSuggestedCard` | "Try next" / "Continue" at the top of Play and Learn |
| `DsHeroHeader` | The scene SVG, optional mascot, title, subtitle, stat chips, overlay slot (the top bar) |
| `showDsDialog` | A themed dialog with a primary and an optional secondary action |
| `DsSvg` | The only file that imports `flutter_svg` (pinned exactly) |

The legacy menu widgets in `lib/ui/widgets.dart` (`StatChip`, `MenuButton`, `HomeIconButton`, `KidPanel`, `KidPage`,
`KidColors.*Of(context)`) switch to the design colours and shared widgets when the app has a design, and keep
their old look otherwise. Home, Shop, Challenges, Settings, the parent gate and the other screens work
unchanged.

## Theme gallery (debug only)

Settings, in a debug build of an app that has a design: "Theme gallery (debug)". It shows every shared widget in
every mode and level of the app, with switches for large text and reduce motion, to review on a device.

## Modes, screens and mastery (issue 2B2)

- **Modes.** Craft apps have Game and Study (the top-bar toggle, `ModeToggle`); a parent can lock a child to one.
  The bottom bar follows the mode: Game = Play, Challenges, Shop; Study = Learn, Progress, Revise. The Mind hubs have
  no modes: Games, Challenges, Shop, and no study content.
- **Study screens** (`lib/ui/tabs/study_tab.dart`), all untimed; practice uses the Quick quiz in study mode with the
  explanation after each answer (no coins):
  - *Learn*: today's goal card, a "Try next" card (the topic with most items to revise, else the first topic), the
    topics by year as `DsTopicCard`s (progress, mastery chip, "to revise" chip, accuracy), and the extra packs the
    parent has downloaded as `DsPackCard`s (no price; the price only shows behind the parent gate).
  - *Progress*: per topic items passed, still to pass, next release, and the star earned for the topic.
  - *Revise*: the "revise mistakes" list, grouped by topic; a tap practises just those items. A "Practise my
    mistakes" card (count, never a price) starts one round of up to 10 items across topics; it also shows on Play
    and Learn, only while something needs revising. Empty state: "Nothing to practise. Great work!". Scout uses
    Flash review cards, the other apps the Quick quiz.
- **Mastery** (rule in `design/tokens.json`, `mastery`, code `masteryOf`): Mastered at 90% passed and 80% correct,
  Learning below 40% passed, else Getting there. Shown as a coloured dot and a word.
- **Accuracy** ("74% correct") shows for Ranger and Champion only (`AppTokens.showsAccuracy`); Scout shows stars, bars
  and chips with no percentages.
- **Mind home**: the same page as Play (`PlayTab`) with the hero, a "Continue" card and the game tiles (best score,
  coin price on locked games); no mode toggle.
- Screens with no Figma frame (Progress, Revise, parent area, settings) reuse the same widgets and tokens.

## Art rules

- **No human figures, faces or silhouettes** in any art; characters are friendly shapes. Never add a person icon
  (use a shape for profile avatars). A test checks the design file names.
- All art is original, written by the studio as SVG; no stock or AI-generated images. Hero scenes are 390 x 208 SVG.
- Prices never appear on children's content cards; wording never pressures children.
- Every generated file under `assets/` is listed in `assets/LICENSES.md` (tokens, icons, art: original; fonts: SIL OFL 1.1).
- Game tile art and avatar shapes are original SVGs held in code (`lib/ui/kit/ds_art.dart`, rendered by `DsSvg.string`, the only `flutter_svg` file): simple shapes, `currentColor` for the theme colour, no people. A new game adds its art there; a test checks every registered game and avatar.
