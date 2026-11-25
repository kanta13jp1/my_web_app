#!/usr/bin/env python3
"""Zero-DB crash-safe Markdown agent memory & git-blame audit trail (#2709).

Provides headless/CI-safe persistence for agent decisions and tool results
in pure Git-tracked Markdown files (no SQLite, Bun, or external DB), atomic
crash-safe writes with automatic recovery from Git HEAD, and `git blame`
provenance auditing.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


REDACTION_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"gh[opsu]_[A-Za-z0-9_]{16,}"), "[REDACTED_GH_CREDENTIAL]"),
    (re.compile(r"github_pat_[A-Za-z0-9_]{16,}"), "[REDACTED_GH_PAT]"),
    (re.compile(r"Bearer\s+[A-Za-z0-9._-]{16,}", re.IGNORECASE), "Bearer [REDACTED]"),
    (re.compile(r"sk-[A-Za-z0-9_-]{16,}"), "sk-[REDACTED]"),
    (re.compile(r"sb_[A-Za-z0-9_]{16,}"), "sb_[REDACTED]"),
)

HEADER_MARKER = "<!-- ci-markdown-memory:v1 -->"
ENTRY_END_MARKER = "<!-- /entry -->"


def redact_sensitive_text(text: str) -> str:
    """Mask common credential patterns before writing Git-tracked memory."""
    cleaned = text
    for pattern, replacement in REDACTION_PATTERNS:
        cleaned = pattern.sub(replacement, cleaned)
    return cleaned


def _run_git(
    repo_root: Path,
    args: list[str],
    *,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=str(repo_root),
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=check,
    )


def _atomic_write_utf8(target: Path, content: str) -> None:
    """Write via temp file + fsync + os.replace to survive mid-write SIGKILL."""
    target.parent.mkdir(parents=True, exist_ok=True)
    normalized = content.replace("\r\n", "\n")
    fd, tmp_name = tempfile.mkstemp(
        prefix=".tmp-ci-mem-",
        suffix=".md",
        dir=str(target.parent),
    )
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(normalized)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_path, target)
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink(missing_ok=True)
        raise


def _cleanup_orphan_temp_files(directory: Path) -> list[str]:
    removed: list[str] = []
    if not directory.exists():
        return removed
    for orphan in sorted(directory.glob(".tmp-ci-mem-*.md")):
        if orphan.is_file():
            orphan.unlink(missing_ok=True)
            removed.append(orphan.name)
    return removed


def is_markdown_memory_intact(text: str) -> bool:
    """Verify required header/entry balance and absence of NUL corruption."""
    if not text.strip():
        return False
    if "\x00" in text:
        return False
    if HEADER_MARKER not in text:
        return False
    entry_starts = text.count("- `")
    entry_ends = text.count(ENTRY_END_MARKER)
    if entry_starts > 0 and entry_ends < entry_starts:
        return False
    return True


def verify_and_recover_memory(
    *,
    repo_root: Path,
    memory_file: Path,
) -> dict[str, Any]:
    """Check Markdown integrity + orphan temps; restore HEAD snapshot if corrupt."""
    resolved_root = repo_root.resolve()
    resolved_file = (
        memory_file if memory_file.is_absolute() else (resolved_root / memory_file)
    ).resolve()
    orphan_removed = _cleanup_orphan_temp_files(resolved_file.parent)

    rel_path = resolved_file.relative_to(resolved_root).as_posix()
    corrupt = False
    reason = "intact"

    if not resolved_file.exists():
        head_check = _run_git(
            resolved_root,
            ["cat-file", "-e", f"HEAD:{rel_path}"],
            check=False,
        )
        if head_check.returncode == 0:
            corrupt = True
            reason = "missing_after_commit"
        else:
            return {
                "ok": True,
                "recovered": False,
                "status": "uninitialized",
                "orphans_cleaned": orphan_removed,
                "memory_file": rel_path,
            }
    else:
        try:
            raw_bytes = resolved_file.read_bytes()
            text = raw_bytes.decode("utf-8", errors="strict")
            if not is_markdown_memory_intact(text):
                corrupt = True
                reason = "truncated_or_malformed_markdown"
        except UnicodeDecodeError:
            corrupt = True
            reason = "invalid_utf8_bytes"

    if not corrupt:
        return {
            "ok": True,
            "recovered": bool(orphan_removed),
            "status": "orphans_cleaned" if orphan_removed else "intact",
            "orphans_cleaned": orphan_removed,
            "memory_file": rel_path,
        }

    show_proc = _run_git(
        resolved_root,
        ["show", f"HEAD:{rel_path}"],
        check=False,
    )
    if show_proc.returncode != 0 or not is_markdown_memory_intact(show_proc.stdout):
        return {
            "ok": False,
            "recovered": False,
            "status": "unrecoverable_no_head_snapshot",
            "reason": reason,
            "orphans_cleaned": orphan_removed,
            "memory_file": rel_path,
        }

    _atomic_write_utf8(resolved_file, show_proc.stdout)
    head_sha = _run_git(resolved_root, ["rev-parse", "HEAD"], check=True).stdout.strip()
    return {
        "ok": True,
        "recovered": True,
        "status": "restored_from_git_head",
        "reason": reason,
        "restored_commit": head_sha,
        "orphans_cleaned": orphan_removed,
        "memory_file": rel_path,
    }


def record_agent_step(
    *,
    repo_root: Path,
    memory_file: Path,
    agent_name: str,
    decision: str,
    tool_name: str,
    tool_outcome: str,
    summary: str,
    run_id: str = "",
    changed_files: list[str] | None = None,
    recover_first: bool = True,
    now_utc: dt.datetime | None = None,
) -> dict[str, Any]:
    """Atomically append an auditable decision/tool line to Markdown memory."""
    resolved_root = repo_root.resolve()
    resolved_file = (
        memory_file if memory_file.is_absolute() else (resolved_root / memory_file)
    ).resolve()
    rel_path = resolved_file.relative_to(resolved_root).as_posix()

    recovery_info: dict[str, Any] | None = None
    if recover_first:
        recovery_info = verify_and_recover_memory(
            repo_root=resolved_root,
            memory_file=resolved_file,
        )

    existing = ""
    if resolved_file.exists():
        existing = resolved_file.read_text(encoding="utf-8", errors="replace").replace("\r\n", "\n")

    if not existing.strip() or HEADER_MARKER not in existing:
        existing = (
            f"{HEADER_MARKER}\n"
            "# CI / Headless Agent Memory Ledger\n\n"
            "> Crash-safe Markdown memory with git-blame provenance (#2709).\n\n"
            "## Timeline\n\n"
        )

    stamp = (now_utc or dt.datetime.now(dt.timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ")
    clean_agent = redact_sensitive_text(" ".join(agent_name.split())) or "ci-agent"
    clean_decision = redact_sensitive_text(" ".join(decision.split())) or "execute"
    clean_tool = redact_sensitive_text(" ".join(tool_name.split())) or "none"
    clean_outcome = redact_sensitive_text(" ".join(tool_outcome.split())) or "ok"
    clean_summary = redact_sensitive_text(" ".join(summary.split())) or "(no summary)"
    clean_run = redact_sensitive_text(" ".join(run_id.split())) or "local"
    files_str = ",".join(
        redact_sensitive_text(p.strip()) for p in (changed_files or []) if p.strip()
    ) or "none"

    # Single atomic line keeps every entry cleanly attributed to one commit in git blame.
    line = (
        f"- `{stamp}` | run=`{clean_run}` | agent=`{clean_agent}` | "
        f"decision=`{clean_decision}` | tool=`{clean_tool}` (`{clean_outcome}`) | "
        f"files=`{files_str}` | {clean_summary} {ENTRY_END_MARKER}\n"
    )
    updated = (existing.rstrip("\n") + "\n" + line)
    _atomic_write_utf8(resolved_file, updated)

    return {
        "ok": True,
        "memory_file": rel_path,
        "timestamp": stamp,
        "entry_line": line.strip(),
        "recovery": recovery_info,
    }


def commit_and_optionally_push(
    *,
    repo_root: Path,
    memory_file: Path,
    commit_message: str,
    push: bool = False,
    remote: str = "origin",
) -> dict[str, Any]:
    """Commit staged Markdown memory in Git and optionally push when authorized."""
    resolved_root = repo_root.resolve()
    resolved_file = (
        memory_file if memory_file.is_absolute() else (resolved_root / memory_file)
    ).resolve()
    rel_path = resolved_file.relative_to(resolved_root).as_posix()

    _run_git(resolved_root, ["add", "--", rel_path], check=True)
    diff_cached = _run_git(
        resolved_root,
        ["diff", "--cached", "--name-only", "--", rel_path],
        check=True,
    )
    if not diff_cached.stdout.strip():
        head_sha = _run_git(resolved_root, ["rev-parse", "HEAD"], check=False).stdout.strip()
        return {"committed": False, "reason": "no_changes", "head_sha": head_sha}

    _run_git(resolved_root, ["commit", "-m", commit_message], check=True)
    head_sha = _run_git(resolved_root, ["rev-parse", "HEAD"], check=True).stdout.strip()

    pushed = False
    if push:
        _run_git(resolved_root, ["push", remote, "HEAD"], check=True)
        pushed = True

    return {
        "committed": True,
        "pushed": pushed,
        "commit_sha": head_sha,
        "memory_file": rel_path,
    }


def audit_with_git_blame(
    *,
    repo_root: Path,
    memory_file: Path,
    query: str = "",
) -> dict[str, Any]:
    """Run `git blame --line-porcelain` on memory Markdown to trace decisions."""
    resolved_root = repo_root.resolve()
    resolved_file = (
        memory_file if memory_file.is_absolute() else (resolved_root / memory_file)
    ).resolve()
    rel_path = resolved_file.relative_to(resolved_root).as_posix()

    blame_proc = _run_git(
        resolved_root,
        ["blame", "--line-porcelain", "--", rel_path],
        check=False,
    )
    if blame_proc.returncode != 0:
        return {
            "ok": False,
            "error": blame_proc.stderr.strip() or "git blame failed",
            "memory_file": rel_path,
            "records": [],
        }

    records: list[dict[str, Any]] = []
    commit_meta: dict[str, dict[str, str]] = {}
    current_sha = ""
    current_line_no = 0

    for raw_line in blame_proc.stdout.splitlines():
        if raw_line.startswith("\t"):
            content = raw_line[1:]
            if content.lstrip().startswith("- `"):
                meta = commit_meta.get(current_sha, {})
                if not query or query.lower() in content.lower():
                    records.append(
                        {
                            "line": current_line_no,
                            "commit": current_sha,
                            "author": meta.get("author", ""),
                            "summary": meta.get("summary", ""),
                            "entry": content.strip(),
                        }
                    )
            current_sha = ""
            continue

        header_match = re.match(r"^([0-9a-f]{40})\s+\d+\s+(\d+)", raw_line)
        if header_match:
            current_sha = header_match.group(1)
            current_line_no = int(header_match.group(2))
            commit_meta.setdefault(current_sha, {})
        elif current_sha:
            if raw_line.startswith("author "):
                commit_meta[current_sha]["author"] = raw_line[7:].strip()
            elif raw_line.startswith("summary "):
                commit_meta[current_sha]["summary"] = raw_line[8:].strip()

    return {
        "ok": True,
        "memory_file": rel_path,
        "total_attributed_entries": len(records),
        "unique_commits": sorted({r["commit"] for r in records}),
        "records": records,
    }


def _run_self_test() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        _run_git(repo, ["init"], check=True)
        _run_git(repo, ["config", "user.name", "ci-bot"], check=True)
        _run_git(repo, ["config", "user.email", "ci-bot@example.invalid"], check=True)

        mem_rel = Path("memory/ci_agent_ledger/run_audit.md")
        mem_abs = repo / mem_rel

        rec1 = record_agent_step(
            repo_root=repo,
            memory_file=mem_rel,
            agent_name="ci-planner",
            decision="select_fast_check",
            tool_name="pytest",
            tool_outcome="passed",
            summary="First commit decision record",
            run_id="run-101",
            changed_files=["scripts/a.py"],
        )
        assert rec1["ok"] is True
        c1 = commit_and_optionally_push(
            repo_root=repo,
            memory_file=mem_rel,
            commit_message="chore(memory): record run-101 decision",
        )
        assert c1["committed"] is True

        rec2 = record_agent_step(
            repo_root=repo,
            memory_file=mem_rel,
            agent_name="ci-fixer",
            decision="patch_lint",
            tool_name="dart_format",
            tool_outcome="passed",
            summary="Second commit tool outcome",
            run_id="run-102",
            changed_files=["lib/main.dart"],
        )
        assert rec2["ok"] is True
        c2 = commit_and_optionally_push(
            repo_root=repo,
            memory_file=mem_rel,
            commit_message="chore(memory): record run-102 tool result",
        )
        assert c2["committed"] is True

        blame = audit_with_git_blame(repo_root=repo, memory_file=mem_rel)
        assert blame["ok"] is True
        assert blame["total_attributed_entries"] == 2
        assert len(blame["unique_commits"]) == 2

        intact_before_crash = mem_abs.read_text(encoding="utf-8")
        # Simulate SIGKILL mid-write: orphan temp file + truncated target file.
        (mem_abs.parent / ".tmp-ci-mem-orphan.md").write_text("partial", encoding="utf-8")
        mem_abs.write_text("# truncated crash", encoding="utf-8")

        recovery = verify_and_recover_memory(repo_root=repo, memory_file=mem_rel)
        assert recovery["ok"] is True
        assert recovery["recovered"] is True
        assert recovery["status"] == "restored_from_git_head"
        assert mem_abs.read_text(encoding="utf-8") == intact_before_crash

    print(json.dumps({"self_test": "passed", "blame_commits": 2, "crash_recovery": "verified"}))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--memory-file", default="memory/ci_agent_ledger/ci_events.md")
    parser.add_argument("--agent", default="ci-agent")
    parser.add_argument("--decision", default="")
    parser.add_argument("--tool", default="none")
    parser.add_argument("--outcome", default="ok")
    parser.add_argument("--summary", default="")
    parser.add_argument("--run-id", default=os.environ.get("GITHUB_RUN_ID", "local"))
    parser.add_argument("--changed-files", default="")
    parser.add_argument("--commit", action="store_true")
    parser.add_argument("--commit-message", default="")
    parser.add_argument("--push", action="store_true")
    parser.add_argument("--recover", action="store_true")
    parser.add_argument("--audit-blame", action="store_true")
    parser.add_argument("--query", default="")
    parser.add_argument("--hook-stdin", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        return _run_self_test()

    repo_root = Path(args.repo_root).resolve()
    mem_file = Path(args.memory_file)

    if args.recover and not args.decision and not args.summary:
        res = verify_and_recover_memory(repo_root=repo_root, memory_file=mem_file)
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return 0 if res.get("ok") else 1

    if args.audit_blame:
        res = audit_with_git_blame(
            repo_root=repo_root,
            memory_file=mem_file,
            query=args.query,
        )
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return 0 if res.get("ok") else 1

    tool_name = args.tool
    summary = args.summary
    if args.hook_stdin and not sys.stdin.isatty():
        raw_hook = sys.stdin.read().strip()
        if raw_hook:
            try:
                hook_data = json.loads(raw_hook)
                if isinstance(hook_data, dict):
                    parsed_tool = str(hook_data.get("tool_name") or "").strip()
                    if parsed_tool and tool_name == "none":
                        tool_name = parsed_tool
                    if not summary:
                        event_name = str(hook_data.get("hook_event_name") or "hook").strip()
                        summary = f"Captured {event_name} event for tool {parsed_tool or tool_name}"
            except json.JSONDecodeError:
                pass

    files_list = [f.strip() for f in args.changed_files.split(",") if f.strip()]
    rec = record_agent_step(
        repo_root=repo_root,
        memory_file=mem_file,
        agent_name=args.agent,
        decision=args.decision or "record_step",
        tool_name=tool_name,
        tool_outcome=args.outcome,
        summary=summary or "Headless CI agent step recorded",
        run_id=args.run_id,
        changed_files=files_list,
    )
    out: dict[str, Any] = {"recorded": rec}

    if args.commit:
        msg = args.commit_message or (
            f"chore(memory): auto-capture {args.agent} [{args.tool}:{args.outcome}]"
        )
        out["git"] = commit_and_optionally_push(
            repo_root=repo_root,
            memory_file=mem_file,
            commit_message=msg,
            push=args.push,
        )

    print(json.dumps(out, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
