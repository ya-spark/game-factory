# Manual setup checklist (human steps)

These cannot be automated. Tick them off once; items marked *per game* repeat for each game.

- [ ] **Google Play developer account** ($25 one-time). Complete identity verification.
      Note: new personal accounts must run a closed test with 12 testers for 14 days before production.
- [ ] **AdMob account** at admob.google.com; link to payments profile. Create an Android app
      per game and note the app ID (`ca-app-pub-...~...`) and ad unit IDs (banner, interstitial,
      rewarded). *per game*
- [ ] **Merchant (payments) profile** in Play Console, required for paid items / in-app products.
- [ ] **Service account** for publishing: Google Cloud project -> enable "Google Play Android
      Developer API" -> create service account -> JSON key; in Play Console -> Users and
      permissions -> invite the service account email with release permissions.
      Store the JSON only as GitHub secret `PLAY_SERVICE_ACCOUNT_JSON`.
- [ ] **Upload keystore**: `keytool -genkeypair -v -storetype JKS -keyalg RSA -keysize 2048
      -validity 10000 -keystore upload.jks -alias upload`. Back it up offline. Store as GitHub
      secrets `ANDROID_KEYSTORE_BASE64` (`base64 -w0 upload.jks`), `ANDROID_KEYSTORE_PASSWORD`,
      `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Enroll in Play App Signing. Never commit it.
- [ ] **First release per game must be uploaded manually** in Play Console (create the app,
      fill the store listing, content rating, target audience, data safety, ads declaration,
      privacy policy URL, then upload the first AAB). The API can only update existing apps. *per game*
- [ ] **Closed test with 12 testers** for 14 consecutive days (personal accounts created after
      Nov 2023). Recruit testers, create the closed track, add the tester list. *per game*
- [ ] **Play Games Services setup** (optional per game): Play Console -> Play Games Services ->
      Setup; create credentials (needs the app's signing SHA-1), achievements and leaderboards;
      put the Games app ID in `app.config.yaml`. Step-by-step: `PLAY_GAMES_SETUP.md`. *per game*
- [ ] **License testers**: Play Console -> Settings -> License testing; add tester Gmail
      accounts so purchases are test purchases. Create in-app products matching `products.yaml`. *per game*
- [ ] **GitHub secrets**: the five secrets above. Set them **once at the organization level**
      (Organization Settings -> Secrets and variables -> Actions -> New organization secret ->
      repository access: the game repos) when every game shares one Play service account and one
      upload key. A secret with the same name set on a single repo overrides the organization one,
      so a game that needs its own key (for example a different `ANDROID_KEY_ALIAS`) sets just
      that secret on its repo. No repository variable is needed: workflows read the package name
      from `app.config.yaml`.
- [ ] **`production` environment** (per game repo): Settings -> Environments -> production ->
      Required reviewers. The `promote-production` workflow uses it, so every promotion waits for
      an explicit approval. The `release` workflow uses a separate `internal` environment with no
      reviewers so tag pushes run unattended.

## Release flow

1. Bump `version:` in `pubspec.yaml`, commit to `main`.
2. Push a tag that matches it (`git tag v1.0.1 && git push origin v1.0.1`). The `release`
   workflow builds the signed bundle and uploads it to the **internal** track, rolled out to
   internal testers immediately. It stops if the tag does not match `pubspec.yaml`.
3. Test the internal build on a device.
4. When it is good, run **Actions -> promote-production -> Run workflow** (after approving the
   `production` environment). It promotes the same version code that was tested; nothing is
   rebuilt. The default status is `draft`, so the release then waits for **Roll out** in Play
   Console; choose `inProgress` plus a fraction for a staged rollout, or `completed` to release
   to everyone at once.

`release` run by hand (without a tag) builds the bundle and, if `upload` is ticked, uploads it as a
release. On the closed testing (alpha) track, and on internal, it goes live to testers at once (owner, 2026-11-09); beta stays a draft until you click **Roll out**. It cannot target production. A draft cannot be promoted: roll it out to testers first.

## Importing one-time products from a CSV

Play Console -> Monetize with Play -> Products -> One-time products can import a CSV instead of
filling the form by hand.

- `docs/play-import/one_time_products_sample.csv` is the format Play gave the owner (39 columns).
- `docs/play-import/one_time_products_example.csv` is the file used for Block Fall, Block Puzzle and
  Wingy: `remove_ads_all` 2.99, `coins_500` 0.99, `coins_1500` 2.49, `coins_4000` 4.99 (USD, US only).

Each product takes two rows: row 1 has the id, language, name, description and tax category
(`Digital app sales`); row 2 has the purchase option (`buy`, `active`, `buy`, region, `USD 1.99`,
`available`, `digitalContent`). Add one row per extra country (region plus `CUR amount`) or language.
Add other countries after the import with the Console's price conversion if no local prices are known.

The template's `products.yaml` already lists these four ids (`remove_ads_all` non-consumable, the
three coin packs consumable); create them in Play Console with exactly these ids. The retired id
`remove_ads` is never created again: a saved or restored `remove_ads` entitlement still counts as
owned in the game. Remove Ads removes all ads, banner, interstitial and rewarded.

Data safety and ads: the app manifest removes the advertising ID permission
(`com.google.android.gms.permission.AD_ID`, `tools:node="remove"`) because the ads are
child-directed. The `release` workflow has an information-only step, "Report whether the bundle
asks for the advertising ID", that prints the bundle's permissions and warns if AD_ID slipped in.
Answer the Play Console "Advertising ID" declaration accordingly (the app does not use it).

A product ID can never be reused once it has been created and deleted in Play Console (that is why
the Remove Ads product is `remove_ads_all`). IDs are case-sensitive. Check each imported product is
Active with a Buy option. The game's `products.yaml` ids must match the Play ids exactly.
