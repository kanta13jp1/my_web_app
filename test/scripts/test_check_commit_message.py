#!/usr/bin/env python3
"""Unit tests for scripts/check_commit_message.py, install_commit_msg_hook.sh, and CI skip guard."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import check_commit_message  # noqa: E402


class CheckCommitMessageTests(unittest.TestCase):
    def test_valid_ticket_formats_pass(self) -> None:
        valid_messages = (
            "feat: optimize pipeline refs #2727",
            "fix: restore artifact upload\n\nCloses #2727\n",
            "docs: onboarding guide\n\nRelated to #2724",
            "chore(ci): tidy workflow (#2727)",
            "feat(#42): scoped header notation",
            "fix: keep template comments\n\nRefs: #901\n# Please enter the commit message\n",
        )
        for msg in valid_messages:
            with self.subTest(msg=msg):
                ok, detail = check_commit_message.validate_commit_message(msg)
                self.assertTrue(ok, detail)

    def test_missing_or_invalid_ticket_fails(self) -> None:
        invalid_messages = (
            "",
            "   \n# comment only line\n",
            "feat: optimize CI workflow without issue link",
            "fix: zero ticket refs #0",
            "docs: mention #notanumber in text",
            "revert: manual commit missing issue reference",
        )
        for msg in invalid_messages:
            with self.subTest(msg=msg):
                ok, detail = check_commit_message.validate_commit_message(msg)
                self.assertFalse(ok, detail)

    def test_exempt_prefixes_pass_without_ticket(self) -> None:
        exempt_messages = (
            "Merge branch 'main' into feat/issue-2727-ci-commit-hooks",
            "Merge pull request #999 from kanta13jp1/fix-something",
            'Revert "temporary workaround"',
            "fixup! improve lint report",
            "squash! adjust build step",
            "amend! clarify hook text",
        )
        for msg in exempt_messages:
            with self.subTest(msg=msg):
                ok, detail = check_commit_message.validate_commit_message(msg)
                self.assertTrue(ok, detail)

    def test_cli_message_file_exit_codes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            msg_file = Path(tmp) / "COMMIT_EDITMSG"
            msg_file.write_text("feat: add validation (refs #2727)\n", encoding="utf-8")
            self.assertEqual(
                check_commit_message.main(["--message-file", str(msg_file)]),
                0,
            )

            msg_file.write_text("feat: missing reference\n", encoding="utf-8")
            self.assertEqual(
                check_commit_message.main(["--message-file", str(msg_file)]),
                1,
            )

    def test_detect_ci_skip_ignores_comments(self) -> None:
        self.assertTrue(check_commit_message.detect_ci_skip("docs: note [skip ci] (refs #2727)"))
        self.assertTrue(check_commit_message.detect_ci_skip("chore: cleanup\n\n[CI SKIP] refs #12"))
        self.assertFalse(
            check_commit_message.detect_ci_skip(
                "feat: normal commit (refs #2727)\n# [skip ci] in git comment template\n"
            )
        )

    def test_git_skip_guard_evaluates_head_and_pr_merge_parent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            env = {
                **os.environ,
                "GIT_AUTHOR_NAME": "Test Bot",
                "GIT_AUTHOR_EMAIL": "test@example.com",
                "GIT_COMMITTER_NAME": "Test Bot",
                "GIT_COMMITTER_EMAIL": "test@example.com",
            }
            subprocess.run(["git", "init", "-b", "main"], cwd=repo, check=True, env=env, capture_output=True)
            (repo / "README.md").write_text("base\n", encoding="utf-8")
            subprocess.run(["git", "add", "README.md"], cwd=repo, check=True, env=env, capture_output=True)
            subprocess.run(["git", "commit", "-m", "chore: base (refs #100)"], cwd=repo, check=True, env=env, capture_output=True)

            normal = check_commit_message.evaluate_ci_skip(repo, event_name="push")
            self.assertEqual(normal["skip_requested"], "false")
            self.assertEqual(normal["skip_non_required_heavy"], "false")

            subprocess.run(["git", "checkout", "-b", "feat"], cwd=repo, check=True, env=env, capture_output=True)
            (repo / "README.md").write_text("feat\n", encoding="utf-8")
            subprocess.run(["git", "add", "README.md"], cwd=repo, check=True, env=env, capture_output=True)
            subprocess.run(["git", "commit", "-m", "docs: update [skip ci] (refs #2727)"], cwd=repo, check=True, env=env, capture_output=True)

            out_file = repo / "github_output.txt"
            code = check_commit_message.main(
                [
                    "--check-ci-skip-git",
                    "--repo-root",
                    str(repo),
                    "--event-name",
                    "push",
                    "--github-output",
                    str(out_file),
                ]
            )
            self.assertEqual(code, 0)
            written = out_file.read_text(encoding="utf-8")
            self.assertIn("skip_requested=true\n", written)
            self.assertIn("skip_non_required_heavy=true\n", written)

            dispatch = check_commit_message.evaluate_ci_skip(repo, event_name="workflow_dispatch")
            self.assertEqual(dispatch["skip_requested"], "true")
            self.assertEqual(dispatch["skip_non_required_heavy"], "false")

            # Simulate GitHub pull_request synthetic merge commit (HEAD^1=main, HEAD^2=feat).
            subprocess.run(["git", "checkout", "main"], cwd=repo, check=True, env=env, capture_output=True)
            (repo / "OTHER.md").write_text("main\n", encoding="utf-8")
            subprocess.run(["git", "add", "OTHER.md"], cwd=repo, check=True, env=env, capture_output=True)
            subprocess.run(["git", "commit", "-m", "chore: main move (refs #101)"], cwd=repo, check=True, env=env, capture_output=True)
            subprocess.run(
                ["git", "merge", "--no-ff", "feat", "-m", "Merge feat into main"],
                cwd=repo,
                check=True,
                env=env,
                capture_output=True,
            )

            pr_eval = check_commit_message.evaluate_ci_skip(repo, event_name="pull_request")
            self.assertEqual(pr_eval["skip_requested"], "true")
            self.assertEqual(pr_eval["skip_non_required_heavy"], "true")

            push_eval = check_commit_message.evaluate_ci_skip(repo, event_name="push")
            self.assertEqual(push_eval["skip_requested"], "false")

    def test_shallow_pr_merge_checkout_requires_depth_2_for_head2_skip_ci(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            remote = tmp_path / "remote"
            remote.mkdir()
            env = {
                **os.environ,
                "GIT_AUTHOR_NAME": "Test Bot",
                "GIT_AUTHOR_EMAIL": "test@example.com",
                "GIT_COMMITTER_NAME": "Test Bot",
                "GIT_COMMITTER_EMAIL": "test@example.com",
            }
            subprocess.run(["git", "init", "-b", "main"], cwd=remote, check=True, env=env, capture_output=True)
            (remote / "README.md").write_text("base\n", encoding="utf-8")
            subprocess.run(["git", "add", "README.md"], cwd=remote, check=True, env=env, capture_output=True)
            subprocess.run(["git", "commit", "-m", "chore: base (refs #100)"], cwd=remote, check=True, env=env, capture_output=True)

            subprocess.run(["git", "checkout", "-b", "pr-head"], cwd=remote, check=True, env=env, capture_output=True)
            (remote / "NOTE.md").write_text("doc update\n", encoding="utf-8")
            subprocess.run(["git", "add", "NOTE.md"], cwd=remote, check=True, env=env, capture_output=True)
            subprocess.run(
                ["git", "commit", "-m", "docs: skip heavy build [skip ci] (#2727)"],
                cwd=remote,
                check=True,
                env=env,
                capture_output=True,
            )

            subprocess.run(["git", "checkout", "main"], cwd=remote, check=True, env=env, capture_output=True)
            subprocess.run(
                ["git", "merge", "--no-ff", "pr-head", "-m", "Merge pr-head into main"],
                cwd=remote,
                check=True,
                env=env,
                capture_output=True,
            )
            merge_sha = subprocess.check_output(
                ["git", "rev-parse", "HEAD"],
                cwd=remote,
                text=True,
            ).strip()
            subprocess.run(
                ["git", "update-ref", "refs/pull/42/merge", merge_sha],
                cwd=remote,
                check=True,
                env=env,
                capture_output=True,
            )

            remote_url = remote.resolve().as_uri()
            # Shallow --depth=1 omits HEAD^2, mirroring the former ci.yml failure mode.
            depth1 = tmp_path / "checkout-depth1"
            depth1.mkdir()
            subprocess.run(["git", "init"], cwd=depth1, check=True, env=env, capture_output=True)
            subprocess.run(["git", "remote", "add", "origin", remote_url], cwd=depth1, check=True, env=env, capture_output=True)
            subprocess.run(
                ["git", "fetch", "--depth=1", "origin", "+refs/pull/42/merge:refs/remotes/origin/checkout"],
                cwd=depth1,
                check=True,
                env=env,
                capture_output=True,
            )
            subprocess.run(["git", "checkout", "--force", "refs/remotes/origin/checkout"], cwd=depth1, check=True, env=env, capture_output=True)
            eval_d1 = check_commit_message.evaluate_ci_skip(depth1, event_name="pull_request")
            self.assertEqual(eval_d1["skip_requested"], "false")

            # Shallow --depth=2 includes HEAD^2 so PR head [skip ci] is detected cleanly.
            depth2 = tmp_path / "checkout-depth2"
            depth2.mkdir()
            subprocess.run(["git", "init"], cwd=depth2, check=True, env=env, capture_output=True)
            subprocess.run(["git", "remote", "add", "origin", remote_url], cwd=depth2, check=True, env=env, capture_output=True)
            subprocess.run(
                ["git", "fetch", "--depth=2", "origin", "+refs/pull/42/merge:refs/remotes/origin/checkout"],
                cwd=depth2,
                check=True,
                env=env,
                capture_output=True,
            )
            subprocess.run(["git", "checkout", "--force", "refs/remotes/origin/checkout"], cwd=depth2, check=True, env=env, capture_output=True)
            eval_d2 = check_commit_message.evaluate_ci_skip(depth2, event_name="pull_request")
            self.assertEqual(eval_d2["skip_requested"], "true")
            self.assertEqual(eval_d2["skip_non_required_heavy"], "true")

    def test_hook_installer_and_workflow_wiring_contract(self) -> None:
        installer = (REPO_ROOT / "scripts" / "install_commit_msg_hook.sh").read_text(encoding="utf-8")
        self.assertIn("git -C \"${REPO_ROOT}\" rev-parse --git-path hooks", installer)
        self.assertIn("check_commit_message.py", installer)
        self.assertIn("--force", installer)
        self.assertIn("--dry-run", installer)
        self.assertIsNone(
            re.search(r"(?<![{])\$\d+", installer),
            "Installer shell script must brace positional parameters such as ${1:-}.",
        )

        readme = (REPO_ROOT / ".githooks" / "README.md").read_text(encoding="utf-8")
        self.assertIn("install_commit_msg_hook.sh", readme)
        self.assertIn("check_commit_message.py", readme)

        ci_yml = (REPO_ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        self.assertIn("id: commit_skip", ci_yml)
        self.assertIn("scripts/check_commit_message.py --check-ci-skip-git", ci_yml)
        self.assertIn('git fetch --depth=2 origin "+${ref}:refs/remotes/origin/checkout"', ci_yml)
        self.assertIn("steps.commit_skip.outputs.skip_non_required_heavy != 'true'", ci_yml)
        self.assertIn("name: Upload static analysis failure report", ci_yml)
        self.assertIn("if: failure() && steps.changes.outputs.flutter == 'true'", ci_yml)

        # Ensure the CI skip guard checks commit message only through Python/git, never expression injection.
        self.assertIsNone(
            re.search(r"\$\{\{\s*github\.event\.[^\n]*message", ci_yml),
        )

    def test_install_commit_msg_hook_script_installs_and_enforces_rules(self) -> None:
        bash_exe = None
        if os.name == "nt":
            git_bash = Path(r"C:\Program Files\Git\bin\bash.exe")
            if git_bash.is_file():
                bash_exe = str(git_bash)
        if bash_exe is None:
            candidate = shutil.which("bash")
            if candidate:
                probe = subprocess.run([candidate, "-c", "true"], capture_output=True, check=False)
                if probe.returncode == 0:
                    bash_exe = candidate
        if bash_exe is None:
            self.skipTest("Working GNU bash executable is unavailable in this environment")

        installer_src = (REPO_ROOT / "scripts" / "install_commit_msg_hook.sh").read_text(encoding="utf-8")
        validator_src = (REPO_ROOT / "scripts" / "check_commit_message.py").read_text(encoding="utf-8")

        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            env = {
                **os.environ,
                "GIT_AUTHOR_NAME": "Test Bot",
                "GIT_AUTHOR_EMAIL": "test@example.com",
                "GIT_COMMITTER_NAME": "Test Bot",
                "GIT_COMMITTER_EMAIL": "test@example.com",
            }
            if os.name == "nt":
                env["PATH"] = f"{Path(bash_exe).parent};{env.get('PATH', '')}"

            subprocess.run(["git", "init", "-b", "main"], cwd=repo, check=True, env=env, capture_output=True)
            scripts_dir = repo / "scripts"
            scripts_dir.mkdir(parents=True, exist_ok=True)
            installer_path = scripts_dir / "install_commit_msg_hook.sh"
            validator_path = scripts_dir / "check_commit_message.py"
            installer_path.write_bytes(installer_src.encode("utf-8"))
            validator_path.write_bytes(validator_src.encode("utf-8"))
            (repo / "README.md").write_text("seed\n", encoding="utf-8")

            dry_run = subprocess.run(
                [bash_exe, "scripts/install_commit_msg_hook.sh", "--dry-run"],
                cwd=repo,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(dry_run.returncode, 0, dry_run.stderr)
            self.assertIn("[dry-run] Would install commit-msg hook", dry_run.stdout)
            hook_path = repo / ".git" / "hooks" / "commit-msg"
            self.assertFalse(hook_path.exists())

            install = subprocess.run(
                [bash_exe, "scripts/install_commit_msg_hook.sh"],
                cwd=repo,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(install.returncode, 0, install.stderr)
            self.assertTrue(hook_path.is_file())

            subprocess.run(["git", "add", "."], cwd=repo, check=True, env=env, capture_output=True)
            rejected = subprocess.run(
                ["git", "commit", "-m", "chore: missing issue id"],
                cwd=repo,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertNotEqual(rejected.returncode, 0)

            accepted = subprocess.run(
                ["git", "commit", "-m", "chore: install commit hook (refs #2727)"],
                cwd=repo,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(accepted.returncode, 0, accepted.stderr)

            # Custom unmanaged hook collision is blocked unless --force is passed.
            hook_path.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
            blocked = subprocess.run(
                [bash_exe, "scripts/install_commit_msg_hook.sh"],
                cwd=repo,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertNotEqual(blocked.returncode, 0)

            forced = subprocess.run(
                [bash_exe, "scripts/install_commit_msg_hook.sh", "--force"],
                cwd=repo,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(forced.returncode, 0, forced.stderr)


if __name__ == "__main__":
    unittest.main()
