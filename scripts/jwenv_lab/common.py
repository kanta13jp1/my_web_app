"""Shared paths and constants for the Jwenv lab checks (single source: web/labs/jwenv/core.mjs)."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / 'web/labs/jwenv'
VENDOR = LAB / 'vendor/jwenv-8263b81'
RESULTS = LAB / 'results.json'
FIXTURES = ROOT / 'scripts/expense_comparison/fixtures.json'
REFERENCE = ROOT / 'web/labs/expense-comparison/results.json'

# Files whose change invalidates a saved measurement.
MEASUREMENT_INPUTS = [
    LAB / 'core.mjs',
    LAB / 'app.mjs',
    VENDOR / 'manifest.json',
    ROOT / 'scripts/jwenv_lab/run_lab.py',
    REFERENCE,
]


def core_constant(name):
    """Reads a frozen object or string constant from core.mjs without a JS runtime."""
    text = (LAB / 'core.mjs').read_text(encoding='utf-8')
    obj = re.search(rf"export const {name} = Object\.freeze\(\{{(.*?)\}}\);", text, re.S)
    if obj:
        pairs = re.findall(r"(\w+): (?:'([^']*)'|(\d+))", obj.group(1))
        return {k: (s if s else int(n)) for k, s, n in pairs}
    string = re.search(rf"export const {name} = '([^']*)';", text)
    if string:
        return string.group(1)
    raise KeyError(name)


def sha256_file(path, chunk=1 << 20):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while block := f.read(chunk):
            h.update(block)
    return h.hexdigest()


def inputs_sha256():
    h = hashlib.sha256()
    for path in MEASUREMENT_INPUTS:
        h.update(path.relative_to(ROOT).as_posix().encode())
        h.update(path.read_bytes().replace(b'\r\n', b'\n'))
    return h.hexdigest()


def manifest():
    return json.loads((VENDOR / 'manifest.json').read_text(encoding='utf-8'))
