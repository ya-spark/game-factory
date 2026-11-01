# Google Play Games sign-in: per-game setup

Code is done in the template and every game: with `play_games.enabled: true` the game signs the
player in with Google Play Games, submits the high score to a leaderboard, and mirrors the save
(score, coins, progress) to Play Games **Saved Games**, so it survives a reinstall or a new phone.
With `enabled: false` (default) the game is local-only and the Settings row is hidden.

What you do per game, in order:

1. **Play Console -> your game -> Grow users -> Play Games Services -> Setup and management ->
   Configuration.** Create the Play Games Services project (it creates a Google Cloud project for
   you). Note the **Game services project ID** (a number, e.g. `123456789012`). This is
   `play_games.app_id`.
2. **Credentials** (same page, "Add credential" -> Android). One per signing key, using the
   game's package name and that key's SHA-1:
   - **Play App Signing key** (Play Console -> Test and release -> App signing -> "App signing
     key certificate" SHA-1). Needed for builds installed from Play.
   - **Upload key** SHA-1 (`keytool -list -v -keystore upload.jks -alias upload`). Needed for
     release APKs you sideload.
   - **Debug key** SHA-1 (`keytool -list -v -keystore ~/.android/debug.keystore -alias
     androiddebugkey -storepass android`) for local debug runs.
   Sign-in fails silently if the running build's SHA-1 has no credential.
3. **Leaderboard** (Grow users -> Play Games Services -> Leaderboards -> Create): name
   "High Score", format Integer, order "Larger is better". Copy its ID (`CgkI...`). This is
   `play_games.leaderboard_high_score`.
4. **Testers**: Configuration -> Testing -> add the Gmail accounts that will test. Until you
   click **Publish changes**, only these testers can sign in. Publishing is required before the
   public release.
5. **Edit `app.config.yaml`** in the game repo:
   ```yaml
   play_games:
     enabled: true
     app_id: "123456789012"
     leaderboard_high_score: CgkI...
   ```
   These IDs are public identifiers, not secrets; commit them.
6. **Data safety / privacy**: the store listing templates already mention Play Games sign-in;
   confirm the Data safety form lists Player ID and saved game data when enabled.
7. **Verify on a real device** (emulators need Google Play images): install a build whose
   SHA-1 has a credential, open Settings -> "Google Play Games" -> sign in, finish a game, then
   Settings shows your name and the leaderboard shows the score. Reinstall and confirm the
   score returns.

Notes:
- Play Games on Android has no in-app sign-out; players manage it in the Play Games app.
- Conflicts: the save with the newer `savedAtMs` wins as a whole (local vs cloud).
- Achievements: the game unlocks with its internal achievement id. Play requires its own
  `CgkI...` IDs, so Play achievements need an id mapping before they show up (not done yet).
