#!/usr/bin/env python3
"""Run Lefthook jobs without relying on Git Bash on Windows."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent


WINDOWS_EXECUTABLE_FALLBACKS: dict[str, tuple[Path, ...]] = {
    "flutter": (
        Path("C:/app/flutter/bin/flutter.bat"),
        Path("C:/app/flutter/bin/flutter"),
    ),
}


def resolve_command(command: list[str]) -> list[str]:
    executable = command[0]
    if os.name == "nt":
        for fallback in WINDOWS_EXECUTABLE_FALLBACKS.get(executable, ()):
            if fallback.exists():
                return [str(fallback), *command[1:]]

    if shutil.which(executable):
        return command

    return command


def run(command: list[str]) -> int:
    os.chdir(REPO_ROOT)
    command = resolve_command(command)
    print("$ " + " ".join(command))
    try:
        completed = subprocess.run(command, check=False)
    except FileNotFoundError as exc:
        print(f"missing executable: {exc.filename}", file=sys.stderr)
        return 127
    return completed.returncode


def command_for(job: str, args: list[str]) -> list[str]:
    python = sys.executable
    commands: dict[str, list[str]] = {
        "migration-collisions": [python, "scripts/check_migration_timestamps.py"],
        "edge-imports": [python, "scripts/check_edge_function_imports.py"],
        "no-verify-local": [python, "scripts/check_no_verify_policy.py", "--local"],
        "flutter-analyze": ["flutter", "analyze"],
        "edge-lint": [
            "deno",
            "lint",
            "--config",
            "supabase/functions/deno.json",
            "supabase/functions/",
        ],
        "migration-time-relative": [
            python,
            "scripts/check_migration_time_relative_check.py",
        ],
    }

    if job == "commit-msg":
        if not args:
            raise ValueError("commit-msg requires the commit message file path")
        return [python, "scripts/check_no_verify_policy.py", "--commit-msg-file", args[0]]

    if job not in commands:
        raise ValueError(f"unknown Lefthook job: {job}")
    return commands[job]


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv:
        print("usage: run_lefthook_job.py <job> [args...]", file=sys.stderr)
        return 2

    job, rest = argv[0], argv[1:]
    try:
        command = command_for(job, rest)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    return run(command)


if __name__ == "__main__":
    raise SystemExit(main())
