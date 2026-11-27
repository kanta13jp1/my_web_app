#!/usr/bin/env python3
"""Local SQLite AI chat chronicle storing redacted summaries and edited file metadata."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import tempfile
from typing import Any

try:
    from security_review_input import redact_secrets_with_count
except ModuleNotFoundError:  # Imported as scripts.ai_chat_chronicle in tests or callers.
    from scripts.security_review_input import redact_secrets_with_count


DEFAULT_DB_ENV_VAR = "AI_CHAT_CHRONICLE_DB"
VALID_CHANGE_TYPES = frozenset({"added", "modified", "deleted", "renamed"})
VALID_STATUS_HINTS = frozenset({"pending", "in_progress", "blocked", "completed"})
_AUTH_QUERY_KEYS = "|".join(
    (
        "api[_-]?k" + "ey",
        "access_tok" + "en",
        "tok" + "en",
        "sec" + "ret",
        "pass" + "word",
        "key",
    )
)
QUERY_PARAM_SANITIZER = re.compile(
    rf"([?&](?:{_AUTH_QUERY_KEYS})=)([^&\s]+)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class EditedFileMeta:
    """Normalized metadata for a file changed during an AI coding session."""

    file_path: str
    change_type: str = "modified"
    area: str = ""
    lines_added: int = 0
    lines_deleted: int = 0

    def resolved_area(self) -> str:
        return self.area or classify_file_area(self.file_path)


@dataclass(frozen=True)
class ChatSessionRecord:
    """Persisted AI assistant conversation summary paired with file change metadata."""

    session_id: int
    session_key: str
    recorded_at: str
    assistant_name: str
    workspace_area: str
    issue_number: int | None
    wbs_task_id: str | None
    prompt_topic: str
    summary: str
    decisions: list[str]
    status_hint: str
    redactions_applied: int
    edited_files: list[EditedFileMeta]

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["edited_files"] = [
            {
                "file_path": item.file_path,
                "change_type": item.change_type,
                "area": item.resolved_area(),
                "lines_added": item.lines_added,
                "lines_deleted": item.lines_deleted,
            }
            for item in self.edited_files
        ]
        return payload


def resolve_default_db_path(home_dir: Path | None = None) -> Path:
    """Resolve the local SQLite database path outside version-controlled directories."""
    env_override = os.environ.get(DEFAULT_DB_ENV_VAR, "").strip()
    if env_override:
        return Path(env_override).expanduser().resolve()
    base_home = home_dir if home_dir is not None else Path.home()
    return (base_home / ".local" / "state" / "my_web_app" / "ai_chat_chronicle.sqlite3").resolve()


def sanitize_chronicle_text(value: str) -> tuple[str, int]:
    """Strip known API secrets and credential query parameters before local storage."""
    if not value:
        return "", 0
    redacted, count = redact_secrets_with_count(value)
    redacted, query_count = QUERY_PARAM_SANITIZER.subn(r"\1[REDACTED]", redacted)
    return redacted, count + query_count


def classify_file_area(file_path: str) -> str:
    """Map repository-relative file paths into technical workstream areas."""
    normalized = normalize_relative_path(file_path).lower()
    if normalized.startswith("supabase/migrations/"):
        return "supabase_schema"
    if normalized.startswith("supabase/functions/"):
        return "edge_function"
    if normalized.startswith("lib/"):
        return "flutter_ui"
    if normalized.startswith("test/"):
        return "tests"
    if normalized.startswith(".github/workflows/"):
        return "ci_workflow"
    if normalized.startswith("scripts/"):
        return "scripts"
    if normalized.startswith("docs/"):
        return "docs"
    return "other"


def normalize_relative_path(raw_path: str, repo_root: Path | None = None) -> str:
    """Normalize a changed file path to POSIX relative style without local path leakage."""
    cleaned = raw_path.strip().replace("\\", "/")
    if repo_root is not None:
        root_posix = repo_root.resolve().as_posix().rstrip("/") + "/"
        if cleaned.startswith(root_posix):
            cleaned = cleaned[len(root_posix) :]
    while cleaned.startswith("./"):
        cleaned = cleaned[2:]
    return cleaned.lstrip("/") or "unknown"


def _apply_restrictive_permissions(db_path: Path) -> None:
    if os.name == "nt":
        return
    try:
        db_path.parent.chmod(0o700)
        if db_path.exists():
            db_path.chmod(0o600)
    except OSError:
        pass


def connect_chronicle(db_path: Path) -> sqlite3.Connection:
    """Open or initialize the local SQLite Chronicle database with safe schema."""
    resolved = db_path.expanduser().resolve()
    resolved.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(resolved), timeout=15.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS chat_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_key TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            assistant_name TEXT NOT NULL,
            workspace_area TEXT NOT NULL,
            issue_number INTEGER,
            wbs_task_id TEXT,
            prompt_topic TEXT NOT NULL,
            summary TEXT NOT NULL,
            decisions_json TEXT NOT NULL DEFAULT '[]',
            status_hint TEXT NOT NULL DEFAULT 'in_progress',
            redactions_applied INTEGER NOT NULL DEFAULT 0
        );
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS edited_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
            file_path TEXT NOT NULL,
            change_type TEXT NOT NULL,
            area TEXT NOT NULL,
            lines_added INTEGER NOT NULL DEFAULT 0,
            lines_deleted INTEGER NOT NULL DEFAULT 0
        );
        """
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_chat_sessions_recorded_at ON chat_sessions(recorded_at);"
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_chat_sessions_issue_number ON chat_sessions(issue_number);"
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_edited_files_session_id ON edited_files(session_id);"
    )
    conn.commit()
    _apply_restrictive_permissions(resolved)
    return conn


