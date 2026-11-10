# Content format

How learning content is written down, checked and shipped. The code is in `lib/engine/content/`
(pure Dart, vendored into each game) and the tool is `tool/content_cli.dart`.

Authors write one **CSV per pack** in a spreadsheet. The tool turns it into a **pack JSON**, assigns
item ids, and checks it. Authors never type ids.

## Decisions (owner, 2026-11-09)

Seven item types; CSV authoring; recorded audio with Android text-to-speech as the fallback; a fixed
topic list per subject and year; an explanation on every item; typed answers are numbers only (no
fractions); the Australian-spelling check is a warning only; packs of 20 to 50 items; item ids made
by the tool.

## Commands

Run from the project root (`dart run tool/content_cli.dart ...`). Common options: `--topics <file>`
(default `content/topics.yaml`) and `--root <dir>` (project root for asset files and
`assets/LICENSES.md`, default `.`).

| Command | What it does |
|---------|--------------|
| `from-csv <pack.csv> --out <dir>` | CSV to `<dir>/<pack id>.json`, plus `<pack id>.ids` (the ids file), then validates. Writes nothing when there are errors. |
| `validate <file or dir>...` | Checks packs. Exit code 1 on any error; warnings do not fail. |
| `pool <file or dir>...` | Counts items per type, subject, year and topic (and per subject, year and type together). Use it to check a minigame's minimum playable pool. |
| `build-index --app <id> --packs <dir> --out <dir> [--version N]` | Writes `<out>/index.json` with the sha256 and size of every pack file (served as `packs/<file>`) and every asset the packs use. Validates first. |
| `products --packs <dir> [--catalogue <file>] [--json-out f] [--csv-out f]` | Product list (JSON, for the sync workflow) and the Play Console import CSV, from the manifests and `content/catalogue.json` (price tiers, bundles). Stops on any problem. See `docs/PUBLISHING.md`. |
| `publish --app <id> --packs <dir> --out <dir> [--version N] [--sign auto\|yes\|no]` | Validates, checks products, writes `index.json` (with `status` and bundles), signs when a key is set, and prints the files to upload (dry run). |
| `sign --index <index.json> [--out <file>]` | Signs the index (Ed25519). The private key is read from the file named in `CONTENT_SIGNING_KEY_FILE`. Output is a base64 signature, by default `<index>.sig`. |
| `public-key` | Prints the public key (base64) for the key file, to put in the app. |

Signing key: a text file holding the base64 of a 32-byte Ed25519 seed (lines starting with `#` are
ignored). The owner creates it and keeps it off every repo. Tests use the clearly labelled
`test/fixtures/test_only_signing_key.txt`. Signing is optional until the owner adds a key.

## Topics file

`content/topics.yaml` lists the allowed subjects (`maths`, `english`), years (`0` = Foundation, `1` to
`12`) and topic ids, with a display name each. A pack or item whose topic is not listed for its
subject and year is rejected. This is a first draft for the owner to review.

## Pack JSON

```json
{
  "id": "sample_times_tables",
  "version": 1,
  "lang": "en-AU",
  "subject": "maths",
  "year": 3,
  "topic": "times_tables",
  "title": "Times tables (sample)",
  "product_id": "pack_sample_times_tables",
  "licence": "original",
  "preview": {
    "description": "A short sample of the times tables pack.",
    "outline": [{ "topic": "times_tables", "count": 10 }],
    "item_ids": ["sample_times_tables.0001"]
  },
  "items": [ ... ]
}
```

- `product_id`: `null` for built-in content, a Play product id for an extra pack (`pack_<subject>_<year>_<slug>`, see `docs/PUBLISHING.md`).
- `tier`: price tier id from `content/catalogue.json` (extra packs; never a price). `status`: `draft` (default for extra packs) or `live`.
- `preview` is required for an extra pack and optional for built-in content. `item_ids` may be
  empty and has no fixed size. Preview items are also in `items`: `items` is the full part.
  `outline` lists topic names and item counts of the full part; counts must match.
- An item may carry its own `topic` (same subject and year); otherwise it uses the pack topic.
- A pack should hold 20 to 50 items (warning only).

### Common item fields

