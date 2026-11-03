"""Fail when this fixed synthetic suite is absent, skipped, or incomplete."""
from pathlib import Path
import re
import sys


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit('expected one test output file')
    path = Path(sys.argv[1])
    if path.is_symlink() or not path.is_file():
        raise SystemExit('missing test output')
    lines = [line.strip() for line in path.read_text(encoding='utf-8').splitlines() if line.strip()]
    # Flutter expanded output validated in synthetic run 41567800770.
    # A skip marker, failed test, missing test, or extra test count fails closed.
    if not lines or re.fullmatch(r'\d+:\d+ \+18: All tests passed!', lines[-1]) is None:
        raise SystemExit('expected 18 passing tests with no skips')
    print('Verified all 18 fixed synthetic tests completed')


if __name__ == '__main__':
    main()
