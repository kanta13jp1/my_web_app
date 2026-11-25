#!/usr/bin/env python3
"""Tests for crash-safe CI Markdown agent memory and git-blame audit (#2709)."""

from __future__ import annotations

import datetime as dt
import subprocess
import tempfile
import unittest
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import ci_markdown_memory as mem


def _init_temp_repo(root: Path) -> None:
    subprocess.run(["git", "init"], cwd=str(root), check=True, capture_output=True)
    subprocess.run(["git", "config", "user.name", "agent-tester"], cwd=str(root), check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "agent-tester@example.invalid"], cwd=str(root), check=True, capture_output=True)


class CiMarkdownMemoryTests(unittest.TestCase):
    def test_markdown_persistence_and_git_blame_audit_across_commits(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            _init_temp_repo(repo)
            rel_mem = Path("memory/ci_agent_ledger/ci_run.md")

            mem.record_agent_step(
                repo_root=repo,
                memory_file=rel_mem,
                agent_name="planner-agent",
                decision="select_migration_check",
                tool_name="check_migration_timestamps",
                tool_outcome="passed",
                summary="Validated migration monotonicity in CI",
                run_id="gha-401",
                changed_files=["scripts/a.py"],
                now_utc=dt.datetime(2026, 11, 25, 5, 0, tzinfo=dt.timezone.utc),
            )
            c1 = mem.commit_and_optionally_push(
                repo_root=repo,
                memory_file=rel_mem,
                commit_message="chore(memory): planner decision gha-401",
            )
            self.assertTrue(c1["committed"])

            mem.record_agent_step(
                repo_root=repo,
                memory_file=rel_mem,
                agent_name="fixer-agent",
                decision="apply_lint_fix",
                tool_name="ruff",
                tool_outcome="passed",
                summary="Resolved trailing comma issue in widget test",
                run_id="gha-402",
                changed_files=["test/widget_test.dart"],
                now_utc=dt.datetime(2026, 11, 25, 5, 10, tzinfo=dt.timezone.utc),
            )
            c2 = mem.commit_and_optionally_push(
                repo_root=repo,
                memory_file=rel_mem,
                commit_message="chore(memory): fixer tool run gha-402",
            )
            self.assertTrue(c2["committed"])
            self.assertNotEqual(c1["commit_sha"], c2["commit_sha"])

            blame = mem.audit_with_git_blame(repo_root=repo, memory_file=rel_mem)
            self.assertTrue(blame["ok"])
            self.assertEqual(blame["total_attributed_entries"], 2)
            self.assertEqual(
                set(blame["unique_commits"]),
                {c1["commit_sha"], c2["commit_sha"]},
            )

            filtered = mem.audit_with_git_blame(
                repo_root=repo,
                memory_file=rel_mem,
                query="apply_lint_fix",
            )
            self.assertEqual(filtered["total_attributed_entries"], 1)
            self.assertEqual(filtered["records"][0]["commit"], c2["commit_sha"])
            self.assertEqual(filtered["records"][0]["summary"], "chore(memory): fixer tool run gha-402")

    def test_crash_recovery_restores_last_committed_state_cleanly(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            _init_temp_repo(repo)
            rel_mem = Path("memory/ci_agent_ledger/crash_safe.md")
            abs_mem = repo / rel_mem

            mem.record_agent_step(
                repo_root=repo,
                memory_file=rel_mem,
                agent_name="verifier-agent",
                decision="baseline_checkpoint",
                tool_name="unit_tests",
                tool_outcome="passed",
                summary="Baseline committed checkpoint before risky step",
                run_id="gha-500",
            )
            commit_res = mem.commit_and_optionally_push(
                repo_root=repo,
                memory_file=rel_mem,
                commit_message="chore(memory): checkpoint gha-500",
            )
            committed_snapshot = abs_mem.read_text(encoding="utf-8")

            # Simulate SIGKILL mid-write: orphan temp file + corrupted NUL/truncated Markdown.
            (abs_mem.parent / ".tmp-ci-mem-killed999.md").write_text("partial", encoding="utf-8")
            abs_mem.write_bytes(b"corrupt-\x00-\xff-truncated")

            recovery = mem.verify_and_recover_memory(repo_root=repo, memory_file=rel_mem)
            self.assertTrue(recovery["ok"])
            self.assertTrue(recovery["recovered"])
            self.assertEqual(recovery["status"], "restored_from_git_head")
            self.assertEqual(recovery["restored_commit"], commit_res["commit_sha"])
            self.assertIn(".tmp-ci-mem-killed999.md", recovery["orphans_cleaned"])
            self.assertEqual(abs_mem.read_text(encoding="utf-8"), committed_snapshot)

            # Subsequent step after crash appends cleanly onto recovered snapshot.
            after = mem.record_agent_step(
                repo_root=repo,
                memory_file=rel_mem,
                agent_name="recovery-agent",
                decision="resume_after_sigkill",
                tool_name="auto_capture",
                tool_outcome="ok",
                summary="Resumed seamlessly after crash recovery",
                run_id="gha-501",
            )
            self.assertTrue(after["ok"])
            final_text = abs_mem.read_text(encoding="utf-8")
            self.assertIn("Baseline committed checkpoint", final_text)
            self.assertIn("Resumed seamlessly after crash recovery", final_text)

    def test_masks_sensitive_credentials_before_persisting(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            _init_temp_repo(repo)
            rel_mem = Path("memory/ci_agent_ledger/redact.md")
            sample_pat = "ghp_" + "1234567890abcdefghij"

            mem.record_agent_step(
                repo_root=repo,
                memory_file=rel_mem,
                agent_name="ci-agent",
                decision="redact_check",
                tool_name="curl",
                tool_outcome="ok",
                summary=f"Saw {sample_pat} in stdout",
            )
            content = (repo / rel_mem).read_text(encoding="utf-8")
            self.assertNotIn("1234567890abcdefghij", content)
            self.assertIn("[REDACTED_GH_CREDENTIAL]", content)


if __name__ == "__main__":
    unittest.main()