| Field | Rule |
|-------|------|
| `id` | Made by the tool, stable (`<pack id>.0001`). Unique across all packs. |
| `seq` | Release order inside the pack (easiest and earliest topics first). Unique per pack. |
| `difficulty` | 1 to 5. |
| `type` | `mcq`, `series`, `pairs`, `word`, `category`, `numeric`, `cloze`. |
| `explanation` | Required, never empty. |
| `image` / `image_alt` | Optional image path (relative to the project root, for example `assets/content/cat.png`). `image_alt` is required with an image. |
| `audio` | Optional recorded file. When absent the app reads the text aloud with Android text-to-speech (wired in a later issue). |

Every image and audio file must exist and be listed in `assets/LICENSES.md`.

## CSV layout

Rows starting with `#meta` set pack fields: `id`, `version`, `subject`, `year`, `topic`, `title`,
`product_id`, `tier`, `status`, `preview_description`. Then one header row starting with `type`, then one row per item.
Columns can be in any order and unused columns can be left out. Rows starting with another `#` are
comments.

Columns: `type, seq, difficulty, topic, prompt, explanation, image, image_alt, audio, preview,
options, correct, steps, pairs, answer, hint, letters, categories, items, tolerance, unit,
expression, gaps`.

- `seq` is optional (default: row order). `preview` is `yes` for items in the free preview.
- In a multi-value cell, `|` separates entries, `=` separates a pair, `/` separates accepted
  alternatives. Write `\|`, `\=` or `\/` to use the symbol itself.
- `correct` uses option numbers starting at 1 (`2`, or `1|3`); the JSON uses 0-based indexes.
- A column that the type does not use must be empty.

Example file: `test/fixtures/sample_pack.csv`; the tool's output for it is
`test/fixtures/sample_times_tables.json` (a test keeps them in step).

### Stable ids

The ids file `<pack id>.ids` sits next to the pack and remembers which id each row got. On the next
`from-csv` a row keeps its id if it is unchanged (even when moved), or has the same type and prompt
(an edited answer or option), or is at the same row number (an edited prompt). Ids of deleted rows
are never reused. Commit the ids file with the pack.

## The seven types

Each example shows the CSV cells (only the used columns) and the JSON.

### mcq (also true or false)

`prompt`, `options` (at least 2), `correct` (index or list of indexes). True or false is an `mcq`
with two options. A maths `mcq` may add `expression`; the single correct option must equal it.

```
type=mcq | prompt=What is 3 × 4? | options=10|11|12|13 | correct=3
```
```json
{ "type": "mcq", "prompt": "What is 3 × 4?", "options": ["10","11","12","13"], "correct": 2 }
```

### series

`prompt`, ordered `steps` (the app shuffles them).

```
type=series | prompt=Put the multiples of 3 in order. | steps=3|6|9|12
```
```json
{ "type": "series", "prompt": "Put the multiples of 3 in order.", "steps": ["3","6","9","12"] }
```

### pairs

`pairs`: a list of `left` and `right`, at least 2; each `left` once.

```
type=pairs | pairs=2×3=6|3×3=9|4×3=12
```
```json
{ "type": "pairs", "pairs": [ {"left":"2×3","right":"6"}, {"left":"3×3","right":"9"} ] }
```

### word

`answer`, `hint`, optional `letters` (the letters offered; must contain every letter of the answer).

```
type=word | answer=product | hint=The answer to a multiplication | letters=pdorutcqz
```
```json
{ "type": "word", "answer": "product", "hint": "The answer to a multiplication", "letters": "pdorutcqz" }
```

### category

`categories` (at least 2) and `items`, each with its `category`. Every category needs an item.

```
type=category | categories=Even|Odd | items=2=Even|7=Odd|10=Even|13=Odd
```
```json
{ "type": "category", "categories": ["Even","Odd"],
  "items": [ {"text":"2","category":"Even"}, {"text":"7","category":"Odd"} ] }
```

### numeric

`prompt`, `answer`, optional `tolerance` (0 or more), optional `unit`, optional `expression`. The
answer is a number: integers and decimals only. When `expression` is given it must evaluate to the
answer (`+ - * / ^`, brackets, `×`, `÷`).

Equivalent forms count as the same answer: `0.5`, `.5` and `0.50`; `1000`, `1,000` and `1 000`.
A comma is only a thousands separator, never a decimal mark.

```
type=numeric | prompt=How many legs do 7 spiders have? | answer=56 | unit=legs | expression=7*8
```
```json
{ "type": "numeric", "prompt": "How many legs do 7 spiders have?", "answer": 56, "unit": "legs", "expression": "7*8" }
```

**Fractions.** A typed answer is never a fraction (`1/2` is rejected as a numeric answer). A question
whose answer is a fraction uses `mcq` with the fractions as options, for example
`options=1/2|1/3|1/4|2/3`, `correct=1`. A decimal answer such as `0.5` is a `numeric` item.

