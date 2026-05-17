#!/usr/bin/env python3
"""Build a dry-run provider execution manifest for the internal AI bench.

This script intentionally does not call provider APIs. It converts the
official-source bench template into a runbook that names the model slots, tasks,
expected environment variables, and safety notes needed before a live run.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from scripts import internal_ai_bench


PROVIDER_CONFIGS: dict[str, dict[str, Any]] = {
    "openai": {
        "required_env": ["OPENAI_API_KEY"],
        "live_calls_supported": False,
        "operator_note": "Use Responses API-compatible prompts after official model availability is rechecked.",
    },
    "anthropic": {
        "required_env": ["ANTHROPIC_API_KEY"],
        "live_calls_supported": False,
        "operator_note": "Use extended-thinking settings only when official docs and cost limits are attached.",
    },
    "google": {
        "required_env": ["GOOGLE_AI_API_KEY"],
        "live_calls_supported": False,
        "operator_note": "Resolve the exact Gemini model id from official docs at run time.",
    },
    "moonshot": {
        "required_env": ["MOONSHOT_API_KEY"],
        "live_calls_supported": False,
        "operator_note": "Treat Kimi candidates as unavailable until the official API model list is confirmed.",
    },
    "deepseek": {
        "required_env": ["DEEPSEEK_API_KEY"],
        "live_calls_supported": False,
        "operator_note": "Attach current pricing docs before scoring cost.",
    },
    "xai": {
        "required_env": ["XAI_API_KEY"],
        "live_calls_supported": False,
        "operator_note": "Use only documented model ids from xAI developer docs.",
    },
}


SYNTHETIC_INPUT_POLICY = (
    "Use synthetic repository fixtures only. Do not include asset balances, "
    "account ids, API keys, customer data, or live external-site credentials."
)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def task_ids(report: dict[str, Any], selected_tasks: list[str] | None) -> list[str]:
    tasks = report.get("tasks") if isinstance(report.get("tasks"), dict) else internal_ai_bench.TASKS
    available = list(tasks)
    if not selected_tasks:
        return available
    return [task for task in selected_tasks if task in tasks]


def selected_model_entries(
    report: dict[str, Any],
    providers: list[str] | None,
    include_partial: bool,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    provider_filter = {provider.lower() for provider in providers or []}
    runnable: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []

    for entry in internal_ai_bench.iter_model_entries(report):
        provider = str(entry.get("provider", "")).lower()
        label = internal_ai_bench.model_label(entry)
        status = str(entry.get("verification_status", "unverified")).lower()
        sources = internal_ai_bench.source_list(entry)

        if provider_filter and provider not in provider_filter:
            skipped.append(
                {
                    "label": label,
                    "verification_status": status,
                    "reason": "provider filter excluded this model",
                    "official_sources": sources,
                }
            )
            continue

        if status != internal_ai_bench.RANKABLE_STATUS and not (
            include_partial and status == "partial"
        ):
            skipped.append(
                {
                    "label": label,
                    "verification_status": status,
                    "reason": "not eligible for dry-run execution manifest",
                    "official_sources": sources,
                }
            )
            continue

        if not sources:
            skipped.append(
                {
                    "label": label,
                    "verification_status": status,
                    "reason": "official_sources are required",
                }
            )
            continue

        if provider not in PROVIDER_CONFIGS:
            skipped.append(
                {
                    "label": label,
                    "verification_status": status,
                    "reason": "provider config is not defined yet",
                    "official_sources": sources,
                }
            )
            continue

        runnable.append(entry)

    return runnable, skipped


def prompt_package(task_id: str, task: dict[str, Any], axes: dict[str, Any]) -> dict[str, Any]:
    return {
        "task_id": task_id,
        "track": task.get("track", "unknown"),
        "title": task.get("title", "unknown"),
        "required_proof": task.get("proof", ""),
        "instructions": [
            "Follow the repository patterns already present in the target files.",
            "Keep the diff small and explain any skipped requirement explicitly.",
            "Do not perform live deploys, external postings, or account changes.",
            "Return implementation notes, changed files, validation commands, and risk notes.",
        ],
        "scoring_axes": list(axes),
        "input_policy": SYNTHETIC_INPUT_POLICY,
    }


def build_manifest(
    report: dict[str, Any],
    selected_tasks: list[str] | None = None,
    providers: list[str] | None = None,
    include_partial: bool = False,
) -> dict[str, Any]:
    tasks = report.get("tasks") if isinstance(report.get("tasks"), dict) else internal_ai_bench.TASKS
    axes = report.get("axes") if isinstance(report.get("axes"), dict) else internal_ai_bench.AXES
    task_list = task_ids(report, selected_tasks)
    runnable, skipped = selected_model_entries(report, providers, include_partial)

    runs: list[dict[str, Any]] = []
    for entry in runnable:
        provider = str(entry.get("provider", "")).lower()
        config = PROVIDER_CONFIGS[provider]
        for task_id in task_list:
            task = tasks[task_id]
            runs.append(
                {
                    "run_id": f"{task_id}-{provider}-{entry.get('model')}",
                    "task_id": task_id,
                    "provider": provider,
                    "model": entry.get("model"),
                    "verification_status": entry.get("verification_status"),
                    "official_sources": internal_ai_bench.source_list(entry),
                    "required_env": config["required_env"],
                    "live_calls_supported": config["live_calls_supported"],
                    "operator_note": config["operator_note"],
                    "prompt_package": prompt_package(task_id, task, axes),
                }
            )

    return {
        "schema_version": 1,
        "generated_at": utc_now(),
        "issue": report.get("issue", "#2520"),
        "bench_id": report.get("bench_id", "template"),
        "mode": "dry_run_manifest",
        "live_provider_calls": False,
        "operator_approval_required_for_live": True,
        "policy": {
            "rank_only_verified_models": True,
            "fixed_strongest_model": "forbidden",
            "input_policy": SYNTHETIC_INPUT_POLICY,
            "routing_default_rule": (
                "#2521 routing defaults must cite scored bench results or remain feature-flagged."
            ),
        },
        "tasks": {task_id: prompt_package(task_id, tasks[task_id], axes) for task_id in task_list},
        "runs": runs,
        "skipped_models": skipped,
        "warnings": internal_ai_bench.validate_report(report),
    }


def render_sources(sources: list[str]) -> str:
    return "<br>".join(sources) if sources else "none"


def render_markdown(manifest: dict[str, Any]) -> str:
    lines: list[str] = [
        "# Internal AI Bench Provider Dry-Run Manifest",
        "",
        f"- Issue: `{manifest.get('issue', '#2520')}`",
        f"- Bench ID: `{manifest.get('bench_id', 'template')}`",
        f"- Generated at: `{manifest.get('generated_at')}`",
        "- Live provider calls: disabled",
        "- Operator approval required before any live API call",
        "",
        "This manifest prepares provider execution. It does not rank models and it does not call APIs.",
        "",
        "## Runnable Matrix",
        "",
        "| Run ID | Task | Provider | Model | Env | Sources |",
        "| --- | --- | --- | --- | --- | --- |",
    ]

    runs = manifest.get("runs", [])
    if runs:
        for run in runs:
            lines.append(
                "| {run_id} | `{task}` | `{provider}` | `{model}` | `{env}` | {sources} |".format(
                    run_id=run["run_id"],
                    task=run["task_id"],
                    provider=run["provider"],
                    model=run["model"],
                    env=", ".join(run["required_env"]),
                    sources=render_sources(run["official_sources"]),
                )
            )
    else:
        lines.append("| - | - | - | - | - | No eligible provider runs. |")

    lines.extend(
        [
            "",
            "## Skipped Models",
            "",
            "| Model | Verification | Reason | Sources |",
            "| --- | --- | --- | --- |",
        ]
    )
    skipped = manifest.get("skipped_models", [])
    if skipped:
        for entry in skipped:
            lines.append(
                "| `{label}` | `{status}` | {reason} | {sources} |".format(
                    label=entry["label"],
                    status=entry.get("verification_status", "unknown"),
                    reason=entry.get("reason", ""),
                    sources=render_sources(entry.get("official_sources", [])),
                )
            )
    else:
        lines.append("| - | - | None | - |")

    lines.extend(
        [
            "",
            "## Operator Rules",
            "",
            f"- {SYNTHETIC_INPUT_POLICY}",
            "- Keep #2521 routing defaults feature-flagged until a scored bench report is attached.",
            "- Recheck official model ids, pricing, and thinking/tool-use parameters immediately before live runs.",
            "- Record latency, cost, and validation evidence in the normalized bench report, not in this manifest.",
            "",
            "## Warnings",
            "",
        ]
    )
    warnings = manifest.get("warnings", [])
    if warnings:
        lines.extend(f"- {warning}" for warning in warnings)
    else:
        lines.append("- None.")

    lines.append("")
    return "\n".join(lines)


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="Input benchmark JSON.")
    parser.add_argument("--output-json", type=Path, help="Write dry-run manifest JSON.")
    parser.add_argument("--output-md", type=Path, help="Write dry-run manifest Markdown.")
    parser.add_argument("--task", action="append", help="Limit manifest to a task id such as B1.")
    parser.add_argument("--provider", action="append", help="Limit manifest to a provider key.")
    parser.add_argument(
        "--include-partial",
        action="store_true",
        help="Include partial verification rows in the dry-run manifest.",
    )
    parser.add_argument("--print-markdown", action="store_true", help="Print Markdown to stdout.")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero when warnings exist.")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    report = internal_ai_bench.load_report(args.input)
    manifest = build_manifest(
        report,
        selected_tasks=args.task,
        providers=args.provider,
        include_partial=args.include_partial,
    )
    markdown = render_markdown(manifest)

    if args.output_json:
        write_json(args.output_json, manifest)
    if args.output_md:
        write_text(args.output_md, markdown + "\n")
    if args.print_markdown:
        print(markdown)

    if args.strict and manifest["warnings"]:
        for warning in manifest["warnings"]:
            print(f"WARN: {warning}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
