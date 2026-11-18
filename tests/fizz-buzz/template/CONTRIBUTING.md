# Contributing

## Commits

- One logical change per commit.
- Subject line in the imperative mood, at most 72 characters, no trailing period (for example `Add export_xlsx`).
- Body only when the reason is not obvious from the subject.

## Lock file

`uv.lock` is committed. A change to the dependencies in `pyproject.toml` is committed together with the `uv.lock` change it causes, in the same commit.

## Tests

Run `make test` before every commit and `make test-all` before opening a pull request.
