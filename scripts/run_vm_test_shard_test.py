#!/usr/bin/env python3
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import run_vm_test_shard as shard


class VmFileShardTest(unittest.TestCase):
    def test_partition_has_no_missing_or_duplicate_files_and_is_deterministic(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            expected = {'test/a_test.dart', 'test/z_test.dart',
                        'test/nested/b_test.dart', 'test/nested/c_test.dart',
                        'test/nested/d_test.dart'}
            for name in [*expected, 'test/support.dart', 'test/README.md', 'lib/other_test.dart']:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('fixture', encoding='utf-8')
            first = shard.select_files(root, 0, 2)
            second = shard.select_files(root, 1, 2)
            self.assertEqual(set(first) | set(second), expected)
            self.assertFalse(set(first) & set(second))
            self.assertEqual(first, sorted(expected)[::2])
            self.assertEqual(second, sorted(expected)[1::2])
            self.assertEqual(first, shard.select_files(root, 0, 2))

    def test_empty_and_invalid_shards_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for index, total in ((0, 0), (-1, 2), (2, 2), (0, 2)):
                with self.subTest(index=index, total=total), self.assertRaises(ValueError):
                    shard.select_files(root, index, total)

    def test_flutter_receives_only_selected_files_and_failure_is_propagated(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(shard, '__file__', str(root / 'scripts/runner.py')), \
                 patch.object(shard, 'select_files', return_value=['test/a_test.dart']), \
                 patch.object(shard.subprocess, 'run') as run:
                run.return_value.returncode = 7
                self.assertEqual(shard.main(['--shard-index', '0', '--total-shards', '2']), 7)
                run.assert_called_once_with(['flutter', 'test', '--coverage', '--concurrency=2',
                                             'test/a_test.dart'], cwd=root, check=False)
                manifest = json.loads((root / '.ci-logs/vm-shard.json').read_text())
                self.assertEqual(manifest['files'], ['test/a_test.dart'])


if __name__ == '__main__':
    unittest.main()
