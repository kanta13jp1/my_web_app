"""Prepare the browser fixture only inside a fresh, disposable runner scratch."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys

PREPARE_SHA = '4d593369e675b3a8fa12fb7b0ee67e6f5fa8a99883a4273b93341f9d771bb539'
TEST_SHA = '6e0cb1992eb1a525db3ee80c557793a60378e02b65112472193b60cb2339bf50'


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
    fixture = root / 'test/fixtures/debt_read_fail_closed/browser/asset_debt_read_browser_test.dart.fixture'
    checked_file(prepare, root, PREPARE_SHA)
    test = checked_file(fixture, root, TEST_SHA)
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
    target = root / 'integration_test/asset_debt_read_browser_test.dart'
    if target.parent.is_symlink() or not target.parent.resolve().is_relative_to(root):
        raise RuntimeError('unsafe integration test directory')
    if target.exists() or target.is_symlink():
        raise RuntimeError('integration test target already exists')
    page_path.write_text(page, encoding='utf-8', newline='\n')
    with target.open('xb') as output:
        output.write(test)
    print('Prepared browser integration fixture in runner scratch only')


if __name__ == '__main__':
    main()