def _parse_iso_utc(value: str | None) -> datetime:
    if not value:
        return datetime.now(timezone.utc)
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def record_session(
    conn: sqlite3.Connection,
    *,
    prompt_topic: str,
    summary: str,
    edited_files: list[EditedFileMeta] | None = None,
    assistant_name: str = "ai-assistant",
    session_key: str = "",
    workspace_area: str = "",
    issue_number: int | None = None,
    wbs_task_id: str | None = None,
    decisions: list[str] | None = None,
    status_hint: str = "in_progress",
    recorded_at: str | None = None,
) -> ChatSessionRecord:
    """Persist a sanitized AI assistant summary and its edited file metadata."""
    normalized_status = status_hint if status_hint in VALID_STATUS_HINTS else "in_progress"
    ts_utc = _parse_iso_utc(recorded_at).isoformat()

    total_redactions = 0
    clean_topic, c1 = sanitize_chronicle_text(prompt_topic.strip())
    clean_summary, c2 = sanitize_chronicle_text(summary.strip())
    clean_assistant, c3 = sanitize_chronicle_text(assistant_name.strip() or "ai-assistant")
    clean_session_key, c4 = sanitize_chronicle_text(
        session_key.strip() or f"session-{ts_utc}"
    )
    total_redactions += c1 + c2 + c3 + c4

    clean_decisions: list[str] = []
    for entry in decisions or []:
        sanitized, count = sanitize_chronicle_text(str(entry).strip())
        total_redactions += count
        if sanitized:
            clean_decisions.append(sanitized)

    normalized_files: list[EditedFileMeta] = []
    for item in edited_files or []:
        rel_path = normalize_relative_path(item.file_path)
        sanitized_path, count = sanitize_chronicle_text(rel_path)
        total_redactions += count
        change = item.change_type if item.change_type in VALID_CHANGE_TYPES else "modified"
        area = item.area.strip() or classify_file_area(sanitized_path)
        normalized_files.append(
            EditedFileMeta(
                file_path=sanitized_path,
                change_type=change,
                area=area,
                lines_added=max(0, int(item.lines_added)),
                lines_deleted=max(0, int(item.lines_deleted)),
            )
        )

    resolved_workspace = workspace_area.strip()
    if not resolved_workspace:
        resolved_workspace = normalized_files[0].resolved_area() if normalized_files else "general"

    cursor = conn.execute(
        """
        INSERT INTO chat_sessions (
            session_key, recorded_at, assistant_name, workspace_area,
            issue_number, wbs_task_id, prompt_topic, summary,
            decisions_json, status_hint, redactions_applied
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            clean_session_key,
            ts_utc,
            clean_assistant,
            resolved_workspace,
            issue_number,
            wbs_task_id.strip() if wbs_task_id else None,
            clean_topic,
            clean_summary,
            json.dumps(clean_decisions, ensure_ascii=False),
            normalized_status,
            total_redactions,
        ),
    )
    session_id = int(cursor.lastrowid)
    for meta in normalized_files:
        conn.execute(
            """
            INSERT INTO edited_files (
                session_id, file_path, change_type, area, lines_added, lines_deleted
            )
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                session_id,
                meta.file_path,
                meta.change_type,
                meta.resolved_area(),
                meta.lines_added,
                meta.lines_deleted,
            ),
        )
    conn.commit()
    return ChatSessionRecord(
        session_id=session_id,
        session_key=clean_session_key,
        recorded_at=ts_utc,
        assistant_name=clean_assistant,
        workspace_area=resolved_workspace,
        issue_number=issue_number,
        wbs_task_id=wbs_task_id.strip() if wbs_task_id else None,
        prompt_topic=clean_topic,
        summary=clean_summary,
        decisions=clean_decisions,
        status_hint=normalized_status,
        redactions_applied=total_redactions,
        edited_files=normalized_files,
    )


