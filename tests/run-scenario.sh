#!/usr/bin/env bash
# Runs the executor of a cat-soup scenario: a headless `claude -p` session started in a lab.
#
# Usage: run-scenario.sh <dest> <scenario> "<typed command>"            first call; starts a session
#        run-scenario.sh <dest> <scenario> --resume <session_id> "<answer>"   continues that session
#
# <dest> is a lab built by make-lab.sh; <scenario> names the run folder
# <runs>/<scenario>-<date>/, with <runs> = $CAT_SOUP_RUNS, else ${TMPDIR:-/tmp}/cat-soup-runs (the OS temporary
# directory, so no log or verdict lands in the repository).
# Every call writes call-<n>.jsonl (stream-json log) and call-<n>.err there, and prints the session_id,
# turns, cost and the assistant's last text. The skills load through --plugin-dir <this checkout>/plugin.
# Environment: MAX_TURNS (default 30) and CALL_TIMEOUT in seconds (default 900) apply to every call.
# Design: Architecture/cat-soup/Design/testing.md#roles
# Why these flags: Architecture/cat-soup/003-Design_0.1/Side-Tests/permission-probe.md
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd -P)
CAT_SOUP=$(cd "$HERE/.." && pwd -P)
RUNS=${CAT_SOUP_RUNS:-${TMPDIR:-/tmp}/cat-soup-runs}   # outside the checkout: runs are never committed
RUNS=${RUNS%/}
MAX_TURNS=${MAX_TURNS:-30}
CALL_TIMEOUT=${CALL_TIMEOUT:-900}

die () { echo "run-scenario: $*" >&2; exit 2; }
usage="usage: run-scenario.sh <dest> <scenario> \"<typed command>\" | run-scenario.sh <dest> <scenario> --resume <session_id> \"<answer>\""

