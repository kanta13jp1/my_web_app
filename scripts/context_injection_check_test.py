#!/usr/bin/env python3
from __future__ import annotations

import copy
import unittest
from pathlib import Path

from context_injection_check import (
    build_session_snapshot,
    load_config,
    matched_routes,
    notebooklm_intake_summary,
    repo_root,
    validate_config,
)


class ContextInjectionCheckTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = repo_root()
        self.config = load_config(self.root)

    def test_repo_config_validates(self) -> None:
        failures = validate_config(self.root, self.config)

        self.assertEqual(failures, [])

    def test_ai_tool_prompt_routes_to_issue_1644(self) -> None:
        routes = matched_routes(
            self.config,
            "Before hook and NotebookLM skill activation, check Codex memory.",
        )

        self.assertGreaterEqual(len(routes), 1)
        self.assertEqual(routes[0]["id"], "ai-tool-adoption")
        self.assertIn(1644, routes[0]["connectToIssues"])

    def test_mcp_prompt_routes_to_mcp_boundary(self) -> None:
        routes = matched_routes(
            self.config,
            "Dynamic MCP external tool permission and Docker MCP isolation",
        )

        self.assertGreaterEqual(len(routes), 1)
        self.assertEqual(routes[0]["id"], "mcp-tool-boundary")
        self.assertIn(1645, routes[0]["connectToIssues"])

    def test_notebooklm_intake_summary_exposes_harness_and_candidates(self) -> None:
        summary = notebooklm_intake_summary(self.root)

        self.assertEqual(summary["harness_notebook_id"], "bc58b50b-5fc4-4840-9a62-b397d6d3b65a")
        self.assertTrue(summary["harness_found"])
        self.assertGreaterEqual(summary["notebook_count"], 1)
        self.assertIn("candidate_issue_drafts", summary)

    def test_missing_doc_path_is_reported(self) -> None:
        broken = copy.deepcopy(self.config)
        broken["routes"][0]["docs"].append("docs/DOES_NOT_EXIST_FOR_1644.md")

        failures = validate_config(self.root, broken)

        self.assertTrue(any("DOES_NOT_EXIST_FOR_1644" in item for item in failures))

    def test_session_snapshot_has_default_routes_and_proposal_policy(self) -> None:
        snapshot = build_session_snapshot(self.root)

        route_ids = [route["id"] for route in snapshot["matchedRoutes"]]
        self.assertIn("ai-tool-adoption", route_ids)
        self.assertIn("wbs-priority-routing", route_ids)
        self.assertTrue(snapshot["proposalPolicy"]["forbidRawNotebooklmDump"])


if __name__ == "__main__":
    unittest.main()
