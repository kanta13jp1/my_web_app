#!/usr/bin/env python3
from __future__ import annotations

import copy
import unittest

from check_mcp_container_isolation import (
    DEFAULT_CONFIG,
    direct_smoke,
    load_json,
    validate_compose_contract,
    validate_contract,
    validate_dockerfile_contract,
    REPO_ROOT,
)


class McpContainerIsolationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.contract = load_json(DEFAULT_CONFIG)

    def test_repo_contract_validates(self) -> None:
        self.assertEqual(validate_contract(REPO_ROOT, self.contract), [])

    def test_direct_stdio_smoke_exposes_read_only_tool(self) -> None:
        self.assertEqual(direct_smoke(REPO_ROOT, self.contract), [])

    def test_high_risk_permission_requires_matching_approval(self) -> None:
        broken = copy.deepcopy(self.contract)
        for entry in broken["serverExecutionMatrix"]:
            if entry["id"] == "slack-gmail-outbound":
                entry["approvalRequiredFor"] = ["delete"]

        errors = validate_contract(REPO_ROOT, broken)

        self.assertTrue(any("send" in error and "external_share" in error for error in errors), errors)

    def test_low_risk_entry_cannot_request_send_scope(self) -> None:
        broken = copy.deepcopy(self.contract)
        broken["serverExecutionMatrix"][0]["permissions"].append("send")

        errors = validate_contract(REPO_ROOT, broken)

        self.assertTrue(any("low-risk entries" in error for error in errors), errors)

    def test_compose_contract_rejects_host_network_and_ports(self) -> None:
        errors = validate_compose_contract(
            """
            services:
              mcp:
                network_mode: host
                read_only: true
                cap_drop:
                  - ALL
                security_opt:
                  - no-new-privileges:true
                ports:
                  - "8080:8080"
            """
        )

        self.assertTrue(any("host networking" in error for error in errors), errors)
        self.assertTrue(any("published ports" in error for error in errors), errors)

    def test_dockerfile_contract_rejects_root_and_expose(self) -> None:
        errors = validate_dockerfile_contract(
            """
            FROM python:3.12-alpine
            USER root
            EXPOSE 8080
            """
        )

        self.assertTrue(any("root" in error for error in errors), errors)
        self.assertTrue(any("expose" in error.lower() for error in errors), errors)


if __name__ == "__main__":
    unittest.main()
