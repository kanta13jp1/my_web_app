#!/usr/bin/env python3
"""Dry-run checks for scripts/feature_review.py."""

from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "feature_review.py"
CONFIG = ROOT / "scripts" / "feature_review_config.json"


def load_module():
    spec = importlib.util.spec_from_file_location("feature_review", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("failed to load feature_review.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()
    config = module.load_config(CONFIG)

    assert module.select_feature_for_this_hour(config, hour_override=0) == "home"
    assert module.select_feature_for_this_hour(config, hour_override=5) == "ai_hub"
    assert module.issue_title_hash("home", "ui_bug", "button overlap") == module.issue_title_hash(
        "home",
        "ui_bug",
        "button overlap",
    )

    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--config",
            str(CONFIG),
            "--dry-run",
            "--targets",
            "ai_hub",
            "--skip-ai",
        ],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=120,
        check=False,
    )
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr, file=sys.stderr)
        return result.returncode
    assert "reviewing ai_hub" in result.stdout
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
