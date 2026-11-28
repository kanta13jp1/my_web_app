#!/usr/bin/env python3
"""Daily KPI aggregation, draft package builder, and fail-closed human-review staging.

Bridges existing content automation workflows (daily-report, weekly-sns-draft,
blog-draft, blog-publish) by deterministically aggregating daily KPI metrics
and commit history without external paid-AI dependencies, redacting secrets/PII,
and staging drafts behind an explicit human-approval gate before publishing.
"""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Iterable, Sequence

try:
    from security_review_input import redact_secrets_with_count
except ModuleNotFoundError:
    try:
        from scripts.security_review_input import redact_secrets_with_count
    except ModuleNotFoundError:
        _SCRIPTS_DIR = Path(__file__).resolve().parent
        if str(_SCRIPTS_DIR) not in sys.path:
            sys.path.insert(0, str(_SCRIPTS_DIR))
        from security_review_input import redact_secrets_with_count


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_METRICS_PATH = REPO_ROOT / "docs" / "metrics" / "daily-metrics.json"
REQUIRED_PIPELINE_WORKFLOWS = (
    ".github/workflows/daily-report.yml",
    ".github/workflows/weekly-sns-draft.yml",
    ".github/workflows/blog-draft.yml",
    ".github/workflows/blog-publish.yml",
)

PROVIDER_PREFIX_RE = re.compile(
    r"\b(?:github_pat_[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9_]+|glpat-[A-Za-z0-9_-]+|"
    r"sb_secret_[A-Za-z0-9._-]+|sbp_[A-Za-z0-9._-]+|xox[baprs]-[A-Za-z0-9-]+|"
    r"sk-(?:proj-)?[A-Za-z0-9._-]+|AIza[A-Za-z0-9_-]+|eaw_[A-Za-z0-9]+)\b"
)
EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
ACCOUNT_DIGITS_RE = re.compile(r"\b(?:\d{4}[-\s]\d{4}[-\s]\d{4}[-\s]\d{1,4}|\d{12,19})\b")
URL_RE = re.compile(r"https?://\S+")
BOT_ACTORS = {"", "bot", "github-actions[bot]", "dependabot[bot]", "renovate[bot]"}


@dataclasses.dataclass(frozen=True)
class DailyKpiSnapshot:
    report_date: str
    users_total: int
    paid_total: int
    mrr_yen: int
    new_requests_today: int
    open_requests_count: int
    top_open_requests: tuple[str, ...]
    recent_achievements: tuple[str, ...]
    redaction_count: int


@dataclasses.dataclass(frozen=True)
class DraftBundle:
    target_date: str
    kpi: DailyKpiSnapshot
    commit_highlights: tuple[str, ...]
    daily_report_md: str
    weekly_sns_md: str
    blog_draft_ja_md: str
    blog_draft_en_md: str
    draft_sha256: str
    redaction_count: int


@dataclasses.dataclass(frozen=True)
class ReviewStagingRecord:
    staging_id: str
    target_date: str
    review_status: str
    auto_publish_allowed: bool
    draft_sha256: str
    issue_title: str
    issue_body: str
    issue_labels: tuple[str, ...]


@dataclasses.dataclass(frozen=True)
class PublishGateResult:
    allowed: bool
    reason: str
    reviewer: str
    approved_at: str
    checked_sha256: str


def sanitize_untrusted_text(value: Any, *, max_chars: int = 140) -> tuple[str, int]:
    """Redact credentials/PII, flatten newlines, and bound length."""
    raw = str(value or "")
    cleaned, base_hits = redact_secrets_with_count(raw)
    cleaned, prefix_hits = PROVIDER_PREFIX_RE.subn("[REDACTED_TOKEN]", cleaned)
    cleaned, email_hits = EMAIL_RE.subn("[REDACTED_EMAIL]", cleaned)
    cleaned, digit_hits = ACCOUNT_DIGITS_RE.subn("[REDACTED_ID]", cleaned)
    cleaned = URL_RE.sub("[link]", cleaned)
    flattened = " ".join(cleaned.split()).strip()
    if len(flattened) > max_chars:
        flattened = flattened[: max_chars - 3].rstrip() + "..."
    return flattened, base_hits + prefix_hits + email_hits + digit_hits


