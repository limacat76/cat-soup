#!/usr/bin/env bash
# Layer 1 file checks: no model, run on every commit.
# Usage: tests/check-files.sh
# Each group below prints every failure it finds; the script stops after the first failing group.
set -uo pipefail
cd "$(dirname "$0")/.."

PLUGIN=plugin
MANIFEST="$PLUGIN/.claude-plugin/plugin.json"
TEMPLATE_SKILL="$PLUGIN/skills/cat-open-plan/SKILL.md"
fails=0
fail () { echo "FAIL $*"; fails=$((fails + 1)); }
group_end () {  # $1 = group name
  if [ "$fails" -gt 0 ]; then echo "check-files: group '$1' failed ($fails)"; exit 1; fi
  echo "ok   $1"
}

skills () { find "$PLUGIN" -name SKILL.md | sort; }

# front matter of a file: the lines between the first two `---`
front_matter () { awk '/^---[[:space:]]*$/{n++; next} n==1{print} n>=2{exit}' "$1"; }

# 1. claude plugin validate
if command -v claude >/dev/null 2>&1; then
  out=$(claude plugin validate "$PLUGIN/" 2>&1) || { fail "claude plugin validate $PLUGIN/"; echo "$out" | sed 's/^/     /'; }
else
  echo "skip claude plugin validate: claude is not installed"
fi
group_end "claude plugin validate"

# 2. every SKILL.md has name, description and disable-model-invocation: true
for f in $(skills); do
  fm=$(front_matter "$f")
  grep -Eq '^name:[[:space:]]*[^[:space:]]' <<<"$fm" || fail "$f: front matter has no name"
  grep -Eq '^description:[[:space:]]*[^[:space:]]' <<<"$fm" || fail "$f: front matter has no description"
  grep -Eq '^disable-model-invocation:[[:space:]]*true[[:space:]]*$' <<<"$fm" || fail "$f: front matter lacks disable-model-invocation: true"
done
group_end "SKILL.md front matter"

# 3. every SKILL.md states the same version as plugin.json
want=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$MANIFEST" 2>/dev/null) \
  || fail "$MANIFEST: cannot read version"
for f in $(skills); do
  got=$(front_matter "$f" | sed -n 's/^version:[[:space:]]*//p' | tr -d '"'"'"' \r')
  [ "$got" = "${want:-}" ] || fail "$f: version '${got}' differs from $MANIFEST '${want:-}'"
done
group_end "versions"

# 4. every relative link in plugin/ resolves (links inside code fences are skipped)
while IFS= read -r f; do
  dir=$(dirname "$f")
  while IFS= read -r link; do
    target=${link%%#*}
    [ -z "$target" ] && continue
    [ -e "$dir/$target" ] || fail "$f: broken relative link '$link'"
  done < <(awk '/^```/{c=!c; next} !c' "$f" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//; s/\)$//' | grep -Ev '^([a-z]+:|#)' || true)
done < <(find "$PLUGIN" -name '*.md' | sort)
group_end "relative links"

# 5. no file under plugin/ other than plugin.json and SKILL.md files
while IFS= read -r f; do
  case "$f" in
    "$MANIFEST") ;;
    */SKILL.md) ;;
    */.DS_Store) ;;
    *) fail "$f: stray file under $PLUGIN/" ;;
  esac
done < <(find "$PLUGIN" -type f | sort)
group_end "no stray files"

# 6. plan template: markers in SKILL.md and, from stage B, the plans printed by make-lab.sh --print-plan.
# Until make-lab.sh exists, no plan is passed and only the SKILL.md markers are checked.
python3 -I tests/check-template.py "$TEMPLATE_SKILL" || fail "tests/check-template.py $TEMPLATE_SKILL"
group_end "plan template"

echo "check-files: all groups passed"
