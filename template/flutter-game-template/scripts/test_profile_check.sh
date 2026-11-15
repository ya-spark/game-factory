#!/usr/bin/env bash
# Self-test for profile_check.sh: passes on good configs, fails on each unsafe combination.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fails=0

# NORM resets a repo's own profile to the plain adult template state, so every case below starts from the same
# config whether this runs in the template or in a child, teen or adult game repo.
NORM='s/^audience: [a-z]+/audience: adult/; s/^  age_treatment: [a-z]+/  age_treatment: none/; s/^  child_directed: (true|false)/  child_directed: false/; s/^  rewarded_enabled: (true|false)/  rewarded_enabled: true/; s/^  max_ad_content_rating: [A-Z]+/  max_ad_content_rating: PG/; s/^  interstitials_enabled: (true|false)/  interstitials_enabled: false/; /^play_games:/,/^[^ #]/ s/^  enabled: (true|false)/  enabled: false/; /^adsense:/,/^[^ #]/ s/^  enabled: (true|false)/  enabled: false/'

# case <name> <expected 0|1> <sed expression applied after NORM>
run_case() {
  local name="$1" expected="$2" expr="$3"
  cp "$root/app.config.yaml" "$tmp/c.yaml"
  sed -i -E "$NORM" "$tmp/c.yaml"
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
# AdSense (X2b): the age treatment must match the audience when AdSense is switched on.
ASON='/^adsense:/,/^[^ #]/ s/^  enabled: false/  enabled: true/'
run_case "adult with adsense on and treatment none passes" 0 "$NORM; $ASON"
run_case "child with adsense on, treatment child passes" 0 "$NORM; $CHILD; $ASON; /^adsense:/,/^[^ #]/ s/^  age_treatment: none/  age_treatment: child/"
run_case "teen with adsense on, treatment teen passes" 0 "$NORM; $TEEN; $ASON; /^adsense:/,/^[^ #]/ s/^  age_treatment: none/  age_treatment: teen/"
run_case "child with adsense on, treatment none fails" 1 "$NORM; $CHILD; $ASON"
run_case "child with adsense on, treatment teen fails" 1 "$NORM; $CHILD; $ASON; /^adsense:/,/^[^ #]/ s/^  age_treatment: none/  age_treatment: teen/"
run_case "teen with adsense on, treatment none fails" 1 "$NORM; $TEEN; $ASON"
run_case "teen with adsense on, treatment child fails" 1 "$NORM; $TEEN; $ASON; /^adsense:/,/^[^ #]/ s/^  age_treatment: none/  age_treatment: child/"
run_case "unknown age treatment fails" 1 "$NORM; s/^  age_treatment: none/  age_treatment: adult/"
exit $fails
