#!/usr/bin/env python3
"""Run the local quality gates shared by Lefthook and humans."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO


TIMEOUT_EXIT_CODE = 124
LOCK_TIMEOUT_EXIT_CODE = 75
DEFAULT_COMMAND_TIMEOUT_SECONDS = 300.0
DEFAULT_ANALYZER_LOCK_WAIT_SECONDS = 30.0


@dataclass(frozen=True)
class GateCommand:
    name: str
    args: list[str]
    required_binary: str | None = None
    timeout_seconds: float = DEFAULT_COMMAND_TIMEOUT_SECONDS
    resource_lock: str | None = None


@dataclass(frozen=True)
class GateResult:
    name: str
    command: list[str]
    returncode: int
    status: str
    elapsed_seconds: float
    timeout_seconds: float
    cleanup: dict[str, object]
    lock_path: str | None = None


class ResourceLockTimeout(RuntimeError):
    """Raised when a shared local resource cannot be leased in time."""


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


def flutter_vm_test_concurrency(platform_name: str | None = None) -> int:
    """Keep the long Windows VM suite on one stable test worker."""
    resolved_platform = os.name if platform_name is None else platform_name
    return 1 if resolved_platform == "nt" else 2


def base_commands() -> list[GateCommand]:
    python = sys.executable
    return [
        GateCommand(
            "minimal e2e gate tests",
            [python, "scripts/check_minimal_e2e_gate_test.py"],
        ),
        GateCommand(
            "dependabot pub policy tests",
            [python, "scripts/check_dependabot_pub_policy_test.py"],
        ),
        GateCommand(
            "high-risk ultrareview gate tests",
            [python, "scripts/check_high_risk_ultrareview_gate_test.py"],
        ),
        GateCommand(
            "codex ui qa playbook tests",
            [python, "scripts/check_codex_ui_qa_playbook_test.py"],
        ),
        GateCommand(
            "ai tool update routing tests",
            [python, "scripts/check_ai_tool_update_routing_test.py"],
        ),
        GateCommand(
            "dynamic context injection tests",
            [python, "scripts/context_injection_check_test.py"],
        ),
        GateCommand(
            "mcp container isolation contract",
            [python, "scripts/check_mcp_container_isolation.py"],
        ),
        GateCommand(
            "mcp container isolation tests",
            [python, "scripts/check_mcp_container_isolation_test.py"],
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
            "deterministic PR CI gate tests",
            [python, "scripts/check_pr_deterministic_ci_test.py"],
        ),
        GateCommand(
            "quality gate resource bounds tests",
            [python, "scripts/quality_gate_test.py"],
        ),
        GateCommand(
            "edge function import check",
            [python, "scripts/check_edge_function_imports.py"],
        ),
        GateCommand(
            "github actions node runtime floor",
            [python, "scripts/check_github_actions_node_runtime.py"],
        ),
        GateCommand(
            "github actions status-function placement",
            [python, "scripts/check_github_actions_status_functions.py"],
        ),
        GateCommand(
            "github actions PowerShell splatting",
            [python, "scripts/check_github_actions_powershell_splatting.py"],
        ),
        GateCommand(
            "wbs sync timeout resilience",
            [python, "scripts/check_wbs_sync_timeout_resilience.py"],
        ),
    ]


def fast_commands() -> list[GateCommand]:
    return [
        *base_commands(),
        GateCommand(
            "flutter analyze",
            ["flutter", "analyze"],
            "flutter",
            timeout_seconds=300,
            resource_lock="flutter-analyzer",
        ),
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
            timeout_seconds=300,
        ),
    ]


def full_commands(root: Path) -> list[GateCommand]:
    commands = [
        *fast_commands(),
        GateCommand(
            "dart format check",
            ["dart", "format", "--output=none", "--set-exit-if-changed", "."],
            "dart",
            timeout_seconds=300,
        ),
        GateCommand(
            "flutter vm tests",
            [
                "flutter",
                "test",
                "--coverage",
                f"--concurrency={flutter_vm_test_concurrency()}",
            ],
            "flutter",
            timeout_seconds=3600,
        ),
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
                timeout_seconds=900,
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
                timeout_seconds=1200,
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


def _git_common_dir(root: Path) -> Path:
    override = os.environ.get("QUALITY_GATE_LOCK_ROOT")
    if override:
        return Path(override).resolve()
    result = subprocess.run(
        ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
        cwd=root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=10,
        check=False,
    )
    if result.returncode == 0 and result.stdout.strip():
        return Path(result.stdout.strip()).resolve()
    return (root / ".git").resolve()


def resource_lock_path(root: Path, resource: str) -> Path:
    path = _git_common_dir(root) / "codex-quality" / f"{resource}.lock"
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def _try_lock_windows(handle: BinaryIO) -> None:
    import msvcrt

    handle.seek(0, os.SEEK_END)
    if handle.tell() == 0:
        handle.write(b"\0")
        handle.flush()
    handle.seek(0)
    msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)


def _unlock_windows(handle: BinaryIO) -> None:
    import msvcrt

    handle.seek(0)
    msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)


def _try_lock_posix(handle: BinaryIO) -> None:
    import fcntl

    fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)


def _unlock_posix(handle: BinaryIO) -> None:
    import fcntl

    fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


class ResourceLock:
    def __init__(
        self,
        path: Path,
        wait_seconds: float,
        *,
        platform_name: str | None = None,
    ) -> None:
        self.path = path
        self.wait_seconds = max(0.0, wait_seconds)
        self.platform_name = os.name if platform_name is None else platform_name
        self.handle: BinaryIO | None = None

    def __enter__(self) -> "ResourceLock":
        deadline = time.monotonic() + self.wait_seconds
        handle = self.path.open("a+b")
        while True:
            try:
                if self.platform_name == "nt":
                    _try_lock_windows(handle)
                else:
                    _try_lock_posix(handle)
                self.handle = handle
                return self
            except OSError as error:
                if time.monotonic() >= deadline:
                    handle.close()
                    raise ResourceLockTimeout(
                        f"resource lock unavailable after {self.wait_seconds:.1f}s: {self.path}"
                    ) from error
                time.sleep(min(0.1, max(0.0, deadline - time.monotonic())))

    def __exit__(self, *_args: object) -> None:
        if self.handle is None:
            return
        try:
            if self.platform_name == "nt":
                _unlock_windows(self.handle)
            else:
                _unlock_posix(self.handle)
        finally:
            self.handle.close()
            self.handle = None


def terminate_owned_process_tree(
    proc: subprocess.Popen[bytes],
    *,
    platform_name: str | None = None,
) -> dict[str, object]:
    resolved_platform = os.name if platform_name is None else platform_name
    result: dict[str, object] = {
        "attempted": True,
        "method": "taskkill" if resolved_platform == "nt" else "process_group",
        "root_pid": proc.pid,
        "succeeded": False,
    }
    try:
        if resolved_platform == "nt":
            cleanup = subprocess.run(
                ["taskkill", "/PID", str(proc.pid), "/T", "/F"],
                capture_output=True,
                timeout=15,
                check=False,
            )
            result["cleanup_returncode"] = cleanup.returncode
        else:
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
        proc.wait(timeout=5)
        result["succeeded"] = proc.poll() is not None
    except (OSError, subprocess.SubprocessError) as error:
        result["error"] = str(error)
    return result


def execute_gate(
    command: GateCommand,
    root: Path,
    *,
    timeout_seconds: float | None = None,
    lock_wait_seconds: float = DEFAULT_ANALYZER_LOCK_WAIT_SECONDS,
) -> GateResult:
    resolved_args = resolve_args(command)
    timeout = command.timeout_seconds if timeout_seconds is None else timeout_seconds
    started = time.monotonic()
    if resolved_args is None:
        return GateResult(
            command.name,
            command.args,
            127,
            "missing_command",
            0.0,
            timeout,
            {"attempted": False},
        )

    lock_path = (
        resource_lock_path(root, command.resource_lock)
        if command.resource_lock
        else None
    )
    lock = ResourceLock(lock_path, lock_wait_seconds) if lock_path else None
    try:
        if lock:
            lock.__enter__()
    except ResourceLockTimeout:
        return GateResult(
            command.name,
            resolved_args,
            LOCK_TIMEOUT_EXIT_CODE,
            "lock_timeout",
            round(time.monotonic() - started, 3),
            timeout,
            {"attempted": False},
            str(lock_path),
        )

    creation: dict[str, object] = {}
    if os.name == "nt":
        creation["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        creation["start_new_session"] = True
    cleanup: dict[str, object] = {"attempted": False}
    try:
        proc = subprocess.Popen(
            resolved_args,
            cwd=root,
            env=command_env(),
            **creation,
        )
        try:
            returncode = proc.wait(timeout=timeout)
            status = "passed" if returncode == 0 else "failed"
        except subprocess.TimeoutExpired:
            cleanup = terminate_owned_process_tree(proc)
            returncode = TIMEOUT_EXIT_CODE
            status = "timeout"
        return GateResult(
            command.name,
            resolved_args,
            returncode,
            status,
            round(time.monotonic() - started, 3),
            timeout,
            cleanup,
            str(lock_path) if lock_path else None,
        )
    finally:
        if lock:
            lock.__exit__(None, None, None)


def run_gate(
    command: GateCommand,
    root: Path,
    *,
    timeout_seconds: float | None = None,
    lock_wait_seconds: float = DEFAULT_ANALYZER_LOCK_WAIT_SECONDS,
    recovery_command: str,
) -> int:
    print(f"==> {command.name}", flush=True)
    result = execute_gate(
        command,
        root,
        timeout_seconds=timeout_seconds,
        lock_wait_seconds=lock_wait_seconds,
    )
    payload = {
        "event": "quality_gate_command",
        "name": result.name,
        "command": result.command,
        "status": result.status,
        "exit_code": result.returncode,
        "elapsed_seconds": result.elapsed_seconds,
        "timeout_seconds": result.timeout_seconds,
        "cleanup": result.cleanup,
        "lock_path": result.lock_path,
        "recovery_command": recovery_command,
    }
    print(json.dumps(payload, ensure_ascii=False), flush=True)
    if result.returncode != 0:
        print(
            f"gate failed: {command.name} ({result.status}, exit {result.returncode}); "
            f"recovery: {recovery_command}",
            file=sys.stderr,
        )
    return result.returncode


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--fast", action="store_true", help="Run pre-commit quality gates.")
    mode.add_argument("--full", action="store_true", help="Run pre-push quality gates.")
    mode.add_argument("--list", action="store_true", help="Print the commands without running them.")
    mode.add_argument(
        "--analyze-only",
        action="store_true",
        help="Run one supervised Flutter analysis, optionally scoped to paths.",
    )
    parser.add_argument("paths", nargs="*", help="Paths for --analyze-only.")
    parser.add_argument(
        "--command-timeout-seconds",
        type=float,
        help="Override each command timeout (must be positive).",
    )
    parser.add_argument(
        "--lock-wait-seconds",
        type=float,
        default=DEFAULT_ANALYZER_LOCK_WAIT_SECONDS,
        help="Bounded wait for the cross-worktree analyzer lock.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = repo_root()
    if args.command_timeout_seconds is not None and args.command_timeout_seconds <= 0:
        raise SystemExit("--command-timeout-seconds must be positive")
    if args.lock_wait_seconds < 0:
        raise SystemExit("--lock-wait-seconds must be non-negative")
    if args.paths and not args.analyze_only:
        raise SystemExit("paths are accepted only with --analyze-only")
    if args.analyze_only:
        commands = [
            GateCommand(
                "flutter analyze",
                ["flutter", "analyze", "--no-pub", *args.paths],
                "flutter",
                timeout_seconds=300,
                resource_lock="flutter-analyzer",
            )
        ]
    else:
        commands = full_commands(root) if args.full else fast_commands()

    mode_args = "--full" if args.full else "--fast"
    if args.analyze_only:
        mode_args = "--analyze-only " + " ".join(args.paths)
    recovery_command = f"{sys.executable} scripts/quality_gate.py {mode_args}".strip()

    if args.list:
        for command in commands:
            print(
                f"{command.name}: {' '.join(command.args)} "
                f"(timeout={command.timeout_seconds:g}s, lock={command.resource_lock or 'none'})"
            )
        return 0

    for command in commands:
        code = run_gate(
            command,
            root,
            timeout_seconds=args.command_timeout_seconds,
            lock_wait_seconds=args.lock_wait_seconds,
            recovery_command=recovery_command,
        )
        if code != 0:
            return code
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
