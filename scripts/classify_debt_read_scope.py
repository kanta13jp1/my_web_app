"""Fail-closed selection of the debt-read synthetic test for required CI."""
import json
import os
from pathlib import Path, PurePosixPath
import re

EXACT = frozenset({
    'lib/pages/asset_management_page.dart',
    '.github/workflows/ci.yml',
    'scripts/classify_debt_read_scope.py',
    'scripts/prepare_debt_read_sandbox.py',
    'scripts/run_debt_read_sandbox.sh',
    'scripts/verify_debt_read_result.py',
    'scripts/prepare_browser_scratch.py',
    'scripts/run_browser_in_namespace.sh',
    'scripts/test_classify_debt_read_scope.py',
    'scripts/test_ci_collection.cjs',
    'test_driver/asset_triage_visual.dart',
    'integration_test/asset_debt_read_browser_test.dart',
    'integration_test/support/asset_debt_read_contract.dart',
    'integration_test/support/asset_debt_read_factory.dart',
})
FIXTURE_PREFIX = 'test/fixtures/debt_read_fail_closed/'
REQUIRED = (
    'lib/pages/asset_management_page.dart',
    'scripts/classify_debt_read_scope.py',
    'scripts/prepare_debt_read_sandbox.py',
    'scripts/run_debt_read_sandbox.sh',
    'scripts/verify_debt_read_result.py',
    'scripts/prepare_browser_scratch.py',
    'scripts/run_browser_in_namespace.sh',
    'scripts/test_classify_debt_read_scope.py',
    'scripts/test_ci_collection.cjs',
    'test_driver/asset_triage_visual.dart',
    'integration_test/asset_debt_read_browser_test.dart',
    'integration_test/support/asset_debt_read_contract.dart',
    'integration_test/support/asset_debt_read_factory.dart',
    FIXTURE_PREFIX + 'browser/asset_debt_read_factory.dart.fixture',
    FIXTURE_PREFIX + 'build_test_instrumentation.py.fixture',
    FIXTURE_PREFIX + 'debt_read_fail_closed_test.dart.fixture',
)
STATUSES = frozenset({'added', 'modified', 'removed', 'renamed', 'copied', 'changed', 'unchanged'})
SHA = re.compile(r'[0-9a-f]{40}\Z')


def valid_path(value: object) -> str:
    if not isinstance(value, str) or not value or '\x00' in value or '\\' in value:
        raise ValueError('invalid changed path')
    parts = value.split('/')
    if value.startswith('/') or any(part in {'', '.', '..'} for part in parts):
        raise ValueError('unsafe changed path')
    if PurePosixPath(value).as_posix() != value:
        raise ValueError('non-canonical changed path')
    return value


def relevant(path: str) -> bool:
    return path in EXACT or path.startswith(FIXTURE_PREFIX)


def classify_pr(event: object, data: object) -> bool:
    if not isinstance(event, dict) or not isinstance(data, dict):
        raise ValueError('event or file list is not an object')
    pull = event.get('pull_request')
    if not isinstance(pull, dict):
        raise ValueError('missing pull_request')
    base, head = pull.get('base'), pull.get('head')
    if not isinstance(base, dict) or not isinstance(head, dict):
        raise ValueError('missing immutable refs')
    base_sha, head_sha = base.get('sha'), head.get('sha')
    number = pull.get('number')
    if (not isinstance(base_sha, str) or SHA.fullmatch(base_sha) is None or
        not isinstance(head_sha, str) or SHA.fullmatch(head_sha) is None or
        type(number) is not int or number <= 0):
        raise ValueError('invalid PR identity')
    if (type(data.get('schema')) is not int or data.get('schema') != 1 or
        type(data.get('number')) is not int or data.get('number') != number or
        data.get('base_sha') != base_sha or data.get('head_sha') != head_sha):
        raise ValueError('file list does not match event identity')
    files, count = data.get('files'), data.get('count')
    if (not isinstance(files, list) or type(count) is not int or
        count <= 0 or count >= 3000 or len(files) != count):
        raise ValueError('empty, truncated, or invalid file list')
    # If the webhook supplies a count, it must agree with the bounded API result.
    event_count = pull.get('changed_files')
    if event_count is not None and (type(event_count) is not int or event_count != count):
        raise ValueError('event file count differs')
    current_names: set[str] = set()
    run = False
    for row in files:
        if not isinstance(row, dict) or row.get('status') not in STATUSES:
            raise ValueError('invalid changed-file status')
        name = valid_path(row.get('filename'))
        if name in current_names:
            raise ValueError('duplicate current path')
        current_names.add(name)
        names = [name]
        previous = row.get('previous_filename')
        if row['status'] in {'renamed', 'copied'}:
            old = valid_path(previous)
            if old == name:
                raise ValueError('invalid previous path')
            names.append(old)
        elif previous is not None:
            raise ValueError('unexpected previous path')
        run = run or any(relevant(path) for path in names)
    return run


def check_required_files(root: Path) -> None:
    root = root.resolve(strict=True)
    for relative in REQUIRED:
        path = root / relative
        if (path.is_symlink() or not path.is_file() or
            not path.resolve(strict=True).is_relative_to(root)):
            raise RuntimeError('required debt-read input missing or linked: ' + relative)


def main() -> None:
    check_required_files(Path.cwd())
    event_name = os.environ['GITHUB_EVENT_NAME']
    with open(os.environ['GITHUB_EVENT_PATH'], encoding='utf-8') as stream:
        event = json.load(stream)
    if not isinstance(event, dict):
        raise ValueError('event JSON is not an object')
    if event_name == 'pull_request':
        path = Path('.ci-logs/debt-read-files.json')
        if path.is_symlink() or not path.is_file():
            raise RuntimeError('missing debt-read PR file list')
        with path.open(encoding='utf-8') as stream:
            data = json.load(stream)
        run = classify_pr(event, data)
    elif event_name in {'push', 'workflow_dispatch', 'workflow_call'}:
        run = True
    else:
        raise ValueError('unsupported CI event')
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
        output.write('run=' + ('true' if run else 'false') + '\n')
    print('debt read synthetic test:', 'required' if run else 'unrelated change')


if __name__ == '__main__':
    main()
