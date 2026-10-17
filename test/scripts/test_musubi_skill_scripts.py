"""Offline behavioral checks for release preflight and checkpoint safety."""
import argparse
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPTS = Path(__file__).resolve().parents[2] / ".agents/skills/musubi-social-release-pipeline/scripts"


def load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


checkpoint = load("checkpoint")
preflight = load("preflight")


class CheckpointTests(unittest.TestCase):
    def test_worktree_identity_resolves_common_packed_refs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            common = root / "common"
            git_dir = common / "worktrees" / "example"
            git_dir.mkdir(parents=True)
            checkout = root / "checkout"
            checkout.mkdir()
            (checkout / ".git").write_text("gitdir: ../common/worktrees/example\n", encoding="utf-8")
            (git_dir / "commondir").write_text("../..\n", encoding="utf-8")
            (git_dir / "HEAD").write_text("ref: refs/heads/codex/example\n", encoding="utf-8")
            (common / "packed-refs").write_text("a" * 40 + " refs/heads/codex/example\n", encoding="utf-8")
            self.assertEqual(checkpoint.locate_git_dir(checkout), git_dir.resolve())
            self.assertEqual(checkpoint.repository_identity(git_dir), ("codex/example", "a" * 12))

    def test_checkpoint_round_trip_and_secret_rejection_preserves_state(self):
        with tempfile.TemporaryDirectory() as directory:
            git_dir = Path(directory) / ".git"
            git_dir.mkdir()
            (git_dir / "HEAD").write_text("b" * 40, encoding="utf-8")
            destination = git_dir / "codex" / "musubi-social-release-state.json"
            args = argparse.Namespace(phase="validation", status="passed", summary="検証成功", next_action="review", evidence=["tests passed"], blocker=[])
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(checkpoint.command_set(destination, args), 0)
            saved = destination.read_bytes()
            self.assertEqual(json.loads(saved)["branch"], "detached")
            self.assertEqual(checkpoint.read_state(destination)["summary"], "検証成功")
            self.assertFalse(destination.with_suffix(".json.tmp").exists())
            for secret in ("token=example", "service_role: example", "eyJabc.def.ghi"):
                with self.subTest(secret_kind=secret.split("=")[0]):
                    args.evidence = [secret]
                    with self.assertRaises(ValueError):
                        checkpoint.command_set(destination, args)
                    self.assertEqual(destination.read_bytes(), saved)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(checkpoint.command_clear(destination), 0)
            self.assertIsNone(checkpoint.read_state(destination))


class PreflightTests(unittest.TestCase):
    def args(self, repo, **overrides):
        values = dict(repo=str(repo), environment="staging", check_github_secrets=True, memory_warn_threshold=80, memory_block_threshold=90, git_timeout=15)
        values.update(overrides)
        return argparse.Namespace(**values)

    def test_high_memory_blocks_before_git_or_secret_lookup(self):
        with patch.object(preflight, "memory_used_percent", return_value=90), patch.object(preflight, "git_value") as git, patch.object(preflight, "github_secret_names") as secrets:
            report = preflight.inspect(self.args("."))
        self.assertFalse(report["safe_to_continue"])
        self.assertEqual(report["branch"], "skipped-high-memory")
        git.assert_not_called()
        secrets.assert_not_called()

    def test_timeout_becomes_blocking_status_without_raising(self):
        with patch.object(preflight.subprocess, "run", side_effect=subprocess.TimeoutExpired(["git"], 1)):
            result = preflight.run(["git", "status"], Path.cwd(), timeout=1)
        self.assertEqual(result.returncode, 124)
        self.assertIn("timed out", result.stderr)

    def test_required_secrets_and_git_status_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in ("AGENTS.md", "pubspec.yaml", ".github/workflows/deploy-staging.yml", ".github/workflows/deploy-prod.yml"):
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.touch()
            def git_value(repo, *args):
                return str(root) if "--show-toplevel" in args else "codex/example"
            with patch.object(preflight, "memory_used_percent", return_value=40), patch.object(preflight, "git_value", side_effect=git_value), patch.object(preflight.shutil, "which", return_value="tool"), patch.object(preflight, "run", return_value=subprocess.CompletedProcess([], 0, "", "")) as run, patch.object(preflight, "github_secret_names", return_value=(preflight.SECRET_NAMES["staging"], None)) as secrets:
                self.assertTrue(preflight.inspect(self.args(root))["safe_to_continue"])
                secrets.return_value = (set(), None)
                report = preflight.inspect(self.args(root))
                self.assertFalse(report["safe_to_continue"])
                self.assertTrue(any(f["code"] == "github-secrets" and f["level"] == "BLOCK" for f in report["findings"]))
                run.return_value = subprocess.CompletedProcess([], 124, "", "timeout")
                report = preflight.inspect(self.args(root, check_github_secrets=False))
                self.assertIsNone(report["dirty_paths"])
                self.assertFalse(report["safe_to_continue"])


if __name__ == "__main__":
    unittest.main()
