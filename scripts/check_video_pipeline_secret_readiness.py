#!/usr/bin/env python3
"""Validate NotebookLM video-pipeline secret readiness without exposing values."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Mapping


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_SECRETS = (
    "GITHUB_PAT",
    "NOTEBOOKLM_STORAGE_STATE_JSON",
    "ELEVENLABS_API_KEY",
    "YOUTUBE_CLIENT_SECRET_JSON",
    "YOUTUBE_TOKEN_JSON",
)

SECRET_DESCRIPTIONS = {
    "GITHUB_PAT": "checkout/push token for the auto-embed commit",
    "NOTEBOOKLM_STORAGE_STATE_JSON": "NotebookLM CLI storage_state.json payload",
    "ELEVENLABS_API_KEY": "ElevenLabs Scribe transcription API key",
    "YOUTUBE_CLIENT_SECRET_JSON": "YouTube OAuth client secret JSON",
    "YOUTUBE_TOKEN_JSON": "YouTube OAuth refresh token JSON",
}

PIPELINE_WORKFLOW_MARKERS = (
    "NotebookLM Video Pipeline",
    "Check required video pipeline secrets",
    "HAS_GITHUB_PAT",
    "secrets.GITHUB_PAT || github.token",
    "check_video_pipeline_secret_readiness.py",
)

READINESS_WORKFLOW_MARKERS = (
    "Video Pipeline Secret Readiness",
    "check_video_pipeline_secret_readiness.py",
    "--require-secrets",
    r"re:uses:\s*actions/upload-artifact@[0-9a-f]{40}\s+#\s*v7\b",
)

DOC_MARKERS: dict[str, tuple[str, ...]] = {
    "docs/GA_LAUNCH_READINESS_GATE_SPEC.md": REQUIRED_SECRETS,
    "docs/AI_VIDEO_PRINCIPLES.md": ("#1724", "YOUTUBE_TOKEN_JSON", "NOTEBOOKLM_STORAGE_STATE_JSON"),
}


def add_check(
    checks: list[dict[str, str]],
    name: str,
    ok: bool,
    detail: str,
    *,
    warn: bool = False,
) -> None:
    status = "pass" if ok else ("warn" if warn else "fail")
    checks.append({"name": name, "status": status, "detail": detail})


def secret_present(name: str, env: Mapping[str, str]) -> bool:
    flag_names = (f"HAS_{name}", f"VIDEO_PIPELINE_SECRET_{name}")
    truthy = {"1", "true", "yes", "present", "set"}
    falsy = {"", "0", "false", "no", "missing", "unset"}

    for flag_name in flag_names:
        if flag_name in env:
            value = env[flag_name].strip().lower()
            if value in truthy:
                return True
            if value in falsy:
                return False

    return bool(env.get(name, "").strip())


def check_file_contains(
    root: Path,
    relative: str,
    markers: tuple[str, ...],
    checks: list[dict[str, str]],
    name: str,
) -> None:
    path = root / relative
    if not path.exists():
        add_check(checks, name, False, f"{relative} is missing.")
        return

    content = path.read_text(encoding="utf-8")
    missing = [
        marker
        for marker in markers
        if not (
            re.search(marker.removeprefix("re:"), content)
            if marker.startswith("re:")
            else marker in content
        )
    ]
    add_check(
        checks,
        name,
        not missing,
        "all markers present" if not missing else f"missing markers: {', '.join(missing)}",
    )


def evaluate(
    *,
    root: Path,
    require_secrets: bool,
    env: Mapping[str, str],
) -> dict[str, object]:
    checks: list[dict[str, str]] = []
    secrets: list[dict[str, object]] = []

    check_file_contains(
        root,
        ".github/workflows/notebooklm-video-pipeline.yml",
        PIPELINE_WORKFLOW_MARKERS,
        checks,
        "notebooklm video pipeline preflight",
    )
    check_file_contains(
        root,
        ".github/workflows/video-pipeline-secret-readiness.yml",
        READINESS_WORKFLOW_MARKERS,
        checks,
        "video pipeline secret readiness workflow",
    )
    for relative, markers in DOC_MARKERS.items():
        check_file_contains(root, relative, markers, checks, f"doc markers: {relative}")

    missing_secrets: list[str] = []
    for secret in REQUIRED_SECRETS:
        present = secret_present(secret, env)
        secrets.append(
            {
                "name": secret,
                "present": present,
                "description": SECRET_DESCRIPTIONS[secret],
            }
        )
        if not present:
            missing_secrets.append(secret)

    if missing_secrets:
        add_check(
            checks,
            "video pipeline secrets",
            False,
            f"missing: {', '.join(missing_secrets)}",
            warn=not require_secrets,
        )
    else:
        add_check(
            checks,
            "video pipeline secrets",
            True,
            "all required video pipeline secret flags are present",
        )

    has_failures = any(check["status"] == "fail" for check in checks)
    has_warnings = any(check["status"] == "warn" for check in checks)
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "status": "fail" if has_failures else ("warn" if has_warnings else "pass"),
        "require_secrets": require_secrets,
        "checks": checks,
        "secrets": secrets,
        "missing_secrets": missing_secrets,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--require-secrets", action="store_true")
    parser.add_argument("--report", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = evaluate(
        root=args.root.resolve(),
        require_secrets=args.require_secrets,
        env=os.environ,
    )

    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 1 if report["status"] == "fail" else 0


if __name__ == "__main__":
    sys.exit(main())
