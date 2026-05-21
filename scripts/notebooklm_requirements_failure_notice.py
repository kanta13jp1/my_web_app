#!/usr/bin/env python3
"""Upsert the NotebookLM requirements workflow failure notice on GitHub Issues."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


UTC = dt.timezone.utc
NOTICE_MARKER = "<!-- notebooklm-requirements-failure-notice -->"


def now_iso() -> str:
    return (
        dt.datetime.now(UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def parse_bool(value: str | bool | None) -> bool:
    if isinstance(value, bool):
        return value
    return str(value or "").strip().lower() in {"1", "true", "yes", "on"}


def root_cause(secret_present: bool) -> str:
    if not secret_present:
        return (
            "`NOTEBOOKLM_STORAGE_STATE_JSON` is missing or empty, so the "
            "workflow cannot restore NotebookLM auth."
        )
    return (
        "`NOTEBOOKLM_STORAGE_STATE_JSON` is present, but NotebookLM auth or "
        "requirements extraction still failed. The stored browser state is "
        "likely expired or the NotebookLM CLI could not list notebooks."
    )


def render_notice(
    *,
    workflow: str,
    run_url: str,
    run_id: str,
    event: str,
    head_sha: str,
    secret_present: bool,
    updated_at: str | None = None,
) -> str:
    updated = updated_at or now_iso()
    short_sha = head_sha[:12] if head_sha else "unknown"
    secret_state = "present" if secret_present else "missing_or_empty"
    return f"""{NOTICE_MARKER}
## NotebookLM Requirements workflow failure notice

- Workflow: `{workflow}`
- Run: {run_url or f"`{run_id}`"}
- Event: `{event or "unknown"}`
- Head SHA: `{short_sha}`
- Secret state: `{secret_state}`
- Updated: `{updated}`

### Current blocker

{root_cause(secret_present)}

### Required next action

1. Refresh local NotebookLM auth with `notebooklm login`.
2. Update the GitHub Actions secret from the refreshed storage state:
   `gh secret set NOTEBOOKLM_STORAGE_STATE_JSON < ~/.notebooklm/storage_state.json`
3. Re-run `NotebookLM Requirements to Issues` with `create_issues=true`.
4. Confirm `GitHub Issues WBS Sync` and `WBS Auto Reschedule` after a successful run.

This comment is updated in place by `scripts/notebooklm_requirements_failure_notice.py`
so repeated scheduled failures do not create duplicate Issue comments.
"""


def run_gh(args: list[str], *, input_text: str | None = None) -> str:
    env = {**os.environ, "PYTHONUTF8": "1"}
    proc = subprocess.run(
        ["gh", *args],
        input=input_text,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "gh failed")
    return proc.stdout


def find_notice_comment(comments: list[dict[str, Any]]) -> int | None:
    for comment in comments:
        body = str(comment.get("body") or "")
        if NOTICE_MARKER in body:
            comment_id = comment.get("id")
            return int(comment_id) if comment_id is not None else None
    return None


def fetch_issue_comments(repo: str, issue: int) -> list[dict[str, Any]]:
    raw = run_gh(
        [
            "api",
            "--method",
            "GET",
            f"repos/{repo}/issues/{issue}/comments",
            "-F",
            "per_page=100",
        ]
    )
    parsed = json.loads(raw or "[]")
    if not isinstance(parsed, list):
        raise ValueError("GitHub comments response was not a list")
    return parsed


def upsert_notice(repo: str, issue: int, body: str) -> str:
    existing_id = find_notice_comment(fetch_issue_comments(repo, issue))
    if existing_id is None:
        return run_gh(
            [
                "api",
                "--method",
                "POST",
                f"repos/{repo}/issues/{issue}/comments",
                "-f",
                f"body={body}",
            ]
        )
    return run_gh(
        [
            "api",
            "--method",
            "PATCH",
            f"repos/{repo}/issues/comments/{existing_id}",
            "-f",
            f"body={body}",
        ]
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--issue", type=int, required=True)
    parser.add_argument("--workflow", default="NotebookLM Requirements to Issues")
    parser.add_argument("--run-url", default="")
    parser.add_argument("--run-id", default="")
    parser.add_argument("--event", default="")
    parser.add_argument("--head-sha", default="")
    parser.add_argument("--secret-present", default="false")
    parser.add_argument("--updated-at")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--body-out")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    body = render_notice(
        workflow=args.workflow,
        run_url=args.run_url,
        run_id=args.run_id,
        event=args.event,
        head_sha=args.head_sha,
        secret_present=parse_bool(args.secret_present),
        updated_at=args.updated_at,
    )
    if args.body_out:
        Path(args.body_out).write_text(body, encoding="utf-8", newline="\n")
    if args.dry_run:
        print(body)
        return 0
    upsert_notice(args.repo, args.issue, body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
