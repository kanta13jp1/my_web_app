#!/usr/bin/env python3
"""Validate and render the #1644 dynamic context injection map."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


CONFIG_PATH = Path("config/context-injection-map.json")
NOTEBOOKLM_SNAPSHOT_PATH = Path("docs/notebooklm-intake/latest-snapshot.json")
NOTEBOOKLM_ISSUE_DRAFTS_PATH = Path("docs/notebooklm-intake/issue-drafts.md")
HARNESS_NOTEBOOK_ID = "bc58b50b-5fc4-4840-9a62-b397d6d3b65a"
SAFE_DISPOSITIONS = {
    "applied",
    "priority_reference",
    "route_existing_issue",
    "skipped",
}
UNAPPLIED_DISPOSITIONS = {
    "candidate_issue_draft",
    "manual_triage",
    "new_issue_draft",
    "needs_issue",
    "unrouted",
}


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8-sig"))


def load_config(root: Path) -> dict[str, Any]:
    data = load_json(root / CONFIG_PATH, {})
    if not isinstance(data, dict):
        raise ValueError(f"{CONFIG_PATH} must contain a JSON object")
    return data


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip().lower()


def route_score(route: dict[str, Any], prompt: str) -> int:
    text = normalize(prompt)
    if not text:
        return 1 if route.get("sessionStartDefault") else 0
    score = 0
    for keyword in route.get("keywords", []):
        if normalize(str(keyword)) in text:
            score += 1
    return score


def matched_routes(
    config: dict[str, Any],
    prompt: str = "",
    *,
    limit: int = 5,
) -> list[dict[str, Any]]:
    ranked: list[tuple[int, int, dict[str, Any]]] = []
    for index, route in enumerate(config.get("routes", [])):
        if not isinstance(route, dict):
            continue
        score = route_score(route, prompt)
        if score:
            ranked.append((score, -index, route))
    ranked.sort(reverse=True)
    return [route for _, _, route in ranked[:limit]]


def validate_config(root: Path, config: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    if config.get("schemaVersion") != 1:
        failures.append("schemaVersion must be 1")
    if config.get("issue") != 1644:
        failures.append("issue must be 1644")
    if config.get("harnessNotebookId") != HARNESS_NOTEBOOK_ID:
        failures.append(f"harnessNotebookId must be {HARNESS_NOTEBOOK_ID}")

    owner = config.get("ownerModel", {})
    active_instances = owner.get("activeInstances", []) if isinstance(owner, dict) else []
    if active_instances != ["Claude Code #1", "Codex #1"]:
        failures.append("ownerModel.activeInstances must be Claude Code #1 + Codex #1")
    if any(item in active_instances for item in ["Codex #2", "Codex #3"]):
        failures.append("old Codex #2/#3 lanes must not be active owners")

    policy = config.get("proposalPolicy", {})
    if not isinstance(policy, dict):
        failures.append("proposalPolicy must be an object")
    elif not policy.get("forbidRawNotebooklmDump"):
        failures.append("proposalPolicy.forbidRawNotebooklmDump must be true")

    routes = config.get("routes", [])
    if not isinstance(routes, list) or not routes:
        failures.append("routes must be a non-empty list")
        return failures

    for route in routes:
        if not isinstance(route, dict):
            failures.append("each route must be an object")
            continue
        route_id = str(route.get("id", "<missing>"))
        for field in ("keywords", "docs", "skills", "notebooklmQueries", "connectToIssues"):
            value = route.get(field)
            if not isinstance(value, list) or not value:
                failures.append(f"{route_id}: {field} must be a non-empty list")
        for field in ("docs", "skills"):
            for raw_path in route.get(field, []):
                relative = Path(str(raw_path))
                if relative.is_absolute():
                    failures.append(f"{route_id}: {field} path must be relative: {raw_path}")
                    continue
                if not (root / relative).exists():
                    failures.append(f"{route_id}: missing {field} path: {raw_path}")
        for query in route.get("notebooklmQueries", []):
            if not isinstance(query, dict):
                failures.append(f"{route_id}: notebooklmQueries entries must be objects")
                continue
            if query.get("notebookId") != HARNESS_NOTEBOOK_ID:
                failures.append(f"{route_id}: notebooklm query must target the harness notebook")
            if not str(query.get("question", "")).strip():
                failures.append(f"{route_id}: notebooklm query is missing a question")
        for issue in route.get("connectToIssues", []):
            if not isinstance(issue, int):
                failures.append(f"{route_id}: connectToIssues must contain integers")
    return failures


def notebooklm_intake_summary(root: Path) -> dict[str, Any]:
    snapshot_path = root / NOTEBOOKLM_SNAPSHOT_PATH
    drafts_path = root / NOTEBOOKLM_ISSUE_DRAFTS_PATH
    snapshot = load_json(snapshot_path, {})
    notebooks = snapshot.get("notebooks", []) if isinstance(snapshot, dict) else []
    if not isinstance(notebooks, list):
        notebooks = []

    candidates: list[dict[str, str]] = []
    for notebook in notebooks:
        if not isinstance(notebook, dict):
            continue
        disposition = str(notebook.get("disposition", "")).strip()
        existing_issue = str(notebook.get("existing_issue_number", "")).strip()
        is_unapplied = disposition in UNAPPLIED_DISPOSITIONS
        if not existing_issue and disposition and disposition not in SAFE_DISPOSITIONS:
            is_unapplied = True
        if is_unapplied:
            candidates.append(
                {
                    "short_id": str(notebook.get("short_id", "")),
                    "title": str(notebook.get("title", "")),
                    "disposition": disposition,
                }
            )

    drafts_state = "missing"
    if drafts_path.exists():
        drafts = drafts_path.read_text(encoding="utf-8-sig")
        drafts_state = "none" if "No new issue drafts" in drafts else "has_drafts"

    return {
        "snapshot": str(NOTEBOOKLM_SNAPSHOT_PATH),
        "issue_drafts": str(NOTEBOOKLM_ISSUE_DRAFTS_PATH),
        "state": "ok" if snapshot_path.exists() else "missing_snapshot",
        "harness_notebook_id": snapshot.get("harness_notebook_id", HARNESS_NOTEBOOK_ID)
        if isinstance(snapshot, dict)
        else HARNESS_NOTEBOOK_ID,
        "harness_found": bool(snapshot.get("harness_found", False))
        if isinstance(snapshot, dict)
        else False,
        "notebook_count": int(snapshot.get("notebook_count", len(notebooks)))
        if isinstance(snapshot, dict)
        else len(notebooks),
        "candidate_issue_drafts": len(candidates),
        "unapplied_candidates": candidates[:10],
        "issue_drafts_state": drafts_state,
    }


def build_session_snapshot(root: Path, prompt: str = "") -> dict[str, Any]:
    config = load_config(root)
    validation_errors = validate_config(root, config)
    routes = matched_routes(config, prompt)
    return {
        "state": "ok" if not validation_errors else "invalid",
        "config": str(CONFIG_PATH),
        "issue": config.get("issue"),
        "prompt": prompt,
        "validation_errors": validation_errors,
        "ownerModel": config.get("ownerModel", {}),
        "proposalPolicy": config.get("proposalPolicy", {}),
        "matchedRoutes": routes,
        "routeCount": len(config.get("routes", [])),
        "notebooklm": notebooklm_intake_summary(root),
    }


def render_markdown(snapshot: dict[str, Any]) -> str:
    lines = [
        "# Dynamic Context Injection Check",
        "",
        f"- State: `{snapshot['state']}`",
        f"- Config: `{snapshot['config']}`",
        f"- Issue: `#{snapshot['issue']}`",
        f"- Prompt: `{snapshot['prompt'] or '(session start defaults)'}`",
        f"- Routes configured: `{snapshot['routeCount']}`",
        "",
        "## Owner Model",
    ]
    owner = snapshot.get("ownerModel", {})
    lines.append(f"- Active instances: `{', '.join(owner.get('activeInstances', []))}`")
    lines.append(f"- Design owner: `{owner.get('designOwner', 'unknown')}`")
    lines.append(f"- Implementation owner: `{owner.get('implementationOwner', 'unknown')}`")
    lines.append(f"- External memory owner: `{owner.get('externalMemoryOwner', 'unknown')}`")

    notebooklm = snapshot["notebooklm"]
    lines.extend(
        [
            "",
            "## NotebookLM Intake",
            f"- Snapshot: `{notebooklm['snapshot']}`",
            f"- Harness notebook: `{notebooklm['harness_notebook_id']}`",
            f"- Harness found: `{notebooklm['harness_found']}`",
            f"- Notebook count: `{notebooklm['notebook_count']}`",
            f"- Unapplied candidates: `{notebooklm['candidate_issue_drafts']}`",
            f"- Issue drafts state: `{notebooklm['issue_drafts_state']}`",
        ]
    )
    for candidate in notebooklm["unapplied_candidates"][:5]:
        lines.append(
            f"- `{candidate['short_id']}` {candidate['title']} "
            f"({candidate['disposition']})"
        )

    lines.extend(["", "## Matched Routes"])
    if not snapshot["matchedRoutes"]:
        lines.append("- No route matched. Add keywords or use a session-start default route.")
    for route in snapshot["matchedRoutes"]:
        lines.append(f"- `{route['id']}`: {route.get('description', '')}")
        lines.append(f"  - Docs: {', '.join(f'`{item}`' for item in route.get('docs', []))}")
        lines.append(f"  - Skills: {', '.join(f'`{item}`' for item in route.get('skills', []))}")
        lines.append(
            "  - Issue targets: "
            + ", ".join(f"#{issue}" for issue in route.get("connectToIssues", []))
        )
        for query in route.get("notebooklmQueries", [])[:2]:
            lines.append(
                f"  - NotebookLM query: `{query.get('notebookName')}` "
                f"-> {query.get('question')}"
            )

    policy = snapshot.get("proposalPolicy", {})
    lines.extend(
        [
            "",
            "## Proposal Connection Rule",
            "- NotebookLM output must be distilled, not pasted raw.",
            "- Connect proposals to: "
            + ", ".join(policy.get("connectNotebooklmOutputTo", [])),
        ]
    )

    lines.extend(["", "## Validation"])
    if snapshot["validation_errors"]:
        for failure in snapshot["validation_errors"]:
            lines.append(f"- FAIL: {failure}")
    else:
        lines.append("- PASS: mapping paths, owner model, NotebookLM query target, and proposal policy are valid.")

    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prompt", default="", help="User prompt text to route.")
    parser.add_argument("--json", action="store_true", help="Print JSON instead of Markdown.")
    parser.add_argument("--check", action="store_true", help="Exit non-zero if the map is invalid.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    args = parse_args(argv)
    root = repo_root()
    snapshot = build_session_snapshot(root, args.prompt)
    if args.json:
        print(json.dumps(snapshot, ensure_ascii=False, indent=2))
    else:
        print(render_markdown(snapshot))
    if args.check and snapshot["validation_errors"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
