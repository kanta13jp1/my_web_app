#!/usr/bin/env python3
from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

from check_managed_mcp_policy import (
    DEFAULT_CONFIG,
    load_policy,
    session_findings,
    validate_policy,
)


class ManagedMcpPolicyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.policy = load_policy(DEFAULT_CONFIG)

    def test_default_policy_is_valid(self) -> None:
        errors = validate_policy(self.policy)
        self.assertEqual(errors, [])

    def test_required_integrations_are_enforced(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["allowedMcpServers"] = [
            entry for entry in policy["allowedMcpServers"] if entry["id"] != "github"
        ]

        errors = validate_policy(policy)

        self.assertTrue(any("github" in error for error in errors), errors)

    def test_unmanaged_server_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            settings = Path(tmp) / "settings.json"
            settings.write_text(
                json.dumps({"mcpServers": {"random-ai": {"command": "random-ai"}}}),
                encoding="utf-8",
            )

            findings = session_findings(self.policy, [settings])

        self.assertTrue(any(f.kind == "unmanaged_server" for f in findings), findings)

    def test_denied_server_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            settings = Path(tmp) / "settings.json"
            settings.write_text(
                json.dumps({"enabledPlugins": {"caveman@caveman": True}}),
                encoding="utf-8",
            )

            findings = session_findings(self.policy, [settings])

        self.assertTrue(any(f.kind == "denied_server_active" for f in findings), findings)

    def test_auth_cache_maps_to_session_warning(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp) / "mcp-needs-auth-cache.json"
            cache.write_text(
                json.dumps({"claude.ai Google Drive": {"timestamp": 1778049805068}}),
                encoding="utf-8",
            )

            findings = session_findings(self.policy, [cache])

        self.assertTrue(any(f.kind == "auth_required" for f in findings), findings)

    def test_codex_toml_plugins_are_mapped(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "config.toml"
            config.write_text(
                '\n'.join(
                    [
                        '[mcp_servers.notion]',
                        'url = "https://mcp.notion.com/mcp"',
                        '[plugins."github@openai-curated"]',
                        'enabled = true',
                        '[plugins."slack@openai-curated"]',
                        'enabled = true',
                    ]
                ),
                encoding="utf-8",
            )

            findings = session_findings(self.policy, [config])

        unmanaged = [finding for finding in findings if finding.kind == "unmanaged_server"]
        self.assertEqual(unmanaged, [])

    def test_dangerous_permission_is_reported_without_secret_values(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            settings = Path(tmp) / "settings.json"
            settings.write_text(
                json.dumps(
                    {
                        "permissions": {
                            "defaultMode": "bypassPermissions",
                            "allow": ["Bash(printenv SUPABASE_SERVICE_ROLE_KEY)"],
                        },
                    }
                ),
                encoding="utf-8",
            )

            findings = session_findings(self.policy, [settings])

        danger = [finding for finding in findings if finding.kind == "dangerous_permission"]
        self.assertTrue(danger, findings)
        self.assertFalse(any("gho_" in finding.message for finding in danger))


if __name__ == "__main__":
    unittest.main()
