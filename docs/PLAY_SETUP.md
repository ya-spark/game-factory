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
      put the Games app ID in `app.config.yaml`. *per game*
- [ ] **License testers**: Play Console -> Settings -> License testing; add tester Gmail
      accounts so purchases are test purchases. Create in-app products matching `products.yaml`. *per game*
- [ ] **GitHub secrets** (per game repo): the five secrets above.
