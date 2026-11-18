# fizz-buzz lab

The lab the cat-soup scenarios run in. `make-lab.sh` builds it; the design is in `Architecture/cat-soup/Design/testing.md`. Step F2 adds how to build the lab and run a scenario by hand.

## Files

```text
tests/fizz-buzz/
  README.md
  LAB.md
  feedback.txt
  make-lab.sh
  make-drift.sh                # stage E
  designs/
    excel-export.md
    excel-export-open.md
    vague.md
  patches/
    step1.patch
    step2.patch
                               # D1 to D4 patches: stage E
  roles/                       # stage F
    tester.md
    judger.md
  scenarios/                   # stages D and E
    cat-setup.md
    cat-to-plan.md
    cat-open-plan.md
    cat-implement.md
    cat-accept-feedback.md
    cat-review.md
    cat-close-plan.md
  template/                    # the reference project, copied to <dest>/fizz-buzz/
    .gitignore
    Makefile
    README.md
    CONTRIBUTING.md
    pyproject.toml
    uv.lock
    fizzbuzz/__init__.py
    fizzbuzz/__main__.py
    fizzbuzz/core.py
    tests/test_core.py         # includes the one slow test
```

## Dependency table

Each skill's step (D and E) adds its row: the scenarios that read the skill's output. A change to a skill means every scenario in its row is run.

| Skill | Scenarios that read its output |
| :-- | :-- |
