#!/usr/bin/env python3
"""Check GitHub Issues WBS Sync timeout-resilience wiring."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "issue-to-wbs.yml"
TOOLS_HUB = ROOT / "supabase" / "functions" / "tools-hub" / "index.ts"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label} is missing: {needle}")


def main() -> int:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    tools_hub = TOOLS_HUB.read_text(encoding="utf-8")

    require(
        workflow,
        'WBS_SYNC_GLOBAL_REPAIRS: "false"',
        "workflow default global repair guard",
    )
    require(
        workflow,
        '"global_repairs": global_repairs',
        "workflow payload global repair flag",
    )
    require(
        workflow,
        '--max-time "$WBS_SYNC_CURL_MAX_TIME"',
        "workflow curl timeout",
    )
    require(
        workflow,
        'if [ "$HTTP_CODE" -lt 500 ] || [ "$attempt" -ge 2 ]; then',
        "workflow transient 5xx retry guard",
    )
    require(
        workflow,
        'returned HTTP $HTTP_CODE on attempt $attempt; retrying',
        "workflow transient 5xx warning",
    )
    require(
        workflow,
        'if [ "$HTTP_CODE" -ge 400 ]; then',
        "workflow failed batch isolation guard",
    )
    require(
        tools_hub,
        "async function fetchWbsTasksForGithubIssues",
        "scoped WBS task fetcher",
    )
    require(
        tools_hub,
        "body.global_repairs ?? body.globalRepairs",
        "tools-hub global repair option",
    )
    require(
        tools_hub,
        "? await fetchAllWbsTasks(admin, taskSelect)",
        "global repair full scan branch",
    )
    require(
        tools_hub,
        ": await fetchWbsTasksForGithubIssues(",
        "scoped sync fetch branch",
    )

    print("WBS sync timeout resilience wiring: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
