# Excel export for fizzbuzz

## Overview
Users want the FizzBuzz sequence as a spreadsheet. Add `fizzbuzz.export_xlsx(limit, path)` that writes 1..limit to an .xlsx file.

## Requirements
* Sheet named `fizzbuzz` with a header row `n`, `output`, then one row per number 1..limit.
* `limit` must be a positive integer; otherwise raise `ValueError`. A non-integer `limit` (for example `2.5` or `"15"`) also raises `ValueError`.
* `fizzbuzz(n)` and `run(limit)` keep their current behaviour: they are public API.
* Use `openpyxl` as the only new runtime dependency.

## Detailed Implementation

### Step 1: dependency and `export_xlsx`
* `pyproject.toml`: add `openpyxl` to `dependencies`, and commit the `uv.lock` change with it. Needed to write .xlsx.
* `fizzbuzz/export.py` (new): `export_xlsx(limit: int, path: str | Path) -> None`, using `openpyxl.Workbook`, calling `fizzbuzz(n)` for each row. It validates `limit` before it writes anything.
* `fizzbuzz/__init__.py`: export `export_xlsx`.
* `tests/test_export.py` (new): write a file for limit 15 to a temporary directory, read it back with openpyxl, assert the sheet name, the header row and all 15 rows; assert `ValueError` for limit 0 and for a non-integer limit.

### Step 2: document `export_xlsx`
* `README.md`: one line documenting `export_xlsx`.
