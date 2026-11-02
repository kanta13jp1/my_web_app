from pathlib import Path
import hashlib
import os
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch


APPROVED_WORKFLOW_SHA256 = 'b701860e234b214f94f3540a507912878cf8f19148cf54052dddcc1b88c170fc'
APPROVED_SCRIPT_SHA256 = '39f127ecaba14380731c5973615ea06d53c44b168eab4858267b16554a5417a3'


def read_workflow(root):
    shadow = root / 'scripts/candidate.yml'
    if shadow.exists() or shadow.is_symlink():
        raise AssertionError('shadow fixture is not allowed in CI')
    raw = (root / '.github/workflows/claude-agent-review.yml').read_bytes()
    if hashlib.sha256(raw).hexdigest() != APPROVED_WORKFLOW_SHA256:
        raise AssertionError('unreviewed workflow bytes')
    return raw.decode('utf-8')


def gate_section(text):
    starts = list(re.finditer(r'(?m)^  high-risk-ultrareview-gate:[ \t]*$', text))
    if len(starts) != 1:
        raise AssertionError('high-risk job must be unique')
    start = starts[0].end()
    ending = re.search(r'(?m)^  [A-Za-z_][\w-]*:[ \t]*$', text[start:])
    return text[start:start + ending.start()] if ending else text[start:]


def prepare_script(text):
    gate = gate_section(text)
    prepare_marker = '      - name: Prepare bounded gate status\n'
    upload_marker = '      - name: Upload gate status\n'
    if gate.count(prepare_marker) != 1 or gate.count(upload_marker) != 1:
        raise AssertionError('high-risk status steps must be unique')
    prepare = gate.split(prepare_marker, 1)[1].split(upload_marker, 1)[0]
    script = prepare.split('        run: |\n', 1)[1]
    script = '\n'.join(line[10:] for line in script.splitlines() if line.startswith('          '))
    if hashlib.sha256(script.encode('utf-8')).hexdigest() != APPROVED_SCRIPT_SHA256:
        raise AssertionError('unreviewed workflow shell will not be executed')
    return script


def approved_bash():
    # Production CI is Ubuntu. On other platforms, preserve static checks and
    # explicitly skip execution rather than trust a caller-controlled PATH.
    if os.name == 'nt':
        return None
    for path in ('/usr/bin/bash', '/bin/bash'):
        if Path(path).is_file():
            return path
    return None


class WorkflowContractTest(unittest.TestCase):
    def test_status_only_upload_runs_after_the_contract_even_on_failure(self):
        text = read_workflow(Path(__file__).resolve().parent.parent)
        gate = gate_section(text)
        self.assertIn('id: high_risk_contract', gate)
        prepare = gate.split('- name: Prepare bounded gate status', 1)[1].split('- name: Upload gate status', 1)[0]
        upload = gate.split('- name: Upload gate status', 1)[1]
        self.assertIn('if: always()', prepare)
        self.assertIn('steps.high_risk_contract.outcome', prepare)
        self.assertIn('mktemp -d', prepare)
        self.assertIn("case '${{ steps.high_risk_contract.outcome }}' in", prepare)
        self.assertNotIn('env:', prepare)
        self.assertIn('independent-review-evidence: not-established', prepare)
        self.assertIn('if: always()', upload)
        self.assertIn('path: ${{ steps.gate_status.outputs.path }}', upload)
        self.assertIn('if-no-files-found: error', upload)
        self.assertNotIn('.ci-logs/', upload)
        self.assertNotIn('include-hidden-files: true', upload)

    def test_shadow_fixture_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='gate-shadow-') as directory:
            root = Path(directory)
            (root / 'scripts').mkdir()
            (root / 'scripts/candidate.yml').write_text('shadow', encoding='utf-8')
            with self.assertRaisesRegex(AssertionError, 'shadow fixture'):
                read_workflow(root)

    def test_unreviewed_shell_is_rejected_before_execution(self):
        text = read_workflow(Path(__file__).resolve().parent.parent)
        edited = text.replace('status_dir=$(mktemp -d', 'status_dir=$(command mktemp -d', 1)
        self.assertNotEqual(edited, text)
        with patch(__name__ + '.read_workflow', return_value=edited), patch.object(subprocess, 'run') as execute:
            with self.assertRaisesRegex(AssertionError, 'unreviewed workflow shell'):
                self.test_real_shell_writes_only_fixed_status()
            execute.assert_not_called()

    def test_decoy_step_in_other_job_cannot_bypass_hash(self):
        text = read_workflow(Path(__file__).resolve().parent.parent)
        gate = gate_section(text)
        prepare_marker = '      - name: Prepare bounded gate status\n'
        upload_marker = '      - name: Upload gate status\n'
        decoy_step = prepare_marker + gate.split(prepare_marker, 1)[1].split(upload_marker, 1)[0]
        altered = text.replace('status_dir=$(mktemp -d', 'status_dir=$(command mktemp -d', 1)
        altered = altered.replace('  high-risk-ultrareview-gate:',
                                  '  decoy-job:\n    runs-on: ubuntu-latest\n    steps:\n' + decoy_step + '  high-risk-ultrareview-gate:', 1)
        with patch(__name__ + '.read_workflow', return_value=altered), patch.object(subprocess, 'run') as execute:
            with self.assertRaisesRegex(AssertionError, 'unreviewed workflow shell'):
                self.test_real_shell_writes_only_fixed_status()
            execute.assert_not_called()

    def test_real_shell_writes_only_fixed_status(self):
        text = read_workflow(Path(__file__).resolve().parent.parent)
        script = prepare_script(text)
        bash = approved_bash()
        if not bash:
            if os.name != 'nt' or os.environ.get('GITHUB_ACTIONS') == 'true':
                self.fail('trusted Bash unavailable in required CI')
            self.skipTest('trusted Bash unavailable; shell execution unverified')
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
                status_dir = run_dir / 'fixed-status-dir'
                status_dir.mkdir()
                # Values are fixed synthetic fixtures, not PR-controlled input.
                rendered = script.replace('${{ steps.high_risk_contract.outcome }}', outcome)
                prefix = 'mktemp() { printf "%s\\n" "$TEST_STATUS_DIR"; }\n'
                startup = run_dir / 'startup.sh'
                startup.write_text('echo INHERITED_ENV_EXECUTED\n', encoding='utf-8')
                poisoned = {'BASH_ENV': shell_path(startup), 'PYTHONPATH': directory,
                            'HTTP_PROXY': 'http://invalid.test', 'DUMMY_SECRET': 'synthetic'}
                with patch.dict(os.environ, poisoned):
                    env = {key: os.environ[key] for key in ('SYSTEMROOT', 'WINDIR', 'TEMP', 'TMP') if key in os.environ}
                    env.update(PATH='', RUNNER_TEMP=shell_path(run_dir), GITHUB_OUTPUT=shell_path(output), TEST_STATUS_DIR=shell_path(status_dir))
                    for key in poisoned:
                        self.assertNotIn(key, env)
                    result = subprocess.run([bash, '-c', prefix + rendered], env=env, capture_output=True, timeout=10, check=True)
                expected = outcome if outcome in ('success', 'failure', 'skipped', 'cancelled') else 'unknown'
                self.assertEqual((status_dir / 'status.txt').read_text(encoding='utf-8'), f'high-risk-gate-step: {expected}\nindependent-review-evidence: not-established\n')
                self.assertEqual(output.read_text(encoding='utf-8'), f'path={shell_path(status_dir)}/status.txt\n')
                self.assertEqual([item.name for item in status_dir.iterdir()], ['status.txt'])
                self.assertNotIn(b'fixture-secret', result.stdout + result.stderr)
                self.assertNotIn(b'INHERITED_ENV_EXECUTED', result.stdout + result.stderr)



