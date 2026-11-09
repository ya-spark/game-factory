#!/usr/bin/env bash
# Self-test for profile_check.sh: passes on good configs, fails on each unsafe combination.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fails=0

# case <name> <expected 0|1> <sed expression applied to the template config>
run_case() {
  local name="$1" expected="$2" expr="$3"
  cp "$root/app.config.yaml" "$tmp/c.yaml"
  [ -n "$expr" ] && sed -i -E "$expr" "$tmp/c.yaml"
  PROFILE_CONFIG="$tmp/c.yaml" bash "$root/scripts/profile_check.sh" >/dev/null 2>&1
  local rc=$?
  if { [ "$expected" = 0 ] && [ $rc -eq 0 ]; } || { [ "$expected" = 1 ] && [ $rc -ne 0 ]; }; then
    echo "ok   - $name"
  else
    echo "FAIL - $name (exit $rc, expected $([ "$expected" = 0 ] && echo pass || echo fail))"; fails=1
  fi
}

CHILD='s/^audience: adult/audience: child/; s/^  child_directed: false/  child_directed: true/; s/^  rewarded_enabled: true/  rewarded_enabled: false/; s/^  max_ad_content_rating: PG/  max_ad_content_rating: G/'
TEEN='s/^audience: adult/audience: teen/; s/^  child_directed: false/  child_directed: true/; s/^  rewarded_enabled: true/  rewarded_enabled: false/'

run_case "template (adult) passes" 0 ""
run_case "good child config passes" 0 "$CHILD"
run_case "good teen config passes" 0 "$TEEN"
run_case "teen with optional sign-in passes" 0 "$TEEN; s/^(play_games:)/\1/; /^play_games:/,/^[^ #]/ s/^  enabled: false/  enabled: true/"
run_case "interstitials enabled fails" 1 's/^  interstitials_enabled: false/  interstitials_enabled: true/'
run_case "interstitials key missing fails" 1 '/interstitials_enabled/d'
run_case "missing audience fails" 1 '/^audience:/d'
run_case "unknown audience fails" 1 's/^audience: adult/audience: kids/'
run_case "adult with child_directed true fails" 1 's/^  child_directed: false/  child_directed: true/'
run_case "child with rewarded ads fails" 1 "$CHILD; s/^  rewarded_enabled: false/  rewarded_enabled: true/"
run_case "teen with rewarded ads fails" 1 "$TEEN; s/^  rewarded_enabled: false/  rewarded_enabled: true/"
run_case "child not child-directed fails" 1 "$CHILD; s/^  child_directed: true/  child_directed: false/"
run_case "child with rating PG fails" 1 "$CHILD; s/^  max_ad_content_rating: G/  max_ad_content_rating: PG/"
run_case "teen with rating T fails" 1 "$TEEN; s/^  max_ad_content_rating: PG/  max_ad_content_rating: T/"
run_case "child with sign-in fails" 1 "$CHILD; /^play_games:/,/^[^ #]/ s/^  enabled: false/  enabled: true/"
run_case "child with parent gate off fails" 1 "$CHILD; "'$a\
parent_gate:\
  purchases: false\
  coin_spends: true'
run_case "teen with coin-spend gate off fails" 1 "$TEEN; "'$a\
parent_gate:\
  purchases: true\
  coin_spends: false'
exit $fails
