#!/usr/bin/env python3
"""Unit tests for multi-root workspace spec, generator, and safety rules (#2695)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import ai_review_gate as gate  # noqa: E402
import multiroot_workspace_manager as mgr  # noqa: E402


class MultirootWorkspaceManagerTest(unittest.TestCase):
    def test_repository_spec_and_vscode_parity_pass(self) -> None:
        readiness = mgr.inspect_workspace_readiness(ROOT, require_generated=False)
        self.assertTrue(readiness["ok"], readiness["violations"])
        self.assertEqual(
            readiness["rendered_files"],
            [
                ".cursor/rules/flutter_supabase_cross_stack.mdc",
                ".cursorignore",
                "my_web_app.code-workspace",
            ],
        )

    def test_rendered_outputs_are_valid_and_pass_future_review_scope(self) -> None:
        spec = json.loads((ROOT / mgr.SPEC_REL).read_text(encoding="utf-8"))
        ws_json = json.loads(mgr.render_code_workspace(spec))
        paths = [f["path"] for f in ws_json["folders"]]
        self.assertIn(".", paths)
        self.assertIn("lib", paths)
        self.assertIn("supabase", paths)

        ignore_text = mgr.render_cursorignore(spec)
        self.assertIn(".env.*", ignore_text)
        self.assertIn(".dart_tool/", ignore_text)

        mdc_text = mgr.render_cross_stack_mdc(spec)
        self.assertIn("lib/**/*.dart", mdc_text)
        self.assertIn("supabase/migrations/*.sql", mdc_text)

        # Verify the expanded allowlist in ai_review_gate accepts all 3 generated targets
        gate.validate_scope(
            [
                "my_web_app.code-workspace",
                ".cursorignore",
                ".cursor/rules/flutter_supabase_cross_stack.mdc",
            ],
            "diff --git a/.cursorignore b/.cursorignore\n+.env*\n",
        )

    def test_write_and_drift_detection_in_temp_repo(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            for folder in ("lib", "test", "supabase", "scripts", ".vscode"):
                (tmp / folder).mkdir(parents=True, exist_ok=True)
            for rel in (
                mgr.SPEC_REL,
                ".vscode/extensions.json",
                "scripts/ai_review_gate.py",
            ):
                dst = tmp / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                dst.write_bytes((ROOT / rel).read_bytes())

            self.assertEqual(mgr.main(["--repo-root", str(tmp), "--write"]), 0)
            self.assertEqual(mgr.main(["--repo-root", str(tmp), "--check-generated"]), 0)

            (tmp / ".cursorignore").write_text("# drifted\n", encoding="utf-8", newline="\n")
            self.assertEqual(mgr.main(["--repo-root", str(tmp), "--check-generated"]), 1)
            self.assertEqual(mgr.main(["--repo-root", str(tmp), "--dry-run", "--check-generated"]), 0)

    def test_rejects_traversal_and_missing_required_roots(self) -> None:
        spec = json.loads((ROOT / mgr.SPEC_REL).read_text(encoding="utf-8"))
        spec["folders"] = [{"name": "Escape", "path": "../outside"}]
        violations = mgr.validate_spec(spec, ROOT)
        self.assertTrue(any("without '..'" in v for v in violations))
        self.assertTrue(any("missing required cross-stack roots" in v for v in violations))

    def test_cli_outputs_and_self_test(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            json_out = tmp / "ws.json"
            md_out = tmp / "ws.md"
            gh_out = tmp / "gh.txt"
            rc = mgr.main(
                [
                    "--repo-root",
                    str(ROOT),
                    "--check-spec",
                    "--json-out",
                    str(json_out),
                    "--markdown-out",
                    str(md_out),
                    "--github-output",
                    str(gh_out),
                ],
            )
            self.assertEqual(rc, 0)
            self.assertTrue(json.loads(json_out.read_text(encoding="utf-8"))["ok"])
            self.assertIn("workspace_ok=true", gh_out.read_text(encoding="utf-8"))
        self.assertEqual(mgr.main(["--repo-root", str(ROOT), "--self-test"]), 0)


if __name__ == "__main__":
    unittest.main()