def _as_int(value: Any, default: int = 0) -> int:
    if isinstance(value, bool) or value is None:
        return default
    try:
        return max(0, int(float(value)))
    except (TypeError, ValueError):
        return default


def parse_daily_kpi_metrics(
    payload: dict[str, Any],
    *,
    fallback_date: str = "",
) -> DailyKpiSnapshot:
    """Aggregate KPI counters safely from daily-metrics.json digest payload."""
    digest = payload.get("digest")
    digest_obj = digest if isinstance(digest, dict) else payload

    report_date = str(
        payload.get("report_date")
        or digest_obj.get("date")
        or fallback_date
        or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
    ).strip()

    users_obj = digest_obj.get("users") if isinstance(digest_obj.get("users"), dict) else {}
    paid_obj = digest_obj.get("paid") if isinstance(digest_obj.get("paid"), dict) else {}
    rev_obj = digest_obj.get("revenue") if isinstance(digest_obj.get("revenue"), dict) else {}
    req_obj = (
        digest_obj.get("featureRequests")
        if isinstance(digest_obj.get("featureRequests"), dict)
        else {}
    )

    total_redacts = 0
    top_requests: list[str] = []
    raw_top = req_obj.get("topOpen")
    if isinstance(raw_top, list):
        for entry in raw_top[:5]:
            if isinstance(entry, dict):
                title, cnt = sanitize_untrusted_text(entry.get("title"), max_chars=96)
                votes = _as_int(entry.get("votes"))
                total_redacts += cnt
                if title:
                    top_requests.append(f"{votes}票: {title}")
            elif isinstance(entry, str):
                title, cnt = sanitize_untrusted_text(entry, max_chars=96)
                total_redacts += cnt
                if title:
                    top_requests.append(title)

    achievements: list[str] = []
    raw_ach = digest_obj.get("recentAchievements")
    if isinstance(raw_ach, list):
        for entry in raw_ach[:5]:
            raw_title = entry.get("title") if isinstance(entry, dict) else entry
            clean_title, cnt = sanitize_untrusted_text(raw_title, max_chars=110)
            total_redacts += cnt
            if clean_title:
                achievements.append(clean_title)

    return DailyKpiSnapshot(
        report_date=report_date,
        users_total=_as_int(users_obj.get("total")),
        paid_total=_as_int(paid_obj.get("total")),
        mrr_yen=_as_int(rev_obj.get("mrrYen")),
        new_requests_today=_as_int(req_obj.get("newToday")),
        open_requests_count=_as_int(req_obj.get("openCount")),
        top_open_requests=tuple(top_requests),
        recent_achievements=tuple(achievements),
        redaction_count=total_redacts,
    )


