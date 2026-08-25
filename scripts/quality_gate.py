#!/usr/bin/env python3
"""Run the local quality gates shared by Lefthook and humans."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO


DEFAULT_COMMAND_TIMEOUT_SECONDS = 300.0
DEFAULT_ANALYZE_TIMEOUT_SECONDS = 180.0
DEFAULT_ANALYZER_LOCK_TIMEOUT_SECONDS = 30.0
TIMEOUT_EXIT_CODE = 124
LOCK_TIMEOUT_EXIT_CODE = 75


@dataclass(frozen=True)
class GateCommand:
    name: str
    args: list[str]
    required_binary: str | None = None
    timeout_seconds: float = DEFAULT_COMMAND_TIMEOUT_SECONDS
    serialize_analyzer: bool = False


@dataclass(frozen=True)
class CommandResult:
    returncode: int
    elapsed_seconds: float
    timed_out: bool
    cleanup_result: str


class AnalyzerLockTimeout(RuntimeError):
    pass


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


def env_seconds(name: str, default: float) -> float:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    try:
        value = float(raw)
    except ValueError:
        return default
    return value if value > 0 else default


def shared_git_dir(root: Path) -> Path:
    dot_git = root / ".git"
    if dot_git.is_dir():
        return dot_git
    if dot_git.is_file():
        first_line = dot_git.read_text(encoding="utf-8").splitlines()[0]
        prefix = "gitdir:"
        if first_line.lower().startswith(prefix):
            git_dir = Path(first_line[len(prefix) :].strip())
            if not git_dir.is_absolute():
                git_dir = (root / git_dir).resolve()
            if git_dir.parent.name == "worktrees":
                return git_dir.parent.parent
            return git_dir
    return root / ".git"


def analyzer_lock_path(root: Path) -> Path:
    state_dir = shared_git_dir(root) / "codex-quality-gate"
    state_dir.mkdir(parents=True, exist_ok=True)
    return state_dir / "analyzer.lock"


def _try_lock(handle: BinaryIO, platform_name: str) -> bool:
    handle.seek(0)
    if platform_name == "nt":
        import msvcrt

        try:
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError:
            return False
        return True

    import fcntl

    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return False
    return True


def _unlock(handle: BinaryIO, platform_name: str) -> None:
    handle.seek(0)
    if platform_name == "nt":
        import msvcrt

        msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        return

    import fcntl

    fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


class AnalyzerLock:
    def __init__(
        self,
        path: Path,
        timeout_seconds: float,
        *,
        platform_name: str | None = None,
    ) -> None:
        self.path = path
        self.timeout_seconds = timeout_seconds
        self.platform_name = os.name if platform_name is None else platform_name
        self.handle: BinaryIO | None = None

    def __enter__(self) -> "AnalyzerLock":
        self.path.parent.mkdir(parents=True, exist_ok=True)
        handle = self.path.open("a+b")
        if self.path.stat().st_size == 0:
            handle.write(b"\0")
            handle.flush()
        deadline = time.monotonic() + self.timeout_seconds
        while not _try_lock(handle, self.platform_name):
            if time.monotonic() >= deadline:
                handle.close()
                raise AnalyzerLockTimeout(
                    f"analyzer lock unavailable after {self.timeout_seconds:.1f}s: {self.path}"
                )
            time.sleep(0.05)
        self.handle = handle
        return self

    def __exit__(self, *_: object) -> None:
        if self.handle is None:
            return
        try:
            _unlock(self.handle, self.platform_name)
        finally:
            self.handle.close()
            self.handle = None


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
            timeout_seconds=env_seconds(
                "QUALITY_GATE_ANALYZE_TIMEOUT_SECONDS",
                DEFAULT_ANALYZE_TIMEOUT_SECONDS,
            ),
            serialize_analyzer=True,
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
        GateCommand(
            "flutter vm tests",
            [
                "flutter",
                "test",
                "--coverage",
                f"--concurrency={flutter_vm_test_concurrency()}",
            ],
            "flutter",
            timeout_seconds=1800.0,
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
                timeout_seconds=900.0,
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


def terminate_owned_process_tree(
    proc: subprocess.Popen[bytes],
    *,
    platform_name: str | None = None,
) -> str:
    resolved_platform = os.name if platform_name is None else platform_name
    if proc.poll() is not None:
        return "already_exited"
    if resolved_platform == "nt":
        cleanup = subprocess.run(
            ["taskkill", "/PID", str(proc.pid), "/T", "/F"],
            capture_output=True,
            check=False,
        )
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)
            return f"taskkill_exit_{cleanup.returncode}_then_parent_kill"
        return f"taskkill_exit_{cleanup.returncode}"

    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        return "process_group_already_exited"
    try:
        proc.wait(timeout=2)
        return "process_group_terminated"
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        proc.wait(timeout=5)
        return "process_group_killed"


def run_process(
    args: list[str],
    root: Path,
    timeout_seconds: float,
    *,
    platform_name: str | None = None,
) -> CommandResult:
    resolved_platform = os.name if platform_name is None else platform_name
    popen_kwargs: dict[str, object] = {
        "cwd": root,
        "env": command_env(),
    }
    if resolved_platform == "nt":
        popen_kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        popen_kwargs["start_new_session"] = True
    started = time.monotonic()
    proc = subprocess.Popen(args, **popen_kwargs)
    try:
        returncode = proc.wait(timeout=timeout_seconds)
        return CommandResult(
            returncode=returncode,
            elapsed_seconds=time.monotonic() - started,
            timed_out=False,
            cleanup_result="not_needed",
        )
    except subprocess.TimeoutExpired:
        cleanup_result = terminate_owned_process_tree(
            proc,
            platform_name=resolved_platform,
        )
        return CommandResult(
            returncode=TIMEOUT_EXIT_CODE,
            elapsed_seconds=time.monotonic() - started,
            timed_out=True,
            cleanup_result=cleanup_result,
        )


def emit_result(
    command: GateCommand,
    result: CommandResult,
    *,
    lock_status: str,
) -> None:
    print(
        json.dumps(
            {
                "event": "quality_gate_command",
                "name": command.name,
                "command": shlex.join(command.args),
                "elapsed_seconds": round(result.elapsed_seconds, 3),
                "timeout_seconds": command.timeout_seconds,
                "returncode": result.returncode,
                "timed_out": result.timed_out,
                "cleanup_result": result.cleanup_result,
                "analyzer_lock": lock_status,
                "recovery_command": shlex.join(command.args),
            },
            ensure_ascii=False,
            sort_keys=True,
        ),
        flush=True,
    )


def run_gate(command: GateCommand, root: Path) -> int:
    print(f"==> {command.name}", flush=True)
    resolved_args = resolve_args(command)
    if resolved_args is None:
        print(f"missing required command: {command.required_binary}", file=sys.stderr)
        return 127
    lock_status = "not_required"
    try:
        if command.serialize_analyzer:
            lock_timeout = env_seconds(
                "QUALITY_GATE_ANALYZER_LOCK_TIMEOUT_SECONDS",
                DEFAULT_ANALYZER_LOCK_TIMEOUT_SECONDS,
            )
            with AnalyzerLock(analyzer_lock_path(root), lock_timeout):
                lock_status = "acquired"
                result = run_process(
                    resolved_args,
                    root,
                    command.timeout_seconds,
                )
        else:
            result = run_process(
                resolved_args,
                root,
                command.timeout_seconds,
            )
    except AnalyzerLockTimeout as error:
        print(str(error), file=sys.stderr)
        result = CommandResult(
            returncode=LOCK_TIMEOUT_EXIT_CODE,
            elapsed_seconds=lock_timeout,
            timed_out=False,
            cleanup_result="not_started",
        )
        lock_status = "timeout"
    emit_result(command, result, lock_status=lock_status)
    if result.returncode != 0:
        print(
            f"gate failed: {command.name} (exit {result.returncode})",
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
        "--analyze-files",
        nargs="+",
        metavar="PATH",
        help="Run one bounded, serialized Flutter analysis over explicit paths.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = repo_root()
    if args.analyze_files:
        commands = [
            GateCommand(
                "flutter analyze targeted",
                ["flutter", "analyze", "--no-pub", *args.analyze_files],
                "flutter",
                timeout_seconds=env_seconds(
                    "QUALITY_GATE_ANALYZE_TIMEOUT_SECONDS",
                    DEFAULT_ANALYZE_TIMEOUT_SECONDS,
                ),
                serialize_analyzer=True,
            )
        ]
    else:
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
