#!/usr/bin/env python3
"""Regression checks for sharding and the protected CI aggregate check."""
import itertools
import os
from pathlib import Path
import shutil
import subprocess
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ParallelCiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = (ROOT / '.github/workflows/ci.yml').read_text(encoding='utf-8')
        cls.static = cls.workflow.split('  lint-and-test:\n', 1)[1].split('  vm-tests:\n', 1)[0]
        cls.vm = cls.workflow.split('  vm-tests:\n', 1)[1].split('  ci-complete:\n', 1)[0]
        cls.gate = cls.workflow.split('  ci-complete:\n', 1)[1].split('  actionlint:\n', 1)[0]

    def test_native_shards_cover_whole_vm_suite_without_changing_worker_limit(self):
        self.assertIn('shard: [0, 1]', self.vm)
        self.assertIn('fail-fast: false', self.vm)
        self.assertIn('flutter test --coverage --concurrency=2 --total-shards=2 --shard-index=${{ matrix.shard }}', self.vm)
        self.assertNotIn('needs:', self.vm)
        self.assertNotIn('flutter test --coverage', self.static)
        self.assertIn('flutter test --platform chrome test/web_import_smoke_test.dart', self.static)
        self.assertIn('flutter build web --release', self.static)
        self.assertIn('name: vm-coverage-${{ matrix.shard }}', self.vm)
        self.assertIn('if-no-files-found: error', self.vm)

    def test_shards_keep_scope_and_immutable_checkout_verification(self):
        for job in (self.static, self.vm):
            self.assertIn('refs/pull/${{ github.event.pull_request.number }}/merge', job)
            self.assertIn('ref="${GITHUB_SHA}"', job)
            self.assertIn('actual_head_sha="$(git rev-parse HEAD)"', job)
            self.assertIn('Collect PR changed files', job)
            self.assertIn('python scripts/classify_ci_changes.py', job)
            self.assertIn("if: steps.changes.outputs.flutter == 'true'", job)
        self.assertIn("github.event_name != 'workflow_call' && steps.changes.outputs.web == 'true'", self.static)

    def test_protected_name_is_unique_and_gate_always_checks_both_jobs(self):
        self.assertEqual(self.workflow.count('name: Lint, Format, and Test\n'), 1)
        self.assertIn('needs: [lint-and-test, vm-tests]', self.gate)
        self.assertIn('if: always()', self.gate)
        self.assertNotIn('continue-on-error', self.gate)
        self.assertIn('STATIC_RESULT: ${{ needs.lint-and-test.result }}', self.gate)
        self.assertIn('VM_RESULT: ${{ needs.vm-tests.result }}', self.gate)
        self.assertIn("'${{ needs.ci-complete.result }}' === 'success'", self.workflow)

    @unittest.skipUnless(os.name != 'nt' and shutil.which('bash'), 'Bash behavior is verified on cloud CI')
    def test_actual_gate_fails_for_failed_skipped_or_cancelled_dependencies(self):
        script = textwrap.dedent(self.gate.split('        run: |\n', 1)[1]).strip()
        # GitHub's default bash shell is fail-fast. Emulate that exact behavior.
        for static, vm in itertools.product(('success', 'failure', 'cancelled', 'skipped'), repeat=2):
            with self.subTest(static=static, vm=vm):
                result = subprocess.run(['bash', '--noprofile', '--norc', '-e', '-c', script],
                    env=dict(os.environ, STATIC_RESULT=static, VM_RESULT=vm), capture_output=True)
                self.assertEqual(result.returncode == 0, static == vm == 'success')


if __name__ == '__main__':
    unittest.main()
