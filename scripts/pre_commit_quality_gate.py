#!/usr/bin/env python3
"""Run quick checks for staged paths, then stamp the exact Git tree."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import no_verify_sentinel


def resolve_executable(command: list[str]) -> list[str]:
    """Resolve Windows batch shims before passing a command to CreateProcess."""
    if os.name != "nt" or not command:
        return command
    shim = shutil.which(f"{command[0]}.bat") or shutil.which(f"{command[0]}.cmd")
    return [shim, *command[1:]] if shim else command


def staged_files() -> list[str]:
    proc = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if proc.returncode != 0:
        print(proc.stderr, file=sys.stderr)
        raise SystemExit(proc.returncode)
    return [line.strip().replace("\\", "/") for line in proc.stdout.splitlines() if line.strip()]


def commands_for_paths(paths: list[str]) -> list[list[str]]:
    python = sys.executable
    commands: list[list[str]] = []
    policy_changed = any(
        path == "lefthook.yml"
        or path.startswith(".github/workflows/")
        or path.startswith("scripts/")
        for path in paths
    )
    if policy_changed:
        commands.extend(
            [
                [python, "scripts/classify_ci_changes_test.py"],
                [python, "scripts/cloud_ci_handoff_test.py"],
                [python, "scripts/cloud_first_route_test.py"],
                [python, "scripts/generate_infrastructure_map_test.py"],
                [python, "scripts/cicd_efficiency_test.py"],
                [python, "scripts/quality_gate_test.py"],
                [python, "scripts/pre_commit_quality_gate_test.py"],
                [python, "scripts/check_github_actions_node_runtime.py"],
                [python, "scripts/check_github_actions_python_inline.py"],
                [python, "scripts/check_github_actions_status_functions.py"],
                [python, "scripts/check_github_actions_powershell_splatting.py"],
            ]
        )

    edge_files = [
        path
        for path in paths
        if path.startswith("supabase/functions/")
        and path.endswith((".ts", ".tsx"))
        and Path(path).is_file()
    ]
    if edge_files:
        commands.append(
            ["deno", "lint", "--config", "supabase/functions/deno.json", *edge_files]
        )
        commands.append([python, "scripts/check_edge_function_imports.py"])

    if any(path.startswith("supabase/migrations/") for path in paths):
        commands.append([python, "scripts/check_migration_timestamps.py"])

    return commands


def main() -> int:
    for command in commands_for_paths(staged_files()):
        resolved = resolve_executable(command)
        print(f"[pre-commit] {' '.join(resolved)}", flush=True)
        result = subprocess.run(resolved, check=False)
        if result.returncode != 0:
            return result.returncode
    return no_verify_sentinel.mark_pre_commit()


if __name__ == "__main__":
    raise SystemExit(main())
