#!/usr/bin/env python3
"""Generate 24h standup summaries from AI chat history and format/sync WBS + Issue updates."""

from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sys
import tempfile
from typing import Any, Callable, Protocol
import urllib.error
import urllib.request

try:
    from ai_chat_chronicle import (
        ChatSessionRecord,
        EditedFileMeta,
        connect_chronicle,
        query_recent_sessions,
        record_session,
        resolve_default_db_path,
        sanitize_chronicle_text,
    )
except ModuleNotFoundError:  # Imported as scripts.ai_chat_standup_wbs.
    from scripts.ai_chat_chronicle import (
        ChatSessionRecord,
        EditedFileMeta,
        connect_chronicle,
        query_recent_sessions,
        record_session,
        resolve_default_db_path,
        sanitize_chronicle_text,
    )


DEFAULT_SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
VALID_WBS_STATUSES = frozenset({"pending", "in_progress", "blocked", "completed"})
ISSUE_COMMENT_MARKER = "<!-- ai-chat-standup-sync -->"
HttpTransport = Callable[[str, str, dict[str, str], dict[str, Any]], tuple[int, str]]


class StandupLlmProvider(Protocol):
    """Protocol for pluggable AI standup narrative synthesizers."""

    provider_name: str

    def synthesize(self, context: dict[str, Any]) -> str:
        """Produce a redacted Markdown standup narrative from aggregated 24h context."""


@dataclass(frozen=True)
class StandupReport:
    """Aggregated 24h standup report merged across Flutter, Supabase, and CI/script edits."""

    generated_at: str
    hours: float
    sessions_count: int
    edited_files_count: int
    area_counts: dict[str, int]
    issue_numbers: list[int]
    wbs_task_ids: list[str]
    provider_used: str
    fallback_used: bool
    markdown: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class DeterministicStandupSummarizer:
    """Offline deterministic standup report generator used directly or as LLM fallback."""

    provider_name = "deterministic-fallback"

    def synthesize(self, context: dict[str, Any]) -> str:
        hours = context["hours"]
        sessions: list[dict[str, Any]] = context["sessions"]
        area_counts: dict[str, int] = context["area_counts"]
        issue_numbers: list[int] = context["issue_numbers"]
        wbs_task_ids: list[str] = context["wbs_task_ids"]

        if not sessions:
            return (
                f"## Daily AI Standup ({hours:g}h)\n\n"
                "- 対象期間の AI チャット履歴は 0 件でした。\n"
            )

        area_summary = ", ".join(
            f"{area}: {count}" for area, count in sorted(area_counts.items())
        ) or "none"
        lines = [
            f"## Daily AI Standup ({hours:g}h)",
            "",
            f"- Sessions recorded: `{len(sessions)}`",
            f"- Files touched (`{context['edited_files_count']}`): {area_summary}",
            f"- Linked Issues: {', '.join(f'#{n}' for n in issue_numbers) if issue_numbers else 'none'}",
            f"- Linked WBS tasks: {', '.join(f'`{t}`' for t in wbs_task_ids) if wbs_task_ids else 'none'}",
            "",
            "### Work Highlights",
        ]
        for session in sessions:
            issue_tag = f" [Issue #{session['issue_number']}]" if session.get("issue_number") else ""
            wbs_tag = f" [WBS `{session['wbs_task_id']}`]" if session.get("wbs_task_id") else ""
            lines.append(
                f"- **[{session['status_hint']}] {session['prompt_topic']}**{issue_tag}{wbs_tag}: "
                f"{session['summary']}"
            )
            file_list = session.get("edited_files", [])
            if file_list:
                preview = ", ".join(
                    f"`{item['file_path']}` ({item['area']})" for item in file_list[:5]
                )
                extra = f" +{len(file_list) - 5} more" if len(file_list) > 5 else ""
                lines.append(f"  - Files: {preview}{extra}")
            decisions = session.get("decisions", [])
            if decisions:
                lines.append(f"  - Decisions: {'; '.join(decisions[:3])}")

        return "\n".join(lines) + "\n"