class WorkflowMutationRegressionTest(unittest.TestCase):
    def test_modified_workflows_rejected_before_shell(self):
        source = read_workflow(Path(__file__).resolve().parent.parent)
        def change_once(text, old, new):
            self.assertEqual(text.count(old), 1)
            return text.replace(old, new, 1)
        mutations = []
        for name in ('Prepare bounded gate status', 'Upload gate status'):
            marker = '- name: ' + name
            head, tail = source.split(marker, 1)
            old = '        if: always()\n'
            self.assertIn(old, tail)
            mutations.append(head + marker + tail.replace(old, '        if: false # if: always()\n', 1))
        mutations.append(change_once(source, '        id: high_risk_contract\n',
                                     '        id: other_id # id: high_risk_contract\n'))
        marker = '      - name: Upload gate status\n'
        mutations.append(change_once(source, marker,
            '      - name: Rewrite generated status\n        run: echo forged\n' + marker))
        mutations.append(change_once(source,
            '  pull_request:\n    types: [opened, synchronize, reopened, ready_for_review]',
            '  pull_request:\n    types: [closed]'))
        head, tail = source.split('- name: Upload gate status', 1)
        mutations.append(head + '- name: Upload gate status' + change_once(tail,
            'path: ${{ steps.gate_status.outputs.path }}', 'path: ${{ steps.other.outputs.path }}'))
        mutations.append(head + '- name: Upload gate status' + change_once(tail,
            'uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9',
            'uses: actions/checkout@cf430e030ddbb5b0abf93d22962f4752f3646cd9'))
        mutations.append(change_once(source, '  # --- bc58b50b',
            "      - name: 'Prepare bounded gate status'\n        run: echo harmless\n\n  # --- bc58b50b"))
        needle = '    runs-on: ubuntu-latest\n    timeout-minutes: 5\n    if: github.event_name'
        mutations.append(change_once(source, needle, '    runs-on: evil\n' + needle))
        for changed in mutations:
            with self.subTest(case=mutations.index(changed)), tempfile.TemporaryDirectory(prefix='gate-mutation-') as directory:
                root = Path(directory)
                target = root / '.github/workflows/claude-agent-review.yml'
                target.parent.mkdir(parents=True)
                target.write_text(changed, encoding='utf-8', newline='\n')
                with patch.object(subprocess, 'run') as execute:
                    with self.assertRaisesRegex(AssertionError, 'unreviewed workflow bytes'):
                        read_workflow(root)
                    execute.assert_not_called()

    def test_ci_without_bash_fails_before_execution(self):
        source = read_workflow(Path(__file__).resolve().parent.parent)
        test = WorkflowContractTest('test_real_shell_writes_only_fixed_status')
        with patch(__name__ + '.read_workflow', return_value=source), \
             patch(__name__ + '.approved_bash', return_value=None), \
             patch.dict(os.environ, {'GITHUB_ACTIONS': 'true'}), \
             patch.object(subprocess, 'run') as execute:
            with self.assertRaisesRegex(AssertionError, 'trusted Bash unavailable in required CI'):
                test.test_real_shell_writes_only_fixed_status()
            execute.assert_not_called()


if __name__ == '__main__':
    unittest.main()
