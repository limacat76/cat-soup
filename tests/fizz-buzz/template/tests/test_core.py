import pytest

from fizzbuzz import fizzbuzz, run


@pytest.mark.parametrize(
    "n, expected",
    [(1, "1"), (3, "Fizz"), (5, "Buzz"), (15, "FizzBuzz"), (98, "98"), (99, "Fizz")],
)
def test_fizzbuzz_words(n, expected):
    assert fizzbuzz(n) == expected


def test_fizzbuzz_rejects_zero():
    with pytest.raises(ValueError):
        fizzbuzz(0)


def test_run_prints_one_line_per_number(capsys):
    run(15)
    lines = capsys.readouterr().out.splitlines()
    assert lines == [
        "1", "2", "Fizz", "4", "Buzz", "Fizz", "7", "8", "Fizz", "Buzz",
        "11", "Fizz", "13", "14", "FizzBuzz",
    ]


@pytest.mark.slow
def test_counts_up_to_three_million():
    words = [fizzbuzz(n) for n in range(1, 3_000_001)]
    assert words.count("FizzBuzz") == 200_000
