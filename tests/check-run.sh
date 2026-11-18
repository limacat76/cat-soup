#!/usr/bin/env bash
# Reduces a run's logs to what a reader needs and checks the mechanical lines of a scenario.
#
# Usage: check-run.sh <run dir> <skill>     <skill> is the skill the first call typed, e.g. cat-open-plan
#
# <run dir> is <runs>/<scenario>-<date>/ in the OS temporary directory, made by run-scenario.sh (it prints the path). Prints, per call, every tool call
# (name and truncated arguments), denied permissions and the assistant's text; then the checks, one line each
# (PASS, FAIL or ENV for an environment failure). Exit 1 when a check fails.
# Every run asserts the evidence line: the init event lists cat:<skill>, and the typed command appears as the
# injected command message of the session transcript. Each D and E step adds its scenario's checks in
# scenario_checks below.
# Design: Architecture/cat-soup/Design/testing.md#check-runsh
set -uo pipefail

die () { echo "check-run: $*" >&2; exit 2; }
[ $# -eq 2 ] || die "usage: check-run.sh <run dir> <skill>"
RUN_DIR=$(cd "$1" 2>/dev/null && pwd -P) || die "'$1' is not a directory"
SKILL=$2
command -v jq >/dev/null 2>&1 || die "jq is not installed"
shopt -s nullglob
CALLS=("$RUN_DIR"/call-*.jsonl)
[ "${#CALLS[@]}" -gt 0 ] || die "no call-*.jsonl in $RUN_DIR"

fails=0
pass () { echo "PASS $*"; }
fail () { echo "FAIL $*"; fails=$((fails + 1)); }
env_fail () { echo "ENV  $*"; fails=$((fails + 1)); }
check () { local label=$1; shift; if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi; }

# --- the reduced log ------------------------------------------------------------------------------
for log in "${CALLS[@]}"; do
  echo "===== $(basename "$log" .jsonl): $(head -c 200 "${log%.jsonl}.prompt" 2>/dev/null | head -1)"
  jq -r '
    if .type == "assistant" then
      .message.content[]? |
        if .type == "tool_use" then "tool  \(.name) \(.input | tostring | .[0:160])"
        elif .type == "text" then "text  \(.text)"
        else empty end
    elif .type == "system" and .subtype == "permission_denied" then "DENIED \(. | tostring | .[0:200])"
    elif .type == "result" then "result \(.subtype), \(.num_turns) turns, cost \(.total_cost_usd // "n/a") usd"
    else empty end' "$log" 2>/dev/null
done
echo "===== checks"

# --- evidence line and environment ----------------------------------------------------------------
FIRST=${CALLS[0]}
check "evidence: init event of every call lists cat:$SKILL" \
  bash -c 'for f in "$@"; do jq -e --arg s "cat:'"$SKILL"'" "select(.type==\"system\" and .subtype==\"init\") | .skills | index(\$s)" "$f" >/dev/null || exit 1; done' _ "${CALLS[@]}"
if [ -f "$RUN_DIR/transcript.jsonl" ]; then
  check "evidence: the typed command /cat:$SKILL is the injected command message" \
    jq -s -e --arg c "<command-name>/cat:$SKILL</command-name>" \
      'any(.[]; .type=="user" and ((.message.content | if type=="string" then . else tostring end) | contains($c)))' "$RUN_DIR/transcript.jsonl"
else
  fail "evidence: no transcript.jsonl in the run folder"
fi
check "isolation: plugins are cat and cc-plugin-* only" \
  jq -e 'select(.type=="system" and .subtype=="init") | [.plugins[]? | (.name // .) | select(. != "cat" and (startswith("cc-plugin-") | not))] | length == 0' "$FIRST"
if jq -e 'select(.type=="system" and .subtype=="permission_denied")' "${CALLS[@]}" >/dev/null 2>&1; then
  env_fail "a permission was denied (an environment failure, not a skill failure); see the DENIED lines"
else
  pass "no permission was denied"
fi
check "every call ended with a result event" \
  bash -c 'for f in "$@"; do jq -e "select(.type==\"result\")" "$f" >/dev/null || exit 1; done' _ "${CALLS[@]}"

# --- scenario checks ------------------------------------------------------------------------------
# Each D and E step adds a `case` arm for its scenario: the mechanical Must and Must not lines, written
# with check/fail/pass over the run's logs and the lab named in meta.txt (grep '^dest:').
scenario_checks () {
  case "$(basename "$RUN_DIR" | sed 's/-[0-9]\{4\}-[0-9][0-9]-[0-9][0-9].*$//')" in
    *) : ;;
  esac
}
scenario_checks

echo "===== $fails failed"
[ "$fails" -eq 0 ]
