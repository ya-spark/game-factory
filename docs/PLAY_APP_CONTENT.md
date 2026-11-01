# Play Console "App content" answer sheet (all games)

Play Console's dashboard tasks (Set privacy policy, Sign in details, Ads, Content rating,
Target audience, Data safety, Government apps, Financial features, Health, App category and
contact details, Store listing) **cannot be filled through any API**; only the console UI (or a
CSV import for Data safety) accepts them. So the factory removes the thinking, not the clicking:
every answer below is the standard for a factory game. Copy them in. About 10 minutes per game.

A game deviates only if its `store/google-play/data_safety.md` says so (for example Play Games
sign-in enabled, or a new SDK). Re-check that file before filling in.

Per-game values come from the repo: name and package from `app.config.yaml`, text from
`store/google-play/listing.md`, URL from `docs/DECISIONS.md` (`https://ya-spark.github.io/public/<game>/privacy`).

| Task | Answer |
|------|--------|
| Set privacy policy | `https://ya-spark.github.io/public/<game>/privacy` |
| Sign in details (app access) | "All functionality is available without special access" (no login, no accounts) |
| Ads | **Yes, the app contains ads** (AdMob) |
| Content rating | Category: **Game**. Violence: none. Sexuality: none. Language: none. Controlled substances: none. Gambling: none (no real or simulated gambling). User-generated content: no. Location sharing: no. Digital purchases: yes. Expected rating: Everyone / PEGI 3. Email: the contact email in `docs/DECISIONS.md` |
| Target audience | Age groups **13+ only** (13-15, 16-17, 18+). Not for children. Do not opt into Families. Appeals to children: No |
| Data safety | Use `store/google-play/data_safety.md` of the game. Standard: collected and shared via AdMob only (Advertising ID, approximate location, ad interactions); encrypted in transit: yes; deletion request: not applicable, no account |
| Government apps | No |
| Financial features | No financial features (in-app purchases via Play Billing are not a financial feature) |
| Health | No health features |
| Advertising ID declaration | Yes, used for advertising |
| News app / COVID / other | No |
| App category | Game, then the genre (Puzzle, Arcade, ...) |
| Contact details | Contact email from `docs/DECISIONS.md`. Website: optional. Public developer name: Active Mind Craft |
| Store listing | Paste from `store/google-play/listing.md`; graphics from `store/google-play/graphics/` |
| Merchant account | Created once per developer account, not per game |

## What the factory already automates
- Releases after the first upload (internal track, versioning) via `release.yml`.
- Listing text and graphics updates once the app exists, via the Play Developer API.
- The drafted answers above and `data_safety.md` per game (written by the listing agent).

## What stays manual (Google does not offer an API)
- Creating the app in Play Console and the first upload.
- Submitting the forms in the table above.
