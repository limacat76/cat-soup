def fizzbuzz(n: int) -> str:
    """Return the FizzBuzz word for one number."""
    if n < 1:
        raise ValueError("n must be a positive integer")
    if n % 15 == 0:
        return "FizzBuzz"
    if n % 3 == 0:
        return "Fizz"
    if n % 5 == 0:
        return "Buzz"
    return str(n)


def run(limit: int) -> None:
    """Print FizzBuzz for 1..limit, one line per number."""
    for n in range(1, limit + 1):
        print(fizzbuzz(n))
