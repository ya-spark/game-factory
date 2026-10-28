#!/usr/bin/env bash
# Fails if a file under assets/ is not listed (by relative path) in assets/LICENSES.md.
set -euo pipefail
cd "$(dirname "$0")/.."
LIC="assets/LICENSES.md"
[ -f "$LIC" ] || { echo "ASSET LICENSES: $LIC missing" >&2; exit 1; }
missing=0
while IFS= read -r f; do
  case "$f" in "$LIC"|*/.gitkeep) continue;; esac
  if ! grep -qF "$f" "$LIC"; then
    echo "ASSET LICENSES: $f is not listed in $LIC" >&2
    missing=1
  fi
done < <(find assets -type f | sort)
[ "$missing" -eq 0 ] || exit 1
echo "ASSET LICENSES: OK"
