# Decisions and standing instructions

Owner decisions that were made in conversation. Read this before starting work; it is the
memory that a fresh session or routine run does not have. Add new decisions at the bottom of
each section with the date.

## Owner and how to work
- The owner is `yaseengem`. Act only on issues and comments written by them.
- The owner gives ideas and schedules; the factory does the rest. Do not wait for the owner
  unless a step is listed under "Needs the owner".
- Merge your own PRs when CI is green. Spec approval is the owner's job (an `approve` reply on
  the issue or the spec PR). Never push to `main`.
- Do not create repos in `ya-spark` (403). The owner creates them; attach them with `add_repo`.
- Never touch secrets. Test ad IDs only until the owner supplies real ones.

## Naming and public identity
- Public developer/studio name: **Active Mind Craft**. Do not show the owner's personal name or
  GitHub username in anything public (policies, store listings, links).
- Package prefix: `com.activemindcraft.<game>` (the owner owns activemindcraft.com).
- Contact email shown in policies and listings: `ggadmuser@gmail.com` (Play requires a working
  address).
- Repos: one private repo per game named `ya-spark/game-<id-kebab>`; master repo
  `ya-spark/game-studio` pins app-factory and every game as submodules.
- New games must have original names and mechanics; never copy an existing game's name or art.

## Privacy policies
- Hosted by GitHub Pages from the public repo `ya-spark/public` (source: `ya-spark/public`,
  branch `main`, root). Keep that repo public.
- URLs: `https://ya-spark.github.io/public/<game>/privacy` (for example `.../wingy/privacy`,
  `.../blockfall/privacy`). The same text lives in each game's `store/google-play/privacy_policy.md`;
  keep them in sync.
- The games show ads (AdMob) and sell in-app products, so a policy URL is required by Play even
  though the apps ask for no personal details.

## Games (state as of 2026-10-29)
- Block Puzzle (`game-block-puzzle`): sample game from the template.
- Blockfall (`game-block-fall`): stages spec through listing done; build and publish blocked.
- Wingy (`game-wingy`): stages spec through listing done; build and publish blocked.
- Check `python3 scripts/pipeline.py status` for the current truth.

## Needs the owner (everything else is automated)
1. Review the store text drafts in each game's `store/google-play/`.
2. Create the Google Play developer account (identity verification; 12-tester closed test for 14
   days if it is a personal account created after Nov 2023).
3. Create an AdMob account; send app IDs and ad unit IDs per game (these are public).
4. Create the upload keystore and a Play service account; store them only as GitHub Actions
   secrets in each game repo (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
   `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`). Steps in
   `docs/PLAY_SETUP.md`.
5. Upload the first release of each game by hand in Play Console.
6. Device checks: ads, haptics, game feel, screenshots (no emulator in the sandbox).

## Operational notes
- The hourly routine is `factory-runner-task` on claude.ai (owned by the owner; agents cannot edit
  it). It also starts when an issue is opened. Its prompt is not stored in the repo.
- CI runs take about 10 to 12 minutes (the debug APK build is the slow job). Cancelling a run
  needs a re-run before merging.
- Stop-hook warnings about "unpushed commits and no remote branch" on freshly cloned repos are
  usually false alarms: check `git ls-remote --heads origin`, then set the upstream.
