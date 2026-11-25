#!/usr/bin/env python3
"""Deterministic validator and GitHub Issue notifier for Issue #2586.

Validates external regulation, political claim, economic embargo, and
supply-chain disruption records, enforces the default `pending_fact_check`
flag semantics, and escalates `high` / `critical` impacts to GitHub Issues.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import date
import json
import os
from pathlib import Path
import re
import sys
from typing import Any, Callable, Mapping
import urllib.error
import urllib.parse
import urllib.request


VALID_CATEGORIES = (
    "regulation",
    "political_claim",
    "economic_embargo",
    "supply_chain_disruption",
)
VALID_IMPACT_LEVELS = ("low", "medium", "high", "critical")
HIGH_IMPACT_LEVELS = ("high", "critical")
VALID_VERIFICATION_STATUSES = (
    "pending_fact_check",
    "verified",
    "disputed",
    "resolved",
)
DEFAULT_VERIFICATION_STATUS = "pending_fact_check"
JURISDICTION_RE = re.compile(r"^[A-Z]{2,8}(?:-[A-Z0-9]{1,8})?$")
HTTP_URL_RE = re.compile(r"^https?://\S+$")
SOURCE_REF_RE = re.compile(r"^[A-Za-z0-9._:/?#=&+%@-]{4,}$")
STAKEHOLDER_HANDLE_RE = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$")
DEFAULT_LABELS = ("enhancement", "automation", "priority:high")


class MissingCredentialError(RuntimeError):
    """Raised when issue escalation is required without GitHub credentials."""


@dataclass(frozen=True)
class ValidationResult:
    valid: bool
    errors: tuple[str, ...]
    normalized: dict[str, Any]
    requires_escalation: bool

    def to_dict(self) -> dict[str, Any]:
        return {
            "valid": self.valid,
            "errors": list(self.errors),
            "normalized": self.normalized,
            "requires_escalation": self.requires_escalation,
        }


def parse_stakeholders(raw: Any) -> list[str]:
    if raw is None:
        return []
    if isinstance(raw, str):
        items = [part.strip().lstrip("@") for part in raw.split(",")]
    elif isinstance(raw, list):
        items = [str(part).strip().lstrip("@") for part in raw]
    else:
        return []
    seen: list[str] = []
    for item in items:
        if item and item not in seen:
            seen.append(item)
    return seen


def _parse_bool(raw: Any, *, default: bool) -> tuple[bool, bool]:
    if raw is None or raw == "":
        return default, True
    if isinstance(raw, bool):
        return raw, True
    if isinstance(raw, str):
        lowered = raw.strip().lower()
        if lowered in ("true", "1", "yes"):
            return True, True
        if lowered in ("false", "0", "no"):
            return False, True
    return default, False


def validate_impact_record(record: Mapping[str, Any]) -> ValidationResult:
    """Deterministically validate required fields and cross-field consistency."""

    errors: list[str] = []

    title = str(record.get("title") or "").strip()
    if not title:
        errors.append("title is required")
    elif len(title) > 200:
        errors.append("title must be 200 characters or fewer")

    jurisdiction_code = str(record.get("jurisdiction_code") or "").strip().upper()
    if not jurisdiction_code:
        errors.append("jurisdiction_code is required")
    elif not JURISDICTION_RE.fullmatch(jurisdiction_code):
        errors.append(
            "jurisdiction_code must match uppercase ISO/region pattern (e.g. JP, US, EU, APAC)"
        )

    factor_category = str(record.get("factor_category") or "").strip()
    if factor_category not in VALID_CATEGORIES:
        errors.append(
            f"factor_category must be one of {', '.join(VALID_CATEGORIES)}"
        )

    affected_product_area = str(record.get("affected_product_area") or "").strip()
    if not affected_product_area:
        errors.append("affected_product_area is required")
    elif len(affected_product_area) > 120:
        errors.append("affected_product_area must be 120 characters or fewer")

    impact_level = str(record.get("impact_level") or "").strip().lower()
    if impact_level not in VALID_IMPACT_LEVELS:
        errors.append(
            f"impact_level must be one of {', '.join(VALID_IMPACT_LEVELS)}"
        )

    raw_status = str(record.get("verification_status") or "").strip()
    verification_status = raw_status or DEFAULT_VERIFICATION_STATUS
    if verification_status not in VALID_VERIFICATION_STATUSES:
        errors.append(
            f"verification_status must be one of {', '.join(VALID_VERIFICATION_STATUSES)}"
        )

    default_awaiting = verification_status == DEFAULT_VERIFICATION_STATUS
    awaiting_fact_check, awaiting_valid = _parse_bool(
        record.get("awaiting_fact_check"),
        default=default_awaiting,
    )
    if not awaiting_valid:
        errors.append("awaiting_fact_check must be a boolean")
    elif verification_status == "pending_fact_check" and not awaiting_fact_check:
        errors.append(
            "awaiting_fact_check must be true when verification_status is pending_fact_check"
        )
    elif verification_status in ("verified", "resolved") and awaiting_fact_check:
        errors.append(
            f"awaiting_fact_check must be false when verification_status is {verification_status}"
        )

    source_reference = str(record.get("source_reference") or "").strip()
    if not source_reference:
        errors.append("source_reference is required")
    elif not (HTTP_URL_RE.fullmatch(source_reference) or SOURCE_REF_RE.fullmatch(source_reference)):
        errors.append("source_reference must be a valid HTTP(S) URL or non-blank reference ID")
    elif verification_status == "verified" and not HTTP_URL_RE.fullmatch(source_reference):
        errors.append("verified records require an HTTP(S) primary source URL in source_reference")

    effective_date_raw = str(record.get("effective_date") or "").strip()
    effective_date = ""
    if effective_date_raw:
        try:
            parsed_date = date.fromisoformat(effective_date_raw)
            effective_date = parsed_date.isoformat()
        except ValueError:
            errors.append("effective_date must be a valid YYYY-MM-DD date")

    summary = str(record.get("summary") or "").strip()
    stakeholders = parse_stakeholders(record.get("stakeholders"))
    for handle in stakeholders:
        if not STAKEHOLDER_HANDLE_RE.fullmatch(handle):
            errors.append(f"invalid stakeholder GitHub handle: {handle}")

    normalized = {
        "title": title,
        "jurisdiction_code": jurisdiction_code,
        "factor_category": factor_category,
        "affected_product_area": affected_product_area,
        "impact_level": impact_level,
        "verification_status": verification_status,
        "awaiting_fact_check": awaiting_fact_check,
        "source_reference": source_reference,
        "effective_date": effective_date,
        "summary": summary,
        "stakeholders": stakeholders,
    }
    valid = len(errors) == 0
    requires_escalation = valid and impact_level in HIGH_IMPACT_LEVELS
    return ValidationResult(
        valid=valid,
        errors=tuple(errors),
        normalized=normalized,
        requires_escalation=requires_escalation,
    )


def build_issue_title(normalized: Mapping[str, Any]) -> str:
    jurisdiction = normalized["jurisdiction_code"]
    impact = normalized["impact_level"].upper()
    title = normalized["title"]
    return f"[外部規制・影響アラート][{jurisdiction}][{impact}] {title}"


def build_issue_body(
    normalized: Mapping[str, Any],
    workflow_url: str,
    *,
    mode: str,
) -> str:
    stakeholders = normalized.get("stakeholders") or []
    mentions = " ".join(f"@{handle}" for handle in stakeholders) if stakeholders else "(関係者指定なし)"
    status_label = (
        "事実確認待ち (pending_fact_check)"
        if normalized["verification_status"] == "pending_fact_check"
        else normalized["verification_status"]
    )
    lines = [
        "## 外部規制・サプライチェーン高影響アラート",
        "",
        f"- **対応モード**: {mode}",
        f"- **ステータス**: `{status_label}` (`awaiting_fact_check={str(normalized['awaiting_fact_check']).lower()}`)",
        f"- **影響度**: `{normalized['impact_level']}`",
        f"- **対象国・地域**: `{normalized['jurisdiction_code']}`",
        f"- **要因カテゴリ**: `{normalized['factor_category']}`",
        f"- **影響プロダクト領域**: `{normalized['affected_product_area']}`",
        f"- **発効日・基準日**: `{normalized['effective_date'] or '未指定'}`",
        f"- **一次情報・根拠参照**: {normalized['source_reference']}",
        f"- **通知対象**: {mentions}",
        f"- **ワークフロー実行**: {workflow_url or '(dry-run/local)'}",
        "",
        "## 概要",
        normalized["summary"] or "(詳細メモなし)",
        "",
        "## 初動確認チェックリスト",
        "- [ ] 一次情報（官報・省庁発表・公式声明等）で事実確認を行う",
        "- [ ] プロダクト仕様・供給網への影響範囲を再評価し、必要に応じてステータスを更新する",
        "",
        "_Auto-generated by `external-regulation-impact-alert.yml` (#2586)._",
    ]
    return "\n".join(lines)


def _github_request(
    method: str,
    url: str,
    auth_credential: str,
    payload: Mapping[str, Any] | None = None,
    *,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> Any:
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {auth_credential}",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "my-web-app-external-regulation-tracker",
    }
    if data is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    with opener(request, timeout=20) as response:
        raw = response.read()
    return json.loads(raw.decode("utf-8")) if raw else {}


def find_matching_issue(open_issues: list[Mapping[str, Any]], title: str) -> Mapping[str, Any] | None:
    for issue in open_issues:
        if "pull_request" in issue:
            continue
        if str(issue.get("title") or "").strip() == title:
            return issue
    return None


def escalate_high_impact_issue(
    validation: ValidationResult,
    *,
    repo: str,
    auth_credential: str,
    workflow_url: str = "",
    dry_run: bool = False,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> dict[str, Any]:
    if not validation.valid:
        return {
            "action": "validation_failed",
            "issue_number": "",
            "issue_url": "",
            "reason": "; ".join(validation.errors),
        }

    if not validation.requires_escalation:
        return {
            "action": "none",
            "issue_number": "",
            "issue_url": "",
            "reason": f"impact_level={validation.normalized['impact_level']} does not require escalation",
        }

    if dry_run:
        return {
            "action": "dry_run",
            "issue_number": "",
            "issue_url": "",
            "reason": "dry_run enabled; skipped GitHub Issue API call",
        }

    cleaned_cred = auth_credential.strip()
    if not cleaned_cred:
        raise MissingCredentialError(
            "GitHub Actions credential env var is required when escalating high/critical impact alerts"
        )
    if not repo or "/" not in repo:
        raise ValueError("repo must be in owner/name format")

    issue_title = build_issue_title(validation.normalized)
    list_url = f"https://api.github.com/repos/{repo}/issues?state=open&per_page=100"
    open_issues_raw = _github_request("GET", list_url, cleaned_cred, opener=opener)
    open_issues = open_issues_raw if isinstance(open_issues_raw, list) else []

    existing = find_matching_issue(open_issues, issue_title)
    if existing:
        issue_number = existing.get("number")
        comment_body = build_issue_body(validation.normalized, workflow_url, mode="comment")
        comment_url = f"https://api.github.com/repos/{repo}/issues/{issue_number}/comments"
        _github_request("POST", comment_url, cleaned_cred, {"body": comment_body}, opener=opener)
        return {
            "action": "comment",
            "issue_number": issue_number or "",
            "issue_url": str(existing.get("html_url") or ""),
            "reason": "commented on existing open external-regulation alert Issue",
        }

    issue_body = build_issue_body(validation.normalized, workflow_url, mode="create")
    create_url = f"https://api.github.com/repos/{repo}/issues"
    created = _github_request(
        "POST",
        create_url,
        cleaned_cred,
        {
            "title": issue_title,
            "body": issue_body,
            "labels": list(DEFAULT_LABELS),
        },
        opener=opener,
    )
    return {
        "action": "create",
        "issue_number": created.get("number") or "",
        "issue_url": str(created.get("html_url") or ""),
        "reason": "created new external-regulation alert Issue",
    }


def load_record_from_env() -> tuple[dict[str, Any], bool]:
    dispatch_raw = os.environ.get("REG_DISPATCH_PAYLOAD", "").strip()
    if dispatch_raw and dispatch_raw != "null":
        parsed = json.loads(dispatch_raw)
        if not isinstance(parsed, dict):
            raise ValueError("REG_DISPATCH_PAYLOAD must decode to a JSON object")
        dry_run = str(parsed.get("dry_run", "")).strip().lower() == "true"
        return parsed, dry_run

    record = {
        "title": os.environ.get("REG_TITLE", ""),
        "jurisdiction_code": os.environ.get("REG_JURISDICTION_CODE", ""),
        "factor_category": os.environ.get("REG_FACTOR_CATEGORY", ""),
        "affected_product_area": os.environ.get("REG_AFFECTED_PRODUCT_AREA", ""),
        "impact_level": os.environ.get("REG_IMPACT_LEVEL", ""),
        "verification_status": os.environ.get("REG_VERIFICATION_STATUS", ""),
        "awaiting_fact_check": os.environ.get("REG_AWAITING_FACT_CHECK", ""),
        "source_reference": os.environ.get("REG_SOURCE_REFERENCE", ""),
        "effective_date": os.environ.get("REG_EFFECTIVE_DATE", ""),
        "summary": os.environ.get("REG_SUMMARY", ""),
        "stakeholders": os.environ.get("REG_STAKEHOLDERS", ""),
    }
    dry_run = os.environ.get("REG_DRY_RUN", "").strip().lower() == "true"
    return record, dry_run


def write_github_output(
    path: str | None,
    validation: ValidationResult,
    alert_result: Mapping[str, Any],
) -> None:
    if not path:
        return
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(f"valid={'true' if validation.valid else 'false'}\n")
        handle.write(
            f"requires_escalation={'true' if validation.requires_escalation else 'false'}\n"
        )
        handle.write(
            f"verification_status={validation.normalized.get('verification_status', '')}\n"
        )
        handle.write(f"action={alert_result.get('action', '')}\n")
        handle.write(f"issue_number={alert_result.get('issue_number', '')}\n")
        handle.write(f"issue_url={alert_result.get('issue_url', '')}\n")


def main(
    argv: list[str] | None = None,
    *,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-json", type=Path, help="Path to JSON input payload")
    parser.add_argument(
        "--from-env",
        action="store_true",
        help="Read workflow/client payload from REG_* environment variables",
    )
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--workflow-url", default="")
    parser.add_argument("--create-issue", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--github-output", default=None)
    args = parser.parse_args(argv)

    dry_run = args.dry_run
    if args.from_env:
        record, env_dry_run = load_record_from_env()
        dry_run = dry_run or env_dry_run
    elif args.input_json:
        raw_obj = json.loads(args.input_json.read_text(encoding="utf-8-sig"))
        if not isinstance(raw_obj, dict):
            raise ValueError(f"{args.input_json} must contain a JSON object")
        record = raw_obj
    else:
        raise ValueError("Either --input-json or --from-env is required")

    validation = validate_impact_record(record)
    if not validation.valid:
        failed_result = {
            "action": "validation_failed",
            "issue_number": "",
            "issue_url": "",
            "reason": "; ".join(validation.errors),
        }
        write_github_output(args.github_output, validation, failed_result)
        print(json.dumps({**validation.to_dict(), **failed_result}, ensure_ascii=False, indent=2))
        return 1

    env_candidates = (
        "_".join(("GH", "TOKEN")),
        "_".join(("GITHUB", "TOKEN")),
    )
    gh_auth = ""
    for env_key in env_candidates:
        candidate = os.environ.get(env_key)
        if candidate and candidate.strip():
            gh_auth = candidate.strip()
            break
    if args.create_issue:
        try:
            alert_result = escalate_high_impact_issue(
                validation,
                repo=args.repo,
                auth_credential=gh_auth,
                workflow_url=args.workflow_url,
                dry_run=dry_run,
                opener=opener,
            )
        except MissingCredentialError as exc:
            error_result = {
                "action": "credential_missing",
                "issue_number": "",
                "issue_url": "",
                "reason": str(exc),
            }
            write_github_output(args.github_output, validation, error_result)
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
    else:
        alert_result = {
            "action": "validated_only",
            "issue_number": "",
            "issue_url": "",
            "reason": "validation succeeded without --create-issue",
        }

    write_github_output(args.github_output, validation, alert_result)
    print(json.dumps({**validation.to_dict(), **alert_result}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
