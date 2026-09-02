#!/usr/bin/env python3
"""Build the approval-gated X candidate for the first-user campaign."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


CANDIDATE_KEY = "first-user-launch/outcome-first-hook-b/v2"
CANDIDATE_TYPE = "first_user_launch"
SOURCE_KIND = "x-first-user-launch-candidate.yml"
VARIANT = "outcome_first_b_failure_numbers_hook"
PROMPT_PROFILE = "first_user_failure_numbers_hook_v2"
MEDIA_URL = (
    "https://my-web-app-b67f4.web.app/"
    "lp-og-first-action-20260720.png"
)
TARGET_URL = (
    "https://my-web-app-b67f4.web.app/"
    "?lp_intent=trial"
    "&src=x_share"
    "&utm_source=x"
    "&utm_medium=organic"
    "&utm_campaign=first_user_growth"
    "&utm_content=outcome_first_a"
)
CONTROL_HOOK = """仕事・学習・お金の情報が散らかって、
「結局、今日なにをやる？」で止まる人へ。
"""
HOOK = """フォロワー3,698人のXで個人開発を告知。
24時間後、13表示・クリック0でした。

作っただけでは、誰にも届かない。"""
FIXED_PARENT_BODY = """悩みを1行入れると、AIが
・今日やる1件
・その理由
・最初の10分行動
まで返す「自分株式会社」を作りました。

登録前に30秒で試せます。カード不要です。
使って迷ったところを1つ教えてください。

#個人開発 #AI活用"""
CONTROL_PARENT_TEXT = f"{CONTROL_HOOK.strip()}\n\n{FIXED_PARENT_BODY}"
PARENT_TEXT = f"{HOOK}\n\n{FIXED_PARENT_BODY}"
REPLY_TEXT = f"無料で30秒試す:\n{TARGET_URL}"
MEDIA_ALT = (
    "自分株式会社のランディングページ。悩みを1行入力すると、"
    "AIが今日やる1件と最初の10分行動を提案する画面。"
)


def parse_bool(value: str) -> bool:
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    raise argparse.ArgumentTypeError(f"expected boolean, got: {value}")


def build_candidate_request(
    *,
    dry_run: bool,
    actor: str = "",
    run_id: str = "",
    run_attempt: str = "",
    ref: str = "",
    sha: str = "",
) -> dict[str, Any]:
    """Return the exact payload reviewed before any public X action."""
    return {
        "action": "x.candidate.create",
        "candidateKey": CANDIDATE_KEY,
        "candidateType": CANDIDATE_TYPE,
        "sourceKind": SOURCE_KIND,
        "sourceUrls": [MEDIA_URL, TARGET_URL],
        "createdBy": f"github-actions:{SOURCE_KIND}",
        "postPayload": {
            "action": "x.post",
            "text": PARENT_TEXT,
            "replyTexts": [REPLY_TEXT],
            "mediaUrl": MEDIA_URL,
            "mediaType": "image/png",
            "mediaAlt": MEDIA_ALT,
            "source": SOURCE_KIND,
            "route": "/",
            "experimentKey": "x_first_user_growth_10k",
            "variant": VARIANT,
            "utmContent": "outcome_first_a",
            "promptProfile": PROMPT_PROFILE,
            "fallbackUsed": False,
            "contentKind": CANDIDATE_TYPE,
            "contentArchetype": "build_in_public_learning",
            "linkInReply": True,
        },
        "context": {
            "workflow": SOURCE_KIND,
            "workflow_run_id": run_id,
            "workflow_run_attempt": run_attempt,
            "event": "workflow_dispatch",
            "actor": actor,
            "ref": ref,
            "sha": sha,
            "selected_variant": VARIANT,
            "target_url": TARGET_URL,
        },
        "dryRun": dry_run,
    }


def validate_candidate_request(payload: dict[str, Any]) -> None:
    """Fail closed when campaign safety or attribution invariants drift."""
    if payload.get("action") != "x.candidate.create":
        raise ValueError("candidate action must be x.candidate.create")
    if payload.get("candidateKey") != CANDIDATE_KEY:
        raise ValueError("candidate key must remain stable")
    if payload.get("candidateType") != CANDIDATE_TYPE:
        raise ValueError("unexpected candidate type")
    if payload.get("sourceKind") != SOURCE_KIND:
        raise ValueError("unexpected source kind")

    post = payload.get("postPayload")
    if not isinstance(post, dict) or post.get("action") != "x.post":
        raise ValueError("post payload must use x.post")
    text = str(post.get("text", ""))
    if "http://" in text or "https://" in text:
        raise ValueError("the parent post must not contain a URL")
    if not text or len(text) > 280:
        raise ValueError("the parent post must fit the standard X limit")
    if post.get("mediaUrl") != MEDIA_URL or post.get("mediaType") != "image/png":
        raise ValueError("the reviewed PNG must be attached to the parent post")
    if post.get("linkInReply") is not True:
        raise ValueError("campaign link must be placed in a reply")

    replies = post.get("replyTexts")
    if not isinstance(replies, list) or len(replies) != 1:
        raise ValueError("exactly one campaign reply is required")
    reply = str(replies[0])
    if TARGET_URL not in reply:
        raise ValueError("the reviewed campaign URL is missing from the reply")

    parsed = urlparse(TARGET_URL)
    query = parse_qs(parsed.query)
    required_query = {
        "lp_intent": ["trial"],
        "utm_source": ["x"],
        "utm_medium": ["organic"],
        "utm_campaign": ["first_user_growth"],
        "utm_content": ["outcome_first_a"],
    }
    for key, expected in required_query.items():
        if query.get(key) != expected:
            raise ValueError(f"campaign URL has invalid {key}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", type=parse_bool, default=True)
    parser.add_argument("--actor", default="")
    parser.add_argument("--run-id", default="")
    parser.add_argument("--run-attempt", default="")
    parser.add_argument("--ref", default="")
    parser.add_argument("--sha", default="")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    payload = build_candidate_request(
        dry_run=args.dry_run,
        actor=args.actor,
        run_id=args.run_id,
        run_attempt=args.run_attempt,
        ref=args.ref,
        sha=args.sha,
    )
    validate_candidate_request(payload)
    rendered = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
