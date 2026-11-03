"""Require the four named synthetic scenarios and a clean Flutter summary."""
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
    if sum(bool(re.fullmatch(r'\d+:\d{2} \+4: All tests passed!', line)) for line in lines) != 1:
        raise ValueError('expected clean four-test summary')
    if any('[E]' in line or ' SKIP' in line or re.search(r'\+\d+\s+~\d+', line) for line in lines):
        raise ValueError('test failures or skips found')

if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('expected one test log')
    verify(Path(sys.argv[1]).read_text(encoding='utf-8'))
    print('Verified four named synthetic scenarios and clean summary')
