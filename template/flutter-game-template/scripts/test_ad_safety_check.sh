#!/usr/bin/env bash
# Self-test for ad_safety_check.sh: proves it passes on the template and FAILS on violations.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fails=0

run_case() { # name expected(0|1) mutation-command
  local name="$1" expected="$2" mutate="$3"
  rm -rf "$tmp/w" && mkdir -p "$tmp/w"
  (cd "$root" && cp -r app.config.yaml scripts "$tmp/w/" && { [ -d lib ] && cp -r lib "$tmp/w/"; [ -d android ] && mkdir -p "$tmp/w/android/app" && cp -r android/app/src "$tmp/w/android/app/" && cp android/app/build.gradle.kts "$tmp/w/android/app/"; } ) >/dev/null 2>&1
  (cd "$tmp/w" && eval "$mutate")
  (cd "$tmp/w" && bash scripts/ad_safety_check.sh >/dev/null 2>&1)
  local rc=$?
  if { [ "$expected" = 0 ] && [ $rc -eq 0 ]; } || { [ "$expected" = 1 ] && [ $rc -ne 0 ]; }; then
    echo "ok   - $name"
  else
    echo "FAIL - $name (exit $rc, expected $([ "$expected" = 0 ] && echo pass || echo fail))"; fails=1
  fi
}

REAL_ID='ca-app-pub-1234567890123456/1111111111'
run_case "template as shipped passes" 0 ":"
run_case "real ID in admob.debug fails" 1 "sed -i '0,/banner: ca-app-pub-3940256099942544\/6300978111/s||banner: $REAL_ID|' app.config.yaml"
run_case "test ID in admob.release fails" 1 "sed -i 's|banner: PLACEHOLDER_ADMOB_BANNER_ID|banner: ca-app-pub-3940256099942544/6300978111|' app.config.yaml"
run_case "real release IDs pass" 0 "sed -i 's|banner: PLACEHOLDER_ADMOB_BANNER_ID|banner: $REAL_ID|' app.config.yaml"
run_case "real ID hardcoded in lib/ fails" 1 "mkdir -p lib && echo \"const x = '$REAL_ID';\" > lib/leak.dart"
run_case "real ID in debug manifest fails" 1 "mkdir -p android/app/src/debug && echo '<meta-data android:value=\"ca-app-pub-1234567890123456~1111111111\"/>' > android/app/src/debug/AndroidManifest.xml"
run_case "real ID hardcoded in main manifest fails" 1 "echo '<meta-data android:value=\"ca-app-pub-1234567890123456~1111111111\"/>' >> android/app/src/main/AndroidManifest.xml"
exit $fails