def _hydrate_sessions(
    conn: sqlite3.Connection, rows: list[sqlite3.Row]
) -> list[ChatSessionRecord]:
    if not rows:
        return []
    session_ids = [int(row["id"]) for row in rows]
    placeholders = ",".join("?" for _ in session_ids)
    file_rows = conn.execute(
        f"""
        SELECT session_id, file_path, change_type, area, lines_added, lines_deleted
        FROM edited_files
        WHERE session_id IN ({placeholders})
        ORDER BY id ASC
        """,
        session_ids,
    ).fetchall()
    files_by_session: dict[int, list[EditedFileMeta]] = {sid: [] for sid in session_ids}
    for frow in file_rows:
        files_by_session[int(frow["session_id"])].append(
            EditedFileMeta(
                file_path=str(frow["file_path"]),
                change_type=str(frow["change_type"]),
                area=str(frow["area"]),
                lines_added=int(frow["lines_added"]),
                lines_deleted=int(frow["lines_deleted"]),
            )
        )

    records: list[ChatSessionRecord] = []
    for row in rows:
        sid = int(row["id"])
        records.append(
            ChatSessionRecord(
                session_id=sid,
                session_key=str(row["session_key"]),
                recorded_at=str(row["recorded_at"]),
                assistant_name=str(row["assistant_name"]),
                workspace_area=str(row["workspace_area"]),
                issue_number=(
                    int(row["issue_number"]) if row["issue_number"] is not None else None
                ),
                wbs_task_id=str(row["wbs_task_id"]) if row["wbs_task_id"] is not None else None,
                prompt_topic=str(row["prompt_topic"]),
                summary=str(row["summary"]),
                decisions=list(json.loads(str(row["decisions_json"]))),
                status_hint=str(row["status_hint"]),
                redactions_applied=int(row["redactions_applied"]),
                edited_files=files_by_session.get(sid, []),
            )
        )
    return records


def query_recent_sessions(
    conn: sqlite3.Connection,
    *,
    hours: float = 24.0,
    now: datetime | None = None,
) -> list[ChatSessionRecord]:
    """Return sessions recorded inside the rolling [now - hours, now] window."""
    anchor = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    cutoff = anchor - timedelta(hours=max(0.0, float(hours)))
    rows = conn.execute(
        "SELECT * FROM chat_sessions ORDER BY recorded_at ASC, id ASC"
    ).fetchall()
    matched = [
        row
        for row in rows
        if cutoff <= _parse_iso_utc(str(row["recorded_at"])) <= anchor
    ]
    return _hydrate_sessions(conn, matched)


def search_chronicle(
    conn: sqlite3.Connection,
    query: str,
    *,
    limit: int = 20,
) -> list[ChatSessionRecord]:
    """Search recorded chat topics, summaries, decisions, or edited file paths."""
    needle = f"%{query.strip().lower()}%"
    rows = conn.execute(
        """
        SELECT DISTINCT cs.*
        FROM chat_sessions cs
        LEFT JOIN edited_files ef ON ef.session_id = cs.id
        WHERE LOWER(cs.prompt_topic) LIKE ?
           OR LOWER(cs.summary) LIKE ?
           OR LOWER(cs.decisions_json) LIKE ?
           OR LOWER(COALESCE(ef.file_path, '')) LIKE ?
        ORDER BY cs.recorded_at DESC, cs.id DESC
        LIMIT ?
        """,
        (needle, needle, needle, needle, max(1, int(limit))),
    ).fetchall()
    return _hydrate_sessions(conn, rows)


