"""Prepare the browser fixture only inside a fresh, disposable runner scratch."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys

PREPARE_SHA = 'd380e9259cd420d53b3163be2bb43abc9ba7596127d8dcb04760a0d15d7e002c'
TEST_SHA = '9e999f9b1701c79a812382d9d61121f17f7a966f46be2c0965c9466d1b6dd265'
CONTRACT_SHA = 'cf1424065e31b277070a89a21d2d33217ca56b1c49313c19bf660d870350278f'
STUB_SHA = '26373d186cfbd0c0e39b7a25ffeb0a77075481b7b84633279494ab188435a05d'
FACTORY_SHA = '1903224391773b8a97dadfc459500fe2fa9ccd423de54b02caa96fba06c3809e'


def checked_file(path, root, digest=None):
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(root):
        raise RuntimeError('missing, linked, or out-of-tree fixture')
    data = path.read_bytes()
    if digest is not None and hashlib.sha256(data).hexdigest() != digest:
        raise RuntimeError('fixture digest mismatch: ' + path.name)
    return data


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise RuntimeError('automatic restore instrumentation anchor changed')
    return text.replace(old, new, 1)


def main():
    root = Path(os.environ['SCRATCH']).resolve(strict=True)
    temp = Path(os.environ['RUNNER_TEMP']).resolve(strict=True)
    workspace = Path(os.environ['GITHUB_WORKSPACE']).resolve(strict=True)
    if root == temp or not root.is_relative_to(temp) or root.is_relative_to(workspace):
        raise RuntimeError('scratch boundary invalid')
    prepare = root / 'scripts/prepare_debt_read_sandbox.py'
    fixture = root / 'test/fixtures/debt_read_fail_closed/browser/asset_debt_read_factory.dart.txt'
    checked_file(prepare, root, PREPARE_SHA)
    factory = checked_file(fixture, root, FACTORY_SHA)
    checked_file(root / 'integration_test/asset_debt_read_browser_test.dart', root, TEST_SHA)
    checked_file(root / 'integration_test/support/asset_debt_read_contract.dart', root, CONTRACT_SHA)
    stub = root / 'integration_test/support/asset_debt_read_factory.dart'
    checked_file(stub, root, STUB_SHA)
    subprocess.run([sys.executable, '-B', str(prepare), str(root)], cwd=root, check=True, timeout=30)
    page_path = root / 'lib/pages/asset_management_page.dart'
    page = checked_file(page_path, root).decode('utf-8')
    old = '  Future<void> debugRestoreDebtForTest() => _restoreDebtPaymentDayOverridesFromMirror();\n'
    new = old + '''  Future<void>? _debugDebtAutoRestore;
  @visibleForTesting
  Future<void> debugWaitDebtAutoRestoreForTest() async {
    final future = _debugDebtAutoRestore;
    if (future == null) throw StateError('automatic debt restoration did not start');
    await future;
  }
'''
    page = replace_once(page, old, new)
    old = '      if (!widget.debugDisableDebtBoot) unawaited(_restoreDebtPaymentDayOverridesFromMirror());\n'
    new = '''      if (!widget.debugDisableDebtBoot) {
        _debugDebtAutoRestore = _restoreDebtPaymentDayOverridesFromMirror();
        unawaited(_debugDebtAutoRestore!);
      }
'''
    page = replace_once(page, old, new)
    # The product UI injects built-in fixed-payment rows even for an empty
    # synthetic snapshot. Suppress those rows only in this test copy so the
    # captured viewport does not knowingly include non-fixture financial data.
    default_flag = '      includeDefaultFixedPayments: true,\n'
    if page.count(default_flag) != 2:
        raise RuntimeError('fixed-payment fixture boundary changed')
    page = page.replace(default_flag, '      includeDefaultFixedPayments: false,\n')
    page_path.write_text(page, encoding='utf-8', newline='\n')
    stub.write_bytes(factory)
    print('Prepared browser integration fixture in runner scratch only')


if __name__ == '__main__':
    main()
