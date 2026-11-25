#!/usr/bin/env python3
"""Unit and contract tests for secret auto-rotation orchestrator (#2690)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import secret_auto_rotation as rot  # noqa: E402
import validate_supabase_secrets as vs  # noqa: E402


class SecretAutoRotationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.policy = rot.load_policy(ROOT / "config/secret_rotation_policy.json")
        cls.specs = vs.load_manifest(ROOT / "supabase/required_secrets.json")
        cls.rules = rot.build_rule_inventory(
            ROOT / "supabase/required_secrets.json",
            cls.policy,
        )
        cls.now = datetime(2026, 11, 25, 0, 0, tzinfo=timezone.utc)

    def test_policy_covers_all_required_secrets_manifest_entries(self) -> None:
        rule_by_name = {rule.entry_name: rule for rule in self.rules}
        for spec in self.specs:
            self.assertIn(spec.name, rule_by_name)
            rule = rule_by_name[spec.name]
            self.assertGreater(rule.cadence_days, 0)
            self.assertIn(rule.revocation_policy, rot.VALID_REVOCATION_POLICIES)
            self.assertIn(spec.category, self.policy["category_defaults"])

    def test_schedule_evaluation_detects_overdue_expiring_fresh_and_revocation_due(self) -> None:
        snapshots = [
            rot.MetadataSnapshot(
                entry_name="INTERNAL_HMAC_SECRET",
                store="supabase_edge_secrets",
                updated_at=self.now - timedelta(days=61),
            ),
            rot.MetadataSnapshot(
                entry_name="STRIPE_SECRET_KEY",
                store="supabase_edge_secrets",
                updated_at=self.now - timedelta(days=80),
            ),
            rot.MetadataSnapshot(
                entry_name="GROQ_API_KEY",
                store="supabase_edge_secrets",
                updated_at=self.now - timedelta(days=10),
            ),
            rot.MetadataSnapshot(
                entry_name="SUPABASE_SECRET_KEY",
                store="supabase_api_keys",
                updated_at=self.now - timedelta(days=2),
                active_key_id="sb_key_v2",
                previous_key_id="sb_key_v1",
                previous_key_created_at=self.now - timedelta(hours=30),
                previous_key_revoked_at=None,
            ),
        ]
        plans = {
            p.entry_name: p
            for p in rot.evaluate_rotation_schedule(
                self.rules,
                snapshots,
                now=self.now,
                target_names={
                    "INTERNAL_HMAC_SECRET",
                    "STRIPE_SECRET_KEY",
                    "GROQ_API_KEY",
                    "SUPABASE_SECRET_KEY",
                    "SUPABASE_URL",
                },
            )
        }
        self.assertEqual(plans["INTERNAL_HMAC_SECRET"].sla_state, "overdue")
        self.assertEqual(plans["INTERNAL_HMAC_SECRET"].planned_action, "rotate_auto")
        self.assertEqual(plans["STRIPE_SECRET_KEY"].sla_state, "expiring_soon")
        self.assertEqual(plans["STRIPE_SECRET_KEY"].planned_action, "notify_manual_rotation")
        self.assertEqual(plans["GROQ_API_KEY"].sla_state, "fresh")
        self.assertEqual(plans["GROQ_API_KEY"].planned_action, "noop_fresh")
        self.assertEqual(plans["SUPABASE_SECRET_KEY"].revocation_state, "revocation_due")
        self.assertEqual(plans["SUPABASE_SECRET_KEY"].planned_action, "revoke_expired_previous")
        self.assertEqual(plans["SUPABASE_URL"].sla_state, "not_applicable")

    def test_dry_run_default_and_unconfirmed_live_never_mutate(self) -> None:
        calls: list[tuple[str, str]] = []

        def forbid_transport(method: str, url: str, **_kwargs: object) -> dict[str, object]:
            calls.append((method, url))
            return {}

        snapshots = [
            rot.MetadataSnapshot(
                entry_name="INTERNAL_HMAC_SECRET",
                store="supabase_edge_secrets",
                updated_at=self.now - timedelta(days=90),
            ),
        ]
        report = rot.execute_rotation_cycle(
            rules=self.rules,
            snapshots=snapshots,
            policy=self.policy,
            environ={},
            now=self.now,
            live=True,
            confirm_rotate=False,
            target_names={"INTERNAL_HMAC_SECRET"},
            transport=forbid_transport,
        )
        self.assertEqual(report["mode"], "dry_run")
        self.assertEqual(calls, [])
        self.assertEqual(report["summary_counts"]["rotated"], 0)
        self.assertEqual(report["summary_counts"]["overdue"], 1)
        self.assertTrue(report["admin_notification"]["notify_required"])

    def test_live_mode_fails_closed_without_credentials_or_oidc(self) -> None:
        snapshots = [
            rot.MetadataSnapshot(
                entry_name="INTERNAL_HMAC_SECRET",
                store="supabase_edge_secrets",
                updated_at=self.now - timedelta(days=90),
            ),
        ]
        report = rot.execute_rotation_cycle(
            rules=self.rules,
            snapshots=snapshots,
            policy=self.policy,
            environ={},
            now=self.now,
            live=True,
            confirm_rotate=True,
            require_oidc=True,
            target_names={"INTERNAL_HMAC_SECRET"},
        )
        self.assertEqual(report["status"], "blocked_missing_credentials")
        self.assertIn("GITHUB_ACTIONS_OIDC_RUNTIME", report["missing_credentials"])
        self.assertIn("SUPABASE_ACCESS_TOKEN", report["missing_credentials"])
        self.assertEqual(report["admin_notification"]["severity"], "critical")
        self.assertTrue(report["admin_notification"]["notify_required"])

    def test_live_simulation_rotates_via_oidc_updates_stores_and_revokes_previous(self) -> None:
        calls: list[tuple[str, str]] = []
        synthetic_jwt = ".".join(["eyJfakeheader123", "fakepayload456", "fakesig789"])
        synthetic_new_key = "sb_" + "secret_" + "unit_test_new_999"

        def mock_transport(method: str, url: str, **_kwargs: object) -> dict[str, object]:
            calls.append((method, url))
            if "token.actions.githubusercontent.com" in url:
                return {"value": synthetic_jwt}
            if "exchange.supabase.internal" in url or url.startswith("https://api.supabase.com/oidc"):
                return {
                    "SUPABASE_MANAGEMENT_CREDENTIAL": "sbp_" + "exchanged_short_lived_123",
                    "SUPABASE_PROJECT_REF_ID": "projabcd1234",
                }
            if method == "POST" and url.endswith("/api-keys"):
                return {("api" + "_key"): synthetic_new_key}
            return {"ok": True}

        def mock_gh_updater(**kwargs: object) -> dict[str, object]:
            calls.append(("GH_SET", f"{kwargs['entry_name']}:{kwargs['store']}"))
            return {"store": str(kwargs["store"]), "status": "updated"}

        snapshots = [
            rot.MetadataSnapshot(
                entry_name="SUPABASE_SECRET_KEY",
                store="supabase_api_keys",
                updated_at=self.now - timedelta(days=100),
                active_key_id="old_sb_key_42",
            ),
            rot.MetadataSnapshot(
                entry_name="INTERNAL_HMAC_SECRET",
                store="supabase_edge_secrets",
                updated_at=self.now - timedelta(days=2),
                active_key_id="hmac_v2",
                previous_key_id="INTERNAL_HMAC_SECRET_PREVIOUS",
                previous_key_created_at=self.now - timedelta(hours=50),
                previous_key_revoked_at=None,
            ),
        ]
        env = {
            rot.OIDC_URL_ENV: "https://token.actions.githubusercontent.com/id?run=9",
            rot.OIDC_AUTH_ENV: "oidc_req_cred_dummy",
            "OIDC_EXCHANGE_ENDPOINT": "https://api.supabase.com/oidc/exchange",
            "GH_SECRETS_ADMIN_CREDENTIAL": "ghp_" + "admin_dummy_99999999",
            "GITHUB_REPOSITORY_SLUG": "kanta13jp1/my_web_app",
        }
        report = rot.execute_rotation_cycle(
            rules=self.rules,
            snapshots=snapshots,
            policy=self.policy,
            environ=env,
            now=self.now,
            live=True,
            confirm_rotate=True,
            require_oidc=True,
            target_names={"SUPABASE_SECRET_KEY", "INTERNAL_HMAC_SECRET"},
            transport=mock_transport,
            gh_updater=mock_gh_updater,
        )
        self.assertTrue(report["oidc"]["verified_live_exchange"])
        self.assertEqual(report["summary_counts"]["rotated"], 1)
        self.assertEqual(report["summary_counts"]["revoked"], 1)
        self.assertEqual(report["summary_counts"]["pending_revocation"], 1)
        self.assertIn(("DELETE", "https://api.supabase.com/v1/projects/projabcd1234/secrets"), calls)
        self.assertIn(("GH_SET", ":".join(["SUPABASE_SECRET_KEY", "github_actions_env"])), calls)

        serialized = json.dumps(report, ensure_ascii=False)
        self.assertNotIn(synthetic_jwt, serialized)
        self.assertNotIn(synthetic_new_key, serialized)
        self.assertNotIn("exchanged_short_lived_123", serialized)
        self.assertNotIn("admin_dummy_99999999", serialized)

    def test_store_propagation_failure_aborts_revocation_and_masks_errors(self) -> None:
        calls: list[tuple[str, str]] = []
        leaked_style_err = "Bearer " + "leaktest_token_123456"

        def failing_transport(method: str, url: str, **_kwargs: object) -> dict[str, object]:
            calls.append((method, url))
            if method == "POST" and url.endswith("/secrets"):
                raise RuntimeError(f"upstream failed auth={leaked_style_err}")
            return {"ok": True}

        snapshots = [
            rot.MetadataSnapshot(
                entry_name="INTERNAL_HMAC_SECRET",
                store="supabase_edge_secrets",
                updated_at=self.now - timedelta(days=75),
                active_key_id="hmac_v1",
            ),
        ]
        env = {
            "SUPABASE_MANAGEMENT_CREDENTIAL": "sbp_" + "valid_dummy_123456",
            "SUPABASE_PROJECT_REF_ID": "projabcd1234",
            "GH_SECRETS_ADMIN_CREDENTIAL": "ghp_" + "valid_dummy_123456",
            "GITHUB_REPOSITORY_SLUG": "kanta13jp1/my_web_app",
        }
        report = rot.execute_rotation_cycle(
            rules=self.rules,
            snapshots=snapshots,
            policy=self.policy,
            environ=env,
            now=self.now,
            live=True,
            confirm_rotate=True,
            target_names={"INTERNAL_HMAC_SECRET"},
            transport=failing_transport,
        )
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["summary_counts"]["rotated"], 0)
        self.assertEqual(report["summary_counts"]["revoked"], 0)
        self.assertEqual(report["summary_counts"]["failed"], 1)
        self.assertFalse(any(method == "DELETE" for method, _ in calls))
        self.assertEqual(report["execution_records"][0]["status"], "failed_old_key_preserved")
        serialized = json.dumps(report, ensure_ascii=False)
        self.assertNotIn("leaktest_token_123456", serialized)
        self.assertIn("Bearer ***", serialized)

    def test_ssrf_allowlist_blocks_disallowed_hosts_and_plain_http(self) -> None:
        with self.assertRaises(ValueError):
            rot.request_json_pinned_https("GET", "http://api.supabase.com/v1/projects")
        with self.assertRaises(ValueError):
            rot.request_json_pinned_https("GET", "https://127.0.0.1/metadata")

    def test_workflow_contract_security_boundaries(self) -> None:
        wf_path = ROOT / ".github/workflows/secret-auto-rotation.yml"
        wf_text = wf_path.read_text(encoding="utf-8")
        self.assertIn("permissions: {}", wf_text)
        self.assertIn("id-token: write", wf_text)
        self.assertIn("if: github.event_name != 'pull_request'", wf_text)
        self.assertIn("default: true", wf_text)
        self.assertNotIn("secrets.ANTHROPIC_API_KEY", wf_text)
        self.assertNotIn("secrets.SUPABASE_SERVICE_ROLE_KEY", wf_text)
        self.assertNotIn("deploy-prod.yml", wf_text)

    def test_gh_environment_name_propagates_from_env_and_cli_arg(self) -> None:
        recorded_envs: list[str | None] = []

        def fake_transport(method: str, url: str, **kwargs: object) -> dict[str, object]:
            return {"status": "ok"}

        def fake_gh_updater(**kwargs: object) -> dict[str, str]:
            recorded_envs.append(kwargs.get("environment_name") if isinstance(kwargs.get("environment_name"), str) else None)
            return {"store": str(kwargs.get("store", "")), "status": "updated"}

        snapshots = [
            rot.MetadataSnapshot(
                entry_name="INTERNAL_HMAC_SECRET",
                store="supabase_edge_secrets",
                updated_at=self.now - timedelta(days=95),
                active_key_id="hmac_v1",
            ),
        ]
        env = {
            "SUPABASE_MANAGEMENT_CREDENTIAL": "sbp_" + "valid_dummy_123456",
            "SUPABASE_PROJECT_REF_ID": "projabcd1234",
            "GH_SECRETS_ADMIN_CREDENTIAL": "ghp_" + "valid_dummy_123456",
            "GITHUB_REPOSITORY_SLUG": "kanta13jp1/my_web_app",
            "GH_SECRETS_ENVIRONMENT_NAME": "staging-security",
        }
        rot.execute_rotation_cycle(
            rules=self.rules,
            snapshots=snapshots,
            policy=self.policy,
            environ=env,
            now=self.now,
            live=True,
            confirm_rotate=True,
            target_names={"INTERNAL_HMAC_SECRET"},
            transport=fake_transport,
            gh_updater=fake_gh_updater,
        )
        rot.execute_rotation_cycle(
            rules=self.rules,
            snapshots=snapshots,
            policy=self.policy,
            environ=env,
            now=self.now,
            live=True,
            confirm_rotate=True,
            target_names={"INTERNAL_HMAC_SECRET"},
            gh_environment_name="custom-prod-env",
            transport=fake_transport,
            gh_updater=fake_gh_updater,
        )
        self.assertEqual(recorded_envs, ["staging-security", "custom-prod-env"])


if __name__ == "__main__":
    unittest.main()
