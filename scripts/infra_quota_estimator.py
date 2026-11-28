#!/usr/bin/env python3
"""Infra quota usage-vs-threshold estimator and billing pre-alert (#2767).

Deterministic and offline: it reads a vendor limit table
(`docs/infra-quota-limits.json`) and an owner-recorded usage snapshot
(`docs/infra-usage-snapshot.json`), classifies each measured dimension against
its plan limit, projects month-to-date usage to the end of the billing period,
and estimates the pay-as-you-go cost for growth scenarios.

It never calls a vendor API and never needs a privileged credential. The only
network call is the optional GitHub Issue upsert (`--create-issue`), which uses
the workflow `GITHUB_TOKEN` against api.github.com.

Cost figures are estimates derived from a dated copy of public price lists, not
invoices. An unmeasured or stale snapshot is never reported as healthy.
"""

from __future__ import annotations

import argparse
import calendar
from datetime import date, datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request
from typing import Any, Callable

DEFAULT_LIMITS = Path("docs/infra-quota-limits.json")
DEFAULT_SNAPSHOT = Path("docs/infra-usage-snapshot.json")
DEFAULT_ALERT_THRESHOLD_PCT = 80.0
DEFAULT_MAX_AGE_DAYS = 35
DEFAULT_GROWTH_SCENARIOS = (0, 50, 100)
WATCH_PCT = 70.0
CRITICAL_PCT = 90.0
EXCEEDED_PCT = 100.0

ALERT_TITLE_PREFIX = "[infra-quota-alert]"
REVIEW_TITLE_PREFIX = "[infra-quota-monthly-review]"
SIGNATURE_MARKER = "infra-quota-signature"
GITHUB_API = "https://api.github.com"
REPOSITORY_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")

COST_DISCLAIMER = (
    "金額はベンダー公開価格表の確認日時点の写しに基づく見積りであり、請求額ではありません。"
    "Compute add-on・Spend Cap 設定・割引・クレジットは含みません。"
)

STATE_NORMAL = "NORMAL"
STATE_WATCH = "WATCH"
STATE_ACTION = "ACTION"
STATE_CRITICAL = "CRITICAL"
STATE_EXCEEDED = "EXCEEDED"
STATE_UNMEASURED = "UNMEASURED"
STATE_LIMIT_UNVERIFIED = "LIMIT_UNVERIFIED"
STATE_NOT_APPLICABLE = "NOT_APPLICABLE"

ALERT_STATES = frozenset({STATE_ACTION, STATE_CRITICAL, STATE_EXCEEDED})


class InputError(ValueError):
    """Raised for malformed limit or snapshot input."""


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise InputError(f"cannot read {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise InputError(f"{path} must contain a JSON object")
    return data


def parse_date(value: object, label: str) -> date | None:
    if value is None:
        return None
    if not isinstance(value, str):
        raise InputError(f"{label} must be YYYY-MM-DD or null")
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise InputError(f"{label} must be YYYY-MM-DD: {value!r}") from exc


def _number(value: object) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)) and value >= 0:
        return float(value)
    return None


def classify(pct: float, alert_threshold_pct: float) -> str:
    if pct >= EXCEEDED_PCT:
        return STATE_EXCEEDED
    if pct >= CRITICAL_PCT:
        return STATE_CRITICAL
    if pct >= alert_threshold_pct:
        return STATE_ACTION
    if pct >= WATCH_PCT:
        return STATE_WATCH
    return STATE_NORMAL


def resolve_plan(limits_doc: dict[str, Any], snapshot: dict[str, Any], service: str) -> tuple[str, bool]:
    """Return (plan key, assumed). Unknown plans use the conservative default."""
    plans = limits_doc.get("plans", {}).get(service, {})
    declared = snapshot.get("plans", {}).get(service)
    if isinstance(declared, str) and declared in plans and declared != "default_when_unknown":
        return declared, False
    return str(plans.get("default_when_unknown", "")), True


def month_projection(usage: float, kind: str, period_start: date | None, collected: date | None) -> float | None:
    """Linear end-of-period projection for cumulative month counters only."""
    if kind != "month" or period_start is None or collected is None:
        return None
    elapsed_days = (collected - period_start).days + 1
    if elapsed_days <= 0:
        return None
    days_in_period = calendar.monthrange(period_start.year, period_start.month)[1]
    return usage / elapsed_days * days_in_period


