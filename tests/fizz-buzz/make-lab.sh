#!/usr/bin/env bash
# Builds the fizz-buzz lab the cat-soup scenarios run in.
#
# Usage: make-lab.sh <dest> [--remotes|--no-upstream|--empty] [--plan clean|step1-committed|done]
#        make-lab.sh --print-plan <state> [<root>]
#
# <dest> is an existing, empty directory, for example `make-lab.sh "$(mktemp -d)"`.
# --print-plan prints the plan file of <state> without building a lab (no git, no uv); the paths in it
# are written under <root>, which defaults to /lab. A built lab's plan file equals `--print-plan <state> <dest>`
# with <dest> as `cd <dest> && pwd -P` prints it.
# Design: Architecture/cat-soup/Design/testing.md#make-labsh
set -euo pipefail

# --- shared definitions -------------------------------------------------------------------------
BASE=main                    # base branch, written to the plan header as base_branch
ORIGIN=origin                # the contributor's fork
UPSTREAM=upstream            # the project the fork came from
REPO=fizz-buzz               # repo folder name: the skills' default paths use it
SLUG=excel-export            # plan slug; plan branch is cat/$SLUG
PLAN_DATE=2026-11-14         # plan file name prefix; the lab's history is synthetic
BASELINE_TEST_CMD='make test'
BASELINE_PASSED=8            # `make test` on the template: 8 passed, 1 deselected
SYNTH_AUTHOR=fizz-lab
SYNTH_EMAIL=fizz-lab@example.invalid

HERE=$(cd "$(dirname "$0")" && pwd -P)
CAT_SOUP=$(cd "$HERE/../.." && pwd -P)
SKILL="$CAT_SOUP/plugin/skills/cat-open-plan/SKILL.md"

die () { echo "make-lab: $*" >&2; exit 2; }
refuse () { echo "make-lab: refused: $*" >&2; exit 2; }

