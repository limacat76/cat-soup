import sys

from .core import run


def main() -> None:
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    run(limit)


if __name__ == "__main__":
    main()