def overage_cost(value: float, limit: float, price: float | None) -> float:
    if price is None:
        return 0.0
    return max(0.0, value - limit) * price


def evaluate(
    limits_doc: dict[str, Any],
    snapshot: dict[str, Any],
    *,
    today: date,
    alert_threshold_pct: float = DEFAULT_ALERT_THRESHOLD_PCT,
    max_age_days: int = DEFAULT_MAX_AGE_DAYS,
    growth_scenarios: tuple[int, ...] = DEFAULT_GROWTH_SCENARIOS,
) -> dict[str, Any]:
    if not 0 < alert_threshold_pct <= EXCEEDED_PCT:
        raise InputError("alert threshold must be in (0, 100]")
    dimensions = limits_doc.get("dimensions")
    if not isinstance(dimensions, list) or not dimensions:
        raise InputError("limits file needs a non-empty dimensions list")

    collected = parse_date(snapshot.get("collected_at"), "collected_at")
    period_start = parse_date(snapshot.get("period_start"), "period_start")
    usage_map = snapshot.get("usage") if isinstance(snapshot.get("usage"), dict) else {}
    in_use = snapshot.get("services_in_use")
    in_use_set = {s for s in in_use if isinstance(s, str)} if isinstance(in_use, list) else set()

    age_days = None if collected is None else (today - collected).days
    stale = collected is None or age_days is None or age_days > max_age_days or age_days < 0

    plan_info: dict[str, dict[str, Any]] = {}
    rows: list[dict[str, Any]] = []
    for dim in dimensions:
        service = str(dim["service"])
        plan_key, assumed = resolve_plan(limits_doc, snapshot, service)
        plan_info[service] = {"plan": plan_key, "assumed": assumed}
        limit = _number(dim.get("limits", {}).get(plan_key))
        price = _number(dim.get("overage_usd_per_unit", {}).get(plan_key))
        usage = _number(usage_map.get(dim["id"]))
        row: dict[str, Any] = {
            "id": dim["id"],
            "service": service,
            "label": dim["label"],
            "unit": dim["unit"],
            "kind": dim["kind"],
            "plan": plan_key,
            "plan_assumed": assumed,
            "limit": limit,
            "usage": usage,
            "pct": None,
            "projected": None,
            "projected_pct": None,
            "forecast_exceeds": False,
            "state": STATE_NORMAL,
            "alert": False,
        }
        if service not in in_use_set:
            row["state"] = STATE_NOT_APPLICABLE
        elif limit is None:
            row["state"] = STATE_LIMIT_UNVERIFIED
        elif usage is None or stale:
            row["state"] = STATE_UNMEASURED
        else:
            row["pct"] = round(usage / limit * 100.0, 1) if limit else None
            if row["pct"] is not None:
                row["state"] = classify(row["pct"], alert_threshold_pct)
            projected = month_projection(usage, str(dim["kind"]), period_start, collected)
            if projected is not None and dim["id"] != "supabase.mau":
                row["projected"] = round(projected, 3)
                row["projected_pct"] = round(projected / limit * 100.0, 1) if limit else None
                row["forecast_exceeds"] = bool(row["projected_pct"] is not None and row["projected_pct"] >= EXCEEDED_PCT)
            row["alert"] = row["state"] in ALERT_STATES or row["forecast_exceeds"]
        rows.append(row)

    scenarios = _scenarios(limits_doc, snapshot, rows, dimensions, plan_info, growth_scenarios)
    measurable = [r for r in rows if r["state"] not in (STATE_NOT_APPLICABLE,)]
    unmeasured = [r["id"] for r in measurable if r["state"] == STATE_UNMEASURED]
    unverified = [r["id"] for r in measurable if r["state"] == STATE_LIMIT_UNVERIFIED]
    alerts = [r["id"] for r in rows if r["alert"]]
    owner_action = bool(stale or unmeasured)
    status = "alert" if alerts else ("owner_action_required" if owner_action else "ok")
    return {
        "generated_for": today.isoformat(),
        "alert_threshold_pct": alert_threshold_pct,
        "snapshot": {
            "collected_at": None if collected is None else collected.isoformat(),
            "period_start": None if period_start is None else period_start.isoformat(),
            "age_days": age_days,
            "max_age_days": max_age_days,
            "stale": stale,
        },
        "plans": plan_info,
        "rows": rows,
        "alerts": alerts,
        "unmeasured": unmeasured,
        "limit_unverified": unverified,
        "owner_action_required": owner_action,
        "status": status,
        "scenarios": scenarios,
        "limits_verified_on": limits_doc.get("verified_on"),
        "cost_disclaimer": COST_DISCLAIMER,
    }


