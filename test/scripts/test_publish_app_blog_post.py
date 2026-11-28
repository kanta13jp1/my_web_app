from __future__ import annotations

import base64
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import publish_app_blog_post as app_pub  # noqa: E402


SAMPLE_MARKDOWN = """# 固定費とサブスクの見直しを月1回15分で終わらせる棚卸しチェックリスト

気づかないうちに口座から引き落とされている月額サブスクや固定費は、毎月の家計管理で最も見落とされやすい出費です。1回ごとの金額が小さくても、1年単位で見ると数万円の差になって残ります。

とはいえ、すべての支出を毎週のように見直すのは続きません。固定費の棚卸しは月に1回、15分だけ時間を決めて同じ順番で確認するだけで十分に回ります。

## 1. まず「固定費・サブスク」と「変動費」を分ける（3分）

食費や日用品の細かな節約より先に、毎月決まって発生する支出だけを1か所へ一覧化します。ここを混ぜると、何が止められる出費なのか判断しにくくなります。

## 2. 「金額」ではなく「今月使った回数」で仕分ける（6分）

一覧ができたら、各項目について「直近30日で何回使ったか」だけを確認します。
"""

FRONTMATTER_MARKDOWN = """---
title: "Frontmatter Title Example"
tags: [Flutter, Supabase, "AI体験"]
description: "Frontmatter custom preview summary."
---

# Ignored Duplicate H1

本文は最低200文字以上のチェックを通過するためのダミーテキストです。家計管理と固定費の見直しを月1回15分で行うための具体的な手順を解説しています。日々の収支整理を自動化して判断疲れを減らしましょう。テスト用の十分な長さの本文をここに記載して文字数検証を確実に通過させます。さらに追加の段落を足して十分な文字数にします。月末の口座残高の確認と翌月予算の設計もあわせて行うことで、引き落とし予定日の抜け漏れを防ぎ、安心感のある生活基盤を作ることができます。
"""


class FakeTransport:
    """In-memory PostgREST simulator for deterministic unit tests."""

    def __init__(self, initial_rows: list[dict] | None = None) -> None:
        self.rows: list[dict] = [dict(r) for r in (initial_rows or [])]
        self.calls: list[tuple[str, str, dict | None]] = []
        self.counter = 0

    def __call__(
        self,
        method: str,
        url: str,
        headers: dict[str, str],
        payload: bytes | None,
    ) -> tuple[int, str]:
        del headers
        body = json.loads(payload.decode("utf-8")) if payload else None
        self.calls.append((method, url, body))
        if method == "GET":
            if "draft_path=eq." in url:
                slug_encoded = url.split("draft_path=eq.", 1)[1].split("&", 1)[0]
                import urllib.parse

                slug = urllib.parse.unquote(slug_encoded)
                matched = [r for r in self.rows if r.get("draft_path") == slug]
                return 200, json.dumps(matched)
            if "status=eq.posted" in url:
                matched = [r for r in self.rows if r.get("status") == "posted"]
                return 200, json.dumps(matched)
            return 200, json.dumps(self.rows)
        if method == "POST":
            self.counter += 1
            new_row = {
                "id": f"00000000-0000-4000-8000-{self.counter:012d}",
                **(body or {}),
            }
            self.rows.append(new_row)
            return 201, json.dumps([new_row])
        if method == "PATCH":
            id_encoded = url.split("id=eq.", 1)[1].split("&", 1)[0]
            updated = []
            for row in self.rows:
                if row.get("id") == id_encoded:
                    row.update(body or {})
                    updated.append(row)
            return 200, json.dumps(updated)
        return 405, "{}"