[ $# -ge 3 ] || die "$usage"
DEST_ARG=$1; SCENARIO=$2; shift 2
RESUME=
if [ "$1" = "--resume" ]; then
  [ $# -eq 3 ] || die "$usage"
  RESUME=$2; PROMPT=$3
else
  [ $# -eq 1 ] || die "$usage"
  PROMPT=$1
fi
[ -n "$PROMPT" ] || die "empty prompt"
case "$SCENARIO" in ''|*/*|.*) die "scenario '$SCENARIO' must be a plain name" ;; esac

# --- refusals -----------------------------------------------------------------------------------
[ -z "${ANTHROPIC_API_KEY:-}" ] || die "ANTHROPIC_API_KEY is set; the checks run on the plan login, not on an API key"
[ -d "$DEST_ARG" ] || die "<dest> '$DEST_ARG' is not a directory"
DEST=$(cd "$DEST_ARG" && pwd -P)
[ -f "$DEST/allowed-tools.txt" ] && [ -f "$DEST/CLAUDE.md" ] || die "'$DEST' is not a lab built by make-lab.sh (no allowed-tools.txt or CLAUDE.md)"
case "$DEST/" in */.claude/*) die "<dest> is under a .claude directory; Claude Code refuses writes there" ;; esac
TIMEOUT=$(command -v timeout || command -v gtimeout || true)
[ -n "$TIMEOUT" ] || die "neither timeout nor gtimeout is installed (brew install coreutils)"
for tool in claude jq; do command -v "$tool" >/dev/null 2>&1 || die "'$tool' is not installed"; done

# --- the run folder -----------------------------------------------------------------------------
if [ -n "$RESUME" ]; then
  RUN_DIR=$(grep -lx "$RESUME" "$RUNS/$SCENARIO"-*/session_id 2>/dev/null | head -1 | xargs -I{} dirname {} || true)
  [ -n "$RUN_DIR" ] || die "no run of '$SCENARIO' under $RUNS has session_id $RESUME"
else
  base="$RUNS/$SCENARIO-$(date +%Y-%m-%d)"; RUN_DIR=$base; n=1
  while [ -e "$RUN_DIR" ]; do n=$((n + 1)); RUN_DIR="$base-$n"; done
  mkdir -p "$RUN_DIR"
  {
    echo "scenario: $SCENARIO"
    echo "date: $(date +%Y-%m-%dT%H:%M:%S%z)"
    echo "claude: $(claude --version)"
    echo "cat-soup commit: $(git -C "$CAT_SOUP" rev-parse --short HEAD)$(git -C "$CAT_SOUP" diff --quiet HEAD -- plugin 2>/dev/null || echo ' (plugin modified)')"
    echo "dest: $DEST"
  } > "$RUN_DIR/meta.txt"
fi
N=$(( $(find "$RUN_DIR" -maxdepth 1 -name 'call-*.jsonl' | wc -l | tr -d ' ') + 1 ))
LOG="$RUN_DIR/call-$N.jsonl"; ERR="$RUN_DIR/call-$N.err"
printf '%s\n' "$PROMPT" > "$RUN_DIR/call-$N.prompt"

# --- one call -----------------------------------------------------------------------------------
RULES=(); while IFS= read -r r; do [ -n "$r" ] && RULES+=("$r"); done < "$DEST/allowed-tools.txt"
ARGS=(-p "$PROMPT")
[ -z "$RESUME" ] || ARGS+=(--resume "$RESUME")
ARGS+=(--plugin-dir "$CAT_SOUP/plugin" --output-format stream-json --verbose --max-turns "$MAX_TURNS"
       --setting-sources project,local --allowed-tools "${RULES[@]}")

# The executor must not inherit the caller's session markers, an API key or a forge token.
CLEAN=()
for v in $(env | sed -n 's/^\(CLAUDE[A-Za-z_]*\)=.*/\1/p'); do CLEAN+=(-u "$v"); done
CLEAN+=(-u AI_AGENT -u GH_TOKEN -u GITHUB_TOKEN -u GITLAB_TOKEN)

rc=0
( cd "$DEST" && env ${CLEAN[@]+"${CLEAN[@]}"} PATH="$DEST/bin:$PATH" \
    "$TIMEOUT" "$CALL_TIMEOUT" claude "${ARGS[@]}" > "$LOG" 2> "$ERR" ) || rc=$?

# --- report -------------------------------------------------------------------------------------
SID=$(jq -r 'select(.type=="system" and .subtype=="init") | .session_id' "$LOG" 2>/dev/null | head -1 || true)
if [ -z "$RESUME" ] && [ -n "$SID" ]; then echo "$SID" > "$RUN_DIR/session_id"; fi
# The stream log does not echo the typed command; the session transcript holds it as the injected command
# message. Claude Code names the transcript folder after the path with every non-alphanumeric turned into '-'.
if [ -n "$SID" ]; then
  transcript="$HOME/.claude/projects/$(printf '%s' "$DEST" | sed 's/[^A-Za-z0-9]/-/g')/$SID.jsonl"
  if [ -f "$transcript" ]; then cp "$transcript" "$RUN_DIR/transcript.jsonl"
  else echo "run-scenario: no session transcript at $transcript" >&2; fi
fi
echo "run:        $RUN_DIR (call $N, exit $rc)"
echo "session_id: ${SID:-none}"
jq -r 'select(.type=="result") | "result:     \(.subtype), \(.num_turns) turns, cost \(.total_cost_usd // "n/a") usd, \((.duration_ms // 0) / 1000 | floor) s"' "$LOG" 2>/dev/null || true
echo "--- last assistant text"
jq -rs '[.[] | select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text] | last // "(none)"' "$LOG" 2>/dev/null || true
echo "---"

status=0
[ "$rc" -eq 0 ] || { echo "run-scenario: claude exited $rc (124 is the timeout); see $ERR" >&2; status=1; }
[ -n "$SID" ] || { echo "run-scenario: no init event in $LOG" >&2; status=1; }
if [ -n "$SID" ] && ! jq -e 'select(.type=="system" and .subtype=="init") | .skills | any(startswith("cat:"))' "$LOG" >/dev/null 2>&1; then
  echo "run-scenario: the init event lists no cat: skill" >&2; status=1
fi
[ -z "$RESUME" ] || [ "$SID" = "$RESUME" ] || { echo "run-scenario: resumed session_id is ${SID:-none}, not $RESUME" >&2; status=1; }
exit $status
