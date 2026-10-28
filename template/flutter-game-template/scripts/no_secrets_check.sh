#!/usr/bin/env bash
# Fails if a keystore, key.properties or service-account file is tracked by git.
set -euo pipefail
cd "$(dirname "$0")/.."
bad="$(git ls-files 2>/dev/null | grep -Ei '(\.jks|\.keystore|\.p12|key\.properties|service[-_]?account.*\.json|google-services\.json)$' || true)"
if [ -n "$bad" ]; then
  echo "SECRETS: tracked secret-like files:" >&2
  echo "$bad" >&2
  exit 1
fi
# Private key material anywhere in tracked text files.
if git ls-files -z 2>/dev/null | xargs -0 grep -lE -- '-----BEGIN (RSA |EC )?PRIVATE KEY-----' 2>/dev/null; then
  echo "SECRETS: private key material found in tracked files" >&2
  exit 1
fi
echo "SECRETS: OK"
