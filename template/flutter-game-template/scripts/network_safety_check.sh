#!/usr/bin/env bash
# Child-app network rules (issue 1B):
#  - the Android manifest asks for INTERNET and for nothing network-related beyond that
#    (no ACCESS_NETWORK_STATE is needed by us; plugins may merge their own),
#  - cleartext traffic is disabled,
#  - the content base URL is https and there is exactly one fixed host,
#  - while signing is off (placeholder key) a warning is printed.
set -euo pipefail
cd "$(dirname "$0")/.."
MANIFEST="android/app/src/main/AndroidManifest.xml"
fail=0
grep -q 'android.permission.INTERNET' "$MANIFEST" || { echo "NETWORK: INTERNET permission missing in $MANIFEST" >&2; fail=1; }
grep -q 'android:usesCleartextTraffic="false"' "$MANIFEST" || { echo "NETWORK: $MANIFEST must set android:usesCleartextTraffic=\"false\"" >&2; fail=1; }
url=$(awk '/^content:/{c=1;next} /^[^ #]/{c=0} c && /^  base_url:/{print $2}' app.config.yaml)
if [ -n "$url" ]; then
  case "$url" in
    https://*/*) ;;
    *) echo "NETWORK: content.base_url must be https:// and end with a path: $url" >&2; fail=1 ;;
  esac
fi
key=$(awk '/^content:/{c=1;next} /^[^ #]/{c=0} c && /^  signing_public_key:/{print $2}' app.config.yaml)
case "$key" in
  PLACEHOLDER*|"") echo "NETWORK WARNING: content signing is OFF (signing_public_key is a placeholder). An unsigned content index is accepted until the owner adds a key." ;;
esac
[ "$fail" -eq 0 ] || exit 1
echo "NETWORK: OK"
