#!/usr/bin/env python3
"""Unit tests for Team Memory sanitizer, scope boundary isolation, and SQL/TS contracts (#2686)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import team_memory_isolation as tmi  # noqa: E402


class TeamMemoryIsolationTest(unittest.TestCase):
    def test_sql_and_ts_contracts_pass(self) -> None:
        audit = tmi.inspect_isolation_contracts(ROOT)
        self.assertTrue(audit["contracts_ok"], audit["violations"])

    def test_contract_audit_detects_missing_rls_or_revoke(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            for rel in (tmi.MIGRATION_REL, tmi.TS_MODULE_REL):
                dst = tmp / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                text = (ROOT / rel).read_text(encoding="utf-8")
                if rel == tmi.MIGRATION_REL:
                    text = text.replace("enable row level security;", "-- disabled", 1)
                dst.write_text(text, encoding="utf-8", newline="\n")

            audit = tmi.inspect_isolation_contracts(tmp)
            self.assertFalse(audit["contracts_ok"])
            self.assertTrue(any("RLS enabled" in v for v in audit["violations"]))

    def test_sanitizes_tokens_code_blocks_pii_and_post_llm_output(self) -> None:
        sample_ghp = "".join(["ghp", "_SecretTestValue123456"])
        sample_sk = "".join(["sk", "-ModelEchoedKey987654"])
        sample_email = "developer" + "@example.com"
        code_fence = "```sql\nSELECT * FROM users;\n```"

        entry = tmi.prepare_pattern_entry(
            scope_type="org",
            scope_id="org:engineering",
            pattern_type="anti_pattern",
            raw_summary=f"Do not log {sample_ghp} for {sample_email} or store C:\\Users\\alice\\env {code_fence}",
            raw_rule="Never emit raw database queries or tokens into shared prompts.",
            session_id="session-42",
            llm_abstractor=lambda rule: f"{rule} Avoid leaking {sample_sk}!",
        )

        self.assertTrue(entry.is_sanitized)
        self.assertGreater(entry.redaction_count, 0)
        self.assertNotIn("SecretTestValue123456", entry.sanitized_summary)
        self.assertNotIn("ModelEchoedKey987654", entry.abstract_rule)
        self.assertNotIn("example.com", entry.sanitized_summary)
        self.assertNotIn("```", entry.sanitized_summary)
        self.assertIsNone(tmi.detect_residual_sensitive_material(entry.abstract_rule))
        self.assertIsNone(tmi.detect_residual_sensitive_material(entry.sanitized_summary))

    def test_cross_scope_isolation_prevents_leakage(self) -> None:
        store = tmi.IsolationBoundaryStore()
        store.grant_scope("codex-1", "project", "proj:alpha")
        store.grant_scope("claude-1", "project", "proj:alpha")
        store.grant_scope("codex-2", "project", "proj:beta")

        rule_entry = tmi.prepare_pattern_entry(
            scope_type="project",
            scope_id="proj:alpha",
            pattern_type="success_rule",
            raw_summary="Copy constant test seed arrays defensively before adding test items.",
            session_id="sess-alpha",
        )
        store.publish("codex-1", rule_entry)

        # Authorized sibling agent within same project receives abstracted rule
        alpha_rows = store.query("claude-1", "project", "proj:alpha")
        self.assertEqual(len(alpha_rows), 1)
        self.assertEqual(alpha_rows[0].scope_id, "proj:alpha")

        # Unauthorized agent in another scope is strictly blocked
        with self.assertRaises(PermissionError):
            store.query("codex-2", "project", "proj:alpha")
        with self.assertRaises(PermissionError):
            store.publish("codex-2", rule_entry)

        # Unsanitized entry blocked fail-closed
        unsafe_entry = tmi.TeamMemoryEntry(
            scope_type="project",
            scope_id="proj:alpha",
            pattern_type="guardrail",
            abstract_rule="Unsanitized entry check",
            sanitized_summary="Should be rejected without flag",
            redaction_count=0,
            source_session_hash="a" * 32,
            is_sanitized=False,
        )
        with self.assertRaises(PermissionError):
            store.publish("codex-1", unsafe_entry)

    def test_cli_outputs_and_self_test(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            json_out = tmp / "tmi.json"
            md_out = tmp / "tmi.md"
            gh_out = tmp / "gh.txt"
            rc = tmi.main(
                [
                    "--repo-root",
                    str(ROOT),
                    "--check-contracts",
                    "--json-out",
                    str(json_out),
                    "--markdown-out",
                    str(md_out),
                    "--github-output",
                    str(gh_out),
                ],
            )
            self.assertEqual(rc, 0)
            self.assertTrue(json.loads(json_out.read_text(encoding="utf-8"))["contracts_ok"])
            self.assertIn("contracts_ok=true", gh_out.read_text(encoding="utf-8"))
        self.assertEqual(tmi.main(["--repo-root", str(ROOT), "--self-test"]), 0)


if __name__ == "__main__":
    unittest.main()
