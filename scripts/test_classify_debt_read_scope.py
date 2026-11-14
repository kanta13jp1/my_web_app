"""Local pure checks; no GitHub, Flutter, production DB, or filesystem writes."""
import io
import json
import os
from pathlib import Path
import unittest
from unittest import mock

import classify_debt_read_scope as scope

BASE = 'a' * 40
HEAD = 'b' * 40
TARGET = 'lib/pages/asset_management_page.dart'


def event():
    return {'pull_request': {'number': 7, 'base': {'sha': BASE}, 'head': {'sha': HEAD}}}


def listing(*rows):
    return {'schema': 1, 'number': 7, 'base_sha': BASE, 'head_sha': HEAD,
            'count': len(rows), 'files': list(rows)}


def row(name, status='modified', previous=None):
    result = {'filename': name, 'status': status}
    if previous is not None:
        result['previous_filename'] = previous
    return result


class ScopeTests(unittest.TestCase):
    def test_relevant_add_modify_delete_and_unrelated(self):
        for status in ('added', 'modified', 'removed'):
            self.assertTrue(scope.classify_pr(event(), listing(row(TARGET, status))))
            for path in ('integration_test/asset_debt_read_browser_test.dart',
                         'integration_test/support/asset_debt_read_factory.dart',
                         'scripts/run_browser_in_namespace.sh'):
                self.assertTrue(scope.classify_pr(event(), listing(row(path, status))))
        self.assertFalse(scope.classify_pr(event(), listing(row('lib/unrelated.dart'))))

    def test_rename_either_side_and_irrelevant_rename(self):
        self.assertTrue(scope.classify_pr(event(), listing(row('lib/new.dart', 'renamed', TARGET))))
        self.assertTrue(scope.classify_pr(event(), listing(row(TARGET, 'renamed', 'lib/old.dart'))))
        self.assertTrue(scope.classify_pr(event(), listing(row('old/location', 'renamed',
            'test/fixtures/debt_read_fail_closed/debt_read_fail_closed_test.dart.txt'))))
        self.assertFalse(scope.classify_pr(event(), listing(row('lib/new.dart', 'renamed', 'lib/old.dart'))))
        self.assertTrue(scope.classify_pr(event(), listing(row('odd\nname', 'renamed', TARGET))))

    def test_rename_missing_or_invalid_previous_is_error(self):
        for item in (row(TARGET, 'renamed'), row(TARGET, 'renamed', ''),
                     row(TARGET, 'renamed', TARGET), row(TARGET, 'renamed', '../oops')):
            with self.assertRaises((ValueError, TypeError)):
                scope.classify_pr(event(), listing(item))

    def test_empty_truncated_limit_and_mismatched_count(self):
        for data in (listing(), {**listing(row(TARGET)), 'count': 2},
                     {**listing(row(TARGET)), 'count': 3000},
                     {**listing(row(TARGET)), 'files': None}):
            with self.assertRaises((ValueError, TypeError)):
                scope.classify_pr(event(), data)
        capped = listing(*(row('unrelated/file-' + str(i)) for i in range(3000)))
        self.assertEqual(capped['count'], 3000)
        with self.assertRaises(ValueError):
            scope.classify_pr(event(), capped)

    def test_event_identity_mismatch_and_malformed(self):
        for data in ({**listing(row(TARGET)), 'head_sha': 'c' * 40},
                     {**listing(row(TARGET)), 'number': 8},
                     {**listing(row(TARGET)), 'base_sha': 'bad'},
                     {**listing(row(TARGET)), 'schema': True}, None):
            with self.assertRaises((ValueError, TypeError)):
                scope.classify_pr(event(), data)
        with self.assertRaises(ValueError):
            scope.classify_pr({'pull_request': {'number': 7}}, listing(row(TARGET)))

    def test_event_count_mismatch_and_duplicate_or_invalid_status(self):
        e = event()
        e['pull_request']['changed_files'] = 2
        with self.assertRaises(ValueError):
            scope.classify_pr(e, listing(row(TARGET)))
        for data in (listing(row(TARGET), row(TARGET)), listing(row(TARGET, 'unexpected')),
                     listing(row('/absolute')), listing(row('a/../b'))):
            with self.assertRaises((ValueError, TypeError)):
                scope.classify_pr(event(), data)

    def test_malformed_event_json_fails(self):
        with mock.patch.object(scope, 'check_required_files'), \
             mock.patch.dict(os.environ, {'GITHUB_EVENT_NAME': 'pull_request',
                                         'GITHUB_EVENT_PATH': 'fake.json'}, clear=False), \
             mock.patch('builtins.open', return_value=io.StringIO('{invalid')):
            with self.assertRaises(json.JSONDecodeError):
                scope.main()

    def test_malformed_file_list_json_fails(self):
        with mock.patch.object(scope, 'check_required_files'), \
             mock.patch.dict(os.environ, {'GITHUB_EVENT_NAME': 'pull_request',
                                         'GITHUB_EVENT_PATH': 'fake.json'}, clear=False), \
             mock.patch('builtins.open', return_value=io.StringIO(json.dumps(event()))), \
             mock.patch.object(Path, 'is_symlink', return_value=False), \
             mock.patch.object(Path, 'is_file', return_value=True), \
             mock.patch.object(Path, 'open', return_value=io.StringIO('{invalid')):
            with self.assertRaises(json.JSONDecodeError):
                scope.main()

    def test_missing_required_file_fails(self):
        with mock.patch.object(Path, 'resolve', return_value=Path.cwd()), \
             mock.patch.object(Path, 'is_symlink', return_value=False), \
             mock.patch.object(Path, 'is_file', return_value=False):
            with self.assertRaises(RuntimeError):
                scope.check_required_files(Path.cwd())

    def test_linked_required_file_fails(self):
        with mock.patch.object(Path, 'resolve', return_value=Path.cwd()), \
             mock.patch.object(Path, 'is_symlink', return_value=True):
            with self.assertRaises(RuntimeError):
                scope.check_required_files(Path.cwd())


if __name__ == '__main__':
    unittest.main()
