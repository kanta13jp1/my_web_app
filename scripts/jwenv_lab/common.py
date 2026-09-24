"""Shared paths and constants for the Jwenv lab checks (single source: web/labs/jwenv/core.mjs)."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / 'web/labs/jwenv'
VENDOR = LAB / 'vendor/jwenv-8263b81'
RESULTS = LAB / 'results.json'  # 2026-09-22 SwiftShader record of method A (kept as history)
RESULTS_SMOKE = LAB / 'results-smoke.json'  # CI SwiftShader smoke of methods A and B
RESULTS_GPU = LAB / 'results-gpu.json'  # local real-GPU run of methods A and B
HOLDOUT = LAB / 'holdout.json'
FIXTURES = ROOT / 'scripts/expense_comparison/fixtures.json'
REFERENCE = ROOT / 'web/labs/expense-comparison/results.json'

# Files whose change invalidates a saved measurement.
MEASUREMENT_INPUTS = [
    LAB / 'core.mjs',
    LAB / 'app.mjs',
    VENDOR / 'manifest.json',
    ROOT / 'scripts/jwenv_lab/run_lab.py',
    REFERENCE,
    HOLDOUT,
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


def free_memory_gib():
    """Available physical memory, or None when it cannot be read."""
    try:
        import ctypes

        class MemoryStatus(ctypes.Structure):
            _fields_ = [('dwLength', ctypes.c_ulong), ('dwMemoryLoad', ctypes.c_ulong),
                        ('ullTotalPhys', ctypes.c_ulonglong), ('ullAvailPhys', ctypes.c_ulonglong),
                        ('ullTotalPageFile', ctypes.c_ulonglong), ('ullAvailPageFile', ctypes.c_ulonglong),
                        ('ullTotalVirtual', ctypes.c_ulonglong), ('ullAvailVirtual', ctypes.c_ulonglong),
                        ('sullAvailExtendedVirtual', ctypes.c_ulonglong)]

        status = MemoryStatus()
        status.dwLength = ctypes.sizeof(MemoryStatus)
        if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
            return status.ullAvailPhys / 2**30
    except (AttributeError, OSError):
        pass
    try:
        for line in Path('/proc/meminfo').read_text().splitlines():
            if line.startswith('MemAvailable:'):
                return int(line.split()[1]) / 2**20
    except OSError:
        pass
    return None


def manifest():
    return json.loads((VENDOR / 'manifest.json').read_text(encoding='utf-8'))