# --- the plan file ------------------------------------------------------------------------------
# The template block of SKILL.md, without the code fences. The script keeps no copy of it.
template_block () {
  [ -f "$SKILL" ] || die "$SKILL not found"
  local out
  out=$(awk 'index($0, "cat-soup:plan-template begin") {p = 1; next}
             index($0, "cat-soup:plan-template end") {p = 0}
             p && $0 !~ /^```/' "$SKILL")
  [ -n "$out" ] || die "no plan template between the markers in $SKILL"
  printf '%s\n' "$out"
}

# plan_text <state> <root>: the plan file for <state>, paths under <root>.
plan_text () {
  local state=$1 root=$2 tpl tick key rest label
  case "$state" in
    clean|step1-committed) tick=' ' ;;
    done) tick=x ;;
    *) die "unknown plan state '$state' (clean, step1-committed, done)" ;;
  esac
  tpl=$(template_block)

  # front matter: keys and their order from the template, values written here
  echo '---'
  while IFS= read -r line; do
    key=${line%%:*}
    rest=${line#*: }           # the template's own value stays where this script has none
    case "$key" in
      source)            rest="$root/designs/$SLUG.md" ;;
      repo)              rest="$root/$REPO" ;;
      base_branch)       rest="$BASE" ;;
      branch)            rest="cat/$SLUG" ;;
      worktree)          rest="$root/Projects-Worktrees/$REPO/$SLUG" ;;
      baseline_failures) rest='[]' ;;
    esac
    echo "$key: $rest"
  done < <(printf '%s\n' "$tpl" | awk '/^---[ \t]*$/ {n++; next} n == 1 {print} n >= 2 {exit}')
  echo '---'

  # the Conventions label from the template, the value written here
  label=$(printf '%s\n' "$tpl" | sed -n 's/^\(Conventions\):.*/\1/p' | head -1)
  echo "${label:-Conventions}: CONTRIBUTING.md: one logical change per commit, imperative subject of at most 72 characters, a dependency change is committed with its \`uv.lock\` change. README: keep \`fizzbuzz(n)\` and \`run(limit)\` backwards compatible; they are public API."
  echo

  # the field labels of a step from the template, the values written here
  local labels=()
  while IFS= read -r label; do labels+=("$label"); done < <(
    printf '%s\n' "$tpl" | awk '/^- \[[ x]\] 1\./ {s = 1; next} s && /^- / {exit} s && /^  - [A-Z][A-Za-z ]*:/ {sub(/^  - /, ""); sub(/:.*/, ""); print}')
  [ "${#labels[@]}" -eq 3 ] || die "expected 3 step field labels in the template, found ${#labels[@]}"

  echo "- [$tick] 1. Add the openpyxl dependency and \`export_xlsx\`"
  echo "  - ${labels[0]}: pyproject.toml, uv.lock, fizzbuzz/export.py, fizzbuzz/__init__.py, tests/test_export.py"
  echo "  - ${labels[1]}: tests/test_export.py writes a limit-15 file, reads it back with openpyxl and asserts the sheet name \`fizzbuzz\`, the header row \`n\`, \`output\` and all 15 rows; it also asserts ValueError for limit 0 and for a non-integer limit, and FileExistsError for an existing path. Fails before, passes after."
  echo "  - ${labels[2]}: \`export_xlsx(15, path)\` writes the sheet described in the source and refuses to overwrite an existing file."
  echo "- [$tick] 2. Document \`export_xlsx\`"
  echo "  - ${labels[0]}: README.md"
  echo "  - ${labels[1]}: none (documentation). Check: README shows one usage line for \`export_xlsx\`."
  echo "  - ${labels[2]}: the README line exists."
  echo

  # the Notes heading from the template, the lines written here
  echo "$(printf '%s\n' "$tpl" | grep -m1 '^## Notes' || echo '## Notes')"
  echo "- Baseline: \`$BASELINE_TEST_CMD\`, $BASELINE_PASSED passed, no failures."
  echo "- Existing path: \`export_xlsx\` raises FileExistsError, as the source requires."
}

# --- --print-plan -------------------------------------------------------------------------------
if [ "${1:-}" = "--print-plan" ]; then
  [ $# -ge 2 ] && [ $# -le 3 ] || die "usage: make-lab.sh --print-plan <state> [<root>]"
  plan_text "$2" "${3:-/lab}"
  exit 0
fi

# --- arguments ----------------------------------------------------------------------------------
usage="usage: make-lab.sh <dest> [--remotes|--no-upstream|--empty] [--plan clean|step1-committed|done]"
[ $# -ge 1 ] || die "$usage"
DEST_ARG=$1; shift
MODE=local; PLAN=
while [ $# -gt 0 ]; do
  case "$1" in
    --remotes|--no-upstream|--empty)
      [ "$MODE" = local ] || refuse "$1 together with --$MODE"
      MODE=${1#--} ;;
    --plan)
      [ $# -ge 2 ] || die "--plan needs a state"
      [ -z "$PLAN" ] || die "--plan given twice"
      PLAN=$2; shift ;;
    *) die "unknown argument '$1'. $usage" ;;
  esac
  shift
done
if [ -n "$PLAN" ]; then
  case "$PLAN" in clean|step1-committed|done) ;; *) die "unknown plan state '$PLAN' (clean, step1-committed, done)" ;; esac
fi
[ "$MODE" != empty ] || [ -z "$PLAN" ] || refuse "--empty together with --plan"

# --- refusals -----------------------------------------------------------------------------------
[ -d "$DEST_ARG" ] || refuse "<dest> '$DEST_ARG' is not an existing directory; the caller creates it"
DEST=$(cd "$DEST_ARG" && pwd -P)
case "$DEST/" in "$CAT_SOUP"/*) refuse "<dest> is inside the cat-soup checkout ($CAT_SOUP)" ;; esac
[ -z "$(ls -A "$DEST")" ] || refuse "<dest> '$DEST' is not empty"
if [ -e "$HOME/.claude/skills/cat" ] || [ -L "$HOME/.claude/skills/cat" ]; then
  refuse "~/.claude/skills/cat exists on this machine; it would load next to the plugin under test"
fi
for tool in git uv jq python3; do
  command -v "$tool" >/dev/null 2>&1 || refuse "required tool '$tool' is not installed"
done

# --- build --------------------------------------------------------------------------------------
LAB_REPO="$DEST/$REPO"
export GIT_AUTHOR_NAME=$SYNTH_AUTHOR GIT_AUTHOR_EMAIL=$SYNTH_EMAIL
export GIT_COMMITTER_NAME=$SYNTH_AUTHOR GIT_COMMITTER_EMAIL=$SYNTH_EMAIL
git_at () {  # git_at <iso date> <git args...>: a commit date, so the history is the same on every build
  local when=$1; shift
  GIT_AUTHOR_DATE=$when GIT_COMMITTER_DATE=$when git "$@"
}

mkdir -p "$DEST/Plans/$REPO" "$DEST/Projects-Worktrees/$REPO" "$DEST/bin"
cp -R "$HERE/designs" "$DEST/designs"
cp "$HERE/LAB.md" "$DEST/LAB.md"
printf '@LAB.md\n' > "$DEST/CLAUDE.md"

# failing stubs: the lab has no forge, a skill that calls gh or glab must see it fail
for forge in gh glab; do
  printf '#!/usr/bin/env bash\necho "%s: no forge in this lab" >&2\nexit 1\n' "$forge" > "$DEST/bin/$forge"
  chmod +x "$DEST/bin/$forge"
done

# the lab's permission rules for the headless executor, one per line, for `claude -p --allowed-tools`.
# The headless session ignores <dest>/.claude/settings.json (the workspace is not trusted), so this file is the
# only route; run-scenario.sh reads it. Probe: Architecture/cat-soup/003-Design_0.1/Side-Tests/permission-probe.md
dest_rel=${DEST#/}
{
  printf '%s\n' "Read(//$dest_rel/**)" "Edit(//$dest_rel/**)" "Write(//$dest_rel/**)"
  printf '%s\n' "Bash(git:*)" "Bash(uv:*)" "Bash(make:*)" "Bash(ls:*)" "Bash(cat:*)" "Bash(mkdir:*)" \
    "Bash(grep:*)" "Bash(test:*)" "Agent"
} > "$DEST/allowed-tools.txt"

cp -R "$HERE/template" "$LAB_REPO"
git -C "$LAB_REPO" init -q -b "$BASE"
git -C "$LAB_REPO" config user.name "fizz-lab"
git -C "$LAB_REPO" config user.email "$SYNTH_EMAIL"

if [ "$MODE" = empty ]; then
  echo "lab (empty) built at $DEST"
  exit 0
fi

git -C "$LAB_REPO" add -A
git_at "2026-11-14T21:00:00+0100" -C "$LAB_REPO" commit -q -m "Add fizzbuzz library, cli and tests"

if [ "$MODE" = remotes ] || [ "$MODE" = no-upstream ]; then
  mkdir -p "$DEST/remotes"
  remote_names=("$ORIGIN"); [ "$MODE" = remotes ] && remote_names=("$UPSTREAM" "$ORIGIN")
  for remote in "${remote_names[@]}"; do
    git init -q --bare -b "$BASE" "$DEST/remotes/$remote.git"
    git -C "$LAB_REPO" remote add "$remote" "$DEST/remotes/$remote.git"
    git -C "$LAB_REPO" push -q "$remote" "$BASE"
  done
  git -C "$LAB_REPO" branch -q --set-upstream-to="$ORIGIN/$BASE" "$BASE"
fi

if [ -n "$PLAN" ]; then
  WORKTREE="$DEST/Projects-Worktrees/$REPO/$SLUG"
  git -C "$LAB_REPO" worktree add -q -b "cat/$SLUG" "$WORKTREE" "$BASE"
  case "$PLAN" in
    step1-committed|done)
      git -C "$WORKTREE" apply "$HERE/patches/step1.patch"
      git -C "$WORKTREE" add -A
      git_at "2026-11-14T21:10:00+0100" -C "$WORKTREE" commit -q -m "Add openpyxl dependency and export_xlsx" ;;
  esac
  if [ "$PLAN" = done ]; then
    git -C "$WORKTREE" apply "$HERE/patches/step2.patch"
    git -C "$WORKTREE" add -A
    git_at "2026-11-14T21:12:00+0100" -C "$WORKTREE" commit -q -m "Document export_xlsx in the README"
  fi
  plan_text "$PLAN" "$DEST" > "$DEST/Plans/$REPO/${PLAN_DATE}_$SLUG.md"
fi

echo "lab built at $DEST (mode: $MODE, plan: ${PLAN:-none})"