### cloze

`text` with gaps `{{1}}`, `{{2}}`, and `gaps`: the accepted words for each gap. Every gap in the text
needs a non-empty list, and no list may be for a gap that is not in the text. In the CSV the text
goes in `prompt` and the gaps in `gaps` as `1=word/other|2=word`.

```
type=cloze | prompt={{1}} × 3 = 12 and 3 × {{2}} = 15. | gaps=1=4/four|2=5/five
```
```json
{ "type": "cloze", "text": "{{1}} × 3 = 12 and 3 × {{2}} = 15.",
  "gaps": { "1": ["4","four"], "2": ["5","five"] } }
```

## What the validator checks

Errors (the pack is rejected): schema and unknown fields; unknown subject or topic; missing
`explanation`; missing `image_alt`; duplicate item ids (across all packs) and pack ids; the declared
correct answers (mcq indexes, category membership, word letters, cloze gaps); maths items whose
`expression` does not give the stated answer; numeric answers that are not numbers; empty text;
assets that are missing, unsafe paths or not listed in `assets/LICENSES.md`; preview ids that are not
in the full part; outline counts that differ from the full part; duplicate `seq`.

Warnings (do not fail): fewer than 20 or more than 50 items; US spellings from a word list
(`colour`, `organise`, `maths` and similar; see `lib/engine/content/spelling.dart`).

## Delivery, release and unlocks (issue 1B)

Code: `lib/engine/content/` (`content_source.dart`, `repository.dart`, `progress.dart`), the glue in
`lib/core/content/`, the screens `lib/ui/profile_picker_screen.dart` and `lib/ui/parent_area_screen.dart`.
Switched on per game with `content.enabled: true` in `app.config.yaml`.

- **Sources.** `ContentSource` (`listPacks`, `loadPack`, `checkForUpdates`). Built-in: `assets/content/index.json`
  and the files it lists (each listed in `assets/LICENSES.md`). Static server: HTTPS, one host
  (`content.base_url`), `<app_id>/index.json`, `index.sig`, then the pack files named by the index
  (by convention `packs/<pack_id>/<version>/preview.json` and `full.json`, plus assets). An index entry has
  `file` (full) and, for extra packs, `preview_file`.
- **Verification.** Every file is checked against the sha256 and size in the index; a mismatch rejects it.
  Signing is optional until the owner adds a key: `content.signing_public_key` and `signing_key_id` hold
  `PLACEHOLDER_*` and an unsigned index is accepted (`scripts/network_safety_check.sh` and the debug log warn).
  With a real key a valid Ed25519 signature is required on every index. After a signed index has been seen the
  app never accepts an unsigned one (no downgrade) and ignores an index with a lower `version` (no rollback).
- **Cache.** App documents folder, `content/`. A download is written only when every file is complete and
  verified (all or nothing). The newest verified version wins over the built-in one. Update check on launch,
  at most once a day, silent; newer versions of built-in packs download by themselves when the connection allows.
- **Downloads.** Previews on any connection. Full packs on Wi-Fi; on mobile data above
  `content.mobile_confirm_mb` (20) the parent is asked first; with "Wi-Fi only" on, never on mobile data.
- **Daily release** (`content.daily_release`: 10 at the start, 2 a day per subject and year, `require_passed`).
  Items open in `seq` order; the next 2 open on a new local day only when every open item has been passed
  (answered correctly once). Missed days are not caught up. Open items stay open. A year change starts a new
  release for that year. Known limit: a changed device date opens items sooner.
- **Unlocks.** `unlock_full` (non-consumable, in `products.yaml`) opens all built-in content, including updates.
  Extra packs are `pack_<id>` non-consumables named by the index (`product_id`): the preview is free and playable
  in both modes; the full part downloads only after Play Billing confirms the purchase. Shared by every child
  on the device, like the coin balance and Remove Ads.
- **Profiles.** Up to 4 children per device (nickname, built-in avatar, year, mode lock, progress), picker on
  every launch, parent area behind the "Ask a grown-up" gate. Save version 3; an old single-player save
  becomes the first profile.
- **Network rules.** No personal data and no analytics; GET requests to one fixed host with no query, cookies or
  headers of ours; `INTERNET` permission; cleartext traffic disabled. For the privacy policy: the app contacts
  `content.base_url` only to fetch learning content and sends nothing about the child.
