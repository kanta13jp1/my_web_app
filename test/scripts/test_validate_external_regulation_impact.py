#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from validate_external_regulation_impact import (  # noqa: E402
    DEFAULT_VERIFICATION_STATUS,
    MissingCredentialError,
    build_issue_body,
    build_issue_title,
    escalate_high_impact_issue,
    main,
    validate_impact_record,
)


class _FakeResponse:
    def __init__(self, payload: object) -> None:
        self._raw = json.dumps(payload).encode("utf-8")

    def read(self) -> bytes:
        return self._raw

    def __enter__(self) -> "_FakeResponse":
        return self

    def __exit__(self, *_args: object) -> None:
        return None


def _sample_record(**overrides: object) -> dict[str, object]:
    base: dict[str, object] = {
        "jurisdiction_code": "cn",
        "factor_category": "regulation",
        "title": "水産物輸入停止措置の更新確認",
        "affected_product_area": "Cross-border Commerce / Supply Chain",
        "impact_level": "high",
        "source_reference": "https://example.go.jp/official/notice-2026",
        "effective_date": "2026-11-24",
        "summary": "対象地域の規制更新に関する一次情報確認待ち案件。",
        "stakeholders": "@supply-lead, qa-owner",
    }
    base.update(overrides)
    return base


class ValidateExternalRegulationImpactTest(unittest.TestCase):
    def test_defaults_to_pending_fact_check_and_normalizes_jurisdiction(self) -> None:
        result = validate_impact_record(_sample_record())

        self.assertTrue(result.valid)
        self.assertEqual(result.normalized["jurisdiction_code"], "CN")
        self.assertEqual(result.normalized["verification_status"], DEFAULT_VERIFICATION_STATUS)
        self.assertTrue(result.normalized["awaiting_fact_check"])
        self.assertTrue(result.requires_escalation)
        self.assertEqual(result.normalized["stakeholders"], ["supply-lead", "qa-owner"])

    def test_low_and_medium_do_not_require_escalation(self) -> None:
        low_result = validate_impact_record(_sample_record(impact_level="low"))
        medium_result = validate_impact_record(_sample_record(impact_level="medium"))

        self.assertTrue(low_result.valid)
        self.assertFalse(low_result.requires_escalation)
        self.assertTrue(medium_result.valid)
        self.assertFalse(medium_result.requires_escalation)

    def test_rejects_missing_required_fields_and_invalid_dates(self) -> None:
        result = validate_impact_record(
            _sample_record(
                title="   ",
                jurisdiction_code="123-invalid!",
                factor_category="unknown_category",
                affected_product_area="",
                impact_level="extreme",
                source_reference="",
                effective_date="2026-02-30",
            )
        )

        self.assertFalse(result.valid)
        self.assertFalse(result.requires_escalation)
        joined = "\n".join(result.errors)
        self.assertIn("title is required", joined)
        self.assertIn("jurisdiction_code", joined)
        self.assertIn("factor_category", joined)
        self.assertIn("affected_product_area", joined)
        self.assertIn("impact_level", joined)
        self.assertIn("source_reference", joined)
        self.assertIn("effective_date", joined)

    def test_enforces_flag_and_source_consistency_for_status(self) -> None:
        mismatch = validate_impact_record(
            _sample_record(verification_status="pending_fact_check", awaiting_fact_check=False)
        )
        verified_without_url = validate_impact_record(
            _sample_record(
                verification_status="verified",
                awaiting_fact_check=False,
                source_reference="internal-memo-12",
            )
        )

        self.assertFalse(mismatch.valid)
        self.assertIn("awaiting_fact_check must be true", "\n".join(mismatch.errors))
        self.assertFalse(verified_without_url.valid)
        self.assertIn("HTTP(S) primary source URL", "\n".join(verified_without_url.errors))

    def test_high_impact_escalation_fails_closed_when_credential_missing(self) -> None:
        result = validate_impact_record(_sample_record(impact_level="high"))

        with self.assertRaises(MissingCredentialError):
            escalate_high_impact_issue(result, repo="kanta13jp1/my_web_app", auth_credential="")

    def test_cli_returns_nonzero_when_credential_missing_on_create_issue(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            payload_path = Path(tmp_dir) / "impact.json"
            payload_path.write_text(json.dumps(_sample_record()), encoding="utf-8")
            with mock.patch.dict(os.environ, {"GH_TOKEN": "", "GITHUB_TOKEN": ""}, clear=False):
                code = main(
                    [
                        "--input-json",
                        str(payload_path),
                        "--repo",
                        "kanta13jp1/my_web_app",
                        "--create-issue",
                    ]
                )

        self.assertEqual(code, 2)

    def test_escalates_by_creating_issue_and_deduplicating_open_issue(self) -> None:
        result = validate_impact_record(_sample_record(impact_level="critical"))
        title = build_issue_title(result.normalized)
        requests: list[tuple[str, str]] = []

        def fake_opener_create(request: object, timeout: int = 20) -> _FakeResponse:
            _ = timeout
            method = getattr(request, "get_method")()
            full_url = getattr(request, "full_url")
            requests.append((method, full_url))
            if method == "GET":
                return _FakeResponse([{"number": 99, "title": "unrelated", "pull_request": {}}])
            return _FakeResponse(
                {"number": 2600, "html_url": "https://github.com/kanta13jp1/my_web_app/issues/2600"}
            )

        created = escalate_high_impact_issue(
            result,
            repo="kanta13jp1/my_web_app",
            auth_credential="sample-auth-fixture",
            workflow_url="https://github.com/kanta13jp1/my_web_app/actions/runs/1",
            opener=fake_opener_create,
        )
        self.assertEqual(created["action"], "create")
        self.assertEqual(created["issue_number"], 2600)
        self.assertEqual(
            requests,
            [
                ("GET", "https://api.github.com/repos/kanta13jp1/my_web_app/issues?state=open&per_page=100"),
                ("POST", "https://api.github.com/repos/kanta13jp1/my_web_app/issues"),
            ],
        )

        comment_requests: list[tuple[str, str]] = []

        def fake_opener_comment(request: object, timeout: int = 20) -> _FakeResponse:
            _ = timeout
            method = getattr(request, "get_method")()
            full_url = getattr(request, "full_url")
            comment_requests.append((method, full_url))
            if method == "GET":
                return _FakeResponse(
                    [
                        {
                            "number": 2600,
                            "title": title,
                            "html_url": "https://github.com/kanta13jp1/my_web_app/issues/2600",
                        }
                    ]
                )
            return _FakeResponse({"id": 777})

        commented = escalate_high_impact_issue(
            result,
            repo="kanta13jp1/my_web_app",
            auth_credential="sample-auth-fixture",
            workflow_url="https://github.com/kanta13jp1/my_web_app/actions/runs/2",
            opener=fake_opener_comment,
        )
        self.assertEqual(commented["action"], "comment")
        self.assertEqual(commented["issue_number"], 2600)
        self.assertEqual(
            comment_requests,
            [
                ("GET", "https://api.github.com/repos/kanta13jp1/my_web_app/issues?state=open&per_page=100"),
                ("POST", "https://api.github.com/repos/kanta13jp1/my_web_app/issues/2600/comments"),
            ],
        )

        body = build_issue_body(
            result.normalized,
            "https://github.com/kanta13jp1/my_web_app/actions/runs/2",
            mode="comment",
        )
        self.assertIn("事実確認待ち (pending_fact_check)", body)
        self.assertIn("@supply-lead @qa-owner", body)


if __name__ == "__main__":
    unittest.main()
