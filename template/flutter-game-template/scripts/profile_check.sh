#!/usr/bin/env bash
# Compliance profile check (issue 1C2). Reads app.config.yaml and fails (exit 1) on unsafe
# combinations for the app's `audience:` (child | teen | adult):
#   every profile : audience is set and valid; ads.interstitials_enabled is false;
#                   ads.banner_enabled is a plain boolean
#   child, teen   : ads.child_directed true; ads.rewarded_enabled not true; max_ad_content_rating
#                   at most G (child) or PG (teen); content.enabled apps keep the parent gate
#                   (parent_gate.purchases and parent_gate.coin_spends must not be false)
#   child         : play_games.enabled false (no sign-in)
#   adult         : ads.child_directed false
# Run from the game repo root:  bash scripts/profile_check.sh
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${PROFILE_CONFIG:-app.config.yaml}"
fail=0
err() { echo "PROFILE: $*" >&2; fail=1; }
[ -f "$CONFIG" ] || { echo "PROFILE: $CONFIG not found" >&2; exit 1; }

# top <key>: value of a top-level key (comments stripped).
top() { awk -v k="$1" '$0 ~ "^" k ":" { sub("^" k ":[ ]*", ""); sub("[ ]*#.*$", ""); gsub(/"/, ""); print; exit }' "$CONFIG"; }
# sub <section> <key>: value of a key one level down.
sub() {
  awk -v s="$1" -v k="$2" '
    /^[^ #]/ { in_s = ($0 ~ "^" s ":"); next }
    in_s && $0 ~ "^  " k ":" { sub("^  " k ":[ ]*", ""); sub("[ ]*#.*$", ""); gsub(/"/, ""); print; exit }' "$CONFIG"
}

audience="$(top audience)"
case "$audience" in
  child | teen | adult) ;;
  *) err "audience must be child, teen or adult (got '${audience:-missing}')"; audience="" ;;
esac

interstitials="$(sub ads interstitials_enabled)"
[ "$interstitials" = "false" ] || err "ads.interstitials_enabled must be false in every profile (got '${interstitials:-missing}')"
banner="$(sub ads banner_enabled)"
case "$banner" in true | false) ;; *) err "ads.banner_enabled must be true or false (got '${banner:-missing}')" ;; esac

rewarded="$(sub ads rewarded_enabled)"
directed="$(sub ads child_directed)"
rating="$(sub ads max_ad_content_rating)"
signin="$(sub play_games enabled)"
gate_p="$(sub parent_gate purchases)"
gate_c="$(sub parent_gate coin_spends)"

case "$audience" in
  child | teen)
    [ "$directed" = "true" ] || err "$audience profile: ads.child_directed must be true"
    [ "$rewarded" != "true" ] || err "$audience profile: rewarded ads are not allowed (ads.rewarded_enabled must not be true)"
    [ "$gate_p" != "false" ] || err "$audience profile: parent_gate.purchases must not be false (parent gate on every purchase)"
    [ "$gate_c" != "false" ] || err "$audience profile: parent_gate.coin_spends must not be false (parent gate on coin spends)"
    if [ "$audience" = "child" ]; then
      [ "$rating" = "G" ] || err "child profile: ads.max_ad_content_rating must be G (got '${rating:-missing}')"
      [ "$signin" != "true" ] || err "child profile: play_games.enabled must be false (no sign-in)"
    else
      case "$rating" in G | PG) ;; *) err "teen profile: ads.max_ad_content_rating must be G or PG (got '${rating:-missing}')" ;; esac
    fi
    ;;
  adult)
    [ "$directed" = "false" ] || err "adult profile: ads.child_directed must be false"
    ;;
esac

if [ "$fail" -ne 0 ]; then
  echo "PROFILE: FAILED" >&2
  exit 1
fi
echo "PROFILE: OK (audience ${audience})"
