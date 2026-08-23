#!/usr/bin/env python3
"""Validate the GA readiness gate wiring for #1640."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    ".github/workflows/ga-readiness-gate.yml",
    "docs/GA_LAUNCH_READINESS_GATE_SPEC.md",
    "docs/CORPORATE_FORMATION_RUNBOOK.md",
    "supabase/functions/app-hub/ga_readiness.ts",
    "supabase/functions/app-hub/index.ts",
    "lib/widgets/ga_readiness_gate_panel.dart",
    "lib/pages/home_page.dart",
]

REQUIRED_AXIS_IDS = [
    "mvp_scope",
    "pricing_v1",
    "legal_entity",
    "banking",
    "video_secrets",
]


def read_text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def contains_all(text: str, tokens: Iterable[str]) -> bool:
    return all(token in text for token in tokens)


def build_report() -> dict[str, object]:
    failures: list[str] = []
    for path in REQUIRED_FILES:
        require((ROOT / path).is_file(), f"missing required file: {path}", failures)

    ga_source = read_text("supabase/functions/app-hub/ga_readiness.ts")
    app_hub = read_text("supabase/functions/app-hub/index.ts")
    home_page = read_text("lib/pages/home_page.dart")
    panel = read_text("lib/widgets/ga_readiness_gate_panel.dart")
    workflow = read_text(".github/workflows/ga-readiness-gate.yml")

    require(
        contains_all(ga_source, REQUIRED_AXIS_IDS),
        "ga_readiness.ts does not expose every required GA axis",
        failures,
    )
    require(
        contains_all(ga_source, ["1640", "1662", "1724"]),
        "ga_readiness.ts is missing the issue linkage for #1640/#1662/#1724",
        failures,
    )
    require(
        "agent.list_ga_axes" in app_hub and "handleGaReadinessAction" in app_hub,
        "app-hub does not route agent.list_ga_axes",
        failures,
    )
    require(
        "GaReadinessGatePanel" in home_page
        and "ga_readiness_gate_panel.dart" in home_page,
        "home_page.dart does not surface the GA readiness panel",
        failures,
    )
    require(
        "agent.list_ga_axes" in panel
        and "home_section_ga_readiness_gate" in panel,
        "GA readiness panel is not wired to the app-hub action",
        failures,
    )
    require(
        contains_all(
            workflow,
            [
                "GA Launch Readiness Gate",
                "check_ga_readiness_gate.py",
                "deno check",
                "deno test",
                "Critical browser E2E",
            ],
        ),
        "workflow is missing one or more required GA gate checks",
        failures,
    )

    axes = [
        {"id": "mvp_scope", "issue": 1640, "owner": "Claude Code #1 + Codex #1"},
        {"id": "pricing_v1", "issue": 1640, "owner": "User"},
        {"id": "legal_entity", "issue": 1662, "owner": "User"},
        {"id": "banking", "issue": 1662, "owner": "User"},
        {"id": "video_secrets", "issue": 1724, "owner": "User"},
    ]
    return {
        "success": not failures,
        "failure_count": len(failures),
        "failures": failures,
        "axes": axes,
    }


def write_summary(path: Path, report: dict[str, object]) -> None:
    lines = [
        "# GA Launch Readiness Gate",
        "",
        f"Result: {'PASS' if report['success'] else 'FAIL'}",
        f"Axis count: {len(report['axes'])}",
        "",
        "## Axes",
    ]
    for axis in report["axes"]:
        axis_map = dict(axis)
        lines.append(
            f"- `{axis_map['id']}`: #{axis_map['issue']} ({axis_map['owner']})"
        )
    failures = report.get("failures") or []
    if failures:
        lines.extend(["", "## Failures"])
        lines.extend(f"- {failure}" for failure in failures)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-json", type=Path)
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()

    report = build_report()
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if args.output_json:
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        write_summary(args.summary, report)
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
