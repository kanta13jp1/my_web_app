"""Require the 22 synthetic scenarios, including four named cases."""
from pathlib import Path
import re
import sys

NAMES = (
    'deleted read from A is discarded after switching to B',
    'switch during tombstone platform write stops subsequent deletion and mirror',
    'same owner applies deleted ID and retains other data',
    'switch while local override save is pending stops later mirror',
)

def verify(text):
    lines = text.splitlines()
    for name in NAMES:
        pattern = re.compile(r'^\d+:\d{2} \+\d+: ' + re.escape(name) + r'$')
        if sum(bool(pattern.fullmatch(line)) for line in lines) != 1:
            raise ValueError('expected exactly one execution of a named scenario')
    if not lines or re.fullmatch(r'\d+:\d{2} \+22: All tests passed!', lines[-1]) is None:
        raise ValueError('expected clean 22-test summary')
    if any('[E]' in line or ' SKIP' in line or re.search(r'\+\d+\s+~\d+', line) for line in lines):
        raise ValueError('test failures or skips found')

if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('expected one test log')
    path = Path(sys.argv[1])
    if path.is_symlink() or not path.is_file():
        raise SystemExit('missing or linked test output')
    verify(path.read_text(encoding='utf-8'))
    print('Verified 22 synthetic scenarios including four named cases')
