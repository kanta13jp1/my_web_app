#!/usr/bin/env python3
"""Wait for deterministic PR validation checks before a protected gate passes."""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_REQUIRED_CHECKS = (
    "Lint, Format, and Test",
    "Security Check",
)

CI_IGNORED_PATTERNS = (
    "docs/**",
    ".github/*.md",
    ".github/**/*.md",
    ".github/ISSUE_TEMPLATE/**",
    ".github/PULL_REQUEST_TEMPLATE.md",
)


@dataclass(frozen=True)
class CheckResult:
    name: str
    status: str
    conclusion: str
    details_url: str


@dataclass(frozen=True)
class Evaluation:
    state: str
    passed: tuple[CheckResult, ...]
    pending: tuple[CheckResult, ...]
    failed: tuple[CheckResult, ...]
    missing: tuple[str, ...]


def normalize_path(path: str) -> str:
    normalized = path.replace("\ufeff", "").replace("\\", "/")
    while normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized


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


def is_ci_ignored_path(path: str) -> bool:
    normalized = normalize_path(path)
    return any(fnmatch.fnmatchcase(normalized, pattern) for pattern in CI_IGNORED_PATTERNS)


def ci_required_for_changes(changed_files: list[str]) -> bool:
    if not changed_files:
        return True
    return any(not is_ci_ignored_path(path) for path in changed_files)


def latest_check_runs_by_name(check_runs: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    latest: dict[str, dict[str, Any]] = {}
    for run in check_runs:
        name = run.get("name")
        if not isinstance(name, str):
            continue
        current = latest.get(name)
        if current is None or check_run_sort_key(run) >= check_run_sort_key(current):
            latest[name] = run
    return latest


def check_run_sort_key(run: dict[str, Any]) -> tuple[str, str, int]:
    return (
        str(run.get("started_at") or ""),
        str(run.get("completed_at") or ""),
        int(run.get("id") or 0),
    )


def result_from_run(name: str, run: dict[str, Any]) -> CheckResult:
    return CheckResult(
        name=name,
        status=str(run.get("status") or "unknown"),
        conclusion=str(run.get("conclusion") or ""),
        details_url=str(run.get("details_url") or run.get("html_url") or ""),
    )


def evaluate_check_runs(check_runs: list[dict[str, Any]], required_checks: list[str]) -> Evaluation:
    latest = latest_check_runs_by_name(check_runs)
    passed: list[CheckResult] = []
    pending: list[CheckResult] = []
    failed: list[CheckResult] = []
    missing: list[str] = []

    for name in required_checks:
        run = latest.get(name)
        if run is None:
            missing.append(name)
            continue

        result = result_from_run(name, run)
        if result.status != "completed":
            pending.append(result)
        elif result.conclusion == "success":
            passed.append(result)
        else:
            failed.append(result)

    if failed:
        state = "failure"
    elif pending or missing:
        state = "pending"
    else:
        state = "success"
    return Evaluation(
        state=state,
        passed=tuple(passed),
        pending=tuple(pending),
        failed=tuple(failed),
        missing=tuple(missing),
    )


def fetch_check_runs(repo: str, sha: str, token: str) -> list[dict[str, Any]]:
    url = f"https://api.github.com/repos/{repo}/commits/{sha}/check-runs?per_page=100"
    results: list[dict[str, Any]] = []
    while url:
        request = urllib.request.Request(
            url,
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {token}",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "my-web-app-deterministic-ci-gate",
            },
        )
        with urllib.request.urlopen(request, timeout=20) as response:
            payload = json.loads(response.read().decode("utf-8"))
            runs = payload.get("check_runs", [])
            if isinstance(runs, list):
                results.extend(item for item in runs if isinstance(item, dict))
            url = next_link(response.headers.get("Link", ""))
    return results


def next_link(link_header: str) -> str:
    for part in link_header.split(","):
        segment = part.strip()
        if 'rel="next"' not in segment:
            continue
        if segment.startswith("<") and ">;" in segment:
            return segment[1 : segment.index(">;")]
    return ""


