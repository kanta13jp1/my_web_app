#!/usr/bin/env python3
"""Validate the #1638 NotebookLM session-ops route manifest."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


CONFIG_PATH = Path("config/notebooklm-session-ops-routes.json")
NOTEBOOKLM_REPORT_PATH = Path("docs/notebooklm-intake/latest-report.md")
AI_TOOL_REPORT_PATH = Path("docs/ai-tool-watch/latest-report.md")
ISSUE_NUMBER = 1638
ACTIVE_INSTANCES = ["Claude Code #1", "Codex #1"]
REQUIRED_SHORT_IDS = {
    "1aced136",
    "9b8885ef",
    "ed1aac00",
    "d89ae1f5",
    "b74e9ada",
    "64fc639e",
    "f0895eb0",
    "52daba63",
    "c3b1d9f2",
    "9871b0b1",
}
ALLOWED_OWNERS = {"Claude Code #1", "Codex #1", "Automation", "User"}
ALLOWED_LANDING_TYPES = {"config", "docs", "issue", "script", "workflow"}
REQUIRED_AI_TOOL_GROUPS = {
    "codex-runtime",
    "hooks",
    "integration",
    "quality-cost",
    "schedule",
}
REQUIRED_OFFICIAL_SOURCES = {
    "Claude Code changelog",
    "Claude Code hooks reference",
    "Claude Code GitHub Actions",
    "Codex overview",
}


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def validate_path(root: Path, raw_path: str, *, failures: list[str], context: str) -> None:
    path = Path(raw_path)
    if path.is_absolute():
        failures.append(f"{context}: path must be repo-relative: {raw_path}")
        return
    if not (root / path).exists():
        failures.append(f"{context}: missing repo path: {raw_path}")


def evidence_types(route: dict[str, Any]) -> set[str]:
    return {str(item.get("type", "")) for item in route.get("verifiedBy", []) if isinstance(item, dict)}


def route_landing_types(route: dict[str, Any]) -> set[str]:
    return {
        str(item.get("type", ""))
        for item in route.get("landingTargets", [])
        if isinstance(item, dict)
    }


def validate_config(root: Path, config: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    if config.get("schemaVersion") != 1:
        failures.append("schemaVersion must be 1")
    if config.get("issue") != ISSUE_NUMBER:
        failures.append(f"issue must be {ISSUE_NUMBER}")
    if config.get("status") != "active":
        failures.append("status must be active")

    owner = config.get("ownerModel", {})
    if not isinstance(owner, dict):
        failures.append("ownerModel must be an object")
    else:
        if owner.get("activeInstances") != ACTIVE_INSTANCES:
            failures.append("ownerModel.activeInstances must be Claude Code #1 + Codex #1")
        if owner.get("implementationOwner") != "Codex #1":
            failures.append("ownerModel.implementationOwner must be Codex #1")
        active_instances = owner.get("activeInstances", [])
        if any(instance in active_instances for instance in ["Codex #2", "Codex #3"]):
            failures.append("ownerModel must not activate old Codex #2/#3 lanes")

    policy = config.get("verificationPolicy", {})
    if not isinstance(policy, dict):
        failures.append("verificationPolicy must be an object")
    else:
        if not policy.get("notebooklmIsAdvisory"):
            failures.append("verificationPolicy.notebooklmIsAdvisory must be true")
        if not policy.get("requireOfficialOrAiToolWatchEvidence"):
            failures.append("verificationPolicy.requireOfficialOrAiToolWatchEvidence must be true")
        if not policy.get("forbidRawNotebooklmDump"):
            failures.append("verificationPolicy.forbidRawNotebooklmDump must be true")
        allowed = set(policy.get("allowedLandingTypes", []))
        if allowed != ALLOWED_LANDING_TYPES:
            failures.append(
                "verificationPolicy.allowedLandingTypes must match the approved landing types"
            )

    for field in ("latestNotebooklmReport", "latestAiToolWatchReport"):
        value = str(config.get(field, ""))
        if not value:
            failures.append(f"{field} is required")
        else:
            validate_path(root, value, failures=failures, context=field)

    routes = config.get("routes", [])
    if not isinstance(routes, list) or not routes:
        failures.append("routes must be a non-empty list")
        return failures

    route_ids = set()
    short_ids = set()
    for index, route in enumerate(routes):
        context = f"routes[{index}]"
        if not isinstance(route, dict):
            failures.append(f"{context}: route must be an object")
            continue
        short_id = str(route.get("shortId", "")).strip()
        route_id = str(route.get("routeId", "")).strip()
        if not short_id:
            failures.append(f"{context}: shortId is required")
        if not route_id:
            failures.append(f"{context}: routeId is required")
        if route_id in route_ids:
            failures.append(f"{context}: duplicate routeId {route_id}")
        route_ids.add(route_id)
        if short_id in short_ids:
            failures.append(f"{context}: duplicate shortId {short_id}")
        short_ids.add(short_id)

        if route.get("owner") not in ALLOWED_OWNERS:
            failures.append(f"{context}: owner must be one of {sorted(ALLOWED_OWNERS)}")
        if route.get("implementationOwner") != "Codex #1":
            failures.append(f"{context}: implementationOwner must be Codex #1")
        if any(owner in str(route) for owner in ["Codex #2", "Codex #3"]):
            failures.append(f"{context}: old Codex #2/#3 lanes must not be active")
        if not str(route.get("title", "")).strip():
            failures.append(f"{context}: title is required")
        if not str(route.get("nextAction", "")).strip():
            failures.append(f"{context}: nextAction is required")

        evidence = route.get("verifiedBy", [])
        if not isinstance(evidence, list) or not evidence:
            failures.append(f"{context}: verifiedBy must be a non-empty list")
        else:
            kinds = evidence_types(route)
            if "notebooklm-report" not in kinds:
                failures.append(f"{context}: verifiedBy must include notebooklm-report")
            if not ({"official-source-signal", "ai-tool-watch-group"} & kinds):
                failures.append(
                    f"{context}: verifiedBy must include official source or AI Tool Watch evidence"
                )
            for evidence_index, item in enumerate(evidence):
                if not isinstance(item, dict):
                    failures.append(f"{context}.verifiedBy[{evidence_index}]: must be an object")
                    continue
                path = item.get("path")
                if path:
                    validate_path(
                        root,
                        str(path),
                        failures=failures,
                        context=f"{context}.verifiedBy[{evidence_index}]",
                    )

        targets = route.get("landingTargets", [])
        if not isinstance(targets, list) or not targets:
            failures.append(f"{context}: landingTargets must be a non-empty list")
        else:
            target_types = route_landing_types(route)
            if not target_types <= ALLOWED_LANDING_TYPES:
                failures.append(f"{context}: unknown landing target type {sorted(target_types)}")
            if not target_types:
                failures.append(f"{context}: at least one landing target is required")
            for target_index, item in enumerate(targets):
                if not isinstance(item, dict):
                    failures.append(f"{context}.landingTargets[{target_index}]: must be an object")
                    continue
                target_type = str(item.get("type", ""))
                if target_type in {"config", "docs", "script", "workflow"}:
                    path = item.get("path")
                    if not path:
                        failures.append(
                            f"{context}.landingTargets[{target_index}]: path is required"
                        )
                    else:
                        validate_path(
                            root,
                            str(path),
                            failures=failures,
                            context=f"{context}.landingTargets[{target_index}]",
                        )
                if target_type == "issue":
                    issue = item.get("issue")
                    if not isinstance(issue, int) or issue <= 0:
                        failures.append(
                            f"{context}.landingTargets[{target_index}]: issue must be a positive integer"
                        )

    missing = sorted(REQUIRED_SHORT_IDS - short_ids)
    if missing:
        failures.append(f"missing required #1638 NotebookLM routes: {', '.join(missing)}")
    return failures


def validate_reports(root: Path, config: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    notebook_report = read_text(root / NOTEBOOKLM_REPORT_PATH)
    ai_tool_report = read_text(root / AI_TOOL_REPORT_PATH)

    for short_id in REQUIRED_SHORT_IDS:
        if short_id not in notebook_report and short_id not in json.dumps(config):
            failures.append(f"NotebookLM route short id missing from report/config: {short_id}")
    if "#1638" not in notebook_report:
        failures.append("NotebookLM latest report must route at least one item to #1638")
    if "Candidate Issue Drafts" not in notebook_report or "- None." not in notebook_report:
        failures.append("NotebookLM latest report must show no candidate issue drafts")

    for group in REQUIRED_AI_TOOL_GROUPS:
        if group not in ai_tool_report:
            failures.append(f"AI Tool Watch report missing routing group: {group}")
    for source in REQUIRED_OFFICIAL_SOURCES:
        if source not in ai_tool_report:
            failures.append(f"AI Tool Watch report missing official source signal: {source}")
    if "Claude Code #1" not in ai_tool_report or "Codex #1" not in ai_tool_report:
        failures.append("AI Tool Watch report must include the two-instance routing reminder")
    return failures


def build_snapshot(root: Path) -> dict[str, Any]:
    config = load_json(root / CONFIG_PATH)
    failures = validate_config(root, config)
    failures.extend(validate_reports(root, config))
    routes = config.get("routes", [])
    return {
        "state": "ok" if not failures else "invalid",
        "config": str(CONFIG_PATH),
        "issue": config.get("issue"),
        "route_count": len(routes) if isinstance(routes, list) else 0,
        "short_ids": [route.get("shortId") for route in routes if isinstance(route, dict)],
        "validation_errors": failures,
    }


def render_markdown(snapshot: dict[str, Any]) -> str:
    lines = [
        "# NotebookLM Session-Ops Routes Check",
        "",
        f"- State: `{snapshot['state']}`",
        f"- Config: `{snapshot['config']}`",
        f"- Issue: `#{snapshot['issue']}`",
        f"- Routes: `{snapshot['route_count']}`",
        f"- Short IDs: `{', '.join(snapshot['short_ids'])}`",
        "",
        "## Validation",
    ]
    if snapshot["validation_errors"]:
        for error in snapshot["validation_errors"]:
            lines.append(f"- {error}")
    else:
        lines.append("- All #1638 NotebookLM session-ops routes are verified and landed.")
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Print JSON instead of Markdown.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    args = parse_args(argv)
    snapshot = build_snapshot(repo_root())
    if args.json:
        print(json.dumps(snapshot, ensure_ascii=False, indent=2))
    else:
        print(render_markdown(snapshot))
    return 0 if snapshot["state"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
