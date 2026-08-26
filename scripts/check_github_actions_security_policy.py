#!/usr/bin/env python3
"""Enforce least-privilege and supply-chain policy for GitHub Actions."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_ROOT = Path(".github/workflows")
TOP_LEVEL_KEY = re.compile(r"^(?P<key>[A-Za-z0-9_-]+):(?P<value>.*)$")
JOB_KEY = re.compile(r"^  (?P<name>[A-Za-z0-9_-]+):\s*(?:#.*)?$")
EXTERNAL_USE = re.compile(r"\buses:\s*(?P<target>[^\s#]+)")
FULL_SHA = re.compile(r"^[0-9a-f]{40}$")


@dataclass(frozen=True)
class Violation:
    path: Path
    line: int
    message: str


def workflow_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    return sorted([*root.glob("*.yml"), *root.glob("*.yaml")])


def _top_level_blocks(lines: list[str]) -> dict[str, tuple[int, int, str]]:
    blocks: dict[str, tuple[int, int, str]] = {}
    starts: list[tuple[int, str, str]] = []
    for index, line in enumerate(lines):
        match = TOP_LEVEL_KEY.match(line)
        if match:
            starts.append((index, match.group("key"), match.group("value").strip()))
    for offset, (start, key, value) in enumerate(starts):
        end = starts[offset + 1][0] if offset + 1 < len(starts) else len(lines)
        blocks[key] = (start, end, value)
    return blocks


def _job_blocks(lines: list[str]) -> list[tuple[str, int, int]]:
    jobs = _top_level_blocks(lines).get("jobs")
    if jobs is None:
        return []
    _, jobs_end, _ = jobs
    starts: list[tuple[str, int]] = []
    for index in range(jobs[0] + 1, jobs_end):
        match = JOB_KEY.match(lines[index])
        if match:
            starts.append((match.group("name"), index))
    return [
        (name, start, starts[offset + 1][1] if offset + 1 < len(starts) else jobs_end)
        for offset, (name, start) in enumerate(starts)
    ]


def find_violations(paths: list[Path]) -> list[Violation]:
    violations: list[Violation] = []
    actionlint_configured = False

    for path in paths:
        lines = path.read_text(encoding="utf-8-sig").splitlines()
        blocks = _top_level_blocks(lines)

        concurrency = blocks.get("concurrency")
        if concurrency is None:
            violations.append(Violation(path, 1, "missing workflow concurrency"))
        else:
            start, end, _ = concurrency
            if not any(
                re.match(r"^  cancel-in-progress:\s*\S", line)
                for line in lines[start + 1 : end]
            ):
                violations.append(
                    Violation(path, start + 1, "concurrency must set cancel-in-progress")
                )

        permissions = blocks.get("permissions")
        if permissions is None:
            violations.append(
                Violation(path, 1, "missing workflow-level `permissions: {}` default deny")
            )
        elif permissions[2] != "{}":
            violations.append(
                Violation(
                    path,
                    permissions[0] + 1,
                    "workflow-level permissions must be exactly `permissions: {}`",
                )
            )

        for name, start, end in _job_blocks(lines):
            job_lines = lines[start + 1 : end]
            if not any(re.match(r"^    permissions:\s*", line) for line in job_lines):
                violations.append(
                    Violation(path, start + 1, f"job `{name}` must declare permissions")
                )
            reusable_call = any(re.match(r"^    uses:\s*", line) for line in job_lines)
            if not reusable_call and not any(
                re.match(r"^    timeout-minutes:\s*[1-9][0-9]*\s*(?:#.*)?$", line)
                for line in job_lines
            ):
                violations.append(
                    Violation(path, start + 1, f"job `{name}` must declare timeout-minutes")
                )

        for index, line in enumerate(lines):
            match = EXTERNAL_USE.search(line)
            if not match:
                continue
            target = match.group("target")
            if target.startswith("./") or target.startswith("docker://"):
                continue
            _, separator, revision = target.rpartition("@")
            if not separator or not FULL_SHA.fullmatch(revision):
                violations.append(
                    Violation(
                        path,
                        index + 1,
                        f"external action must use a full commit SHA: {target}",
                    )
                )

        if any("actionlint" in line and not line.lstrip().startswith("#") for line in lines):
            actionlint_configured = True

    if paths and not actionlint_configured:
        violations.append(
            Violation(paths[0], 1, "no GitHub Actions workflow runs actionlint")
        )
    return violations


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    args = parser.parse_args(argv)

    files = workflow_files(args.root)
    if not files:
        print(f"no workflow files found under {args.root}", file=sys.stderr)
        return 1

    violations = find_violations(files)
    if violations:
        for violation in violations:
            print(f"{violation.path}:{violation.line}: {violation.message}")
        return 1

    print(f"OK: checked {len(files)} workflows for GitHub Actions security policy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
