"""Generate test-only hooks in an isolated GitHub runner scratch copy.

Fixtures are bound to synthetic run 41567800770. The product page is always
the page in the event commit, not a permanently pinned copy of a large file.
Every instrumentation anchor is checked before modifying the scratch copy.
"""
import hashlib
import os
from pathlib import Path
import subprocess
import sys

BUILDER_SHA256 = '3b1ed941d4f3c0cb70764806a186491c89066717f23341ce40080972a793865f'
FIXTURE_SHA256 = '8599dc6b5fe2d3bfe9f0ae6c0e73a5299a3d25c9ef4575b4630794bf47a71d70'


def require_file(path: Path, digest: str | None, root: Path) -> bytes:
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(root):
        raise RuntimeError('missing, linked, or out-of-tree test input')
    raw = path.read_bytes()
    if digest is not None and hashlib.sha256(raw).hexdigest() != digest:
        raise RuntimeError('test input digest mismatch: ' + path.name)
    return raw


def check_replacements(page: str) -> None:
    # The fixed instrumentation fixture uses these scoped replacements. Check
    # their exact multiplicity so a refactor cannot silently skip a seam.
    sections = (
        ('  Future<void> _backfillPrefIfServerMissing(',
         '  /// 当該ユーザーの', (2, 2, 0, 0)),
        ('  Future<void> _mirrorDebtPaymentDayOverrides(',
         '  Future<void> _restoreDebtPaymentDayOverridesFromMirror()', (1, 0, 0, 0)),
        ('  Future<void> _restoreDebtPaymentDayOverridesFromMirror()',
         '  /// 入金予定のミラー取り込みプレビュー', (3, 2, 1, 2)),
        ('  Future<void> _saveDebtPaymentDayOverrides(',
         '  Widget _buildDebtPaymentDayInput(', (1, 1, 0, 0)),
    )
    tokens = (
        '_supabase.auth.currentUser?.id',
        '_supabase.auth.currentSession?.accessToken',
        '_supabase.auth.currentUser == null',
        'unawaited(_mirrorDebtPaymentDayOverrides(_debtPaymentDayOverrides));',
    )
    for start, end, expected in sections:
        if page.count(start) != 1:
            raise RuntimeError('missing or ambiguous target section')
        begin = page.index(start)
        finish = page.find(end, begin)
        if finish < 0:
            raise RuntimeError('missing target section end')
        part = page[begin:finish]
        if tuple(part.count(token) for token in tokens) != expected:
            raise RuntimeError('target section changed: re-review test instrumentation')


def main() -> None:
    if len(sys.argv) != 2:
        raise RuntimeError('expected one isolated checkout path')
    temp = Path(os.environ['RUNNER_TEMP']).resolve(strict=True)
    workspace = Path(os.environ['GITHUB_WORKSPACE']).resolve(strict=True)
    root = Path(sys.argv[1]).resolve(strict=True)
    if root == temp or not root.is_relative_to(temp) or root == workspace or root.is_relative_to(workspace):
        raise RuntimeError('refusing to instrument outside runner scratch')
    page_path = root / 'lib/pages/asset_management_page.dart'
    fixture_dir = root / 'test/fixtures/debt_read_fail_closed'
    builder_path = fixture_dir / 'build_test_instrumentation.py.txt'
    test_path = fixture_dir / 'debt_read_fail_closed_test.dart.txt'
    page = require_file(page_path, None, root)
    builder = require_file(builder_path, BUILDER_SHA256, root)
    test = require_file(test_path, FIXTURE_SHA256, root)
    output_test = root / 'test/widgets/debt_read_fail_closed_synthetic_test.dart'
    if (output_test.parent.is_symlink() or not output_test.parent.is_dir() or
            not output_test.parent.resolve().is_relative_to(root)):
        raise RuntimeError('test output directory is linked or out of tree')
    if output_test.exists() or output_test.is_symlink():
        raise RuntimeError('test output path already exists')
    if b'debugDebtRead' in page or b'debugDebtAuthEvents' in page:
        raise RuntimeError('refusing page with test hooks already present')
    check_replacements(page.decode('utf-8'))

    stage = root / '.debt-read-synthetic-stage'
    stage.mkdir()  # fail closed if an earlier stage exists
    (stage / 'asset_management_page_candidate.dart').write_bytes(page)
    (stage / 'build_test_instrumentation.py').write_bytes(builder)
    subprocess.run([sys.executable, '-B', str(stage / 'build_test_instrumentation.py')],
                   cwd=stage, check=True, timeout=30)
    instrumented = require_file(stage / 'instrumented_page.dart', None, root)
    if b'debugDebtRead' not in instrumented or b'debugDebtAuthEvents' not in instrumented:
        raise RuntimeError('test hooks were not generated')
    page_path.write_bytes(instrumented)
    with output_test.open('xb') as target:
        target.write(test)
    # Save no instrumented artifact: all generated files remain in scratch.
    print('Product page SHA256:', hashlib.sha256(page).hexdigest())
    print('Instrumented scratch page SHA256:', hashlib.sha256(instrumented).hexdigest())
    print('Prepared verified synthetic-only page and test in runner scratch')


if __name__ == '__main__':
    main()
