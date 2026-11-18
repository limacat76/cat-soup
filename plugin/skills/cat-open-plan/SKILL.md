---
name: cat-open-plan
description: Open a plan from a source document (path, URL, issue): write the plan file, create its worktree and take the test baseline.
disable-model-invocation: true
version: 0.1.0
---

# cat-open-plan

The skill body is written in step D2.

## Plan file template

<!-- cat-soup:plan-template begin -->
```markdown
---
template: 1
source: <path or URL of the source document>
repo: <real path of the main checkout>
base_branch: main
branch: cat/<plan_slug>
worktree: <real path of the worktree>
baseline_failures: [<test IDs as the runner prints them>]
---
Conventions: <commit style, sign-off, AI-assistance and attribution policy, lock-file policy, compatibility promises, from CONTRIBUTING, README and similar files>

- [ ] 1. <what the step does>
  - Files: <paths>
  - Test: <the test that fails before and passes after, or the check that replaces it>
  - Done when: <observable result>
- [ ] 2. review: <finding from /cat:cat-review>
- [ ] 3. feedback: <request from a maintainer>

## Notes
- Baseline: `<test command>`, <n> passed, <failures>.
- <decision, why>
```
<!-- cat-soup:plan-template end -->
