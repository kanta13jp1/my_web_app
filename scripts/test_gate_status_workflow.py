from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


class WorkflowContractTest(unittest.TestCase):
    def test_status_only_upload_runs_after_the_contract_even_on_failure(self):
        here = Path(__file__).resolve().parent
        fixture = here / 'candidate.yml'
        workflow = fixture if fixture.exists() else here.parent / '.github/workflows/claude-agent-review.yml'
        text = workflow.read_text(encoding='utf-8')
        gate = text.split('  high-risk-ultrareview-gate:', 1)[1].split('\n  # ---', 1)[0]
        self.assertIn('id: high_risk_contract', gate)
        prepare = gate.split('- name: Prepare bounded gate status', 1)[1].split('- name: Upload gate status', 1)[0]
        upload = gate.split('- name: Upload gate status', 1)[1]
        self.assertIn('if: always()', prepare)
        self.assertIn('steps.high_risk_contract.outcome', prepare)
        self.assertIn('mktemp -d', prepare)
        self.assertIn('case "$GATE_OUTCOME" in', prepare)
        self.assertIn('independent-review-evidence: not-established', prepare)
        self.assertIn('if: always()', upload)
        self.assertIn('path: ${{ steps.gate_status.outputs.path }}', upload)
        self.assertIn('if-no-files-found: error', upload)
        self.assertNotIn('.ci-logs/', upload)
        self.assertNotIn('include-hidden-files: true', upload)

    def test_real_shell_writes_only_fixed_status(self):
        here = Path(__file__).resolve().parent
        fixture = here / 'candidate.yml'
        workflow = fixture if fixture.exists() else here.parent / '.github/workflows/claude-agent-review.yml'
        prepare = workflow.read_text(encoding='utf-8').split('- name: Prepare bounded gate status', 1)[1].split('- name: Upload gate status', 1)[0]
        script = prepare.split('        run: |\n', 1)[1]
        script = '\n'.join(line[10:] for line in script.splitlines() if line.startswith('          '))
        bash = os.environ.get('GATE_FIXTURE_BASH') or shutil.which('bash')
        if not bash:
            self.skipTest('bash unavailable')
        with tempfile.TemporaryDirectory(prefix='synthetic-gate-status-') as directory:
            root = Path(directory)
            def shell_path(path):
                value = Path(path).as_posix()
                return '/' + value[0].lower() + value[2:] if os.name == 'nt' else value
            for number, outcome in enumerate(('success', 'failure', 'skipped', 'cancelled', 'fixture-secret\n$(false)', '')):
                run_dir = root / str(number)
                run_dir.mkdir()
                output = run_dir / 'github-output'
                output.touch()
                env = dict(os.environ, RUNNER_TEMP=shell_path(run_dir), GITHUB_OUTPUT=shell_path(output), GATE_OUTCOME=outcome)
                result = subprocess.run([bash, '-c', script], env=env, capture_output=True, timeout=10, check=True)
                expected = outcome if outcome in ('success', 'failure', 'skipped', 'cancelled') else 'unknown'
                files = list(run_dir.glob('high-risk-gate-status.*/status.txt'))
                self.assertEqual(len(files), 1)
                self.assertEqual(files[0].read_text(encoding='utf-8'), f'high-risk-gate-step: {expected}\nindependent-review-evidence: not-established\n')
                self.assertNotIn(b'fixture-secret', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
