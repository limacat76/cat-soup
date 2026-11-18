# fizzbuzz

FizzBuzz as a library (`fizzbuzz.fizzbuzz`, `fizzbuzz.run`) and a command line tool (`python -m fizzbuzz 15`).

## Development

    make setup     # uv sync: creates .venv with the dev dependencies
    make test      # fast tests
    make test-all  # fast and slow tests

Contributions: keep `fizzbuzz(n)` and `run(limit)` backwards compatible; they are public API.