def _scenarios(
    limits_doc: dict[str, Any],
    snapshot: dict[str, Any],
    rows: list[dict[str, Any]],
    dimensions: list[dict[str, Any]],
    plan_info: dict[str, dict[str, Any]],
    growth_scenarios: tuple[int, ...],
) -> list[dict[str, Any]]:
    """Estimate pay-as-you-go cost if the account were on the paid plan.

    Paid-plan keys are those with a positive overage price for a dimension.
    Free/Spark plans do not bill; the consequence is a restriction instead.
    """
    paid_plan = {"supabase": "pro", "firebase_hosting": "blaze"}
    plans = limits_doc.get("plans", {})
    by_id = {d["id"]: d for d in dimensions}
    results: list[dict[str, Any]] = []
    for growth in growth_scenarios:
        multiplier = 1.0 + growth / 100.0
        total = 0.0
        per_service: dict[str, float] = {}
        for service, plan_key in paid_plan.items():
            base = _number(plans.get(service, {}).get(plan_key, {}).get("base_monthly_usd")) or 0.0
            per_service[service] = base
        complete = True
        for row in rows:
            if row["state"] in (STATE_NOT_APPLICABLE,):
                continue
            service = row["service"]
            plan_key = paid_plan[service]
            dim = by_id[row["id"]]
            limit = _number(dim.get("limits", {}).get(plan_key))
            price = _number(dim.get("overage_usd_per_unit", {}).get(plan_key))
            value = row["projected"] if row["projected"] is not None else row["usage"]
            if value is None or limit is None or row["state"] == STATE_UNMEASURED:
                complete = False
                continue
            per_service[service] += overage_cost(value * multiplier, limit, price)
        total = sum(per_service.values())
        results.append(
            {
                "growth_pct": growth,
                "estimated_monthly_usd": round(total, 2),
                "per_service_usd": {k: round(v, 2) for k, v in per_service.items()},
                "complete": complete,
            }
        )
    return results


def build_signature(report: dict[str, Any]) -> str:
    parts = [
        report["status"],
        ",".join(sorted(report["alerts"])),
        ",".join(sorted(report["unmeasured"])),
        "stale" if report["snapshot"]["stale"] else "fresh",
    ]
    return hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()[:16]


def _fmt(value: float | None, digits: int = 1) -> str:
    return "未計測" if value is None else f"{value:,.{digits}f}"


