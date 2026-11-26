#!/usr/bin/env python3
"""Offline unit tests for scripts/sync_external_search_acls.py (#2655)."""

from __future__ import annotations

import json
from pathlib import Path
import socket
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import sync_external_search_acls as acl_sync  # noqa: E402


class SyncExternalSearchAclsTest(unittest.TestCase):
    def _sample_corpus(self) -> tuple[dict[str, acl_sync.IndexedDocument], list[acl_sync.DocumentAclGrant]]:
        docs = {
            "doc-public-owner": acl_sync.IndexedDocument(
                id="doc-public-owner",
                owner_user_id="owner-1",
                external_source_key="drive://roadmap-2026",
                title="製品ロードマップ 2026",
                content_excerpt="RLS検索とAI統合の優先マイルストーン",
                acl_version=1,
                embedding=(0.9, 0.2, 0.0),
            ),
            "doc-restricted": acl_sync.IndexedDocument(
                id="doc-restricted",
                owner_user_id="owner-2",
                external_source_key="notion://board-confidential",
                title="取締役会非公開資料",
                content_excerpt="未公開 M&A 候補と報酬情報",
                acl_version=1,
                embedding=(0.99, 0.01, 0.0),
            ),
            "doc-revoked": acl_sync.IndexedDocument(
                id="doc-revoked",
                owner_user_id="owner-1",
                external_source_key="drive://former-partner-spec",
                title="旧パートナー契約仕様",
                content_excerpt="失効済みの外部共有メモ",
                acl_version=3,
                embedding=(0.95, 0.1, 0.0),
            ),
        }
        acls = [
            acl_sync.DocumentAclGrant(
                document_id="doc-public-owner",
                grantee_user_id="alice",
                permission_level="viewer",
                granted_by_user_id="owner-1",
            ),
            acl_sync.DocumentAclGrant(
                document_id="doc-revoked",
                grantee_user_id="alice",
                permission_level="viewer",
                granted_by_user_id="owner-1",
                revoked_at="2026-11-24T08:00:00Z",
            ),
        ]
        return docs, acls

    def test_unauthorized_and_revoked_docs_excluded_before_prompt_construction(self) -> None:
        docs, acls = self._sample_corpus()
        bundle = acl_sync.search_and_build_prompt_context(
            docs,
            acls,
            caller_user_id="alice",
            query="ロードマップ",
            query_embedding=(0.99, 0.01, 0.0),
        )
        self.assertEqual([h.document_id for h in bundle.hits], ["doc-public-owner"])
        self.assertEqual(
            set(bundle.excluded_document_ids),
            {"doc-restricted", "doc-revoked"},
        )
        self.assertIn("製品ロードマップ 2026", bundle.prompt_context)
        self.assertNotIn("取締役会非公開資料", bundle.prompt_context)
        self.assertNotIn("未公開 M&A", bundle.prompt_context)
        self.assertNotIn("旧パートナー契約仕様", bundle.prompt_context)

    def test_hmac_signature_verification_rejects_tamper_or_missing_header(self) -> None:
        payload = json.dumps(
            {"external_source_key": "drive://roadmap-2026", "action": "revoke"}
        ).encode("utf-8")
        key_val = "hmac_key_demo_only_for_unit_test"
        valid_sig = acl_sync.compute_webhook_signature(payload, hmac_key=key_val)

        self.assertTrue(
            acl_sync.verify_webhook_signature(payload, valid_sig, hmac_key=key_val)
        )
        self.assertFalse(
            acl_sync.verify_webhook_signature(payload, None, hmac_key=key_val)
        )
        self.assertFalse(
            acl_sync.verify_webhook_signature(
                payload + b" ", valid_sig, hmac_key=key_val
            )
        )
        self.assertFalse(
            acl_sync.verify_webhook_signature(payload, "sha256=deadbeef", hmac_key=key_val)
        )

    def test_immediate_acl_revocation_excludes_previously_visible_document(self) -> None:
        docs, acls = self._sample_corpus()
        before = acl_sync.search_and_build_prompt_context(
            docs,
            acls,
            caller_user_id="alice",
            query="ロードマップ",
            query_embedding=(0.9, 0.2, 0.0),
        )
        self.assertEqual(len(before.hits), 1)

        with self.assertRaises(PermissionError):
            acl_sync.apply_acl_delta(
                docs,
                acls,
                acl_sync.AclDeltaEvent(
                    external_source_key="drive://roadmap-2026",
                    grantee_user_id="alice",
                    action="revoke",
                ),
                actor_user_id="intruder",
            )

        docs2, acls2, bumped = acl_sync.apply_acl_delta(
            docs,
            acls,
            acl_sync.AclDeltaEvent(
                external_source_key="drive://roadmap-2026",
                grantee_user_id="alice",
                action="revoke",
            ),
            actor_user_id="owner-1",
            is_trusted_sync=False,
        )
        self.assertEqual(bumped.acl_version, 2)

        after = acl_sync.search_and_build_prompt_context(
            docs2,
            acls2,
            caller_user_id="alice",
            query="ロードマップ",
            query_embedding=(0.9, 0.2, 0.0),
        )
        self.assertEqual(len(after.hits), 0)
        self.assertNotIn("製品ロードマップ 2026", after.prompt_context)

    def test_owner_and_active_editor_both_authorized(self) -> None:
        docs, acls = self._sample_corpus()
        docs2, acls2, _ = acl_sync.apply_acl_delta(
            docs,
            acls,
            acl_sync.AclDeltaEvent(
                external_source_key="notion://board-confidential",
                grantee_user_id="alice",
                action="grant",
                permission_level="editor",
            ),
            actor_user_id="sync-service",
            is_trusted_sync=True,
        )
        owner_bundle = acl_sync.search_and_build_prompt_context(
            docs2,
            acls2,
            caller_user_id="owner-2",
            query="非公開",
        )
        alice_bundle = acl_sync.search_and_build_prompt_context(
            docs2,
            acls2,
            caller_user_id="alice",
            query="非公開",
        )
        self.assertEqual(owner_bundle.hits[0].permission_source, "owner")
        self.assertEqual(alice_bundle.hits[0].permission_source, "editor")

    def test_pinned_https_connection_rejects_ssrf_and_handles_errors_safely(self) -> None:
        cleaned = acl_sync._sanitize_url_for_log(
            "https://example.supabase.co/rest/v1/rls_ai_documents?select=id&auth=abc#sec"
        )
        self.assertEqual(cleaned, "https://example.supabase.co/rest/v1/rls_ai_documents")

        with self.assertRaises(ValueError):
            acl_sync.validate_and_resolve_https_url("http://example.supabase.co/rest/v1")
        with patch(
            "socket.getaddrinfo",
            return_value=[(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("127.0.0.1", 443))],
        ):
            with self.assertRaises(ValueError):
                acl_sync.validate_and_resolve_https_url("https://rebind.example.com/rest/v1")

        fake_conn = MagicMock()
        redirect_resp = MagicMock(status=302)
        redirect_resp.read.return_value = b"Found"
        fake_conn.getresponse.return_value = redirect_resp
        with (
            patch(
                "socket.getaddrinfo",
                return_value=[(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))],
            ),
            patch.object(acl_sync, "_PinnedHTTPSConnection", return_value=fake_conn) as pinned_cls,
        ):
            with self.assertRaises(RuntimeError) as redir_ctx:
                acl_sync._http_json(
                    "https://example.supabase.co/rest/v1/rls_ai_documents?sig=xyz",
                    method="POST",
                    headers={"Content-Type": "application/json"},
                    payload={"query": "x"},
                )
        self.assertIn("Redirect blocked (HTTP 302)", str(redir_ctx.exception))
        self.assertNotIn("sig=xyz", str(redir_ctx.exception))
        self.assertEqual(pinned_cls.call_args.kwargs["pinned_ip"], "93.184.216.34")
        self.assertEqual(pinned_cls.call_args.kwargs["tls_hostname"], "example.supabase.co")

        err_resp = MagicMock(status=403)
        err_resp.read.return_value = b"permission denied"
        fake_conn.getresponse.return_value = err_resp
        with (
            patch(
                "socket.getaddrinfo",
                return_value=[(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))],
            ),
            patch.object(acl_sync, "_PinnedHTTPSConnection", return_value=fake_conn),
        ):
            with self.assertRaises(RuntimeError) as ctx:
                acl_sync._http_json(
                    "https://example.supabase.co/rest/v1/rls_ai_documents?sig=xyz",
                    method="POST",
                    headers={"Content-Type": "application/json"},
                    payload={"query": "x"},
                )
        self.assertIn("HTTP 403", str(ctx.exception))
        self.assertNotIn("sig=xyz", str(ctx.exception))

    def test_cli_self_test_and_fail_closed_signature_gate(self) -> None:
        self.assertEqual(acl_sync.main(["--self-test"]), 0)
        with tempfile.TemporaryDirectory() as tmpdir:
            delta_path = Path(tmpdir) / "delta.json"
            delta_path.write_text('{"action":"revoke"}', encoding="utf-8")
            with patch.dict("os.environ", {"EXTERNAL_ACL_WEBHOOK_HMAC": "unit_test_hmac_val"}):
                rc_bad = acl_sync.main(
                    ["--delta-json", str(delta_path), "--sig-header", "sha256=bad"]
                )
                self.assertEqual(rc_bad, 2)


if __name__ == "__main__":
    unittest.main()
