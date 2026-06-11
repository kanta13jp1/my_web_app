#!/usr/bin/env python3
"""
Audit stale EF references in client code.

Reads DEAD_LIST from deploy-prod.yml and checks if any retired EF names
are still referenced via invoke() in lib/ or scripts/.

Exit codes:
  0 = clean (no stale refs)
  1 = stale refs detected (CI fail)
  2 = script error
"""
import os
import re
import sys


HUB_ACTIONS: dict[str, tuple[str, str]] = {
    "public-memo-share": ("core-hub", "public-memo-share"),
    "memo-reactions": ("core-hub", "memo-reactions"),
    "get-ogp": ("core-hub", "get-ogp"),
    "get-public-memo-ogp": ("core-hub", "get-public-memo-ogp"),
    "note-comments": ("core-hub", "note-comments"),
    "notification-center": ("core-hub", "notification-center"),
    "user-profile-manager": ("core-hub", "user-profile-manager"),
    "onboarding-flow": ("core-hub", "onboarding-flow"),
    "feature-request-manager": ("core-hub", "feature-request-manager"),
    "user-feedback-collector": ("core-hub", "user-feedback-collector"),
    "notify-feature-request": ("core-hub", "notify-feature-request"),
    "personal-dashboard": ("core-hub", "personal-dashboard"),
    "system-status": ("core-hub", "system-status"),
    "development-achievements": ("core-hub", "development-achievements"),
    "app-analytics-dashboard": ("core-hub", "app-analytics-dashboard"),
    "growth-acquisition": ("growth-hub", "growth-acquisition"),
    "growth-command-center": ("growth-hub", "growth-command-center"),
    "growth-referral": ("growth-hub", "growth-referral"),
    "growth-share-signal": ("growth-hub", "growth-share-signal"),
    "growth-achievement-summary": ("growth-hub", "growth-achievement-summary"),
    "growth-import-preview": ("growth-hub", "growth-import-preview"),
    "growth-import-commit": ("growth-hub", "growth-import-commit"),
    "get-growth-roadmap-progress": ("growth-hub", "get-growth-roadmap-progress"),
    "video-ad-generator": ("growth-hub", "video-ad-generator"),
    "viral-share-engine": ("growth-hub", "viral-share-engine"),
    "x-media-post": ("growth-hub", "x-media-post"),
    "growth-automation-controller": ("growth-hub", "growth-automation-controller"),
    "landing-ab-test": ("growth-hub", "landing-ab-test"),
    "referral-program": ("growth-hub", "referral-program"),
    "share-quote": ("growth-hub", "share-quote"),
    "generate-quote-image": ("growth-hub", "generate-quote-image"),
    "seo-optimizer": ("growth-hub", "seo-optimizer"),
    "send-waitlist-notification": ("growth-hub", "send-waitlist-notification"),
    "viral-ad-generator": ("growth-hub", "viral-ad-generator"),
    "viral-growth-engine": ("growth-hub", "viral-growth-engine"),
    "daily-judgment": ("ai-hub", "daily-judgment"),
    "ai-search": ("ai-hub", "ai-search"),
    "ai-suggest-tags": ("ai-hub", "ai-suggest-tags"),
    "ai-secretary": ("ai-hub", "ai-secretary"),
    "ai-summarizer": ("ai-hub", "ai-summarizer"),
    "agent-hub": ("ai-hub", "agent-hub"),
    "virtual-organization": ("ai-hub", "virtual-organization"),
    "my-ai-agent": ("ai-hub", "my-ai-agent"),
    "generate-daily-challenges": ("ai-hub", "generate-daily-challenges"),
    "trigger-analysis": ("ai-hub", "trigger-analysis"),
    "analyze-reality": ("ai-hub", "analyze-reality"),
    "local-election-intelligence": ("ai-hub", "local-election-intelligence"),
    "ai-university-content": ("ai-hub", "ai-university-content"),
    "ai-university-streaks": ("ai-hub", "ai-university-streaks"),
    "ai-university-badges": ("ai-hub", "ai-university-badges"),
    "get-admin-users": ("admin-hub", "get-admin-users"),
    "submit-feedback": ("admin-hub", "submit-feedback"),
    "get-support-tickets": ("admin-hub", "get-support-tickets"),
    "get-competitor-features": ("admin-hub", "get-competitor-features"),
    "import-from-competitors": ("admin-hub", "import-from-competitors"),
    "health-check": ("admin-hub", "health-check"),
    "get-competitor-monitoring": ("admin-hub", "get-competitor-monitoring"),
    "edge-function-coverage": ("admin-hub", "edge-function-coverage"),
    "content-moderation": ("admin-hub", "content-moderation"),
    "user-activity-tracker": ("admin-hub", "user-activity-tracker"),
    "department-reporting": ("admin-hub", "department-reporting"),
    "admin-notification-hub": ("admin-hub", "admin-notification-hub"),
    "issue-auto-resolver": ("admin-hub", "issue-auto-resolver"),
    "subscription-management": ("app-hub", "subscription-management"),
    "subscription-billing": ("app-hub", "subscription-billing"),
    "email-service": ("app-hub", "email-service"),
    "gamification-engine": ("app-hub", "gamification-engine"),
    "calendar-events": ("app-hub", "calendar-events"),
    "kanban-board": ("app-hub", "kanban-board"),
    "chat-messaging": ("app-hub", "chat-messaging"),
    "team-task-manager": ("app-hub", "team-task-manager"),
    "team-collaboration-sync": ("app-hub", "team-collaboration-sync"),
    "file-storage-manager": ("app-hub", "file-storage-manager"),
    "expense-tracker": ("app-hub", "expense-tracker"),
    "time-tracker": ("app-hub", "time-tracker"),
    "automation-workflows": ("app-hub", "automation-workflows"),
    "data-export-manager": ("app-hub", "data-export-manager"),
    "webhook-manager": ("app-hub", "webhook-manager"),
    "api-rate-limiter": ("app-hub", "api-rate-limiter"),
    "music-collaboration": ("app-hub", "music-collaboration"),
    "schedule-daily-digest": ("schedule-hub", "schedule-daily-digest"),
    "schedule-manager": ("schedule-hub", "schedule-manager"),
    "post-x-update": ("schedule-hub", "post-x-update"),
    "blog-post-manager": ("schedule-hub", "blog-post-manager"),
    "blog-auto-publisher": ("schedule-hub", "blog-auto-publisher"),
}