def render_markdown(report: dict[str, Any]) -> str:
    snap = report["snapshot"]
    lines = [
        "## インフラ利用枠・課金事前アラート (#2767)",
        "",
        f"- 評価日: `{report['generated_for']}` / 状態: `{report['status']}` / アラート閾値: `{report['alert_threshold_pct']:g}%`",
        f"- スナップショット: collected_at=`{snap['collected_at'] or '未記録'}`, period_start=`{snap['period_start'] or '未記録'}`, "
        f"収集からの経過日数=`{snap['age_days'] if snap['age_days'] is not None else '不明'}` (許容 `{snap['max_age_days']}` 日, stale=`{str(snap['stale']).lower()}`)",
    ]
    for service, info in report["plans"].items():
        suffix = " (未確認のため保守的な既定値を適用)" if info["assumed"] else ""
        lines.append(f"- {service} プラン: `{info['plan']}`{suffix}")
    lines += [
        f"- 上限値の確認日: `{report['limits_verified_on']}`",
        "",
        "| 項目 | 単位 | 現在値 | 上限 | 使用率 | 月末予測 | 状態 |",
        "| --- | --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for row in report["rows"]:
        pct = "-" if row["pct"] is None else f"{row['pct']:.1f}%"
        proj = "-"
        if row["projected"] is not None:
            proj = f"{row['projected']:,.1f} ({row['projected_pct']:.0f}%)"
        flag = "⚠️ " if row["alert"] else ""
        lines.append(
            f"| `{row['id']}` | {row['unit']} | {_fmt(row['usage'])} | {_fmt(row['limit'])} | {pct} | {proj} | {flag}{row['state']} |"
        )
    lines += ["", "### 従量課金モデルの試算 (有料プランに移行した場合)", "", "| 利用増加 | 月額見積り (USD) | 内訳 | 全項目計測済み |", "| ---: | ---: | --- | --- |"]
    for sc in report["scenarios"]:
        breakdown = ", ".join(f"{k}: {v:.2f}" for k, v in sc["per_service_usd"].items())
        lines.append(f"| +{sc['growth_pct']}% | {sc['estimated_monthly_usd']:.2f} | {breakdown} | {'yes' if sc['complete'] else 'no (未計測/未確認を除外)'} |")
    lines += ["", f"> {report['cost_disclaimer']}"]
    if report["owner_action_required"]:
        lines += [
            "",
            "### 要対応",
            "- Dashboard の Usage 値を `docs/infra-usage-snapshot.json` に転記し (collected_at / period_start を更新)、PR で反映してください。",
            f"- 未計測の項目: {', '.join(f'`{i}`' for i in report['unmeasured']) or 'なし'}",
        ]
    if report["limit_unverified"]:
        lines.append(f"- 上限値が未確認の項目 (一次情報で確認が必要): {', '.join(f'`{i}`' for i in report['limit_unverified'])}")
    return "\n".join(lines) + "\n"


def render_issue_body(report: dict[str, Any], *, monthly: bool, signature: str) -> str:
    header = "月次インフラ利用状況レビュー" if monthly else "インフラ利用枠アラート"
    checklist = [
        "- [ ] Supabase Dashboard の Usage / 請求ページで当月値を確認し、snapshot を更新した",
        "- [ ] Firebase console の Hosting Usage と Usage and billing を確認し、snapshot を更新した",
        "- [ ] 実際のプラン (Supabase / Firebase) を確認し、snapshot の plans を更新した",
        "- [ ] `docs/infra-quota-limits.json` の上限値・単価を一次情報で再確認した (確認日を更新)",
        "- [ ] 予測が上限超過の項目について、最適化・保持期間・プラン変更を予算責任者へ相談した",
    ]
    body = [f"## {header}", "", render_markdown(report), "### 月次確認チェックリスト", *checklist, ""]
    body.append(f"<!-- {SIGNATURE_MARKER}:{signature} -->")
    return "\n".join(body)


HttpFn = Callable[[str, str, dict[str, str], dict[str, Any] | None], Any]


def _http_json(method: str, url: str, headers: dict[str, str], payload: dict[str, Any] | None) -> Any:
    if not url.startswith(GITHUB_API + "/"):
        raise InputError(f"refusing non-GitHub URL: {url}")
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(request, timeout=20) as response:  # noqa: S310 (fixed https host)
        raw = response.read().decode("utf-8", errors="replace")
    return json.loads(raw) if raw.strip() else {}


def upsert_issue(
    *,
    repository: str,
    auth_value: str,
    title: str,
    title_prefix: str,
    body: str,
    signature: str,
    match_state: str = "open",
    http: HttpFn = _http_json,
) -> str:
    """Create or refresh one tracked issue. Returns created|updated|unchanged."""
    if not REPOSITORY_PATTERN.fullmatch(repository):
        raise InputError("invalid repository name")
    if not auth_value:
        raise InputError("GITHUB_TOKEN is required for --create-issue")
    headers = {
        "Authorization": f"Bearer {auth_value}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
        "User-Agent": "my-web-app-infra-quota-estimator",
    }
    base = f"{GITHUB_API}/repos/{repository}/issues"
    existing = http("GET", f"{base}?state={match_state}&per_page=100", headers, None)
    match = None
    if isinstance(existing, list):
        for issue in existing:
            if isinstance(issue, dict) and "pull_request" not in issue and str(issue.get("title", "")).startswith(title_prefix):
                if match_state == "all" and title_prefix == REVIEW_TITLE_PREFIX and issue.get("title") != title:
                    continue
                match = issue
                break
    if match is None:
        http("POST", base, headers, {"title": title, "body": body})
        return "created"
    if f"{SIGNATURE_MARKER}:{signature}" in str(match.get("body") or ""):
        return "unchanged"
    number = int(match["number"])
    http("PATCH", f"{base}/{number}", headers, {"title": title, "body": body})
    http("POST", f"{base}/{number}/comments", headers, {"body": "利用状況が更新されました。Issue 本文を最新の評価結果へ更新しました。"})
    return "updated"


def parse_scenarios(raw: str) -> tuple[int, ...]:
    try:
        values = tuple(int(part) for part in raw.split(",") if part.strip())
    except ValueError as exc:
        raise InputError(f"invalid growth scenarios: {raw!r}") from exc
    if not values or any(v < 0 or v > 1000 for v in values):
        raise InputError("growth scenarios must be integers in 0..1000")
    return values


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limits", type=Path, default=DEFAULT_LIMITS)
    parser.add_argument("--snapshot", type=Path, default=DEFAULT_SNAPSHOT)
    parser.add_argument("--alert-threshold-pct", type=float, default=DEFAULT_ALERT_THRESHOLD_PCT)
    parser.add_argument("--max-age-days", type=int, default=DEFAULT_MAX_AGE_DAYS)
    parser.add_argument("--growth-scenarios", default=",".join(str(v) for v in DEFAULT_GROWTH_SCENARIOS))
    parser.add_argument("--today", default="", help="Override evaluation date (YYYY-MM-DD, UTC)")
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--markdown-out", type=Path)
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--monthly-review", action="store_true", help="Open the monthly review issue")
    parser.add_argument("--create-issue", action="store_true", help="Upsert GitHub Issues using GITHUB_TOKEN")
    return parser


def _write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="\n")


