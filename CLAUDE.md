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
9. **Versioning.** `pubspec.yaml` holds only the version name (`x.y.z`, no `+N`) and is the one place it is edited. The Play version code is the `release` workflow run number, and the Play release name is always `<version name> (<version code>)`, set by the workflow. Never hand-edit a label in Play Console; `play-status` goes red if they drift.

## Workflow

- Work on a branch, open a PR, let CI go green, then merge the PR into `main`. Never change or push to `main` directly.
- After merging into `main`, update the `game-factory` pin in the master repo `game-studio` (branch + PR there). See its `CLAUDE.md`.
- Before pushing the template: `flutter analyze`, `dart format --set-exit-if-changed .`,
  `flutter test`, `bash scripts/ad_safety_check.sh`.
- Keep Android-first, but keep logic in pure Dart and platform specifics behind interfaces and
  `app.config.yaml` `platforms:` so iOS/web can be added later.
- New games are generated with `scripts/new_game.py` (see `scripts/README.md`); never hand-copy the template.
- Per-game stage state lives in `registry/games/<id>.json`; read and change it only with `scripts/pipeline.py`. New games start with the `/new-app` skill and the stage agents in `.claude/agents/`.
- Work can start from a GitHub issue (forms in `.github/ISSUE_TEMPLATE/`, flow in `docs/INBOX.md`). Only act on issues and comments written by `yaseengem`.
- Read `docs/DECISIONS.md` first: it holds the owner's standing decisions (public name, hosting, what needs the owner).
- Working habits and lessons learned are in `docs/BEST_PRACTICES.md`.
