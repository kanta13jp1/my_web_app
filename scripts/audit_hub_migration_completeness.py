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


# HUB_ACTIONS の「action」列は歴史的に旧 EF 名がそのまま入っており、実在する
# action 名ではない (hub 内の action はドット区切り: core-hub に
# "development-achievements" という action は無い / 正は achievements.list)。
# hub の割り当ては正しいので、hub は HUB_ACTIONS から採り、action 名は
# 実装を読んで確認できたものだけをここに置く。未確認のものは推測を出さず
# 「hub の switch を見ろ」と案内する (誤った action 名を案内する方が有害)。
VERIFIED_ACTIONS: dict[str, str] = {
    "get-support-tickets": "support.list",
    "reply-support-request": "support.reply",
    "notify-feature-request": "notify.feature_request",
    "development-achievements": "achievements.list",
    "get-admin-users": "users.list",
    "get-growth-roadmap-progress": "roadmap.progress",
    "get-competitor-features": "competitor.list",
    "post-x-update": "x.post",
    "x-media-post": "x.post",
}

# reply-support-request は HUB_ACTIONS に項目自体が無い (admin-hub support.reply)。
VERIFIED_HUBS: dict[str, str] = {
    "reply-support-request": "admin-hub",
    "x-media-post": "growth-hub",
}


def hub_guidance(ef_name: str) -> str:
    mapped = HUB_ACTIONS.get(ef_name)
    hub = VERIFIED_HUBS.get(ef_name) or (mapped[0] if mapped else None)
    if hub is None:
        return (
            "Use the consolidated hub/action listed in deploy-prod.yml "
            f"for retired EF '{ef_name}'."
        )
    action = VERIFIED_ACTIONS.get(ef_name)
    if action is None:
        return (
            f"Retired EF '{ef_name}' was merged into '{hub}'. The action name is "
            f"NOT the old EF name — find the matching case in "
            f"supabase/functions/{hub}/index.ts."
        )
    return f"Use client.functions.invoke('{hub}', body: {{'action': '{action}'}})."


def load_dead_list(workflow_path: str) -> list[str]:
    with open(workflow_path, encoding="utf-8") as f:
        content = f.read()
    m = re.search(r"DEAD_LIST=\(\n(.*?)\n\s*\)", content, re.DOTALL)
    if not m:
        print("ERROR: DEAD_LIST not found in deploy-prod.yml", file=sys.stderr)
        sys.exit(2)
    return re.findall(r"\s+(\S+)", m.group(1))


SCANNED_SUFFIXES = (".dart", ".py", ".ts", ".yml", ".yaml")


def load_existing_functions(repo_root: str) -> set[str]:
    """Function names that actually have a directory under supabase/functions/.

    DEAD_LIST is hand-maintained and provably incomplete (development-achievements,
    notify-feature-request, personal-dashboard, system-status and
    app-analytics-dashboard were all deleted without being listed). Detecting
    against the filesystem instead means a reference to any non-existent function
    is caught whether or not somebody remembered to update the list.
    """
    fdir = os.path.join(repo_root, "supabase", "functions")
    existing: set[str] = set()
    if not os.path.isdir(fdir):
        return existing
    for name in os.listdir(fdir):
        if name.startswith("_"):
            continue
        if os.path.isdir(os.path.join(fdir, name)):
            existing.add(name)
    return existing


def scan_stale_refs(
    dead_list: list[str],
    search_dirs: list[str],
    existing_functions: set[str] | None = None,
) -> dict[str, list[str]]:
    # functions.invoke('ef-name', ...) — anchored on `functions.` so that unrelated
    # APIs that happen to expose invoke() (e.g. LangChain samples embedded in
    # AI-University page content) are not treated as EF calls.
    _invoke_re = re.compile(
        r"""functions\s*\.\s*invoke\(\s*['"]([^'"]+)['"]\s*[,)]""", re.DOTALL
    )
    # functions.invoke(someVariable, ...) — dispatch through a variable rather than
    # a literal. The literal regex above cannot see through this indirection, which
    # is exactly how `endpoint = 'post-x-update'; invoke(endpoint, ...)` stayed green.
    _dynamic_invoke_re = re.compile(
        r"""functions\s*\.\s*invoke\(\s*[A-Za-z_$][\w$]*\s*[,)]"""
    )
    # Bare string literal equal to a retired EF name. Only trusted in files that
    # ALSO dispatch dynamically — EF name literals are legitimate and common in
    # catalog/metadata files (edge_function_summary_card.dart, home_tool_catalog.dart)
    # and in hub sources, so applying this everywhere buries the real hits in noise.
    _literal_re = re.compile(r"""['"]([a-z0-9][a-z0-9-]{2,})['"]""")
    # /functions/v1/<name> — an EF endpoint URL. The name must resolve to a real
    # directory; anything else is a guaranteed 404 at runtime. Template
    # interpolation (`/functions/v1/${x}`) does not match and is skipped.
    _url_name_re = re.compile(r"/functions/v1/([A-Za-z0-9][A-Za-z0-9._-]*)")
    stale: dict[str, list[str]] = {}
    dead_set = set(dead_list)
    existing = existing_functions or set()
    this_file = os.path.abspath(__file__)

    def is_stale(name: str) -> bool:
        # Prefer ground truth (does the directory exist?) and fall back to the
        # hand-maintained DEAD_LIST when the functions dir is unavailable.
        if existing:
            return name not in existing
        return name in dead_set
    for d in search_dirs:
        for root, _dirs, files in os.walk(d):
            for fname in files:
                if not fname.endswith(SCANNED_SUFFIXES):
                    continue
                path = os.path.join(root, fname)
                # This script necessarily contains every retired EF name.
                if os.path.abspath(path) == this_file:
                    continue
                try:
                    with open(path, encoding="utf-8") as handle:
                        fc = handle.read()
                except Exception:
                    continue
                hits: set[str] = set()
                # Multi-line invoke() scan
                for m in _invoke_re.finditer(fc):
                    if is_stale(m.group(1)):
                        hits.add(m.group(1))
                # Variable-indirection scan. Keyed on DEAD_LIST rather than on
                # "not an existing function" because every lowercase string
                # literal would otherwise match.
                if _dynamic_invoke_re.search(fc):
                    for m in _literal_re.finditer(fc):
                        if m.group(1) in dead_set:
                            hits.add(m.group(1))
                # EF endpoint URL scan
                for m in _url_name_re.finditer(fc):
                    if is_stale(m.group(1)):
                        hits.add(m.group(1))
                for ef in hits:
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

    # .github と supabase/functions を外すと、GHA workflow の curl と
    # EF から EF を叩く fetch が原理的に検出できない (実際 cs-check.yml と
    # guitar-recording-studio が消えた EF を叩いたまま緑で通っていた)。
    search_dirs = [
        os.path.join(repo_root, "lib"),
        os.path.join(repo_root, "scripts"),
        os.path.join(repo_root, ".github"),
        os.path.join(repo_root, "supabase", "functions"),
    ]

    existing_functions = load_existing_functions(repo_root)
    print(f"Found {len(existing_functions)} live EF directories")

    stale = scan_stale_refs(dead_list, search_dirs, existing_functions)

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

    print(
        "[OK] No stale EF references found in "
        "lib/, scripts/, .github/ or supabase/functions/"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