class PublishAppBlogPostTest(unittest.TestCase):
    def test_parse_h1_strips_leading_heading_and_builds_preview(self) -> None:
        parsed = app_pub.parse_markdown_article(SAMPLE_MARKDOWN)
        self.assertEqual(
            parsed["title"],
            "固定費とサブスクの見直しを月1回15分で終わらせる棚卸しチェックリスト",
        )
        self.assertTrue(parsed["content"].startswith("気づかないうちに口座から引き落とされている"))
        self.assertNotIn("# 固定費とサブスクの見直し", parsed["content"])
        self.assertTrue(parsed["content_preview"].startswith("気づかないうちに口座から"))
        self.assertLessEqual(len(parsed["content_preview"]), 160)
        self.assertEqual(parsed["tags"], ["自分株式会社", "AI体験"])

    def test_parse_frontmatter_and_overrides(self) -> None:
        parsed = app_pub.parse_markdown_article(
            FRONTMATTER_MARKDOWN,
            title_override="Override Title",
            tags_override="固定費, サブスク, 固定費",
        )
        self.assertEqual(parsed["title"], "Override Title")
        self.assertEqual(parsed["tags"], ["固定費", "サブスク"])
        self.assertEqual(parsed["content_preview"], "Frontmatter custom preview summary.")
        self.assertNotIn("Ignored Duplicate H1", parsed["content"])
        self.assertNotIn("Frontmatter Title Example", parsed["content"])

    def test_decode_content_b64_fail_closed_cases(self) -> None:
        raw_b64 = base64.b64encode(SAMPLE_MARKDOWN.encode("utf-8")).decode("ascii")
        self.assertIn("固定費とサブスク", app_pub.decode_content_b64(raw_b64))

        with self.assertRaises(ValueError):
            app_pub.decode_content_b64("not-valid-base64!!!")
        with self.assertRaises(ValueError):
            app_pub.decode_content_b64(base64.b64encode(b"\xff\xfe\xfd").decode("ascii"))
        oversized = base64.b64encode(b"a" * (app_pub.MAX_DECODED_BYTES + 1)).decode("ascii")
        with self.assertRaises(ValueError):
            app_pub.decode_content_b64(oversized)

    def test_load_draft_markdown_rejects_traversal_and_missing_sources(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaises(ValueError):
                app_pub.load_draft_markdown(repo_root=root)
            with self.assertRaises(ValueError):
                app_pub.load_draft_markdown(draft_path="../secret.md", repo_root=root)
            with self.assertRaises(ValueError):
                app_pub.load_draft_markdown(draft_path="missing.md", repo_root=root)

    def test_dedup_matches_existing_posted_app_by_title_with_null_draft_path(self) -> None:
        existing = [
            {
                "id": "78c8f0ee-03d1-49b5-9f17-177265668962",
                "title": "固定費とサブスクの見直しを月1回15分で終わらせる棚卸しチェックリスト",
                "draft_path": None,
                "status": "posted",
                "target_platforms": ["app"],
                "url": None,
            }
        ]
        transport = FakeTransport(existing)
        client = app_pub.SupabaseRestClient(
            supabase_url="https://example.supabase.co",
            credential="test-cred",
            transport=transport,
        )
        res = app_pub.publish_app_blog(
            client=client,
            raw_markdown=SAMPLE_MARKDOWN,
            slug_override="blog-20261128-fixed-cost-audit",
            dry_run=False,
        )
        self.assertEqual(res["dedup_action"], "duplicate_title_posted")
        self.assertEqual(res["post_id"], "78c8f0ee-03d1-49b5-9f17-177265668962")
        self.assertEqual(
            res["app_url"],
            "https://my-web-app-b67f4.web.app/blog/post?id=78c8f0ee-03d1-49b5-9f17-177265668962",
        )
        self.assertTrue(all(m == "GET" for m, _, _ in transport.calls))

    def test_dedup_does_not_block_devto_only_post_with_same_title(self) -> None:
        existing = [
            {
                "id": "e1ed4fe1-a5b2-4e6f-8470-5bb00b3d9c16",
                "title": "固定費とサブスクの見直しを月1回15分で終わらせる棚卸しチェックリスト",
                "draft_path": "docs/blog-drafts/2026-07-12.md",
                "status": "posted",
                "target_platforms": ["devto"],
                "url": None,
            }
        ]
        transport = FakeTransport(existing)
        client = app_pub.SupabaseRestClient(
            supabase_url="https://example.supabase.co",
            credential="test-cred",
            transport=transport,
        )
        res = app_pub.publish_app_blog(
            client=client,
            raw_markdown=SAMPLE_MARKDOWN,
            slug_override="blog-20261128-fixed-cost-audit",
            tags_override="固定費,サブスク",
            notes="idempotency_key=blog-20261128-fixed-cost-audit",
            dry_run=False,
            now_iso="2026-11-28T01:00:00Z",
        )
        self.assertEqual(res["dedup_action"], "created")
        self.assertEqual(res["slug_key"], "app:blog-20261128-fixed-cost-audit")
        post_calls = [body for m, _, body in transport.calls if m == "POST"]
        self.assertEqual(len(post_calls), 1)
        self.assertEqual(post_calls[0]["target_platforms"], ["app"])
        self.assertEqual(post_calls[0]["status"], "posted")
        self.assertIsNone(post_calls[0]["url"])

    def test_dedup_blocks_duplicate_slug_even_with_different_title(self) -> None:
        existing = [
            {
                "id": "11111111-1111-4111-8111-111111111111",
                "title": "以前投稿した別タイトルの記事",
                "draft_path": "app:blog-20261129-ai-daily-routine",
                "status": "posted",
                "target_platforms": ["app"],
                "url": None,
            }
        ]
        transport = FakeTransport(existing)
        client = app_pub.SupabaseRestClient(
            supabase_url="https://example.supabase.co",
            credential="test-cred",
            transport=transport,
        )
        res = app_pub.publish_app_blog(
            client=client,
            raw_markdown=SAMPLE_MARKDOWN,
            slug_override="blog-20261129-ai-daily-routine",
            dry_run=False,
        )
        self.assertEqual(res["dedup_action"], "duplicate_slug_posted")
        self.assertEqual(res["post_id"], "11111111-1111-4111-8111-111111111111")
        self.assertTrue(all(m == "GET" for m, _, _ in transport.calls))

    def test_promotes_existing_draft_row_via_patch(self) -> None:
        existing = [
            {
                "id": "22222222-2222-4222-8222-222222222222",
                "title": "下書きタイトル",
                "draft_path": "app:blog-20261129-ai-daily-routine",
                "status": "draft",
                "target_platforms": ["app"],
                "url": None,
            }
        ]
        transport = FakeTransport(existing)
        client = app_pub.SupabaseRestClient(
            supabase_url="https://example.supabase.co",
            credential="test-cred",
            transport=transport,
        )
        res = app_pub.publish_app_blog(
            client=client,
            raw_markdown=SAMPLE_MARKDOWN,
            slug_override="blog-20261129-ai-daily-routine",
            dry_run=False,
        )
        self.assertEqual(res["dedup_action"], "promoted_existing_draft")
        self.assertEqual(res["post_id"], "22222222-2222-4222-8222-222222222222")
        self.assertTrue(any(m == "PATCH" for m, _, _ in transport.calls))

    def test_dry_run_performs_zero_writes(self) -> None:
        transport = FakeTransport([])
        client = app_pub.SupabaseRestClient(
            supabase_url="https://example.supabase.co",
            credential="test-cred",
            transport=transport,
        )
        res = app_pub.publish_app_blog(
            client=client,
            raw_markdown=SAMPLE_MARKDOWN,
            slug_override="blog-20261129-ai-daily-routine",
            dry_run=True,
        )
        self.assertEqual(res["dedup_action"], "dry_run_would_create")
        self.assertEqual(res["post_id"], "dry-run-id")
        self.assertTrue(all(m == "GET" for m, _, _ in transport.calls))

    def test_blog_publish_workflow_contract(self) -> None:
        wf_path = ROOT / ".github" / "workflows" / "blog-publish.yml"
        if not wf_path.is_file():
            self.skipTest("workflow file not present")
        wf_text = wf_path.read_text(encoding="utf-8")
        for input_name in (
            "app_title:",
            "app_slug:",
            "app_content_b64:",
            "app_tags:",
            "app_notes:",
        ):
            self.assertIn(input_name, wf_text)
        self.assertIn("scripts/publish_app_blog_post.py", wf_text)
        self.assertIn("has_app_target", wf_text)
        self.assertIn("has_external_target", wf_text)


if __name__ == "__main__":
    unittest.main()