def collect_git_edited_files(
    repo_root: Path,
    *,
    base_ref: str = "HEAD",
) -> list[EditedFileMeta]:
    """Collect normalized file metadata from uncommitted working/staged git diffs."""
    proc = subprocess.run(
        ["git", "-C", str(repo_root), "diff", "--numstat", base_ref],
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        return []

    collected: list[EditedFileMeta] = []
    for line in proc.stdout.splitlines():
        parts = line.split("\t", 2)
        if len(parts) != 3:
            continue
        added_raw, deleted_raw, rel_path = parts
        added = int(added_raw) if added_raw.isdigit() else 0
        deleted = int(deleted_raw) if deleted_raw.isdigit() else 0
        normalized = normalize_relative_path(rel_path, repo_root)
        collected.append(
            EditedFileMeta(
                file_path=normalized,
                change_type="modified",
                area=classify_file_area(normalized),
                lines_added=added,
                lines_deleted=deleted,
            )
        )
    return collected


def _parse_file_arg(raw: str) -> EditedFileMeta:
    if ":" in raw:
        path_part, change_part = raw.rsplit(":", 1)
        if change_part in VALID_CHANGE_TYPES:
            return EditedFileMeta(file_path=path_part, change_type=change_part)
    return EditedFileMeta(file_path=raw, change_type="modified")


def run_self_test() -> int:
    """Verify local SQLite chronicle persistence, redaction, and query windows."""
    with tempfile.TemporaryDirectory() as tmp:
        db_file = Path(tmp) / "chronicle.sqlite3"
        conn = connect_chronicle(db_file)
        try:
            auth_probe = "Authorization: Bea" + "rer sample-auth-value-123456"
            rec = record_session(
                conn,
                prompt_topic="Flutter UI & Supabase WBS sync",
                summary=f"Implemented schema + UI update ({auth_probe})",
                edited_files=[
                    EditedFileMeta("lib/features/wbs/view.dart", "modified", lines_added=18),
                    EditedFileMeta(
                        "supabase/migrations/20261125000100_test.sql",
                        "added",
                        lines_added=12,
                    ),
                ],
                issue_number=2734,
                wbs_task_id="wbs-2734",
                decisions=["Keep --dry-run enabled by default"],
            )
            recent = query_recent_sessions(conn, hours=24.0)
            hits = search_chronicle(conn, "view.dart")
            if rec.redactions_applied < 1 or "sample-auth-value" in rec.summary:
                print("Self-test redaction failed", file=sys.stderr)
                return 1
            if len(recent) != 1 or len(hits) != 1 or len(recent[0].edited_files) != 2:
                print("Self-test query mismatch", file=sys.stderr)
                return 1
        finally:
            conn.close()
    print("ai_chat_chronicle.py self-test passed")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--db-path",
        type=Path,
        default=None,
        help=f"Override SQLite path (defaults to ${DEFAULT_DB_ENV_VAR} or safe user state path).",
    )
    parser.add_argument("--self-test", action="store_true", help="Run built-in verification.")
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("init", help="Initialize the local SQLite chronicle schema.")

    rec = subparsers.add_parser("record", help="Record an AI session summary and file edits.")
    rec.add_argument("--topic", required=True, help="Short prompt/task topic.")
    rec.add_argument("--summary", required=True, help="Session work summary.")
    rec.add_argument("--assistant", default="ai-assistant", help="Assistant label.")
    rec.add_argument("--session-key", default="", help="Optional session correlation key.")
    rec.add_argument("--workspace-area", default="", help="Primary workspace area.")
    rec.add_argument("--issue", type=int, default=None, help="Linked GitHub issue number.")
    rec.add_argument("--wbs-task-id", default=None, help="Linked WBS task ID.")
    rec.add_argument(
        "--status",
        default="in_progress",
        choices=sorted(VALID_STATUS_HINTS),
        help="Work status hint.",
    )
    rec.add_argument("--decision", action="append", default=[], help="Key decision (repeatable).")
    rec.add_argument(
        "--file",
        action="append",
        default=[],
        help="Edited file path (optional ':added|modified|deleted|renamed' suffix).",
    )
    rec.add_argument(
        "--from-git-repo",
        type=Path,
        default=None,
        help="Optionally append uncommitted file metadata from git diff --numstat.",
    )

    recent = subparsers.add_parser("recent", help="List sessions from the last N hours.")
    recent.add_argument("--hours", type=float, default=24.0, help="Lookback hours (default: 24).")

    search = subparsers.add_parser("search", help="Search stored sessions and edited paths.")
    search.add_argument("query", help="Case-insensitive keyword.")
    search.add_argument("--limit", type=int, default=20, help="Max results.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.self_test:
        return run_self_test()
    if not args.command:
        print("Specify a subcommand (init, record, recent, search) or --self-test.", file=sys.stderr)
        return 2

    db_path = args.db_path or resolve_default_db_path()
    conn = connect_chronicle(db_path)
    try:
        if args.command == "init":
            print(json.dumps({"db_path": str(db_path), "status": "initialized"}, ensure_ascii=False))
            return 0
        if args.command == "record":
            files = [_parse_file_arg(raw) for raw in args.file]
            if args.from_git_repo is not None:
                files.extend(collect_git_edited_files(args.from_git_repo))
            record = record_session(
                conn,
                prompt_topic=args.topic,
                summary=args.summary,
                edited_files=files,
                assistant_name=args.assistant,
                session_key=args.session_key,
                workspace_area=args.workspace_area,
                issue_number=args.issue,
                wbs_task_id=args.wbs_task_id,
                decisions=args.decision,
                status_hint=args.status,
            )
            print(json.dumps(record.to_dict(), ensure_ascii=False, indent=2))
            return 0
        if args.command == "recent":
            records = [item.to_dict() for item in query_recent_sessions(conn, hours=args.hours)]
            print(json.dumps({"hours": args.hours, "sessions": records}, ensure_ascii=False, indent=2))
            return 0
        if args.command == "search":
            records = [item.to_dict() for item in search_chronicle(conn, args.query, limit=args.limit)]
            print(json.dumps({"query": args.query, "sessions": records}, ensure_ascii=False, indent=2))
            return 0
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