def hub_guidance(ef_name: str) -> str:
    mapped = HUB_ACTIONS.get(ef_name)
    if not mapped:
        return (
            "Use the consolidated hub/action listed in deploy-prod.yml "
            f"for retired EF '{ef_name}'."
        )
    hub, action = mapped
    return f"Use client.functions.invoke('{hub}', body: {{'action': '{action}'}})."


def load_dead_list(workflow_path: str) -> list[str]:
    with open(workflow_path, encoding="utf-8") as f:
        content = f.read()
    m = re.search(r"DEAD_LIST=\(\n(.*?)\n\s*\)", content, re.DOTALL)
    if not m:
        print("ERROR: DEAD_LIST not found in deploy-prod.yml", file=sys.stderr)
        sys.exit(2)
    return re.findall(r"\s+(\S+)", m.group(1))


def scan_stale_refs(dead_list: list[str], search_dirs: list[str]) -> dict[str, list[str]]:
    # Multi-line regex: .invoke( optionally followed by whitespace/newline then 'ef-name'
    _invoke_re = re.compile(r"""\.invoke\(\s*['"]([^'"]+)['"]\s*[,)]""", re.DOTALL)
    _url_re_tmpl = "/functions/v1/{ef}"
    stale: dict[str, list[str]] = {}
    dead_set = set(dead_list)
    for d in search_dirs:
        for root, _dirs, files in os.walk(d):
            for fname in files:
                if not (fname.endswith(".dart") or fname.endswith(".py") or fname.endswith(".ts")):
                    continue
                path = os.path.join(root, fname)
                try:
                    with open(path, encoding="utf-8") as handle:
                        fc = handle.read()
                except Exception:
                    continue
                # Multi-line invoke() scan
                for m in _invoke_re.finditer(fc):
                    ef = m.group(1)
                    if ef in dead_set:
                        stale.setdefault(ef, []).append(path)
                # URL-pattern scan (single-line, fast)
                for ef in dead_set:
                    if f"/functions/v1/{ef}" in fc:
                        if path not in stale.get(ef, []):
                            stale.setdefault(ef, []).append(path)
    # Deduplicate file lists
    return {k: sorted(set(v)) for k, v in stale.items()}


def main() -> int:
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    workflow = os.path.join(repo_root, ".github", "workflows", "deploy-prod.yml")

    if not os.path.exists(workflow):
        print(f"ERROR: {workflow} not found", file=sys.stderr)
        return 2

    dead_list = load_dead_list(workflow)
    print(f"Loaded {len(dead_list)} retired EF names from DEAD_LIST")

    search_dirs = [
        os.path.join(repo_root, "lib"),
        os.path.join(repo_root, "scripts"),
    ]

    stale = scan_stale_refs(dead_list, search_dirs)

    if stale:
        print(f"\n[FAIL] STALE EF REFS DETECTED ({len(stale)} EF(s)):", file=sys.stderr)
        for ef, files in sorted(stale.items()):
            print(f"  [{ef}]", file=sys.stderr)
            for fp in files:
                rel = os.path.relpath(fp, repo_root)
                print(f"    {rel}", file=sys.stderr)
            print(f"    guidance: {hub_guidance(ef)}", file=sys.stderr)
        print(
            "\nAction required: migrate each invoke() to the appropriate hub action.",
            file=sys.stderr,
        )
        return 1

    print(f"[OK] No stale EF references found in lib/ or scripts/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