def main(argv: list[str] | None = None, *, http: HttpFn = _http_json) -> int:
    args = build_parser().parse_args(argv)
    try:
        today = parse_date(args.today, "--today") if args.today else datetime.now(timezone.utc).date()
        assert today is not None
        report = evaluate(
            load_json(args.limits),
            load_json(args.snapshot),
            today=today,
            alert_threshold_pct=args.alert_threshold_pct,
            max_age_days=args.max_age_days,
            growth_scenarios=parse_scenarios(args.growth_scenarios),
        )
    except InputError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    signature = build_signature(report)
    markdown = render_markdown(report)
    print(markdown)
    if args.json_out:
        _write(args.json_out, json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    if args.markdown_out:
        _write(args.markdown_out, markdown)
    if args.github_output:
        growth0 = report["scenarios"][0]["estimated_monthly_usd"] if report["scenarios"] else 0
        with args.github_output.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(f"status={report['status']}\n")
            handle.write(f"alert_count={len(report['alerts'])}\n")
            handle.write(f"owner_action_required={str(report['owner_action_required']).lower()}\n")
            handle.write(f"estimated_monthly_usd={growth0}\n")

    if args.create_issue:
        api_credential = os.environ.get("GITHUB_TOKEN", "")
        repository = os.environ.get("GITHUB_REPOSITORY", "")
        try:
            results = []
            if report["status"] != "ok":
                body = render_issue_body(report, monthly=False, signature=signature)
                title = f"{ALERT_TITLE_PREFIX} インフラ利用枠アラート ({report['status']})"
                results.append(
                    ("alert", upsert_issue(repository=repository, auth_value=api_credential, title=title, title_prefix=ALERT_TITLE_PREFIX, body=body, signature=signature, http=http))
                )
            if args.monthly_review:
                month = today.strftime("%Y-%m")
                title = f"{REVIEW_TITLE_PREFIX} {month}"
                body = render_issue_body(report, monthly=True, signature=signature)
                results.append(
                    ("monthly_review", upsert_issue(repository=repository, auth_value=api_credential, title=title, title_prefix=REVIEW_TITLE_PREFIX, body=body, signature=signature, match_state="all", http=http))
                )
        except (InputError, urllib.error.URLError, OSError) as exc:
            print(f"error: GitHub issue upsert failed: {exc}", file=sys.stderr)
            return 1
        for kind, outcome in results:
            print(f"issue[{kind}]: {outcome}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
