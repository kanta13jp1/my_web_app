#!/usr/bin/env python3
"""Independent GitHub PR review quota guard and async usage tracker (#2700).

Enforces an isolated daily quota bucket for GitHub pull-request code reviews
separate from general IDE/CLI prompt quotas. When the PR review daily limit is
reached, the PR is skipped cleanly (exit code 0) with a structured audit record.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import os
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_CONSUMER_DAILY_LIMIT = 33
DEFAULT_ENTERPRISE_DAILY_LIMIT = 100


def default_limit_for_tier(plan_tier: str) -> int:
    """Return isolated daily PR review limit for the given plan tier."""
    return (
        DEFAULT_ENTERPRISE_DAILY_LIMIT
        if plan_tier.strip().lower() == "enterprise"
        else DEFAULT_CONSUMER_DAILY_LIMIT
    )


def estimate_pr_model_calls(changed_files: int, diff_lines: int) -> int:
    """Estimate async model calls required for a PR based on diff size."""
    files = max(1, int(changed_files))
    lines = max(1, int(diff_lines))
    chunk_calls = math.ceil(lines / 250)
    file_calls = math.ceil(files / 8)
    return max(1, min(20, max(chunk_calls, file_calls)))


def _today_utc(now_utc: dt.datetime | None = None) -> str:
    current = now_utc or dt.datetime.now(dt.timezone.utc)
    return current.date().isoformat()


def _load_state(state_path: Path | None) -> dict[str, Any]:
    if state_path is None or not state_path.exists():
        return {"buckets": {}, "events": []}
    raw = json.loads(state_path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        return {"buckets": {}, "events": []}
    buckets = raw.get("buckets")
    events = raw.get("events")
    return {
        "buckets": buckets if isinstance(buckets, dict) else {},
        "events": events if isinstance(events, list) else [],
    }


def _save_state(state_path: Path | None, state: dict[str, Any]) -> None:
    if state_path is None:
        return
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(
        json.dumps(state, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def evaluate_pr_review_quota(
    *,
    repository: str,
    pr_number: int,
    installation_key: str,
    plan_tier: str = "consumer",
    daily_limit: int | None = None,
    changed_files: int = 1,
    diff_lines: int = 50,
    head_sha: str = "",
    dry_run: bool = False,
    state_path: Path | None = None,
    now_utc: dt.datetime | None = None,
) -> dict[str, Any]:
    """Evaluate PR review quota and either allow execution or skip cleanly."""
    clean_repo = repository.strip()
    clean_install = installation_key.strip() or f"repo-{clean_repo}"
    if not clean_repo or pr_number <= 0:
        raise ValueError("repository and positive pr_number are required")

    tier = "enterprise" if plan_tier.strip().lower() == "enterprise" else "consumer"
    limit = daily_limit if daily_limit and daily_limit > 0 else default_limit_for_tier(tier)
    quota_date = _today_utc(now_utc)
    bucket_key = f"{clean_install}::{quota_date}"
    est_calls = estimate_pr_model_calls(changed_files, diff_lines)

    state = _load_state(state_path)
    buckets: dict[str, Any] = state["buckets"]
    bucket = buckets.get(
        bucket_key,
        {
            "installation_key": clean_install,
            "quota_date": quota_date,
            "plan_tier": tier,
            "pr_review_daily_limit": limit,
            "pr_reviews_used": 0,
            "pr_reviews_skipped": 0,
            "pr_review_model_calls_used": 0,
            "isolated_from_general_quota": True,
        },
    )
    bucket["pr_review_daily_limit"] = limit
    used = int(bucket.get("pr_reviews_used", 0))
    skipped_count = int(bucket.get("pr_reviews_skipped", 0))
    model_calls_used = int(bucket.get("pr_review_model_calls_used", 0))

    if dry_run:
        will_skip = used >= limit
        decision = {
            "ok": True,
            "dry_run": True,
            "allowed": not will_skip,
            "skipped": will_skip,
            "review_executed": False,
            "status": "dry_run",
            "repository": clean_repo,
            "pr_number": pr_number,
            "head_sha": head_sha,
            "installation_key": clean_install,
            "quota_date": quota_date,
            "plan_tier": tier,
            "pr_reviews_used": used,
            "pr_review_daily_limit": limit,
            "remaining": max(0, limit - used),
            "pr_reviews_skipped": skipped_count,
            "estimated_model_calls": est_calls,
            "pr_review_model_calls_used": model_calls_used,
            "isolated_from_general_quota": True,
        }
        state["events"].append(
            {
                "outcome": "dry_run",
                "repository": clean_repo,
                "pr_number": pr_number,
                "quota_date": quota_date,
                "estimated_model_calls": est_calls,
            }
        )
        buckets[bucket_key] = bucket
        _save_state(state_path, state)
        return decision

    if used + 1 > limit:
        skipped_count += 1
        bucket["pr_reviews_skipped"] = skipped_count
        skip_reason = (
            f"PR review quota reached ({used}/{limit} on {quota_date}); "
            "skipped cleanly without error."
        )
        audit_entry = {
            "outcome": "skipped_quota_exceeded",
            "repository": clean_repo,
            "pr_number": pr_number,
            "head_sha": head_sha,
            "installation_key": clean_install,
            "quota_date": quota_date,
            "skip_reason": skip_reason,
            "estimated_model_calls": est_calls,
            "isolated_from_general_quota": True,
        }
        state["events"].append(audit_entry)
        buckets[bucket_key] = bucket
        _save_state(state_path, state)
        return {
            "ok": True,
            "dry_run": False,
            "allowed": False,
            "skipped": True,
            "review_executed": False,
            "status": "skipped_quota_exceeded",
            "skip_reason": skip_reason,
            "repository": clean_repo,
            "pr_number": pr_number,
            "head_sha": head_sha,
            "installation_key": clean_install,
            "quota_date": quota_date,
            "plan_tier": tier,
            "pr_reviews_used": used,
            "pr_review_daily_limit": limit,
            "remaining": 0,
            "pr_reviews_skipped": skipped_count,
            "estimated_model_calls": est_calls,
            "pr_review_model_calls_used": model_calls_used,
            "isolated_from_general_quota": True,
        }

    used += 1
    model_calls_used += est_calls
    bucket["pr_reviews_used"] = used
    bucket["pr_review_model_calls_used"] = model_calls_used
    buckets[bucket_key] = bucket
    state["events"].append(
        {
            "outcome": "reviewed",
            "repository": clean_repo,
            "pr_number": pr_number,
            "head_sha": head_sha,
            "installation_key": clean_install,
            "quota_date": quota_date,
            "estimated_model_calls": est_calls,
            "isolated_from_general_quota": True,
        }
    )
    _save_state(state_path, state)
    return {
        "ok": True,
        "dry_run": False,
        "allowed": True,
        "skipped": False,
        "review_executed": True,
        "status": "reviewed",
        "repository": clean_repo,
        "pr_number": pr_number,
        "head_sha": head_sha,
        "installation_key": clean_install,
        "quota_date": quota_date,
        "plan_tier": tier,
        "pr_reviews_used": used,
        "pr_review_daily_limit": limit,
        "remaining": max(0, limit - used),
        "pr_reviews_skipped": skipped_count,
        "estimated_model_calls": est_calls,
        "pr_review_model_calls_used": model_calls_used,
        "isolated_from_general_quota": True,
    }


def reconcile_async_model_calls(
    *,
    repository: str,
    pr_number: int,
    installation_key: str,
    estimated_model_calls: int,
    actual_model_calls: int,
    state_path: Path | None = None,
    now_utc: dt.datetime | None = None,
) -> dict[str, Any]:
    """Reconcile actual multi-call model usage asynchronously after review."""
    clean_install = installation_key.strip() or f"repo-{repository.strip()}"
    quota_date = _today_utc(now_utc)
    bucket_key = f"{clean_install}::{quota_date}"
    delta = int(actual_model_calls) - int(estimated_model_calls)

    state = _load_state(state_path)
    buckets: dict[str, Any] = state["buckets"]
    bucket = buckets.get(bucket_key)
    if not isinstance(bucket, dict):
        return {"reconciled": False, "reason": "bucket_not_found"}

    next_calls = max(0, int(bucket.get("pr_review_model_calls_used", 0)) + delta)
    bucket["pr_review_model_calls_used"] = next_calls
    buckets[bucket_key] = bucket
    state["events"].append(
        {
            "outcome": "async_reconciled",
            "repository": repository.strip(),
            "pr_number": pr_number,
            "quota_date": quota_date,
            "estimated_model_calls": estimated_model_calls,
            "actual_model_calls": actual_model_calls,
            "delta": delta,
        }
    )
    _save_state(state_path, state)
    return {
        "reconciled": True,
        "delta_model_calls": delta,
        "pr_review_model_calls_used": next_calls,
        "isolated_from_general_quota": True,
    }


def dispatch_webhook_if_configured(
    *,
    webhook_url: str,
    auth_header_name: str,
    auth_header_value: str,
    payload: dict[str, Any],
    timeout_sec: int = 10,
) -> dict[str, Any] | None:
    """Send webhook evaluation payload to Supabase Edge Function when configured."""
    if not webhook_url.strip() or not auth_header_value.strip():
        return None
    req = urllib.request.Request(
        webhook_url.strip(),
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "Content-Type": "application/json",
            auth_header_name: auth_header_value.strip(),
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout_sec) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            parsed = json.loads(raw)
            return parsed if isinstance(parsed, dict) else {"raw": raw}
    except urllib.error.URLError as exc:
        # Fail-open skip semantics (#2700 AC3): webhook reachability issue does not fail PR gate.
        return {
            "ok": True,
            "reviewed": False,
            "skipped": True,
            "status": "skipped_webhook_unreachable",
            "skip_reason": f"Webhook skipped gracefully: {exc}",
        }


def render_markdown_report(decision: dict[str, Any]) -> str:
    """Render concise human-readable Markdown summary for PR quota check."""
    lines = [
        "### GitHub PR Review Quota Report (#2700)",
        "",
        f"- Repository / PR: `{decision.get('repository', '')}#{decision.get('pr_number', '')}`",
        f"- Status: `{decision.get('status', 'unknown')}` | Review Executed: `{decision.get('review_executed', False)}` | Skipped: `{decision.get('skipped', False)}`",
        f"- Isolated Daily Bucket (`{decision.get('quota_date', '')}`): `{decision.get('pr_reviews_used', 0)} / {decision.get('pr_review_daily_limit', 0)}` (`{decision.get('plan_tier', 'consumer')}`)",
        f"- Model Calls Tracked: `{decision.get('pr_review_model_calls_used', 0)}` (estimated PR delta: `{decision.get('estimated_model_calls', 1)}`)",
        f"- Isolated From General Prompt Quotas: `{decision.get('isolated_from_general_quota', True)}`",
    ]
    if decision.get("skip_reason"):
        lines.append(f"- Skip Audit Reason: {decision['skip_reason']}")
    return "\n".join(lines) + "\n"


def _run_self_test() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        state_file = Path(tmp) / "quota_state.json"
        fixed_now = dt.datetime(2026, 11, 25, 5, 0, tzinfo=dt.timezone.utc)
        allowed = evaluate_pr_review_quota(
            repository="kanta13jp1/my_web_app",
            pr_number=6340,
            installation_key="gh-app-self-test",
            plan_tier="consumer",
            daily_limit=1,
            changed_files=9,
            diff_lines=320,
            dry_run=False,
            state_path=state_file,
            now_utc=fixed_now,
        )
        assert allowed["allowed"] is True and allowed["skipped"] is False
        assert allowed["pr_reviews_used"] == 1
        reconciled = reconcile_async_model_calls(
            repository="kanta13jp1/my_web_app",
            pr_number=6340,
            installation_key="gh-app-self-test",
            estimated_model_calls=allowed["estimated_model_calls"],
            actual_model_calls=5,
            state_path=state_file,
            now_utc=fixed_now,
        )
        assert reconciled["reconciled"] is True
        assert reconciled["pr_review_model_calls_used"] == 5

        skipped = evaluate_pr_review_quota(
            repository="kanta13jp1/my_web_app",
            pr_number=6341,
            installation_key="gh-app-self-test",
            plan_tier="consumer",
            daily_limit=1,
            dry_run=False,
            state_path=state_file,
            now_utc=fixed_now,
        )
        assert skipped["ok"] is True
        assert skipped["skipped"] is True
        assert skipped["status"] == "skipped_quota_exceeded"
        assert skipped["pr_reviews_skipped"] == 1
    print(json.dumps({"self_test": "passed", "consumer_default": DEFAULT_CONSUMER_DAILY_LIMIT, "enterprise_default": DEFAULT_ENTERPRISE_DAILY_LIMIT}))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--repository", default="kanta13jp1/my_web_app")
    parser.add_argument("--pr-number", type=int, default=1)
    parser.add_argument("--installation-key", default="gh-app-default")
    parser.add_argument("--plan-tier", default="consumer", choices=["consumer", "enterprise"])
    parser.add_argument("--daily-limit", type=int, default=0)
    parser.add_argument("--changed-files", type=int, default=1)
    parser.add_argument("--diff-lines", type=int, default=50)
    parser.add_argument("--head-sha", default="")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--state-file", default="")
    parser.add_argument("--output-json", default="")
    parser.add_argument("--output-md", default="")
    parser.add_argument("--github-output", default="")
    args = parser.parse_args(argv)

    if args.self_test:
        return _run_self_test()

    state_path = Path(args.state_file) if args.state_file else None
    decision = evaluate_pr_review_quota(
        repository=args.repository,
        pr_number=args.pr_number,
        installation_key=args.installation_key,
        plan_tier=args.plan_tier,
        daily_limit=args.daily_limit if args.daily_limit > 0 else None,
        changed_files=args.changed_files,
        diff_lines=args.diff_lines,
        head_sha=args.head_sha,
        dry_run=args.dry_run,
        state_path=state_path,
    )

    webhook_url = os.environ.get("PR_REVIEW_WEBHOOK_URL", "").strip()
    webhook_auth = os.environ.get("PR_REVIEW_WEBHOOK_AUTH", "").strip()
    if webhook_url and webhook_auth:
        remote = dispatch_webhook_if_configured(
            webhook_url=webhook_url,
            auth_header_name="x-webhook-api-key",
            auth_header_value=webhook_auth,
            payload={
                "source_tool": "github_app",
                "event_type": "pr_review_quota.evaluate",
                "repository": args.repository,
                "pr_number": args.pr_number,
                "installation_key": args.installation_key,
                "plan_tier": args.plan_tier,
                "changed_files": args.changed_files,
                "diff_lines": args.diff_lines,
                "head_sha": args.head_sha,
                "dry_run": args.dry_run,
            },
        )
        if remote is not None:
            decision["remote_webhook"] = remote

    md = render_markdown_report(decision)
    if args.output_json:
        Path(args.output_json).write_text(
            json.dumps(decision, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if args.output_md:
        Path(args.output_md).write_text(md, encoding="utf-8")
    if args.github_output:
        with Path(args.github_output).open("a", encoding="utf-8") as fh:
            fh.write(f"skipped={'true' if decision.get('skipped') else 'false'}\n")
            fh.write(
                f"review_executed={'true' if decision.get('review_executed') else 'false'}\n"
            )
            fh.write(f"status={decision.get('status', 'unknown')}\n")

    print(md)
    # Always exit 0 when quota exceeded (clean skip without failing the PR workflow).
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
