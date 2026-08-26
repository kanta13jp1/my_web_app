#!/usr/bin/env python3
"""Run the local quality gates shared by Lefthook and humans."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
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
DEFAULT_DART_ANALYZE_TIMEOUT_SECONDS = 180.0
TIMEOUT_EXIT_CODE = 124
LOCK_TIMEOUT_EXIT_CODE = 75

ANALYZER_INFRASTRUCTURE_PATTERNS = (
    "analysis server exited",
    "analysis server crashed",
    "analysis server terminated",
    "could not start the analysis server",
    "failed to start the analysis server",
    "out of memory",
    "zone.cc",
    "unexpected extension byte",
    "formatexception",
    "crash report has been written",
)


@dataclass(frozen=True)
class GateCommand:
    name: str
    args: list[str]
    required_binary: str | None = None
    timeout_seconds: float = DEFAULT_COMMAND_TIMEOUT_SECONDS
    serialize_analyzer: bool = False
    capture_output: bool = False


@dataclass(frozen=True)
class CommandResult:
    returncode: int
    elapsed_seconds: float
    timed_out: bool
    cleanup_result: str
    output: str = ""


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


def flutter_analyze_command(paths: list[str] | None = None) -> GateCommand:
    targeted = bool(paths)
    return GateCommand(
        "flutter analyze targeted" if targeted else "flutter analyze",
        [
            "flutter",
            "analyze",
            *(["--no-pub", *paths] if paths else []),
        ],
        "flutter",
        timeout_seconds=env_seconds(
            "QUALITY_GATE_ANALYZE_TIMEOUT_SECONDS",
            DEFAULT_ANALYZE_TIMEOUT_SECONDS,
        ),
        serialize_analyzer=True,
        capture_output=True,
    )


def dart_analyze_fallback_command() -> GateCommand:
    # Plain output is intentional. Windows machine output produced an encoding
    # FormatException in the original #1780 incident.
    return GateCommand(
        "dart analyze fallback",
        ["dart", "analyze"],
        "dart",
        timeout_seconds=env_seconds(
            "QUALITY_GATE_DART_ANALYZE_TIMEOUT_SECONDS",
            DEFAULT_DART_ANALYZE_TIMEOUT_SECONDS,
        ),
        serialize_analyzer=True,
        capture_output=True,
    )


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
        flutter_analyze_command(),
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
    capture_output: bool = False,
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
    if capture_output:
        popen_kwargs.update(
            {
                "stdout": subprocess.PIPE,
                "stderr": subprocess.STDOUT,
                "text": True,
                "encoding": "utf-8",
                "errors": "replace",
            }
        )
    started = time.monotonic()
    proc = subprocess.Popen(args, **popen_kwargs)
    try:
        if capture_output:
            output, _ = proc.communicate(timeout=timeout_seconds)
            returncode = proc.returncode
        else:
            output = ""
            returncode = proc.wait(timeout=timeout_seconds)
        return CommandResult(
            returncode=returncode,
            elapsed_seconds=time.monotonic() - started,
            timed_out=False,
            cleanup_result="not_needed",
            output=output or "",
        )
    except subprocess.TimeoutExpired:
        cleanup_result = terminate_owned_process_tree(
            proc,
            platform_name=resolved_platform,
        )
        output = ""
        if capture_output:
            try:
                output, _ = proc.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                output = ""
        return CommandResult(
            returncode=TIMEOUT_EXIT_CODE,
            elapsed_seconds=time.monotonic() - started,
            timed_out=True,
            cleanup_result=cleanup_result,
            output=output or "",
        )


def emit_result(
    command: GateCommand,
    result: CommandResult,
    *,
    lock_status: str,
    classification: str | None = None,
) -> None:
    payload: dict[str, object] = {
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
    }
    if classification is not None:
        payload["classification"] = classification
    print(
        json.dumps(payload, ensure_ascii=False, sort_keys=True),
        flush=True,
    )


def execute_gate(command: GateCommand, root: Path) -> tuple[CommandResult, str]:
    resolved_args = resolve_args(command)
    if resolved_args is None:
        message = f"missing required command: {command.required_binary}"
        return (
            CommandResult(
                returncode=127,
                elapsed_seconds=0.0,
                timed_out=False,
                cleanup_result="not_started",
                output=message,
            ),
            "not_started",
        )
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
                    capture_output=command.capture_output,
                )
        else:
            result = run_process(
                resolved_args,
                root,
                command.timeout_seconds,
                capture_output=command.capture_output,
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
    return result, lock_status


def print_captured_output(result: CommandResult) -> None:
    if not result.output:
        return
    print(result.output, end="" if result.output.endswith("\n") else "\n", flush=True)


def run_gate(command: GateCommand, root: Path) -> int:
    print(f"==> {command.name}", flush=True)
    result, lock_status = execute_gate(command, root)
    print_captured_output(result)
    emit_result(command, result, lock_status=lock_status)
    if result.returncode != 0:
        print(
            f"gate failed: {command.name} (exit {result.returncode})",
            file=sys.stderr,
        )
    return result.returncode


def classify_analyzer_result(result: CommandResult) -> str:
    if result.returncode == 0:
        return "success"
    if result.returncode == LOCK_TIMEOUT_EXIT_CODE:
        return "infrastructure_lock_timeout"
    if result.timed_out or result.returncode == TIMEOUT_EXIT_CODE:
        return "infrastructure_timeout"
    lowered = result.output.lower()
    if "missing required command" in lowered or result.returncode == 127:
        return "infrastructure_tool_unavailable"
    if (
        result.returncode < 0
        or result.returncode >= 0xC0000000
        or any(pattern in lowered for pattern in ANALYZER_INFRASTRUCTURE_PATTERNS)
    ):
        return "infrastructure_crash"
    return "code_findings"


def tool_version(args: list[str], root: Path) -> str:
    resolved = shutil.which(args[0])
    if resolved is None:
        return f"{args[0]} unavailable"
    try:
        completed = subprocess.run(
            [resolved, *args[1:]],
            cwd=root,
            env=command_env(),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        return f"{args[0]} version unavailable: {type(error).__name__}"
    output = "\n".join(part.strip() for part in (completed.stdout, completed.stderr) if part.strip())
    return output[:2000] or f"{args[0]} version exited {completed.returncode} without output"


def analyzer_result_payload(
    command: GateCommand,
    result: CommandResult,
    *,
    classification: str,
    lock_status: str,
    log_path: Path,
) -> dict[str, object]:
    return {
        "classification": classification,
        "command": shlex.join(command.args),
        "elapsed_seconds": round(result.elapsed_seconds, 3),
        "timeout_seconds": command.timeout_seconds,
        "returncode": result.returncode,
        "timed_out": result.timed_out,
        "cleanup_result": result.cleanup_result,
        "analyzer_lock": lock_status,
        "log_path": log_path.as_posix(),
        "recovery_command": shlex.join(command.args),
    }


def recent_flutter_crash_logs(root: Path) -> list[str]:
    paths = sorted(
        root.glob("flutter_*.log"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    return [path.relative_to(root).as_posix() for path in paths[:5]]


def write_analyzer_evidence(
    root: Path,
    artifact_dir: Path,
    *,
    status: str,
    primary_command: GateCommand,
    primary_result: CommandResult,
    primary_classification: str,
    primary_lock_status: str,
    fallback_command: GateCommand | None,
    fallback_result: CommandResult | None,
    fallback_classification: str | None,
    fallback_lock_status: str | None,
) -> None:
    resolved_dir = artifact_dir if artifact_dir.is_absolute() else root / artifact_dir
    resolved_dir.mkdir(parents=True, exist_ok=True)
    primary_log = resolved_dir / "flutter-analyze.log"
    primary_log.write_text(primary_result.output, encoding="utf-8", errors="replace")

    fallback_payload: dict[str, object] | None = None
    fallback_log: Path | None = None
    if fallback_command is not None and fallback_result is not None:
        fallback_log = resolved_dir / "dart-analyze-fallback.log"
        fallback_log.write_text(fallback_result.output, encoding="utf-8", errors="replace")
        fallback_payload = analyzer_result_payload(
            fallback_command,
            fallback_result,
            classification=fallback_classification or "unknown",
            lock_status=fallback_lock_status or "unknown",
            log_path=fallback_log.relative_to(root),
        )

    payload = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "status": status,
        "primary": analyzer_result_payload(
            primary_command,
            primary_result,
            classification=primary_classification,
            lock_status=primary_lock_status,
            log_path=primary_log.relative_to(root),
        ),
        "fallback": fallback_payload,
        "versions": {
            "flutter": tool_version(["flutter", "--version", "--machine"], root),
            "dart": tool_version(["dart", "--version"], root),
        },
        "flutter_crash_logs": recent_flutter_crash_logs(root),
    }
    evidence_path = resolved_dir / "result.json"
    evidence_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    lines = [
        "### Analyzer gate evidence",
        f"- Status: `{status}`",
        f"- Primary classification: `{primary_classification}`",
        f"- Primary command: `{shlex.join(primary_command.args)}`",
        f"- Primary exit/elapsed: `{primary_result.returncode}` / `{primary_result.elapsed_seconds:.3f}s`",
        f"- Primary cleanup: `{primary_result.cleanup_result}`",
        f"- Primary log: `{primary_log.relative_to(root).as_posix()}`",
    ]
    if fallback_command is not None and fallback_result is not None and fallback_log is not None:
        lines.extend(
            [
                f"- Fallback classification: `{fallback_classification}`",
                f"- Fallback command: `{shlex.join(fallback_command.args)}`",
                f"- Fallback exit/elapsed: `{fallback_result.returncode}` / `{fallback_result.elapsed_seconds:.3f}s`",
                f"- Fallback log: `{fallback_log.relative_to(root).as_posix()}`",
            ]
        )
    lines.extend(
        [
            f"- Flutter version: `{str(payload['versions']['flutter']).splitlines()[0]}`",
            f"- Dart version: `{str(payload['versions']['dart']).splitlines()[0]}`",
            f"- Evidence JSON: `{evidence_path.relative_to(root).as_posix()}`",
        ]
    )
    crash_logs = payload["flutter_crash_logs"]
    if crash_logs:
        lines.append(f"- Flutter crash logs: `{', '.join(crash_logs)}`")
    summary = "\n".join(lines) + "\n"
    (resolved_dir / "summary.md").write_text(summary, encoding="utf-8")

    comment_path = resolved_dir / "comment.md"
    if status == "success":
        comment_path.unlink(missing_ok=True)
    else:
        comment_path.write_text(
            "<!-- analyzer-fallback-evidence -->\n" + summary,
            encoding="utf-8",
        )

    step_summary = os.environ.get("GITHUB_STEP_SUMMARY", "").strip()
    if step_summary:
        with Path(step_summary).open("a", encoding="utf-8", newline="\n") as handle:
            handle.write("\n" + summary)


def run_analyzer_gate(command: GateCommand, root: Path, artifact_dir: Path) -> int:
    print(f"==> {command.name}", flush=True)
    primary_result, primary_lock = execute_gate(command, root)
    print_captured_output(primary_result)
    primary_classification = classify_analyzer_result(primary_result)
    emit_result(
        command,
        primary_result,
        lock_status=primary_lock,
        classification=primary_classification,
    )

    fallback_command: GateCommand | None = None
    fallback_result: CommandResult | None = None
    fallback_lock: str | None = None
    fallback_classification: str | None = None
    status = primary_classification
    returncode = primary_result.returncode

    if primary_classification in {
        "infrastructure_crash",
        "infrastructure_timeout",
        "infrastructure_tool_unavailable",
    }:
        fallback_command = dart_analyze_fallback_command()
        print(f"==> {fallback_command.name}", flush=True)
        fallback_result, fallback_lock = execute_gate(fallback_command, root)
        print_captured_output(fallback_result)
        fallback_classification = classify_analyzer_result(fallback_result)
        emit_result(
            fallback_command,
            fallback_result,
            lock_status=fallback_lock,
            classification=fallback_classification,
        )
        if fallback_result.returncode == 0:
            status = "degraded_pass"
            returncode = 0
        else:
            status = "fallback_failed"
            returncode = fallback_result.returncode

    write_analyzer_evidence(
        root,
        artifact_dir,
        status=status,
        primary_command=command,
        primary_result=primary_result,
        primary_classification=primary_classification,
        primary_lock_status=primary_lock,
        fallback_command=fallback_command,
        fallback_result=fallback_result,
        fallback_classification=fallback_classification,
        fallback_lock_status=fallback_lock,
    )
    if returncode != 0:
        print(f"gate failed: {command.name} ({status}, exit {returncode})", file=sys.stderr)
    return returncode


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--fast", action="store_true", help="Run pre-commit quality gates.")
    mode.add_argument("--full", action="store_true", help="Run pre-push quality gates.")
    mode.add_argument("--list", action="store_true", help="Print the commands without running them.")
    mode.add_argument(
        "--analyze-only",
        action="store_true",
        help="Run the bounded repository-wide analyzer with crash fallback evidence.",
    )
    mode.add_argument(
        "--analyze-files",
        nargs="+",
        metavar="PATH",
        help="Run one bounded, serialized Flutter analysis over explicit paths.",
    )
    parser.add_argument(
        "--analyzer-artifact-dir",
        type=Path,
        default=Path(".ci-logs/analyzer"),
        help="Directory for analyzer logs, versions, JSON evidence, and PR comment markdown.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = repo_root()
    if args.analyze_files:
        commands = [flutter_analyze_command(args.analyze_files)]
    elif args.analyze_only:
        commands = [flutter_analyze_command()]
    else:
        commands = full_commands(root) if args.full else fast_commands()

    if args.list:
        for command in commands:
            print(f"{command.name}: {' '.join(command.args)}")
        return 0

    for command in commands:
        if command.name.startswith("flutter analyze"):
            code = run_analyzer_gate(command, root, args.analyzer_artifact_dir)
        else:
            code = run_gate(command, root)
        if code != 0:
            return code
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
