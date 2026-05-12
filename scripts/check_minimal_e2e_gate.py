#!/usr/bin/env python3
"""Validate that an AI-generated PR declares a minimal black-box E2E plan.

This guard is intentionally lightweight. It does not try to judge the quality of
the E2E test itself; it makes the PR author state the contract that reviewers
should inspect: implementation-independent, about three I/O cases, and either an
E2E file or a visible exception reason.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


APP_CODE_PREFIXES = (
    "lib/",
    "supabase/functions/",
    "web/",
    "android/",
    "ios/",
    "windows/",
    "macos/",
    "linux/",
)

NON_APP_PREFIXES = (
    ".github/",
    "docs/",
    "scripts/",
    "test/scripts/",
)

E2E_PREFIXES = (
    "integration_test/",
    "test/e2e/",
)

IMPLEMENTATION_INDEPENDENT_PATTERNS = (
    r"implementation[- ]detail independent",
    r"implementation independent",
    r"black[- ]box",
    r"i/o",
    r"input/output",
    r"実装詳細に依存しない",
    r"入出力",
)

MINIMAL_CASE_PATTERNS = (
    r"\b3\s*cases?\b",
    r"\bthree\s*cases?\b",
    r"3ケース",
    r"3件",
    r"最小限",
    r"minimal",
)

E2E_DECLARATION_PATTERNS = (
    r"flutter integration test",
    r"integration_test",
    r"playwright",
    r"e2e",
    r"エンドツーエンド",
)

EXCEPTION_PATTERNS = (
    r"e2e[- ]exception",
    r"minimal e2e exception",
    r"e2e exempt",
    r"e2e不要",
    r"e2e例外",
)


def normalize_path(path: str) -> str:
    return path.replace("\ufeff", "").replace("\\", "/").lstrip("./")


def read_changed_files(path: str | None) -> list[str]:
    if not path:
        return []
    source = Path(path)
    if not source.exists():
        return []
    return [
        normalize_path(line.strip())
        for line in source.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def event_payload(path: str | None) -> dict[str, Any]:
    if not path:
        return {}
    source = Path(path)
    if not source.exists():
        return {}
    return json.loads(source.read_text(encoding="utf-8"))


def pr_body(payload: dict[str, Any], body_file: str | None) -> str:
    if body_file:
      source = Path(body_file)
      if source.exists():
          return source.read_text(encoding="utf-8")
    pr = payload.get("pull_request")
    if isinstance(pr, dict):
        body = pr.get("body")
        return body if isinstance(body, str) else ""
    return ""


def pr_labels(payload: dict[str, Any]) -> set[str]:
    pr = payload.get("pull_request")
    labels = pr.get("labels", []) if isinstance(pr, dict) else []
    names: set[str] = set()
    for item in labels:
        if isinstance(item, dict) and isinstance(item.get("name"), str):
            names.add(item["name"].lower())
    return names


def has_any(patterns: tuple[str, ...], text: str) -> bool:
    return any(re.search(pattern, text, flags=re.IGNORECASE) for pattern in patterns)


def has_visible_exception_reason(text: str) -> bool:
    for line in text.splitlines():
        if not has_any(EXCEPTION_PATTERNS, line):
            continue
        cleaned = re.sub(r"<!--.*?-->", "", line).strip()
        cleaned = re.sub(r"(?i)e2e[- ]exception|minimal e2e exception|e2e exempt", "", cleaned)
        cleaned = cleaned.replace("e2e不要", "").replace("e2e例外", "")
        cleaned = cleaned.strip(" :-[]\t")
        if len(cleaned) >= 8:
            return True
    return False


def is_app_code_change(path: str) -> bool:
    path = normalize_path(path)
    if any(path.startswith(prefix) for prefix in NON_APP_PREFIXES):
        return False
    return any(path.startswith(prefix) for prefix in APP_CODE_PREFIXES)


def has_e2e_file(changed_files: list[str]) -> bool:
    return any(
        normalize_path(path).startswith(E2E_PREFIXES)
        for path in changed_files
    )


def validate(body: str, changed_files: list[str], labels: set[str]) -> tuple[bool, list[str], bool]:
    lowered_labels = {label.lower() for label in labels}
    if lowered_labels & {"docs-only", "no-e2e-needed"}:
        return True, ["Skipped by explicit PR label."], False

    app_change = any(is_app_code_change(path) for path in changed_files)
    messages: list[str] = []

    if not body.strip():
        messages.append("PR body is empty; add a Minimal E2E Gate section.")
        return False, messages, app_change

    if not has_any(IMPLEMENTATION_INDEPENDENT_PATTERNS, body):
        messages.append(
            "PR body must state that the E2E test is implementation-detail independent."
        )
    if not has_any(MINIMAL_CASE_PATTERNS, body):
        messages.append("PR body must state the plan is minimal, about three I/O cases.")
    if not has_any(E2E_DECLARATION_PATTERNS, body):
        messages.append("PR body must mention the E2E mechanism, such as integration_test or Playwright.")

    exception_declared = has_visible_exception_reason(body)
    if app_change and not has_e2e_file(changed_files) and not exception_declared:
        messages.append(
            "Application-code PRs must add integration_test/ or test/e2e/ files, "
            "or include an explicit E2E-Exception reason."
        )

    return not messages, messages, app_change


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event", help="GitHub event JSON path")
    parser.add_argument("--body-file", help="Local markdown file to validate")
    parser.add_argument("--changed-files", help="Newline-separated changed file list")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    payload = event_payload(args.event)
    body = pr_body(payload, args.body_file)
    changed_files = read_changed_files(args.changed_files)
    labels = pr_labels(payload)

    ok, messages, app_change = validate(body, changed_files, labels)
    print(f"Minimal E2E gate: {'PASS' if ok else 'FAIL'}")
    print(f"Application-code change detected: {'yes' if app_change else 'no'}")
    if changed_files:
        print(f"Changed files inspected: {len(changed_files)}")
    for message in messages:
        print(f"- {message}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
