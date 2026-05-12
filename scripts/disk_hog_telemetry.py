#!/usr/bin/env python3
"""Emit Issue #1984 Tier 1.7 disk hog telemetry without pruning."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


MAJOR_DIRS = {
    "cache_codex_runtimes_MB": (".cache", "codex-runtimes"),
    "plugins_marketplaces_MB": (".claude", "plugins", "marketplaces"),
    "projects_MB": (".claude", "projects"),
    "vscode_workspaceStorage_MB": ("AppData", "Roaming", "Code", "User", "workspaceStorage"),
    "npm_cache_MB": ("AppData", "Local", "npm-cache"),
}
UNCOVERED_KEYS = (
    "cache_codex_runtimes_MB",
    "plugins_marketplaces_MB",
    "vscode_workspaceStorage_MB",
)


def directory_size_mb(path: Path) -> float:
    if not path.exists():
        return 0.0
    total = 0
    if path.is_file():
        try:
            return round(path.stat().st_size / (1024 * 1024), 1)
        except OSError:
            return 0.0
    for item in path.rglob("*"):
        try:
            if item.is_file():
                total += item.stat().st_size
        except OSError:
            continue
    return round(total / (1024 * 1024), 1)


def collect_metrics(home: Path) -> dict[str, float]:
    return {
        key: directory_size_mb(home.joinpath(*parts))
        for key, parts in MAJOR_DIRS.items()
    }


def uncovered_total_mb(metrics: dict[str, float]) -> float:
    return round(sum(metrics.get(key, 0.0) for key in UNCOVERED_KEYS), 1)


def warning_messages(metrics: dict[str, float], threshold_mb: float) -> list[str]:
    total = uncovered_total_mb(metrics)
    if total <= threshold_mb:
        return []
    return [f"hygiene-uncovered dirs total {total} MB > {threshold_mb:g} MB threshold"]


def append_log(path: Path, metrics: dict[str, float], warnings: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = [f"[{ts}]   {key}: {value} MB" for key, value in metrics.items()]
    lines.extend(f"[{ts}] WARN: {message}" for message in warnings)
    with path.open("a", encoding="utf-8") as handle:
        for line in lines:
            handle.write(line + "\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--threshold-mb", type=float, default=2000.0)
    parser.add_argument("--log-path", type=Path)
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    home = args.home.resolve(strict=False)
    metrics = collect_metrics(home)
    warnings = warning_messages(metrics, args.threshold_mb)
    payload: dict[str, Any] = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "home": str(home),
        "threshold_mb": args.threshold_mb,
        "metrics": metrics,
        "uncovered_total_mb": uncovered_total_mb(metrics),
        "warnings": warnings,
        "auto_prune": False,
    }
    if args.log_path:
        append_log(args.log_path, metrics, warnings)
        payload["log_path"] = str(args.log_path)
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        for key, value in metrics.items():
            print(f"{key}: {value} MB")
        for warning in warnings:
            print(f"WARN: {warning}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
