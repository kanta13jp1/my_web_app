#!/usr/bin/env python3
"""High-resolution Vision UI E2E audit & Task Budget guard (#2790).

Tracks full-resolution screenshot capture metadata without forced downscaling
(long edge <= 2576 px), enforces a per-run Task Budget token ceiling, and
renders structured JSON / GitHub Issue Markdown anomaly reports (dry-run safe).
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import math
from pathlib import Path
import sys
from typing import Any

MAX_HIGH_RES_LONG_EDGE_PX = 2576
PATCH_SIZE_PX = 28
DEFAULT_TASK_BUDGET_UNITS = 64000
TASK_BUDGET_BETA_HEADER = "task-budgets-2026-03-13"


def estimate_vision_units(width_px: int, height_px: int) -> int:
    """Estimate vision input tokens using 28x28 pixel patches."""
    if width_px <= 0 or height_px <= 0:
        raise ValueError("Screenshot dimensions must be positive integers.")
    patches_w = math.ceil(width_px / PATCH_SIZE_PX)
    patches_h = math.ceil(height_px / PATCH_SIZE_PX)
    return patches_w * patches_h


@dataclass(frozen=True)
class ScreenshotCaptureMetadata:
    route: str
    width_px: int
    height_px: int
    full_page: bool
    downscaled: bool
    image_path: str

    @property
    def long_edge_px(self) -> int:
        return max(self.width_px, self.height_px)

    @property
    def exceeds_high_res_limit(self) -> bool:
        return self.long_edge_px > MAX_HIGH_RES_LONG_EDGE_PX

    @property
    def estimated_vision_units(self) -> int:
        return estimate_vision_units(self.width_px, self.height_px)


@dataclass(frozen=True)
class TaskBudgetConfig:
    max_total_units: int = DEFAULT_TASK_BUDGET_UNITS
    effort: str = "high"
    beta_header: str = TASK_BUDGET_BETA_HEADER

    def to_output_config(self) -> dict[str, Any]:
        return {
            "effort": self.effort,
            "task_budget": {
                "type": "tokens",
                "total": self.max_total_units,
            },
        }


class TaskBudgetTracker:
    """Tracks cumulative token consumption against a Task Budget ceiling."""

    def __init__(self, config: TaskBudgetConfig) -> None:
        if config.max_total_units <= 0:
            raise ValueError("max_total_units must be positive.")
        self.config = config
        self.consumed_units = 0

    @property
    def remaining_units(self) -> int:
        return max(0, self.config.max_total_units - self.consumed_units)

    @property
    def budget_exceeded(self) -> bool:
        return self.consumed_units > self.config.max_total_units

    def can_afford(self, next_units: int) -> bool:
        return (self.consumed_units + max(0, next_units)) <= (
            self.config.max_total_units
        )

    def record(self, units: int) -> None:
        if units < 0:
            raise ValueError("Consumed tokens cannot be negative.")
        self.consumed_units += units


@dataclass(frozen=True)
class UiAnomalyFinding:
    route: str
    severity: str
    category: str
    summary: str
    details: str
    screenshot_path: str


@dataclass(frozen=True)
class VisionAuditReport:
    run_id: str
    captures_total: int
    findings_total: int
    total_estimated_units: int
    budget_limit_units: int
    budget_exceeded: bool
    downscale_violations: int
    over_limit_captures: int
    issue_title: str
    issue_markdown: str
    findings: list[dict[str, Any]]
    captures: list[dict[str, Any]]


def render_github_issue_markdown(
    run_id: str,
    captures: list[ScreenshotCaptureMetadata],
    findings: list[UiAnomalyFinding],
    tracker: TaskBudgetTracker,
) -> str:
    """Render a structured Markdown body suitable for GitHub Issue creation."""
    lines: list[str] = [
        f"## Vision UI E2E Audit Report (`{run_id}`)",
        "",
        f"- **Captures inspected**: {len(captures)}",
        f"- **Anomalies detected**: {len(findings)}",
        (
            f"- **Task Budget**: {tracker.consumed_units} / "
            f"{tracker.config.max_total_units} tokens "
            f"(exceeded={str(tracker.budget_exceeded).lower()})"
        ),
        "",
        "### Detected UI / Layout Anomalies",
        "",
    ]
    if not findings:
        lines.append("- No UI anomalies detected.")
    else:
        for idx, item in enumerate(findings, 1):
            lines.extend(
                [
                    (
                        f"{idx}. **[{item.severity.upper()}] `{item.route}` "
                        f"({item.category})**: {item.summary}"
                    ),
                    f"   - Details: {item.details}",
                    f"   - Screenshot: `{item.screenshot_path}`",
                ]
            )
    return "\n".join(lines) + "\n"


def evaluate_audit_run(
    run_id: str,
    captures: list[ScreenshotCaptureMetadata],
    findings: list[UiAnomalyFinding],
    budget_config: TaskBudgetConfig | None = None,
    prompt_overhead_per_capture: int = 800,
) -> VisionAuditReport:
    """Validate captures, enforce Task Budget, and build audit report."""
    config = budget_config or TaskBudgetConfig()
    tracker = TaskBudgetTracker(config)

    capture_dicts: list[dict[str, Any]] = []
    downscale_violations = 0
    over_limit_captures = 0

    for cap in captures:
        if cap.downscaled:
            downscale_violations += 1
        if cap.exceeds_high_res_limit:
            over_limit_captures += 1
        est_units = cap.estimated_vision_units + max(
            0,
            prompt_overhead_per_capture,
        )
        tracker.record(est_units)
        capture_dicts.append(
            {
                **asdict(cap),
                "long_edge_px": cap.long_edge_px,
                "exceeds_high_res_limit": cap.exceeds_high_res_limit,
                "estimated_vision_units": cap.estimated_vision_units,
                "estimated_step_units": est_units,
            }
        )

    issue_title = (
        f"[vision-e2e-audit] {len(findings)} UI anomaly(ies) detected "
        f"in run {run_id}"
    )
    issue_md = render_github_issue_markdown(run_id, captures, findings, tracker)

    return VisionAuditReport(
        run_id=run_id,
        captures_total=len(captures),
        findings_total=len(findings),
        total_estimated_units=tracker.consumed_units,
        budget_limit_units=config.max_total_units,
        budget_exceeded=tracker.budget_exceeded,
        downscale_violations=downscale_violations,
        over_limit_captures=over_limit_captures,
        issue_title=issue_title,
        issue_markdown=issue_md,
        findings=[asdict(f) for f in findings],
        captures=capture_dicts,
    )


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Evaluate Vision E2E UI audit captures and Task Budget.",
    )
    parser.add_argument(
        "--input",
        required=True,
        help="Path to JSON input containing run_id, captures, and findings.",
    )
    parser.add_argument(
        "--budget-units",
        type=int,
        default=DEFAULT_TASK_BUDGET_UNITS,
        help="Task Budget token ceiling for the audit run.",
    )
    parser.add_argument(
        "--out-json",
        help="Optional output path for JSON audit report.",
    )
    parser.add_argument(
        "--out-md",
        help="Optional output path for dry-run GitHub Issue Markdown.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv if argv is not None else sys.argv[1:])
    payload = json.loads(Path(args.input).read_text(encoding="utf-8"))
    captures = [
        ScreenshotCaptureMetadata(**item)
        for item in payload.get("captures", [])
    ]
    findings = [
        UiAnomalyFinding(**item) for item in payload.get("findings", [])
    ]
    report = evaluate_audit_run(
        run_id=str(payload.get("run_id", "local-run")),
        captures=captures,
        findings=findings,
        budget_config=TaskBudgetConfig(max_total_units=args.budget_units),
    )

    report_json = json.dumps(asdict(report), ensure_ascii=False, indent=2)
    if args.out_json:
        Path(args.out_json).write_text(report_json + "\n", encoding="utf-8")
    if args.out_md:
        Path(args.out_md).write_text(report.issue_markdown, encoding="utf-8")
    if not args.out_json and not args.out_md:
        print(report_json)
    return 1 if report.budget_exceeded else 0


if __name__ == "__main__":
    raise SystemExit(main())
