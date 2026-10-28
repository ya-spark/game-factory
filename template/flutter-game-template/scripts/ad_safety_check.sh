#!/usr/bin/env bash
# Ad safety check. Fails (exit 1) if:
#   1. a real (non-test) AdMob ID appears anywhere a debug build can read it:
#      app.config.yaml admob.debug.*, android debug manifests, lib/ sources, tests;
#   2. a Google TEST AdMob ID appears in release config (app.config.yaml admob.release.*).
# Test IDs belong to Google's sample publisher ca-app-pub-3940256099942544.
# Run from the game repo root:  bash scripts/ad_safety_check.sh
set -euo pipefail
cd "$(dirname "$0")/.."

TEST_PUB="ca-app-pub-3940256099942544"
ID_RE='ca-app-pub-[0-9]{16}[~/][0-9]{10}'
fail=0
err() { echo "AD SAFETY: $*" >&2; fail=1; }

CONFIG="app.config.yaml"
[ -f "$CONFIG" ] || { echo "AD SAFETY: $CONFIG not found" >&2; exit 1; }

# Print lines of a section: admob.<mode> (mode = debug|release), as "lineno:content".
section() {
  awk -v mode="$1" '
    /^[^ #]/ { in_admob = ($0 ~ /^admob:/); in_mode = 0; next }
    in_admob && /^  [a-z]+:/ { in_mode = ($0 ~ "^  " mode ":"); next }
    in_admob && in_mode { print NR ":" $0 }
  ' "$CONFIG"
}

debug_lines="$(section debug)"
release_lines="$(section release)"
[ -n "$debug_lines" ] || err "$CONFIG: admob.debug section missing or empty"
[ -n "$release_lines" ] || err "$CONFIG: admob.release section missing or empty"

# 1a. debug section: every AdMob ID must be a test ID.
while IFS= read -r line; do
  [ -z "$line" ] && continue
  for id in $(echo "$line" | grep -oE "$ID_RE" || true); do
    case "$id" in "$TEST_PUB"*) ;; *) err "$CONFIG admob.debug has a REAL ad ID: $id";; esac
  done
done <<< "$debug_lines"
# Debug values must be present and not placeholders.
if echo "$debug_lines" | grep -q 'PLACEHOLDER'; then err "$CONFIG admob.debug must use Google test IDs, not placeholders"; fi

# 2. release section: no test IDs.
if echo "$release_lines" | grep -q "$TEST_PUB"; then
  err "$CONFIG admob.release contains a Google TEST ad ID; release must use real IDs (or PLACEHOLDER_* until set)"
fi

# 1b. Other places a debug build reads: dart sources, tests, debug/profile manifests.
scan_paths=()
for p in lib test integration_test android/app/src/debug android/app/src/profile; do
  [ -e "$p" ] && scan_paths+=("$p")
done
if [ ${#scan_paths[@]} -gt 0 ]; then
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    id="$(echo "$hit" | grep -oE "$ID_RE" | head -1)"
    case "$id" in "$TEST_PUB"*) ;; *) err "real ad ID outside release config: $hit";; esac
  done < <(grep -rnE "$ID_RE" "${scan_paths[@]}" 2>/dev/null || true)
fi

# 1c. The main manifest must not hardcode an AdMob app ID (it is injected per build type).
MAIN_MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MAIN_MANIFEST" ] && grep -qE "$ID_RE" "$MAIN_MANIFEST"; then
  err "$MAIN_MANIFEST hardcodes an AdMob ID; use the \${admobAppId} placeholder"
fi

# 1d. Gradle: debug build type must read admob.debug, release must read admob.release.
GRADLE="android/app/build.gradle.kts"
if [ -f "$GRADLE" ]; then
  awk '
    /debug *\{/ { b="debug" } /release *\{/ { b="release" }
    /manifestPlaceholders\["admobAppId"\]/ {
      if (b=="debug"   && $0 !~ /"admob", *"debug"/)   { print "debug build type does not read admob.debug"; bad=1 }
      if (b=="release" && $0 !~ /"admob", *"release"/) { print "release build type does not read admob.release"; bad=1 }
    }
    END { exit bad }' "$GRADLE" >&2 || err "$GRADLE: admobAppId wiring is wrong (see messages above)"
fi

if [ "$fail" -ne 0 ]; then
  echo "AD SAFETY: FAILED" >&2
  exit 1
fi
echo "AD SAFETY: OK (debug uses test IDs only; release has no test IDs)"