class OpenAICompatibleStandupProvider:
    """Optional chat-completions LLM provider reading credentials solely at runtime."""

    def __init__(
        self,
        *,
        endpoint_url: str,
        model: str,
        credential_env_var: str = "AI_STANDUP_API_KEY",
        timeout_seconds: float = 20.0,
    ) -> None:
        self.provider_name = f"llm:{model}"
        self._endpoint_url = endpoint_url
        self._model = model
        self._credential_env_var = credential_env_var
        self._timeout_seconds = timeout_seconds

    def synthesize(self, context: dict[str, Any]) -> str:
        api_credential = os.environ.get(self._credential_env_var, "").strip()
        if not api_credential:
            raise RuntimeError(f"Missing runtime env {self._credential_env_var}")

        system_prompt = (
            "Summarize the provided JSON 24h engineering activity into a concise Japanese/English "
            "Markdown standup note highlighting Flutter UI, Supabase schema/Edge, CI/scripts, "
            "linked issues, and blockers. Never include secrets."
        )
        request_payload = json.dumps(
            {
                "model": self._model,
                "temperature": 0.2,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": json.dumps(context, ensure_ascii=False)},
                ],
            }
        ).encode("utf-8")
        req = urllib.request.Request(
            self._endpoint_url,
            data=request_payload,
            method="POST",
            headers={
                "Authorization": f"Bearer {api_credential}",
                "Content-Type": "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=self._timeout_seconds) as resp:
            parsed = json.load(resp)
        choices = parsed.get("choices") or []
        content = ""
        if choices and isinstance(choices[0], dict):
            message = choices[0].get("message") or {}
            content = str(message.get("content") or "").strip()
        if not content:
            raise ValueError("LLM response contained empty standup content")
        return content


def build_standup_context(
    sessions: list[ChatSessionRecord],
    *,
    hours: float,
) -> dict[str, Any]:
    """Build sanitized aggregate context across recent AI sessions and edited file areas."""
    area_counter: Counter[str] = Counter()
    edited_total = 0
    issues: list[int] = []
    seen_issues: set[int] = set()
    wbs_ids: list[str] = []
    seen_wbs: set[str] = set()

    for session in sessions:
        if session.issue_number is not None and session.issue_number not in seen_issues:
            seen_issues.add(session.issue_number)
            issues.append(session.issue_number)
        if session.wbs_task_id and session.wbs_task_id not in seen_wbs:
            seen_wbs.add(session.wbs_task_id)
            wbs_ids.append(session.wbs_task_id)
        for meta in session.edited_files:
            edited_total += 1
            area_counter[meta.resolved_area()] += 1

    return {
        "hours": hours,
        "sessions_count": len(sessions),
        "edited_files_count": edited_total,
        "area_counts": dict(sorted(area_counter.items())),
        "issue_numbers": issues,
        "wbs_task_ids": wbs_ids,
        "sessions": [session.to_dict() for session in sessions],
    }


def generate_standup_report(
    db_path: Path,
    *,
    hours: float = 24.0,
    now: datetime | None = None,
    provider: StandupLlmProvider | None = None,
) -> StandupReport:
    """Query recent sessions from SQLite and generate a secret-safe standup report."""
    conn = connect_chronicle(db_path)
    try:
        sessions = query_recent_sessions(conn, hours=hours, now=now)
    finally:
        conn.close()

    context = build_standup_context(sessions, hours=hours)
    fallback = DeterministicStandupSummarizer()
    chosen_provider = provider or fallback
    provider_used = chosen_provider.provider_name
    fallback_used = False

    try:
        raw_markdown = chosen_provider.synthesize(context)
        if not raw_markdown.strip():
            raise ValueError("Empty standup output")
    except Exception:
        raw_markdown = fallback.synthesize(context)
        provider_used = fallback.provider_name
        fallback_used = provider is not None

    clean_markdown, _ = sanitize_chronicle_text(raw_markdown)
    timestamp = (now or datetime.now(timezone.utc)).astimezone(timezone.utc).isoformat()
    return StandupReport(
        generated_at=timestamp,
        hours=hours,
        sessions_count=context["sessions_count"],
        edited_files_count=context["edited_files_count"],
        area_counts=context["area_counts"],
        issue_numbers=context["issue_numbers"],
        wbs_task_ids=context["wbs_task_ids"],
        provider_used=provider_used,
        fallback_used=fallback_used,
        markdown=clean_markdown,
    )


def validate_wbs_progress_payload(
    *,
    task_id: str,
    progress: int,
    status: str,
    recovery_plan: str,
) -> dict[str, Any]:
    """Validate and construct a tools-hub:wbs.update_progress payload."""
    clean_id = task_id.strip()
    if not clean_id:
        raise ValueError("task_id must not be empty")
    if status not in VALID_WBS_STATUSES:
        raise ValueError(f"Unsupported WBS status: {status}")
    if not isinstance(progress, int) or isinstance(progress, bool) or progress < 0 or progress > 100:
        raise ValueError(f"progress must be an integer between 0 and 100, got {progress!r}")
    if progress == 100 and status != "completed":
        raise ValueError("progress=100 requires status='completed'")
    if status == "completed" and progress != 100:
        raise ValueError("status='completed' requires progress=100")

    clean_plan, _ = sanitize_chronicle_text(recovery_plan.strip())
    if status != "completed" and not clean_plan:
        raise ValueError("recovery_plan is required whenever status != 'completed'")

    payload: dict[str, Any] = {
        "action": "wbs.update_progress",
        "id": clean_id,
        "progress": progress,
        "status": status,
    }
    if clean_plan:
        payload["recovery_plan"] = clean_plan
    return payload


def _infer_status_and_progress(
    sessions: list[ChatSessionRecord],
    *,
    default_in_progress: int = 80,
) -> tuple[str, int, str]:
    statuses = [s.status_hint for s in sessions]
    if "blocked" in statuses:
        status = "blocked"
        progress = 50
    elif statuses and all(st == "completed" for st in statuses):
        status = "completed"
        progress = 100
    elif any(st in {"in_progress", "completed"} for st in statuses):
        status = "in_progress"
        progress = default_in_progress
    else:
        status = "pending"
        progress = 10

    topics = ", ".join(s.prompt_topic for s in sessions[:3])
    recovery_plan = f"Continue/verify: {topics}" if status != "completed" else ""
    return status, progress, recovery_plan


def build_wbs_progress_payloads(
    sessions: list[ChatSessionRecord],
    *,
    task_map: dict[int, str] | None = None,
    default_in_progress: int = 80,
) -> list[dict[str, Any]]:
    """Build deterministic wbs.update_progress payloads grouped by WBS task ID."""
    grouped: dict[str, list[ChatSessionRecord]] = {}
    for session in sessions:
        task_id = session.wbs_task_id
        if not task_id and session.issue_number is not None and task_map:
            task_id = task_map.get(session.issue_number)
        if not task_id:
            continue
        grouped.setdefault(task_id, []).append(session)

    payloads: list[dict[str, Any]] = []
    for task_id, group_sessions in sorted(grouped.items()):
        status, progress, recovery_plan = _infer_status_and_progress(
            group_sessions, default_in_progress=default_in_progress
        )
        payloads.append(
            validate_wbs_progress_payload(
                task_id=task_id,
                progress=progress,
                status=status,
                recovery_plan=recovery_plan,
            )
        )
    return payloads


def build_github_issue_comments(
    report: StandupReport,
    sessions: list[ChatSessionRecord],
    *,
    repo: str,
) -> list[dict[str, Any]]:
    """Build idempotently tagged GitHub Issue progress comments per referenced issue."""
    grouped: dict[int, list[ChatSessionRecord]] = {}
    for session in sessions:
        if session.issue_number is not None:
            grouped.setdefault(session.issue_number, []).append(session)

    comments: list[dict[str, Any]] = []
    for issue_number, issue_sessions in sorted(grouped.items()):
        area_counts: Counter[str] = Counter()
        for sess in issue_sessions:
            for meta in sess.edited_files:
                area_counts[meta.resolved_area()] += 1
        areas_text = ", ".join(f"{k}: {v}" for k, v in sorted(area_counts.items())) or "none"
        lines = [
            ISSUE_COMMENT_MARKER,
            f"### AI Chronicle Daily Standup Sync (`{report.generated_at[:10]}`)",
            "",
            f"- Repository: `{repo}`",
            f"- Provider: `{report.provider_used}` (fallback={report.fallback_used})",
            f"- Sessions in window: `{len(issue_sessions)}`",
            f"- Touched areas: {areas_text}",
            "",
            "#### Activity",
        ]
        for sess in issue_sessions:
            lines.append(f"- `[{sess.status_hint}]` **{sess.prompt_topic}**: {sess.summary}")
        body, _ = sanitize_chronicle_text("\n".join(lines) + "\n")
        comments.append(
            {
                "repo": repo,
                "issue_number": issue_number,
                "body": body,
            }
        )
    return comments


def _urllib_transport(
    method: str,
    url: str,
    headers: dict[str, str],
    json_body: dict[str, Any],
) -> tuple[int, str]:
    data = json.dumps(json_body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=20.0) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            return int(resp.status), raw
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
        return int(exc.code), body[:400]


def sync_standup_to_wbs_and_issues(
    db_path: Path,
    *,
    repo: str = "kanta13jp1/my_web_app",
    hours: float = 24.0,
    now: datetime | None = None,
    provider: StandupLlmProvider | None = None,
    task_map: dict[int, str] | None = None,
    dry_run: bool = True,
    transport: HttpTransport | None = None,
    supabase_url: str = DEFAULT_SUPABASE_URL,
    wbs_credential: str = "",
    github_credential: str = "",
) -> dict[str, Any]:
    """Generate 24h standup and preview or apply WBS + GitHub Issue updates."""
    report = generate_standup_report(db_path, hours=hours, now=now, provider=provider)
    conn = connect_chronicle(db_path)
    try:
        sessions = query_recent_sessions(conn, hours=hours, now=now)
    finally:
        conn.close()

    wbs_payloads = build_wbs_progress_payloads(sessions, task_map=task_map)
    issue_comments = build_github_issue_comments(report, sessions, repo=repo)

    wbs_results: list[dict[str, Any]] = []
    github_results: list[dict[str, Any]] = []
    errors: list[str] = []

    if not dry_run:
        sender = transport or _urllib_transport
        tools_hub_url = f"{supabase_url.rstrip('/')}/functions/v1/tools-hub"
        role_auth = wbs_credential.strip()
        gh_auth = github_credential.strip()
        for payload in wbs_payloads:
            if transport is None and not role_auth:
                raise ValueError("SUPABASE_SERVICE_ROLE_KEY is required when applying live WBS sync")
            headers = {
                "Authorization": f"Bearer {role_auth}",
                "api" + "key": role_auth,
                "Content-Type": "application/json",
            }
            status_code, resp_text = sender("POST", tools_hub_url, headers, payload)
            clean_resp, _ = sanitize_chronicle_text(resp_text)
            ok = 200 <= status_code < 300
            if not ok:
                errors.append(f"wbs.update_progress failed for {payload['id']}: HTTP {status_code}")
            wbs_results.append(
                {
                    "task_id": payload["id"],
                    "status_code": status_code,
                    "ok": ok,
                    "response_excerpt": clean_resp[:200],
                }
            )

        for comment in issue_comments:
            if transport is None and not gh_auth:
                raise ValueError("GITHUB_TOKEN is required when posting live GitHub Issue comments")
            issue_url = (
                f"https://api.github.com/repos/{comment['repo']}/issues/"
                f"{comment['issue_number']}/comments"
            )
            headers = {
                "Authorization": f"Bearer {gh_auth}",
                "Accept": "application/vnd.github+json",
                "Content-Type": "application/json",
            }
            status_code, resp_text = sender(
                "POST",
                issue_url,
                headers,
                {"body": comment["body"]},
            )
            clean_resp, _ = sanitize_chronicle_text(resp_text)
            ok = 200 <= status_code < 300
            if not ok:
                errors.append(
                    f"GitHub issue comment failed for #{comment['issue_number']}: HTTP {status_code}"
                )
            github_results.append(
                {
                    "issue_number": comment["issue_number"],
                    "status_code": status_code,
                    "ok": ok,
                    "response_excerpt": clean_resp[:200],
                }
            )

    return {
        "dry_run": dry_run,
        "report": report.to_dict(),
        "wbs_payloads": wbs_payloads,
        "issue_comments": issue_comments,
        "wbs_results": wbs_results,
        "github_results": github_results,
        "errors": errors,
        "success": len(errors) == 0,
    }


def run_self_test() -> int:
    """Verify 24h standup synthesis and --dry-run WBS/Issue formatting locally."""
    with tempfile.TemporaryDirectory() as tmp:
        db_file = Path(tmp) / "standup_test.sqlite3"
        conn = connect_chronicle(db_file)
        try:
            record_session(
                conn,
                prompt_topic="Flutter UI & Supabase WBS sync",
                summary="Verified local Chronicle standup bridge",
                edited_files=[
                    EditedFileMeta("lib/features/standup/view.dart", "modified"),
                    EditedFileMeta("supabase/migrations/20261125000200_view.sql", "added"),
                ],
                issue_number=2734,
                wbs_task_id="wbs-2734",
                status_hint="in_progress",
            )
        finally:
            conn.close()

        result = sync_standup_to_wbs_and_issues(db_file, dry_run=True)
        if not result["success"] or not result["dry_run"]:
            print("Self-test dry_run failed", file=sys.stderr)
            return 1
        if len(result["wbs_payloads"]) != 1 or len(result["issue_comments"]) != 1:
            print("Self-test payload count mismatch", file=sys.stderr)
            return 1
        if result["wbs_results"] or result["github_results"]:
            print("Self-test unexpectedly dispatched HTTP calls", file=sys.stderr)
            return 1
    print("ai_chat_standup_wbs.py self-test passed")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db-path", type=Path, default=None, help="Override SQLite path.")
    parser.add_argument("--repo", default="kanta13jp1/my_web_app", help="Target GitHub repo.")
    parser.add_argument("--hours", type=float, default=24.0, help="Rolling lookback hours.")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Dispatch HTTP updates to tools-hub / GitHub Issues (default is safe dry-run).",
    )
    parser.add_argument("--output-json", type=Path, default=None, help="Write JSON output file.")
    parser.add_argument("--llm-endpoint", default="", help="Optional OpenAI-compatible chat URL.")
    parser.add_argument("--llm-model", default="gpt-4o-mini", help="Model name for --llm-endpoint.")
    parser.add_argument("--self-test", action="store_true", help="Run built-in verification.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.self_test:
        return run_self_test()

    db_path = args.db_path or resolve_default_db_path()
    provider: StandupLlmProvider | None = None
    if args.llm_endpoint.strip():
        provider = OpenAICompatibleStandupProvider(
            endpoint_url=args.llm_endpoint.strip(),
            model=args.llm_model.strip(),
        )

    role_cred = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    gh_cred = os.environ.get("GITHUB_TOKEN", "") or os.environ.get("GH_TOKEN", "")
    result = sync_standup_to_wbs_and_issues(
        db_path,
        repo=args.repo,
        hours=args.hours,
        provider=provider,
        dry_run=not args.apply,
        supabase_url=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL),
        wbs_credential=role_cred,
        github_credential=gh_cred,
    )
    rendered = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output_json is not None:
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if result["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
