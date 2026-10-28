# Conventions for agents

This repo holds the game-studio factory: scripts, agent definitions and a Flutter + Flame
game template (`template/flutter-game-template/`). Games are generated from the template.

## Hard rules

1. **No backend, no Firebase.** Games are fully client-side. No servers, no Firebase SDKs
   (Analytics, Crashlytics, Remote Config, Auth, ...). Cloud features come only from Google
   Play Games Services and Play Billing.
2. **Interfaces rule.** Game and UI code never calls a vendor SDK directly. They depend on the
   service interfaces in `lib/core/` (IdentityService, SaveService, LeaderboardService,
   AdService, PurchaseService, NotificationService, AnalyticsService, RemoteConfigService).
   Vendor SDKs (`google_mobile_ads`, `in_app_purchase`, `flutter_local_notifications`, Play
   Games) may be imported only inside the implementation files of those services.
3. **Pure-Dart game rules.** `lib/game/rules/` has no Flutter, Flame or Android imports, so
   it stays testable on the VM and portable to iOS/web.
4. **Test-ID rule.** Every interactive widget and key game element carries a stable
   `Key('...')` / semantics identifier (constants in `lib/ui/test_ids.dart`) so widget and
   integration tests never depend on text or coordinates alone. New screens add their IDs there.
5. **Never touch secrets.** Never create, read, print, or commit keystores, `key.properties`,
   service-account JSON, real AdMob IDs in debug, or passwords. Secrets live only in GitHub
   Actions secrets. Real AdMob IDs go only into release config via `app.config.yaml`.
6. **Test ad IDs only** in debug and in the template. `scripts/ad_safety_check.sh` enforces it.
7. **Assets** must be listed in `assets/LICENSES.md` (source, license). CI checks this.
8. **Pin Flutter** to `.flutter-version`; do not use floating `stable` in workflows.

## Workflow

- Work on a branch, open a PR, let CI go green. Never push to `main` directly.
- Before pushing the template: `flutter analyze`, `dart format --set-exit-if-changed .`,
  `flutter test`, `bash scripts/ad_safety_check.sh`.
- Keep Android-first, but keep logic in pure Dart and platform specifics behind interfaces and
  `app.config.yaml` `platforms:` so iOS/web can be added later.
