"""Create a new diagnostic-only page copy; do not modify the input file.

The output contains a fake restore barrier and must never be shipped.
"""
import argparse
import hashlib
from pathlib import Path


EXPECTED_GIT_BLOB = 'e42d8f844918e42402f80ab541f9438705443843'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    source = args.input.read_bytes()
    blob = hashlib.sha1(b'blob ' + str(len(source)).encode() + b'\0' + source).hexdigest()
    if blob != EXPECTED_GIT_BLOB:
        raise SystemExit('unexpected input blob; no output created')
    text = source.decode('utf-8')
    edits = [
        (
            '  final Map<String, dynamic>? debugDebtOverridesMirror;\n',
            '  final Map<String, dynamic>? debugDebtOverridesMirror;\n'
            '  /// DIAGNOSTIC COPY ONLY: injected synthetic restore barrier.\n'
            '  @visibleForTesting\n'
            '  final Future<void> Function()? debugBeforeDebtRestoreApply;\n',
        ),
        (
            '    this.debugDebtOverridesMirror,\n',
            '    this.debugDebtOverridesMirror,\n'
            '    this.debugBeforeDebtRestoreApply,\n',
        ),
        (
            "      final dirtyKeys = await _syncDirtyKeysStore.loadDirty(\n"
            "        'debt_payment_day_overrides',\n"
            '      );\n',
            "      final dirtyKeys = await _syncDirtyKeysStore.loadDirty(\n"
            "        'debt_payment_day_overrides',\n"
            '      );\n'
            '      final debugBarrier = widget.debugBeforeDebtRestoreApply;\n'
            '      if (debugBarrier != null) {\n'
            '        await debugBarrier();\n'
            '        if (!mounted) return;\n'
            '      }\n',
        ),
    ]
    for old, new in edits:
        if text.count(old) != 1:
            raise SystemExit('instrumentation marker not unique; no output created')
        text = text.replace(old, new, 1)
    # Refuse to overwrite either the source or an existing diagnostic copy.
    with args.output.open('x', encoding='utf-8', newline='\n') as output:
        output.write(text)


if __name__ == '__main__':
    main()