def render_markdown(
    *,
    state: str,
    repo: str,
    sha: str,
    evaluation: Evaluation | None,
    required_checks: list[str],
    skipped: bool = False,
    error: str = "",
) -> str:
    icon = {
        "success": "PASS",
        "failure": "FAIL",
        "pending": "PENDING",
        "skipped": "SKIPPED",
    }.get(state, state.upper())
    lines = [
        "## Deterministic Validation Summary",
        "",
        f"- Result: `{icon}`",
        f"- Commit: `{sha}`",
        f"- Repository: `{repo}`",
        "- Required CI checks: "
        + ", ".join(f"`{name}`" for name in required_checks),
        "- CI contract: `flutter analyze`, `deno lint`, `dart format`, "
        "`flutter test --coverage`, web smoke/import checks, production web build, "
        "and security audit.",
    ]
    if skipped:
        lines.append("- Reason: CI workflow is path-ignored for this docs/template-only change.")
    if error:
        lines.append(f"- Error: `{error}`")
    if evaluation is not None:
        lines.extend(["", "| Check | Status | Conclusion |", "|---|---|---|"])
        for result in (*evaluation.passed, *evaluation.pending, *evaluation.failed):
            conclusion = result.conclusion or "n/a"
            if result.details_url:
                conclusion = f"[{conclusion}]({result.details_url})"
            lines.append(f"| `{result.name}` | `{result.status}` | {conclusion} |")
        for name in evaluation.missing:
            lines.append(f"| `{name}` | `missing` | n/a |")
    return "\n".join(lines).strip() + "\n"


def write_summary(path: str | None, content: str) -> None:
    if not path:
        return
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="owner/repo")
    parser.add_argument("--sha", required=True, help="PR head commit SHA")
    parser.add_argument("--changed-files", help="Newline-separated changed files")
    parser.add_argument(
        "--required-check",
        action="append",
        default=[],
        help="Required check-run name. May be passed more than once.",
    )
    parser.add_argument("--timeout-seconds", type=int, default=1800)
    parser.add_argument("--poll-seconds", type=int, default=20)
    parser.add_argument("--summary-md", help="Write a Markdown summary")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    required_checks = args.required_check or list(DEFAULT_REQUIRED_CHECKS)
    changed_files = read_changed_files(args.changed_files)

    if not ci_required_for_changes(changed_files):
        summary = render_markdown(
            state="skipped",
            repo=args.repo,
            sha=args.sha,
            evaluation=None,
            required_checks=required_checks,
            skipped=True,
        )
        write_summary(args.summary_md, summary)
        print(summary)
        return 0

    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        summary = render_markdown(
            state="failure",
            repo=args.repo,
            sha=args.sha,
            evaluation=None,
            required_checks=required_checks,
            error="GITHUB_TOKEN is not set",
        )
        write_summary(args.summary_md, summary)
        print(summary, file=sys.stderr)
        return 1

    deadline = time.monotonic() + max(0, args.timeout_seconds)
    last_evaluation: Evaluation | None = None
    while True:
        try:
            check_runs = fetch_check_runs(args.repo, args.sha, token)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            summary = render_markdown(
                state="failure",
                repo=args.repo,
                sha=args.sha,
                evaluation=last_evaluation,
                required_checks=required_checks,
                error=str(exc),
            )
            write_summary(args.summary_md, summary)
            print(summary, file=sys.stderr)
            return 1

        last_evaluation = evaluate_check_runs(check_runs, required_checks)
        if last_evaluation.state in {"success", "failure"}:
            summary = render_markdown(
                state=last_evaluation.state,
                repo=args.repo,
                sha=args.sha,
                evaluation=last_evaluation,
                required_checks=required_checks,
            )
            write_summary(args.summary_md, summary)
            print(summary)
            return 0 if last_evaluation.state == "success" else 1

        if time.monotonic() >= deadline:
            summary = render_markdown(
                state="failure",
                repo=args.repo,
                sha=args.sha,
                evaluation=last_evaluation,
                required_checks=required_checks,
                error="Timed out waiting for required CI checks",
            )
            write_summary(args.summary_md, summary)
            print(summary, file=sys.stderr)
            return 1

        time.sleep(max(1, args.poll_seconds))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
