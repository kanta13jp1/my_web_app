#!/usr/bin/env python3
"""Run the local quality gates shared by Lefthook and humans."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class GateCommand:
    name: str
    args: list[str]
    required_binary: str | None = None


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def has_deno_tests(root: Path) -> bool:
    return any((root / "supabase" / "functions").glob("**/*.test.ts"))


def include_browser_smoke() -> bool:
    if os.environ.get("CI", "").lower() == "true":
        return True
    return os.environ.get("CODEX_INCLUDE_BROWSER_SMOKE", "").lower() in {
        "1",
        "true",
        "yes",
    }


def base_commands() -> list[GateCommand]:
    python = sys.executable
    return [
        GateCommand(
            "minimal e2e gate tests",
            [python, "scripts/check_minimal_e2e_gate_test.py"],
        ),
        GateCommand(
            "codex ui qa playbook tests",
            [python, "scripts/check_codex_ui_qa_playbook_test.py"],
        ),
        GateCommand(
            "dynamic context injection tests",
            [python, "scripts/context_injection_check_test.py"],
        ),
        GateCommand(
            "no-verify bypass tests",
            [python, "scripts/check_no_verify_bypass_test.py"],
        ),
        GateCommand(
            "no-verify sentinel tests",
            [python, "scripts/no_verify_sentinel_test.py"],
        ),
        GateCommand(
            "edge function import check",
            [python, "scripts/check_edge_function_imports.py"],
        ),
        GateCommand(
            "github actions node runtime floor",
            [python, "scripts/check_github_actions_node_runtime.py"],
        ),
    ]


def fast_commands() -> list[GateCommand]:
    return [
        *base_commands(),
        GateCommand("flutter analyze", ["flutter", "analyze"], "flutter"),
        GateCommand(
            "deno lint edge functions",
            [
                "deno",
                "lint",
                "--config",
                "supabase/functions/deno.json",
                "supabase/functions/",
            ],
            "deno",
        ),
    ]


def full_commands(root: Path) -> list[GateCommand]:
    commands = [
        *fast_commands(),
        GateCommand(
            "dart format check",
            ["dart", "format", "--output=none", "--set-exit-if-changed", "."],
            "dart",
        ),
        GateCommand("flutter vm tests", ["flutter", "test", "--coverage"], "flutter"),
    ]
    if include_browser_smoke():
        commands.append(
            GateCommand(
                "flutter web import smoke",
                [
                    "flutter",
                    "test",
                    "--platform",
                    "chrome",
                    "test/web_import_smoke_test.dart",
                ],
                "flutter",
            )
        )
    if has_deno_tests(root):
        commands.append(
            GateCommand(
                "deno test edge functions",
                [
                    "deno",
                    "test",
                    "--allow-all",
                    "--no-check",
                    "--config",
                    "supabase/functions/deno.json",
                    "supabase/functions/",
                ],
                "deno",
            )
        )
    return commands


def resolve_args(command: GateCommand) -> list[str] | None:
    if command.required_binary is None:
        return command.args
    resolved = shutil.which(command.required_binary)
    if resolved is None:
        return None
    return [resolved, *command.args[1:]]


def command_env() -> dict[str, str]:
    env = os.environ.copy()
    for key in (
        "GIT_ALTERNATE_OBJECT_DIRECTORIES",
        "GIT_COMMON_DIR",
        "GIT_DIR",
        "GIT_INDEX_FILE",
        "GIT_OBJECT_DIRECTORY",
        "GIT_PREFIX",
        "GIT_QUARANTINE_PATH",
        "GIT_WORK_TREE",
        "CHROME_CRASHPAD_PIPE_NAME",
    ):
        env.pop(key, None)
    return env


def run_gate(command: GateCommand, root: Path) -> int:
    print(f"==> {command.name}", flush=True)
    resolved_args = resolve_args(command)
    if resolved_args is None:
        print(f"missing required command: {command.required_binary}", file=sys.stderr)
        return 127
    proc = subprocess.run(resolved_args, cwd=root, env=command_env(), check=False)
    if proc.returncode != 0:
        print(f"gate failed: {command.name} (exit {proc.returncode})", file=sys.stderr)
    return proc.returncode


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--fast", action="store_true", help="Run pre-commit quality gates.")
    mode.add_argument("--full", action="store_true", help="Run pre-push quality gates.")
    mode.add_argument("--list", action="store_true", help="Print the commands without running them.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = repo_root()
    commands = full_commands(root) if args.full else fast_commands()

    if args.list:
        for command in commands:
            print(f"{command.name}: {' '.join(command.args)}")
        return 0

    for command in commands:
        code = run_gate(command, root)
        if code != 0:
            return code
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
