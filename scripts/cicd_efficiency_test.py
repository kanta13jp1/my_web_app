#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import unittest
import os
import re
import sys
import hashlib
from unittest.mock import patch
import shutil
import subprocess
import tempfile
import textwrap


ROOT = Path(__file__).resolve().parents[1]


class CicdEfficiencyTest(unittest.TestCase):
    def read(self, relative: str) -> str:
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_push_does_not_repeat_full_local_gate(self) -> None:
        lefthook = self.read("lefthook.yml")
        self.assertNotIn("pre-push:", lefthook)
        self.assertNotIn("quality_gate.py --full", lefthook)
        pre_commit = self.read("scripts/pre_commit_quality_gate.py")
        self.assertNotIn('quality_gate.main(["--fast"])', pre_commit)
        self.assertNotIn('"flutter", "analyze"', pre_commit)
        self.assertNotIn('["dart", "format"', pre_commit)

    def test_deploy_reuses_protected_pr_ci_result(self) -> None:
        deploy = self.read(".github/workflows/deploy-prod.yml")
        self.assertIn("if: github.event_name == 'workflow_dispatch'", deploy)
        self.assertIn("needs.ci.result == 'skipped'", deploy)
        self.assertIn("if: steps.changes.outputs.web == 'true'", deploy)
        self.assertIn("if: steps.changes.outputs.edge == 'true'", deploy)
        self.assertIn("if: steps.changes.outputs.migration == 'true'", deploy)

    def test_manual_web_only_deploy_skips_database_and_edge_scope(self) -> None:
        deploy = self.read(".github/workflows/deploy-prod.yml")
        self.assertIn("deploy_scope:", deploy)
        self.assertIn("- web_only", deploy)
        self.assertIn(
            "WEB_ONLY: ${{ github.event_name == 'workflow_dispatch' && "
            "inputs.deploy_scope == 'web_only' }}",
            deploy,
        )
        self.assertEqual(
            deploy.count(
                "FORCE_ALL: ${{ github.event_name != 'push' && "
                "inputs.deploy_scope != 'web_only' }}"
            ),
            2,
        )
        self.assertIn("printf 'web/index.html\\n'", deploy)
    def test_deploy_uses_global_semver_and_rejects_tag_mismatch(self) -> None:
        deploy = self.read(".github/workflows/deploy-prod.yml")
        self.assertNotIn("git describe --tags", deploy)
        self.assertIn("git tag --list 'v[0-9]*.[0-9]*.[0-9]*'", deploy)
        self.assertIn("grep -E '^v[0-9]+\\.[0-9]+\\.[0-9]+$'", deploy)
        self.assertIn("sort -V", deploy)
        self.assertIn(
            "Existing tag $TAG points to $EXISTING_TARGET, expected $GITHUB_SHA",
            deploy,
        )

        tag_step = deploy.split("- name: Push Release Tag", 1)[1].split(
            "- name: Create GitHub Release", 1
        )[0]
        self.assertNotIn("continue-on-error", tag_step)
        self.assertIn(
            'gh api --method POST "repos/$GITHUB_REPOSITORY/git/refs"',
            tag_step,
        )
        self.assertIn('-f sha="$GITHUB_SHA"', tag_step)
        self.assertIn("target_commitish: ${{ github.sha }}", deploy)
        self.assertIn("- name: Verify Release Tag Target", deploy)
        self.assertIn(
            "Release tag $TAG points to $REF_SHA, expected $GITHUB_SHA",
            deploy,
        )

    def deployment_checkout_script(self) -> str:
        deploy = self.read(".github/workflows/deploy-prod.yml")
        step = deploy.split("      - name: Checkout code\n", 1)[1].split(
            "      - name: Collect pushed files\n", 1
        )[0]
        return textwrap.dedent(step.split("        run: |\n", 1)[1]).strip()

    def test_deploy_checkout_uses_event_sha_not_moving_branch(self) -> None:
        script = self.deployment_checkout_script()
        self.assertIn('git fetch --tags --prune origin "$GITHUB_SHA"', script)
        self.assertIn("git checkout --force --detach FETCH_HEAD", script)
        self.assertIn('git rev-parse HEAD)', script)
        self.assertNotIn("GITHUB_REF", script)

    @unittest.skipUnless(shutil.which("bash"), "Bash integration runs on cloud CI")
    def test_deploy_checkout_survives_branch_advance(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            checkout = root / "checkout"
            source.mkdir()
            checkout.mkdir()
            # Hooks export repository-local Git variables. Never let the
            # temporary fixture initialize or commit in the caller's repository.
            local_git_environment = set(subprocess.check_output(
                ["git", "rev-parse", "--local-env-vars"], text=True,
            ).splitlines())
            isolated_environment = {
                key: value for key, value in os.environ.items()
                if key not in local_git_environment
            }
            env = dict(isolated_environment, GIT_CONFIG_NOSYSTEM="1",
                       GIT_CONFIG_GLOBAL=os.devnull,
                       GIT_AUTHOR_NAME="Fixture", GIT_AUTHOR_EMAIL="fixture@example.invalid",
                       GIT_COMMITTER_NAME="Fixture", GIT_COMMITTER_EMAIL="fixture@example.invalid")
            def git(*args):
                return subprocess.check_output(
                    ["git", "-C", str(source), *args], env=env, text=True,
                    stderr=subprocess.STDOUT,
                ).strip()
            git("init", "--initial-branch=main")
            git("commit", "--allow-empty", "-m", "Event revision")
            event_sha = git("rev-parse", "HEAD")
            git("tag", "v1.0.0")
            git("commit", "--allow-empty", "-m", "Newer branch revision")
            self.assertNotEqual(event_sha, git("rev-parse", "HEAD"))
            script = self.deployment_checkout_script().replace(
                '"https://github.com/${GITHUB_REPOSITORY}.git"', '"$FIXTURE_REMOTE"'
            )
            env.update(GITHUB_SHA=event_sha, GITHUB_REF="refs/heads/main",
                       GITHUB_REPOSITORY="fixture/repo", FIXTURE_REMOTE=str(source))
            result = subprocess.run(
                [shutil.which("bash"), "-c", script], cwd=checkout, env=env, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            actual = subprocess.check_output(
                ["git", "-C", str(checkout), "rev-parse", "HEAD"], env=env, text=True
            ).strip()
            self.assertEqual(actual, event_sha)
            tags = subprocess.check_output(
                ["git", "-C", str(checkout), "tag", "--list"], env=env, text=True
            )
            self.assertIn("v1.0.0", tags)

    def test_minimal_gate_does_not_poll_ci(self) -> None:
        workflow = self.read(".github/workflows/minimal-e2e-gate.yml")
        self.assertNotIn("Wait for deterministic CI checks", workflow)
        self.assertNotIn("check_pr_deterministic_ci.py", workflow)
        self.assertIn("workflow_run:", workflow)
        public_job = workflow.split("  public-e2e-stability:", maxsplit=1)[1]
        self.assertNotIn("github.event_name == 'pull_request'", public_job)
        self.assertNotIn("Select deployed E2E scope", public_job)

    def test_non_app_prs_skip_minimal_e2e_declaration(self) -> None:
        script = self.read("scripts/check_minimal_e2e_gate.py")
        self.assertIn("if not app_change:", script)
        self.assertIn("no application runtime code changed", script)

    def test_ga_gate_does_not_run_for_every_test_file(self) -> None:
        workflow = self.read(".github/workflows/ga-readiness-gate.yml")
        self.assertNotIn('- "test/**"', workflow)
        self.assertNotIn("flutter analyze", workflow)
        self.assertNotIn("flutter test", workflow)
        self.assertIn("cancel-in-progress: ${{ github.event_name == 'pull_request' }}", workflow)

    def test_auto_fix_is_operator_initiated(self) -> None:
        workflow = self.read(".github/workflows/ci-auto-fix.yml")
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("workflow_run:", workflow)

    def test_ci_expensive_steps_are_path_scoped(self) -> None:
        workflow = self.read(".github/workflows/ci.yml")
        self.assertIn("if: steps.changes.outputs.flutter == 'true'", workflow)
        self.assertIn("if: steps.changes.outputs.edge == 'true'", workflow)
        self.assertIn("if: steps.changes.outputs.caption == 'true'", workflow)
        self.assertIn("steps.changes.outputs.web == 'true'", workflow)

    def test_cloud_first_manual_gate_is_available(self) -> None:
        workflow = self.read(".github/workflows/ci.yml")
        self.assertIn("  workflow_dispatch:\n", workflow)
        self.assertIn(
            "github.event_name == 'pull_request' || "
            "github.event_name == 'workflow_dispatch'",
            workflow,
        )
        self.assertIn("python scripts/cloud_first_route_test.py", workflow)
        self.assertIn(
            "python scripts/generate_infrastructure_map_test.py", workflow
        )
        precommit = self.read("scripts/pre_commit_quality_gate.py")
        self.assertIn(
            "scripts/generate_infrastructure_map_test.py", precommit
        )
        self.assertIn("expected_head_sha:", workflow)
        self.assertIn('ref="${GITHUB_SHA}"', workflow)

        cloud_workflow = self.read(".github/workflows/cloud-development.yml")
        self.assertIn("  workflow_dispatch:\n", cloud_workflow)
        self.assertIn(
            ".agents/skills/site-trust-improvement-loop/**",
            cloud_workflow,
        )
        self.assertIn("expected_head_sha:", cloud_workflow)
        self.assertIn(
            'actual_head_sha="$(git rev-parse HEAD)"',
            cloud_workflow,
        )

        guide = self.read("docs/CLOUD_FIRST_DEVELOPMENT.md")
        self.assertIn(
            "python scripts/cloud_ci_handoff.py --profile full "
            "--execute --watch",
            guide,
        )
        self.assertIn("30 GiB", guide)
        self.assertIn("4 GiB", guide)

        trust_loop = self.read(
            ".agents/skills/site-trust-improvement-loop/SKILL.md"
        )
        self.assertIn("python scripts/cloud_first_route.py", trust_loop)
        self.assertIn("cloud_proven", trust_loop)

    def test_required_ci_checks_are_emitted_for_docs_only_prs(self) -> None:
        workflow = self.read(".github/workflows/ci.yml")
        pull_request = workflow.split("  pull_request:", 1)[1].split(
            "  push:", 1
        )[0]
        push = workflow.split("  push:", 1)[1].split("  workflow_call:", 1)[0]
        lint_job = workflow.split("  lint-and-test:", 1)[1].split(
            "  vm-tests:", 1
        )[0]
        security_job = workflow.split("  security-check:", 1)[1].split(
            "  pr-comment:", 1
        )[0]

        self.assertNotIn("paths-ignore:", pull_request)
        self.assertIn("paths-ignore:", push)
        self.assertIn("  workflow_call:", workflow)
        self.assertIn(
            "FORCE_ALL: ${{ github.event_name != 'pull_request' }}", workflow
        )
        self.assertIn("name: Lint, Format, and Test", workflow)
        self.assertIn("name: Security Check", workflow)
        self.assertNotIn("\n    if:", lint_job)
        self.assertNotIn("\n    if:", security_job)


SHELL_SHA256 = {
    'Deploy to Firebase Hosting (Production)': 'f6114d733c4fa1b54834278237892a33c6a9eced9376ead99eca582af273016f',
    'Verify deploy reflects current commit': 'a46c9f8af98e722fd1affa799a4dda4f162ed4589fdce88e042c9b4a41caf984',
}


def step(text, name):
    return text.split(f'      - name: {name}\n', 1)[1].split('\n      - name:', 1)[0]


def bash_executable():
    candidate = shutil.which('bash')
    if os.name == 'nt' and candidate and Path(candidate).parent.name.lower() == 'system32':
        return None
    return str(Path(candidate).resolve()) if candidate else None


def approved_script(workflow, name):
    # Fingerprints detect drift; exact-source outer QA remains required.
    raw = step(workflow, name).split('        run: |\n', 1)[1].split('\n        env:', 1)[0]
    if hashlib.sha256(raw.encode('utf-8')).hexdigest() != SHELL_SHA256[name]:
        raise ValueError('Unreviewed workflow shell: refusing execution')
    return '\n'.join(line[10:] for line in raw.splitlines())


def isolated_environment(**test_values):
    env = {key: os.environ[key] for key in ('SYSTEMROOT', 'WINDIR', 'TEMP', 'TMP') if key in os.environ}
    env.update(PATH='', TEST_PYTHON=sys.executable)
    env.update(test_values)
    return env


# This fixture invokes only the absolute isolated Python interpreter, never curl.
CURL_FIXTURE = r"""
import json, os, sys
args = sys.argv[1:]
with open(os.environ['CURL_TRACE'], 'a', encoding='utf-8') as stream:
    stream.write(json.dumps(args) + '\n')
if len(args) != 8 or args[:7] != ['-fsS', '--connect-timeout', '5', '--max-time', '10', '-H', 'Cache-Control: no-cache']:
    sys.exit(97)
for endpoint, url in [('actual', os.environ['ACTUAL_MANIFEST']), ('public', os.environ['PUBLIC_MANIFEST'])]:
    for attempt in range(1, 5):
        if args[-1] == url + '?expected=test-sha&attempt=' + str(attempt):
            sequence = json.loads(os.environ['FAKE_REPLIES'])[endpoint]
            status, body = sequence[min(attempt - 1, len(sequence) - 1)]
            sys.stdout.write(body)
            sys.exit(status)
sys.exit(98)
"""


class DeploymentGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = (ROOT / '.github/workflows/deploy-prod.yml').read_text(encoding='utf-8')

    def test_web_scope_and_failure_are_enforced(self):
        for name in SHELL_SHA256:
            with self.subTest(name=name):
                s = step(self.workflow, name)
                self.assertIn("if: steps.changes.outputs.web == 'true'", s)
                self.assertNotIn('continue-on-error', s)
        self.assertIn("vars.PRODUCTION_DEPLOY_HOLD == 'false'", self.workflow)
        self.assertIn('cancel-in-progress: false', self.workflow)

    def test_public_verification_has_network_timeouts_and_both_destinations(self):
        s = step(self.workflow, 'Verify deploy reflects current commit')
        self.assertIn('curl -fsS --connect-timeout 5 --max-time 10 -H "Cache-Control: no-cache"', s)
        self.assertIn('for SITE in "${DEPLOY_URL%/}/version.json" "$PUBLIC_MANIFEST"; do', s)
        self.assertIn('DEPLOY_URL: ${{ steps.firebase_cli_deploy.outputs.details_url }}', s)
        self.assertIn('EXPECTED: ${{ github.sha }}', s)
        self.assertIn('PUBLIC_MANIFEST: https://my-web-app-b67f4.web.app/version.json', s)

    def test_firebase_cli_version_is_pinned_and_deploy_status_preserved(self):
        s = step(self.workflow, 'Deploy to Firebase Hosting (Production)')
        self.assertIn('firebase-tools@15.34.0', s)
        self.assertNotIn('firebase-tools@latest', s)
        self.assertIn('deploy_status=0', s)
        self.assertIn('|| deploy_status=$?', s)
        self.assertIn('exit "$deploy_status"', s)

    def test_approved_shell_fingerprints(self):
        for name in SHELL_SHA256:
            with self.subTest(name=name):
                self.assertTrue(approved_script(self.workflow, name))

    def test_unknown_shell_never_runs(self):
        mutated = self.workflow.replace('if RESPONSE=$(curl -fsS ', 'if RESPONSE=$(command curl -fsS ', 1)
        self.assertNotEqual(mutated, self.workflow)
        self.workflow = mutated
        with patch.object(subprocess, 'run') as execute:
            with self.assertRaisesRegex(ValueError, 'Unreviewed workflow shell'):
                self.run_verification()
            execute.assert_not_called()

    def run_verification(self, replies=None, deployment_url='https://fixture-actual.web.app'):
        import json
        script = approved_script(self.workflow, 'Verify deploy reflects current commit')
        prefix = ('sleep() { [[ "$#" -eq 1 && "$1" == 15 ]]; }\n'
                  'curl() { "$TEST_PYTHON" -I "$CURL_FIXTURE_PATH" "$@"; }\n'
                  'python3() { "$TEST_PYTHON" -I "$@"; }\n')
        matching = [0, '{"commit":"test-sha"}']
        if replies is None:
            replies = {'actual': [matching], 'public': [matching]}
        with tempfile.TemporaryDirectory(prefix='verify-manifest-') as directory:
            fixture = Path(directory) / 'curl_fixture.py'
            trace = Path(directory) / 'trace.jsonl'
            fixture.write_text(CURL_FIXTURE, encoding='utf-8')
            trace.write_text('', encoding='utf-8')
            env = isolated_environment(
                DEPLOY_URL=deployment_url, EXPECTED='test-sha',
                ACTUAL_MANIFEST='https://fixture-actual.web.app/version.json',
                PUBLIC_MANIFEST='https://my-web-app-b67f4.web.app/version.json',
                FAKE_REPLIES=json.dumps(replies), CURL_TRACE=str(trace),
                CURL_FIXTURE_PATH=str(fixture))
            result = subprocess.run([bash_executable(), '--noprofile', '--norc', '-c', prefix + script],
                                    env=env, capture_output=True, text=True, encoding='utf-8', timeout=15)
            calls = [json.loads(line) for line in trace.read_text(encoding='utf-8').splitlines()]
        return result, calls

    @unittest.skipUnless(bash_executable(), 'Bash not available; shell execution not verified')
    def test_firebase_cli_failure_propagates_even_if_diagnostics_fail(self):
        script = approved_script(self.workflow, 'Deploy to Firebase Hosting (Production)')
        script = re.sub(r'\$\{\{\s*secrets\.[^}]+\}\}', 'synthetic', script)
        prefix = r"""
mktemp() {
  if [[ ! -e "$FIXTURE_DIR/key" ]]; then
    : > "$FIXTURE_DIR/key"; printf '%s' "$FIXTURE_DIR/key"
  else
    : > "$FIXTURE_DIR/output"; printf '%s' "$FIXTURE_DIR/output"
  fi
}
rm() {
  [[ "$#" -eq 3 && "$1" == -f && "$2" == "$FIXTURE_DIR/key" && "$3" == "$FIXTURE_DIR/output" ]] || return 99
  printf 'cleanup\n' >> "$FIXTURE_DIR/trace"
}
npx() {
  [[ "$#" -eq 8 && "$*" == '-y firebase-tools@15.34.0 deploy --only hosting --project synthetic --json' ]] || return 99
  printf '{"error":{"message":"synthetic"}}'; return 42
}
python3() { printf 'diagnostic\n' >> "$FIXTURE_DIR/trace"; return "$DIAGNOSTIC_STATUS"; }
cat() { printf 'unexpected-success\n' >> "$FIXTURE_DIR/trace"; return 99; }
jq() { return 99; }
head() { return 99; }
"""
        for status in ('0', '17'):
            with self.subTest(diagnostic_status=status), tempfile.TemporaryDirectory(prefix='deploy-failure-') as directory:
                env = isolated_environment(FIXTURE_DIR=Path(directory).as_posix(), DIAGNOSTIC_STATUS=status)
                result = subprocess.run([bash_executable(), '--noprofile', '--norc', '-c', prefix + script],
                                        env=env, capture_output=True, text=True, encoding='utf-8', timeout=15)
                trace = (Path(directory) / 'trace').read_text(encoding='utf-8')
                self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
                self.assertEqual(trace.splitlines(), ['diagnostic', 'cleanup'])
                self.assertNotIn('live deploy complete', result.stdout)
                self.assertNotIn('details_url=', result.stdout)
                self.assertEqual('no readable JSON diagnostic' in result.stdout, status != '0')

    @unittest.skipUnless(bash_executable(), 'Bash not available; shell execution not verified')
    def test_untrusted_startup_environment_is_not_inherited(self):
        with tempfile.TemporaryDirectory(prefix='deploy-env-test-') as directory:
            startup = Path(directory) / 'startup.sh'
            startup.write_text('echo INHERITED_ENV_EXECUTED\n', encoding='utf-8')
            poisoned = {'BASH_ENV': str(startup), 'ENV': str(startup), 'PYTHONPATH': directory,
                        'HTTP_PROXY': 'http://invalid.test', 'HTTPS_PROXY': 'http://invalid.test',
                        'ALL_PROXY': 'http://invalid.test', 'DUMMY_SECRET': 'synthetic',
                        'BASH_FUNC_curl%%': '() { echo INHERITED_ENV_EXECUTED; }'}
            with patch.dict(os.environ, poisoned):
                child = isolated_environment()
                for key in poisoned:
                    self.assertNotIn(key, child)
                self.assertEqual(child['PATH'], '')
                self.assertEqual(child['TEST_PYTHON'], sys.executable)
                result, calls = self.run_verification()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(len(calls), 2)
            self.assertNotIn('INHERITED_ENV_EXECUTED', result.stdout)

    @unittest.skipUnless(bash_executable(), 'Bash not available; shell execution not verified')
    def test_verified_sha_at_both_destinations_succeeds(self):
        result, calls = self.run_verification()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([args[-1] for args in calls], [
            'https://fixture-actual.web.app/version.json?expected=test-sha&attempt=1',
            'https://my-web-app-b67f4.web.app/version.json?expected=test-sha&attempt=1'])
        self.assertIn('live at both required endpoints', result.stdout)

    @unittest.skipUnless(bash_executable(), 'Bash not available; shell execution not verified')
    def test_each_destination_uncertain_states_fail(self):
        matching = [0, '{"commit":"test-sha"}']
        cases = [('{"commit":"other-sha"}', 0), ('not-json', 0), ('', 0),
                 ('{}', 0), ('{"commit":null}', 0), ('', 22),
                 ('{"commit":"test-sha"}', 22), ('', 28), ('{"commit":"test-sha"}', 28)]
        for endpoint in ('actual', 'public'):
            for body, status in cases:
                with self.subTest(endpoint=endpoint, body=body, status=status):
                    replies = {'actual': [matching], 'public': [matching]}
                    replies[endpoint] = [[status, body]]
                    result, calls = self.run_verification(replies)
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertEqual(result.stdout.count('attempt '), 4)
                    self.assertNotIn('Deploy verified', result.stdout)
                    actual = [args[-1] for args in calls if args[-1].startswith('https://fixture-actual.')]
                    public = [args[-1] for args in calls if args[-1].startswith('https://my-web-app-b67f4.')]
                    self.assertEqual(len(actual), 4 if endpoint == 'actual' else 1)
                    self.assertEqual(len(public), 0 if endpoint == 'actual' else 4)

    @unittest.skipUnless(bash_executable(), 'Bash not available; shell execution not verified')
    def test_each_destination_retries_independently(self):
        sequence = [[0, '{"commit":"old"}'], [0, '{"commit":"test-sha"}']]
        result, calls = self.run_verification({'actual': sequence, 'public': sequence})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([args[-1] for args in calls], [
            'https://fixture-actual.web.app/version.json?expected=test-sha&attempt=1',
            'https://fixture-actual.web.app/version.json?expected=test-sha&attempt=2',
            'https://my-web-app-b67f4.web.app/version.json?expected=test-sha&attempt=1',
            'https://my-web-app-b67f4.web.app/version.json?expected=test-sha&attempt=2'])

    @unittest.skipUnless(bash_executable(), 'Bash not available; shell execution not verified')
    def test_invalid_deployment_url_never_calls_curl(self):
        for url in ('', 'http://fixture-actual.web.app', 'https://invalid.test',
                    'https://fixture-actual.web.app/other', 'https://fixture-actual.web.app?x=1'):
            with self.subTest(url=url):
                result, calls = self.run_verification(deployment_url=url)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, [])
                self.assertNotIn('Deploy verified', result.stdout)


if __name__ == '__main__':
    unittest.main()