def collect_commit_highlights(
    repo_root: Path,
    *,
    days: int = 7,
    limit: int = 8,
    explicit_commits: Iterable[str] | None = None,
) -> tuple[tuple[str, ...], int]:
    """Extract sanitized non-automated git commit highlights."""
    raw_lines: list[str]
    if explicit_commits is not None:
        raw_lines = [str(item) for item in explicit_commits]
    else:
        proc = subprocess.run(
            [
                "git",
                "-C",
                str(repo_root),
                "log",
                f"--since={max(1, days)}.days.ago",
                "--no-merges",
                f"--max-count={max(1, limit * 2)}",
                "--pretty=format:%s",
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
        raw_lines = proc.stdout.splitlines() if proc.returncode == 0 else []

    highlights: list[str] = []
    redacts = 0
    for line in raw_lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("自動:"):
            continue
        cleaned, cnt = sanitize_untrusted_text(stripped, max_chars=110)
        redacts += cnt
        if cleaned and cleaned not in highlights:
            highlights.append(cleaned)
        if len(highlights) >= limit:
            break
    return tuple(highlights), redacts


def build_draft_bundle(
    kpi: DailyKpiSnapshot,
    commit_highlights: Sequence[str],
    *,
    target_date: str | None = None,
) -> DraftBundle:
    """Deterministically format daily report, weekly SNS draft, and JA/EN blog drafts."""
    resolved_date = target_date or kpi.report_date
    highlights = tuple(commit_highlights) or ("最新の開発・安定化改善を継続実施",)
    highlights_bullets = "\n".join(f"- {item}" for item in highlights)
    achievements_bullets = "\n".join(f"- {item}" for item in kpi.recent_achievements) or "- (直近実績なし)"
    requests_bullets = "\n".join(f"- {item}" for item in kpi.top_open_requests) or "- (公開要望なし)"

    daily_report_md = (
        f"# Daily KPI Report ({resolved_date})\n\n"
        f"- 登録ユーザー数: `{kpi.users_total}`\n"
        f"- 有料ユーザー数: `{kpi.paid_total}`\n"
        f"- MRR: `¥{kpi.mrr_yen}`\n"
        f"- 新規要望: `{kpi.new_requests_today}` (Open: `{kpi.open_requests_count}`)\n\n"
        f"## 注目のオープン要望\n{requests_bullets}\n\n"
        f"## 直近の開発実績\n{achievements_bullets}\n"
    )

    sns_headline = highlights[0]
    weekly_sns_md = (
        f"# 週次 SNS 投稿ドラフト ({resolved_date})\n\n"
        "> 公開ステータス: pending_human_approval (承認前の自動投稿は禁止)\n\n"
        "## X 投稿案 (承認待ち)\n"
        f"開発日誌 ({resolved_date}): {sns_headline} などを改善しました。"
        f"現在の登録ユーザー {kpi.users_total} 人 / 継続改善中 #buildinpublic #FlutterWeb #Supabase\n\n"
        f"## 今週の開発ハイライト\n{highlights_bullets}\n"
    )

    blog_draft_ja_md = (
        "---\n"
        f'title: "日次KPI集計と開発ログからの原稿ステージング ({resolved_date})"\n'
        "tags: Flutter,Supabase,buildinpublic,automation\n"
        "published: false\n"
        "---\n\n"
        f"# 日次KPI集計と開発ログからの原稿ステージング ({resolved_date})\n\n"
        "## はじめに\n"
        f"{resolved_date} 時点の指標（登録ユーザー {kpi.users_total} 名・要望 {kpi.open_requests_count} 件）と直近コミットを整理しました。\n\n"
        "## 実装ハイライト\n"
        f"{highlights_bullets}\n\n"
        "## 運用とレビューゲート\n"
        "自動生成されたドラフトはすべて `published: false` として人間レビュー Issue へステージングされ、承認前には公開されません。\n\n"
        "## まとめ\n"
        "計測可能なKPIと決定論的品質ゲートにより、安全な情報発信運用を維持しています。\n"
    )

    blog_draft_en_md = (
        "---\n"
        f'title: "Automated KPI Aggregation and Human-Gated Content Staging ({resolved_date})"\n'
        "tags: flutter,supabase,buildinpublic,automation\n"
        "published: false\n"
        "---\n\n"
        f"# Automated KPI Aggregation and Human-Gated Content Staging ({resolved_date})\n\n"
        "## Overview\n"
        f"As of {resolved_date}, total registered users stand at {kpi.users_total} with {kpi.open_requests_count} tracked requests.\n\n"
        "## Engineering Highlights\n"
        f"{highlights_bullets}\n\n"
        "## Human-Review Gate\n"
        "All generated drafts remain strictly marked `published: false` until an explicit human approval hash matches the staged bundle.\n\n"
        "## Next Steps\n"
        "Review and edit staged items before authorizing any external distribution.\n"
    )

    total_redacts = kpi.redaction_count
    canonical_payload = json.dumps(
        {
            "target_date": resolved_date,
            "daily_report_md": daily_report_md,
            "weekly_sns_md": weekly_sns_md,
            "blog_draft_ja_md": blog_draft_ja_md,
            "blog_draft_en_md": blog_draft_en_md,
        },
        ensure_ascii=False,
        sort_keys=True,
    )
    bundle_sha = hashlib.sha256(canonical_payload.encode("utf-8")).hexdigest()

    return DraftBundle(
        target_date=resolved_date,
        kpi=kpi,
        commit_highlights=highlights,
        daily_report_md=daily_report_md,
        weekly_sns_md=weekly_sns_md,
        blog_draft_ja_md=blog_draft_ja_md,
        blog_draft_en_md=blog_draft_en_md,
        draft_sha256=bundle_sha,
        redaction_count=total_redacts,
    )


def _draft_is_unpublished(markdown_text: str) -> bool:
    for line in markdown_text.splitlines():
        if re.match(r"^\s*published:\s*false\s*$", line, re.IGNORECASE):
            return True
    return False


def stage_for_human_review(bundle: DraftBundle) -> ReviewStagingRecord:
    """Create a fail-closed GitHub Issue review-staging payload with auto-publish disabled."""
    if not _draft_is_unpublished(bundle.blog_draft_ja_md) or not _draft_is_unpublished(
        bundle.blog_draft_en_md
    ):
        raise ValueError("Staged blog drafts must keep published: false")

    short_sha = bundle.draft_sha256[:12]
    staging_id = f"content-review-{bundle.target_date}-{short_sha}"
    issue_title = f"[Human Review Required] 日次KPI・週次SNS/ブログ原稿ステージング ({bundle.target_date})"
    issue_body = (
        f"<!-- content-review-staging-id: {staging_id} -->\n"
        f"<!-- content-review-draft-sha256: {bundle.draft_sha256} -->\n\n"
        "## レビュー承認ゲート (`pending_human_approval`)\n"
        "- 自動公開フラグ: `auto_publish_allowed = false`\n"
        f"- 対象日: `{bundle.target_date}`\n"
        f"- 原稿ハッシュ (SHA-256): `{bundle.draft_sha256}`\n"
        "- 公開するには人間レビュー担当者が内容を確認・承認記録を登録してください。\n\n"
        "## 日次KPIサマリー\n"
        f"{bundle.daily_report_md}\n"
        "## 週次 SNS ドラフト案\n"
        f"{bundle.weekly_sns_md}\n"
        "## 日本語ブログドラフト (`published: false`)\n"
        "```markdown\n"
        f"{bundle.blog_draft_ja_md}"
        "```\n"
    )
    redacted_body, _ = redact_secrets_with_count(issue_body)
    redacted_body, _ = PROVIDER_PREFIX_RE.subn("[REDACTED_TOKEN]", redacted_body)
    redacted_body, _ = EMAIL_RE.subn("[REDACTED_EMAIL]", redacted_body)
    redacted_body, _ = ACCOUNT_DIGITS_RE.subn("[REDACTED_ID]", redacted_body)

    return ReviewStagingRecord(
        staging_id=staging_id,
        target_date=bundle.target_date,
        review_status="pending_human_approval",
        auto_publish_allowed=False,
        draft_sha256=bundle.draft_sha256,
        issue_title=issue_title,
        issue_body=redacted_body,
        issue_labels=("content-review", "pending-human-approval", "automated"),
    )


def evaluate_publish_gate(
    staging: ReviewStagingRecord,
    approval: dict[str, Any] | None = None,
) -> PublishGateResult:
    """Fail-closed publish authorization check requiring human reviewer and matching hash."""
    if staging.review_status != "pending_human_approval" or staging.auto_publish_allowed:
        return PublishGateResult(
            allowed=False,
            reason="invalid_staging_baseline",
            reviewer="",
            approved_at="",
            checked_sha256=staging.draft_sha256,
        )

    if not approval or not isinstance(approval, dict):
        return PublishGateResult(
            allowed=False,
            reason="missing_human_approval",
            reviewer="",
            approved_at="",
            checked_sha256=staging.draft_sha256,
        )

    status = str(approval.get("status") or "").strip().lower()
    reviewer = str(approval.get("reviewer") or "").strip()
    approved_at = str(approval.get("approved_at") or "").strip()
    approved_sha = str(approval.get("draft_sha256") or "").strip().lower()

    if status != "approved":
        return PublishGateResult(
            allowed=False,
            reason=f"review_not_approved:{status or 'empty'}",
            reviewer=reviewer,
            approved_at=approved_at,
            checked_sha256=staging.draft_sha256,
        )
    if reviewer.lower() in BOT_ACTORS or reviewer.lower().endswith("[bot]"):
        return PublishGateResult(
            allowed=False,
            reason="bot_approver_rejected",
            reviewer=reviewer,
            approved_at=approved_at,
            checked_sha256=staging.draft_sha256,
        )
    if not approved_at:
        return PublishGateResult(
            allowed=False,
            reason="missing_approval_timestamp",
            reviewer=reviewer,
            approved_at="",
            checked_sha256=staging.draft_sha256,
        )
    if approved_sha != staging.draft_sha256.lower():
        return PublishGateResult(
            allowed=False,
            reason="draft_sha256_mismatch",
            reviewer=reviewer,
            approved_at=approved_at,
            checked_sha256=staging.draft_sha256,
        )

    return PublishGateResult(
        allowed=True,
        reason="human_approved_matching_hash",
        reviewer=reviewer,
        approved_at=approved_at,
        checked_sha256=staging.draft_sha256,
    )


def audit_content_pipeline_contracts(repo_root: Path = REPO_ROOT) -> list[str]:
    """Verify existing daily/weekly/blog workflows remain present and well-formed."""
    errors: list[str] = []
    for rel in REQUIRED_PIPELINE_WORKFLOWS:
        wf_path = repo_root / rel
        if not wf_path.is_file():
            errors.append(f"Missing required workflow: {rel}")
            continue
        text = wf_path.read_text(encoding="utf-8", errors="replace")
        if "permissions: {}" not in text:
            errors.append(f"Workflow missing top-level permissions: {{}}: {rel}")
    return errors


def render_markdown_summary(
    *,
    bundle: DraftBundle,
    staging: ReviewStagingRecord,
    gate: PublishGateResult,
    contract_errors: Sequence[str],
) -> str:
    return (
        "## Content Draft Human-Review Staging Report\n\n"
        f"- Staging ID: `{staging.staging_id}`\n"
        f"- Target Date: `{bundle.target_date}`\n"
        f"- Review Status: `{staging.review_status}`\n"
        f"- Auto-Publish Allowed: `{str(staging.auto_publish_allowed).lower()}`\n"
        f"- Publish Gate Authorized: `{str(gate.allowed).lower()}` (`{gate.reason}`)\n"
        f"- Contract Audit Errors: `{len(contract_errors)}`\n"
        f"- Users / Paid / MRR: `{bundle.kpi.users_total}` / `{bundle.kpi.paid_total}` / `¥{bundle.kpi.mrr_yen}`\n"
        f"- Redactions Applied: `{bundle.redaction_count}`\n"
    )


def run_self_test() -> int:
    sample_metrics = {
        "report_date": "2026-11-25",
        "digest": {
            "users": {"total": 61},
            "paid": {"total": 2},
            "revenue": {"mrrYen": 1960},
            "featureRequests": {
                "newToday": 1,
                "openCount": 12,
                "topOpen": [{"title": "Export CSV " + "ghp_" + "sample1234567890", "votes": 3}],
            },
            "recentAchievements": [{"title": "Added automated staging checks"}],
        },
    }
    kpi = parse_daily_kpi_metrics(sample_metrics)
    assert kpi.redaction_count >= 1
    assert "sample1234567890" not in " ".join(kpi.top_open_requests)

    bundle = build_draft_bundle(kpi, ["Improved automated draft quality verification"])
    staging = stage_for_human_review(bundle)
    assert staging.review_status == "pending_human_approval"
    assert staging.auto_publish_allowed is False

    denied_default = evaluate_publish_gate(staging, None)
    assert denied_default.allowed is False and denied_default.reason == "missing_human_approval"

    denied_bot = evaluate_publish_gate(
        staging,
        {
            "status": "approved",
            "reviewer": "github-actions[bot]",
            "approved_at": "2026-11-25T09:00:00Z",
            "draft_sha256": staging.draft_sha256,
        },
    )
    assert denied_bot.allowed is False and denied_bot.reason == "bot_approver_rejected"

    approved = evaluate_publish_gate(
        staging,
        {
            "status": "approved",
            "reviewer": "kanta13jp1",
            "approved_at": "2026-11-25T09:05:00Z",
            "draft_sha256": staging.draft_sha256,
        },
    )
    assert approved.allowed is True

    with tempfile.TemporaryDirectory() as tmp_dir:
        out_file = Path(tmp_dir) / "staging.json"
        out_file.write_text(json.dumps(dataclasses.asdict(staging)), encoding="utf-8")
        assert out_file.is_file()

    print("OK: content_draft_review_staging self-test passed")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--metrics-json", type=Path, default=DEFAULT_METRICS_PATH)
    parser.add_argument("--commits-json", type=Path)
    parser.add_argument("--git-days", type=int, default=7)
    parser.add_argument("--target-date", default="")
    parser.add_argument("--approval-json", type=Path)
    parser.add_argument("--audit-contracts", action="store_true")
    parser.add_argument("--dry-run", action="store_true", help="Run staging without external API writes")
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--markdown-out", type=Path)
    parser.add_argument("--issue-payload-out", type=Path)
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()

    repo_root = args.repo_root.resolve()
    contract_errors: list[str] = []
    if args.audit_contracts:
        contract_errors = audit_content_pipeline_contracts(repo_root)

    if args.metrics_json.is_file():
        raw_metrics = json.loads(args.metrics_json.read_text(encoding="utf-8-sig"))
    else:
        raw_metrics = {"report_date": args.target_date, "digest": {}}

    kpi = parse_daily_kpi_metrics(raw_metrics, fallback_date=args.target_date)
    explicit_commits: list[str] | None = None
    if args.commits_json is not None and args.commits_json.is_file():
        loaded_commits = json.loads(args.commits_json.read_text(encoding="utf-8-sig"))
        if isinstance(loaded_commits, list):
            explicit_commits = [str(item) for item in loaded_commits]

    highlights, commit_redacts = collect_commit_highlights(
        repo_root,
        days=args.git_days,
        explicit_commits=explicit_commits,
    )
    kpi = dataclasses.replace(kpi, redaction_count=kpi.redaction_count + commit_redacts)
    bundle = build_draft_bundle(kpi, highlights, target_date=args.target_date or None)
    staging = stage_for_human_review(bundle)

    approval_obj: dict[str, Any] | None = None
    if args.approval_json is not None and args.approval_json.is_file():
        loaded_app = json.loads(args.approval_json.read_text(encoding="utf-8-sig"))
        if isinstance(loaded_app, dict):
            approval_obj = loaded_app
    gate = evaluate_publish_gate(staging, approval_obj)

    report = {
        "schema_version": 1,
        "mode": "dry_run",
        "contract_errors": contract_errors,
        "kpi": dataclasses.asdict(kpi),
        "staging": dataclasses.asdict(staging),
        "publish_gate": dataclasses.asdict(gate),
    }
    json_text = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    md_text = render_markdown_summary(
        bundle=bundle,
        staging=staging,
        gate=gate,
        contract_errors=contract_errors,
    )

    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json_text, encoding="utf-8", newline="\n")
    if args.markdown_out is not None:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(md_text, encoding="utf-8", newline="\n")
    if args.issue_payload_out is not None:
        args.issue_payload_out.parent.mkdir(parents=True, exist_ok=True)
        issue_payload = {
            "title": staging.issue_title,
            "body": staging.issue_body,
            "labels": list(staging.issue_labels),
            "review_status": staging.review_status,
            "draft_sha256": staging.draft_sha256,
        }
        args.issue_payload_out.write_text(
            json.dumps(issue_payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    if args.github_output is not None:
        args.github_output.parent.mkdir(parents=True, exist_ok=True)
        with args.github_output.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(f"staging_id={staging.staging_id}\n")
            handle.write(f"review_status={staging.review_status}\n")
            handle.write(f"auto_publish_allowed={str(staging.auto_publish_allowed).lower()}\n")
            handle.write(f"publish_gate_allowed={str(gate.allowed).lower()}\n")
    if args.json_out is None and args.markdown_out is None:
        print(md_text, end="")

    return 1 if contract_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
