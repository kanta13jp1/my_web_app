#!/usr/bin/env python3
"""Unit tests for COMPRESSED_PROMPT sync, rebase protocol, and CI analyze contract (#2680)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import sync_compressed_prompt as sync_mod  # noqa: E402


class SyncCompressedPromptTest(unittest.TestCase):
    def test_repository_sync_and_contracts_pass(self) -> None:
        self.assertTrue((ROOT / ".githooks" / "pre-push").is_file())
        state = sync_mod.check_sync_state(ROOT, strict_metrics=False)
        self.assertTrue(state["in_sync"], state["violations"])
        self.assertTrue(state["ci_analyze_strict"])
        self.assertTrue(state["rebase_protocol_ok"])
        for metric_key in ("migrations", "edge_functions", "workflows", "features"):
            self.assertIsInstance(state["recorded_metrics"].get(metric_key), int)

    def test_detects_v3_checksum_drift_and_recovers_on_write(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            for rel in (
                ".github/COMPRESSED_PROMPT_V3.md",
                ".github/workflows/ci.yml",
                "scripts/quality_gate.py",
                "analysis_options.yaml",
                ".githooks/pre-commit",
                ".githooks/pre-push",
                "scripts/check_remote_synced.py",
            ):
                src = ROOT / rel
                if not src.exists():
                    continue
                dst = tmp / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                dst.write_bytes(src.read_bytes())

            self.assertEqual(sync_mod.main(["--repo-root", str(tmp), "--write"]), 0)
            self.assertEqual(sync_mod.main(["--repo-root", str(tmp), "--check", "--strict-metrics"]), 0)

            mig = tmp / "supabase" / "migrations" / "20261125000001_test.sql"
            mig.parent.mkdir(parents=True, exist_ok=True)
            mig.write_text("-- metric drift test\n", encoding="utf-8")
            self.assertEqual(sync_mod.main(["--repo-root", str(tmp), "--check"]), 0)
            self.assertEqual(sync_mod.main(["--repo-root", str(tmp), "--check", "--strict-metrics"]), 1)

            v3 = tmp / ".github" / "COMPRESSED_PROMPT_V3.md"
            v3.write_text(v3.read_text(encoding="utf-8") + "\n<!-- updated -->\n", encoding="utf-8", newline="\n")
            self.assertEqual(sync_mod.main(["--repo-root", str(tmp), "--check"]), 1)
            self.assertEqual(sync_mod.main(["--repo-root", str(tmp), "--dry-run"]), 0)

    def test_rejects_weakened_ci_analyze_contract(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            for rel in (
                ".github/workflows/ci.yml",
                "scripts/quality_gate.py",
                "analysis_options.yaml",
            ):
                dst = tmp / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                dst.write_bytes((ROOT / rel).read_bytes())

            ci_path = tmp / ".github" / "workflows" / "ci.yml"
            ci_text = ci_path.read_text(encoding="utf-8")
            ci_path.write_text(
                ci_text.replace(
                    "      - name: Analyze code\n",
                    "      - name: Analyze code\n        continue-on-error: true\n",
                    1,
                ),
                encoding="utf-8",
                newline="\n",
            )
            audit = sync_mod.verify_ci_analyze_contract(tmp)
            self.assertFalse(audit["ok"])
            self.assertTrue(any("continue-on-error: true" in v for v in audit["violations"]))

    def test_rejects_missing_rebase_hook_and_emits_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            for rel in (
                ".github/COMPRESSED_PROMPT_V3.md",
                ".githooks/pre-commit",
                "scripts/check_remote_synced.py",
            ):
                dst = tmp / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                dst.write_bytes((ROOT / rel).read_bytes())

            rebase_audit = sync_mod.verify_rebase_sync_protocol(tmp)
            self.assertFalse(rebase_audit["ok"])
            self.assertTrue(any(".githooks/pre-push missing" in v for v in rebase_audit["violations"]))
            self.assertFalse(sync_mod.check_sync_state(tmp)["in_sync"])

            hook = tmp / ".githooks" / "pre-push"
            hook.write_text(
                "#!/usr/bin/env bash\npython -B scripts/sync_compressed_prompt.py --check\n# origin/main git pull --rebase origin main\n",
                encoding="utf-8",
                newline="\n",
            )
            self.assertTrue(sync_mod.verify_rebase_sync_protocol(tmp, require_pre_push_hook=True)["ok"])

            json_out = tmp / "sync.json"
            md_out = tmp / "sync.md"
            gh_out = tmp / "gh_output.txt"
            rc = sync_mod.main(
                [
                    "--repo-root",
                    str(ROOT),
                    "--check",
                    "--require-pre-push-hook",
                    "--json-out",
                    str(json_out),
                    "--markdown-out",
                    str(md_out),
                    "--github-output",
                    str(gh_out),
                ],
            )
            self.assertEqual(rc, 0)
            self.assertTrue(json.loads(json_out.read_text(encoding="utf-8"))["in_sync"])
            self.assertIn("in_sync=true", gh_out.read_text(encoding="utf-8"))

    def test_self_test_passes(self) -> None:
        self.assertEqual(sync_mod.main(["--repo-root", str(ROOT), "--self-test"]), 0)


if __name__ == "__main__":
    unittest.main()
