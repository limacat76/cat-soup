#!/usr/bin/env python3
"""Check that plan files printed by a lab generator have the shape cat-open-plan ships.

Usage: check-template.py <cat-open-plan SKILL.md> [<plan file>...]

SKILL.md holds the plan template between a line containing `cat-soup:plan-template begin`
and one containing `cat-soup:plan-template end`. Each <plan file> is the output of a
generator's `--print-plan` (a plan file, no markers). Values are ignored, only the
structure is compared. Fails when the markers are missing, or when a plan:

  1. has different front-matter keys, or a different order
  2. has a different `Conventions:` label or different `##` headings
  3. has steps whose field labels (`- Files:` lines) differ
  4. has a step kind (`- [ ] 2. review: ...`) the template does not have
  5. omits a Notes label (`- Baseline: ...`) the template has
  6. still holds a template placeholder (`<...>`) in the front matter

With no plan file only the SKILL.md markers are checked. Exit 0 when everything
matches, 1 otherwise. Standard library only.
"""
import re
import sys

BEGIN, END = "cat-soup:plan-template begin", "cat-soup:plan-template end"


def template_lines(path):
    """Lines of the template block of SKILL.md, without the code fences."""
    lines = open(path, encoding="utf-8").read().splitlines()
    start = next((i for i, l in enumerate(lines) if BEGIN in l), None)
    stop = next((i for i, l in enumerate(lines) if END in l and start is not None and i > start), None)
    if start is None or stop is None:
        sys.exit(f"FAIL {path}: missing `{BEGIN}` / `{END}` markers")
    return [l for l in lines[start + 1:stop] if not l.startswith("```")]


def plan_lines(path):
    return open(path, encoding="utf-8").read().splitlines()


def shape(lines):
    keys, values, rest, seen = [], {}, lines, 0
    for i, l in enumerate(lines):  # front matter between the first two `---`
        if l.strip() == "---":
            seen += 1
            if seen == 2:
                rest = lines[i + 1:]
                break
        elif seen == 1:
            key, _, value = l.partition(":")
            keys.append(key.strip())
            values[key.strip()] = value.strip()
    s = {"keys": keys, "values": values, "top": set(), "fields": set(), "kinds": set(), "notes": set()}
    in_notes = False
    for l in rest:
        if l.startswith("## "):
            s["top"].add(l.strip())
            in_notes = l.strip() == "## Notes"
        elif l.startswith("Conventions:"):
            s["top"].add("Conventions:")
        elif m := re.match(r"- \[[ x]\] \d+\. ([a-z]+): ", l):
            s["kinds"].add(m.group(1))
        elif m := re.match(r"\s+- ([A-Z][A-Za-z ]*):", l):
            s["fields"].add(m.group(1))
        elif in_notes and (m := re.match(r"- ([A-Z][A-Za-z ]*):", l)):
            s["notes"].add(m.group(1))
    return s


def compare(t, p):
    errors = []
    if t["keys"] != p["keys"]:
        errors.append(f"front-matter keys: template {t['keys']}, plan {p['keys']}")
    if t["top"] != p["top"]:
        errors.append(f"Conventions/headings: template {sorted(t['top'])}, plan {sorted(p['top'])}")
    if t["fields"] != p["fields"]:
        errors.append(f"step fields: template {sorted(t['fields'])}, plan {sorted(p['fields'])}")
    if extra := p["kinds"] - t["kinds"]:
        errors.append(f"step kinds unknown to the template: {sorted(extra)}")
    if missing := t["notes"] - p["notes"]:
        errors.append(f"Notes labels the plan does not write: {sorted(missing)}")
    if holes := {k: v for k, v in p["values"].items() if re.search(r"<[^<>]*>", v)}:
        errors.append(f"template placeholders left in the front matter: {holes}")
    return errors


def main(argv):
    if len(argv) < 2:
        sys.exit("usage: check-template.py <SKILL.md> [<plan>...]")
    template = shape(template_lines(argv[1]))
    if not template["keys"]:
        sys.exit(f"FAIL {argv[1]}: the template block has no front matter")
    print(f"ok   {argv[1]} (template markers)")
    failed = False
    for plan in argv[2:]:
        errors = compare(template, shape(plan_lines(plan)))
        print(("FAIL " if errors else "ok   ") + plan)
        for e in errors:
            print("     " + e)
        failed |= bool(errors)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
