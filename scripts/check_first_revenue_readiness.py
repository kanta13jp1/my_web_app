#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

DEFAULT_FUNCTION_URL = (
    "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/schedule-hub"
)
DEFAULT_RETURN_URL = "https://my-web-app-b67f4.web.app/subscription-billing"
DEFAULT_MIN_CHARGE_JPY = 50


def as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def checkout_mode(session_id: str) -> str:
    if session_id.startswith("cs_live"):
        return "live"
    if session_id.startswith("cs_test"):
        return "test"
    return "unknown"


def summarize_checkout_response(data: dict[str, Any]) -> dict[str, Any]:
    session_id = str(data.get("id") or "")
    checkout_url = str(data.get("checkout_url") or "")
    host = ""
    if checkout_url:
        try:
            host = urllib.parse.urlparse(checkout_url).hostname or ""
        except ValueError:
            host = ""
    return {
        "success": bool(data.get("success")),
        "session_id": session_id,
        "mode": checkout_mode(session_id),
        "has_checkout_url": bool(checkout_url),
        "checkout_host": host,
        "amount_jpy": as_int(data.get("amount_jpy")),
    }


def validate_checkout(
    summary: dict[str, Any],
    *,
    expected_mode: str,
    min_charge_jpy: int,
) -> list[str]:
    errors: list[str] = []
    if not summary["success"]:
        errors.append("Checkout response did not report success=true.")
    if not summary["has_checkout_url"]:
        errors.append("Checkout response did not include checkout_url.")
    if summary["checkout_host"] != "checkout.stripe.com":
        errors.append(
            f"Checkout URL host is {summary['checkout_host']!r}, not checkout.stripe.com."
        )
    if summary["amount_jpy"] < min_charge_jpy:
        errors.append(
            f"Checkout amount {summary['amount_jpy']} JPY is below {min_charge_jpy} JPY."
        )
    if expected_mode != "any" and summary["mode"] != expected_mode:
        errors.append(
            f"Checkout session is {summary['mode']!r}; expected {expected_mode!r}."
        )
    return errors


def post_supporter_checkout(function_url: str, return_url: str, timeout: int) -> dict[str, Any]:
    payload = json.dumps(
        {
            "action": "billing.create_supporter_checkout_session",
            "return_url": return_url,
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        function_url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def summarize_checkout_expiration_response(
    session_id: str,
    data: dict[str, Any],
) -> dict[str, Any]:
    status = str(data.get("status") or "")
    return {
        "attempted": True,
        "session_id": session_id,
        "mode": checkout_mode(session_id),
        "expired": status == "expired",
        "status": status,
    }


def summarize_checkout_expiration_failure(
    session_id: str,
    error: str,
    *,
    attempted: bool = True,
) -> dict[str, Any]:
    return {
        "attempted": attempted,
        "session_id": session_id,
        "mode": checkout_mode(session_id),
        "expired": False,
        "status": "error" if attempted else "skipped",
        "error": error,
    }


def stripe_error_message(exc: BaseException) -> str:
    if isinstance(exc, urllib.error.HTTPError):
        try:
            data = json.loads(exc.read().decode("utf-8"))
            error = data.get("error") if isinstance(data, dict) else None
            if isinstance(error, dict) and error.get("message"):
                return str(error["message"])
        except (OSError, json.JSONDecodeError, UnicodeDecodeError):
            pass
        return f"Stripe API failed with HTTP {exc.code}."
    return str(exc)


def expire_checkout_session(
    session_id: str,
    stripe_secret_key: str,
    timeout: int,
) -> dict[str, Any]:
    quoted_session_id = urllib.parse.quote(session_id, safe="")
    request = urllib.request.Request(
        f"https://api.stripe.com/v1/checkout/sessions/{quoted_session_id}/expire",
        data=b"",
        headers={
            "Authorization": f"Bearer {stripe_secret_key}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        data = json.loads(response.read().decode("utf-8"))
    if not isinstance(data, dict):
        raise ValueError("Stripe checkout expiration response was not an object.")
    return summarize_checkout_expiration_response(session_id, data)


def summarize_webhook_rows(rows: list[dict[str, Any]]) -> dict[str, Any]:
    paid_rows: list[dict[str, Any]] = []
    for row in rows:
        metadata = row.get("metadata")
        if not isinstance(metadata, dict):
            continue
        if (
            str(metadata.get("payment_status") or "").lower() == "paid"
            and str(metadata.get("currency") or "").lower() == "jpy"
        ):
            paid_rows.append(row)
    latest = paid_rows[0] if paid_rows else None
    latest_metadata = latest.get("metadata") if isinstance(latest, dict) else {}
    if not isinstance(latest_metadata, dict):
        latest_metadata = {}
    return {
        "row_count": len(rows),
        "paid_jpy_row_count": len(paid_rows),
        "latest_created_at": latest.get("created_at") if latest else "",
        "latest_amount_jpy": as_int(latest_metadata.get("amount_total")),
        "latest_checkout_session_id": str(
            latest_metadata.get("stripe_checkout_session_id") or ""
        ),
        "latest_payment_intent_id": str(
            latest_metadata.get("stripe_payment_intent_id") or ""
        ),
    }


def validate_webhook_evidence(
    summary: dict[str, Any],
    *,
    min_charge_jpy: int,
) -> list[str]:
    errors: list[str] = []
    if summary["paid_jpy_row_count"] < 1:
        errors.append("No paid JPY supporter webhook evidence was found.")
    if summary["latest_amount_jpy"] < min_charge_jpy:
        errors.append(
            f"Latest paid supporter amount {summary['latest_amount_jpy']} JPY "
            f"is below {min_charge_jpy} JPY."
        )
    if not summary["latest_checkout_session_id"]:
        errors.append("Latest webhook evidence is missing stripe_checkout_session_id.")
    if not summary["latest_payment_intent_id"]:
        errors.append("Latest webhook evidence is missing stripe_payment_intent_id.")
    return errors


def fetch_supporter_webhook_rows(
    supabase_url: str,
    service_role_key: str,
    timeout: int,
) -> list[dict[str, Any]]:
    query = urllib.parse.urlencode(
        {
            "source": "eq.stripe_supporter_payment",
            "select": "id,metadata,created_at",
            "order": "created_at.desc",
            "limit": "5",
        }
    )
    url = f"{supabase_url.rstrip('/')}/rest/v1/hub_data?{query}"
    request = urllib.request.Request(
        url,
        headers={
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
        },
        method="GET",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        data = json.loads(response.read().decode("utf-8"))
    if not isinstance(data, list):
        raise ValueError("Supabase webhook evidence response was not a list.")
    return [row for row in data if isinstance(row, dict)]


def summarize_bank_evidence(data: dict[str, Any]) -> dict[str, Any]:
    return {
        "statement_date": str(data.get("statement_date") or ""),
        "credited_amount_jpy": as_int(data.get("credited_amount_jpy")),
        "stripe_payout_id": str(data.get("stripe_payout_id") or ""),
        "payout_arrival_date": str(data.get("payout_arrival_date") or ""),
        "bank_reference": str(data.get("bank_reference") or ""),
    }


def validate_bank_evidence(summary: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if summary["credited_amount_jpy"] < 1:
        errors.append("Bank evidence does not show a credited amount of at least 1 JPY.")
    if not summary["statement_date"]:
        errors.append("Bank evidence is missing statement_date.")
    if not (summary["stripe_payout_id"] or summary["payout_arrival_date"]):
        errors.append(
            "Bank evidence needs either stripe_payout_id or payout_arrival_date."
        )
    if not summary["bank_reference"]:
        errors.append("Bank evidence is missing a redacted bank_reference.")
    return errors


def load_json_file(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object.")
    return data


def classify_revenue_stage(
    report: dict[str, Any],
    *,
    min_charge_jpy: int = DEFAULT_MIN_CHARGE_JPY,
) -> dict[str, Any]:
    checks = report.get("checks")
    if not isinstance(checks, dict):
        checks = {}
    errors = report.get("errors")
    if not isinstance(errors, list):
        errors = []

    checkout = checks.get("checkout")
    if not isinstance(checkout, dict):
        checkout = {}
    webhook = checks.get("webhook")
    if not isinstance(webhook, dict):
        webhook = {}
    bank = checks.get("bank")
    if not isinstance(bank, dict):
        bank = {}

    live_checkout_verified = (
        checkout.get("success") is True
        and checkout.get("mode") == "live"
        and checkout.get("checkout_host") == "checkout.stripe.com"
        and as_int(checkout.get("amount_jpy")) >= min_charge_jpy
    )
    webhook_verified = (
        as_int(webhook.get("paid_jpy_row_count")) >= 1
        and as_int(webhook.get("latest_amount_jpy")) >= min_charge_jpy
        and bool(webhook.get("latest_checkout_session_id"))
        and bool(webhook.get("latest_payment_intent_id"))
    )
    bank_verified = not validate_bank_evidence(bank) if bank else False
    goal_complete = bank_verified and not errors

    if goal_complete:
        return {
            "stage": "bank_credit_verified",
            "goal_complete": True,
            "next_action": "Record the verified bank-credit evidence in the WBS and close the session goal.",
        }
    if bank:
        return {
            "stage": "bank_evidence_incomplete",
            "goal_complete": False,
            "next_action": "Fix the redacted bank evidence so it proves credited_amount_jpy >= 1 and links to a Stripe payout.",
        }
    if webhook_verified:
        return {
            "stage": "paid_webhook_verified_waiting_for_bank_credit",
            "goal_complete": False,
            "next_action": "Initiate or wait for the Stripe payout, then verify a redacted bank statement credit of at least 1 JPY.",
        }
    if live_checkout_verified:
        return {
            "stage": "live_checkout_ready_for_real_payment",
            "goal_complete": False,
            "next_action": "Run the first-buyer sprint, capture one real supporter payment, then rerun with --require-webhook.",
        }
    if checkout.get("mode") == "test":
        return {
            "stage": "live_secret_required",
            "goal_complete": False,
            "next_action": "Rotate Supabase STRIPE_SECRET_KEY to sk_live with scripts/rotate_stripe_live_secret_and_check.ps1, then require cs_live.",
        }
    return {
        "stage": "checkout_or_evidence_blocked",
        "goal_complete": False,
        "next_action": "Resolve the reported readiness errors before promotion, real payment, webhook, or bank-payout verification.",
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Verify first-revenue readiness: live Checkout, optional webhook "
            "evidence, and optional redacted bank-credit evidence."
        )
    )
    parser.add_argument("--function-url", default=DEFAULT_FUNCTION_URL)
    parser.add_argument("--return-url", default=DEFAULT_RETURN_URL)
    parser.add_argument("--mode", choices=["live", "test", "any"], default="live")
    parser.add_argument("--min-charge-jpy", type=int, default=DEFAULT_MIN_CHARGE_JPY)
    parser.add_argument("--timeout", type=int, default=20)
    parser.add_argument("--json", action="store_true", help="Print JSON only.")
    parser.add_argument(
        "--skip-checkout",
        action="store_true",
        help="Skip the live Checkout probe; useful for local bank evidence checks.",
    )
    parser.add_argument(
        "--expire-checkout-session",
        action="store_true",
        help=(
            "Expire the created Checkout probe immediately after validation so "
            "readiness checks do not leave an open live payment link."
        ),
    )
    parser.add_argument(
        "--stripe-secret-key-env",
        default="STRIPE_SECRET_KEY",
        help="Environment variable containing a Stripe secret key for probe expiration.",
    )
    parser.add_argument(
        "--require-webhook",
        action="store_true",
        help="Require paid supporter webhook evidence in Supabase hub_data.",
    )
    parser.add_argument("--supabase-url", default="")
    parser.add_argument("--service-role-key", default="")
    parser.add_argument(
        "--bank-evidence",
        type=Path,
        help="Path to redacted bank evidence JSON.",
    )
    parser.add_argument(
        "--require-bank",
        action="store_true",
        help="Fail unless bank evidence proves at least 1 JPY credited.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    report: dict[str, Any] = {"checks": {}, "errors": [], "warnings": []}

    if not args.skip_checkout:
        try:
            checkout = post_supporter_checkout(
                args.function_url,
                args.return_url,
                args.timeout,
            )
            checkout_summary = summarize_checkout_response(checkout)
            report["checks"]["checkout"] = checkout_summary
            report["errors"].extend(
                validate_checkout(
                    checkout_summary,
                    expected_mode=args.mode,
                    min_charge_jpy=args.min_charge_jpy,
                )
            )
            if args.expire_checkout_session:
                session_id = str(checkout_summary.get("session_id") or "")
                secret = os.environ.get(args.stripe_secret_key_env, "").strip()
                if not session_id:
                    warning = "Checkout probe had no session id to expire."
                    report["warnings"].append(warning)
                    report["checks"]["checkout_expiration"] = (
                        summarize_checkout_expiration_failure(
                            session_id,
                            warning,
                            attempted=False,
                        )
                    )
                elif not secret:
                    warning = (
                        f"--expire-checkout-session needs "
                        f"{args.stripe_secret_key_env} in the environment."
                    )
                    report["warnings"].append(warning)
                    report["checks"]["checkout_expiration"] = (
                        summarize_checkout_expiration_failure(
                            session_id,
                            warning,
                            attempted=False,
                        )
                    )
                else:
                    try:
                        report["checks"]["checkout_expiration"] = (
                            expire_checkout_session(
                                session_id,
                                secret,
                                args.timeout,
                            )
                        )
                    except (
                        OSError,
                        urllib.error.URLError,
                        json.JSONDecodeError,
                        ValueError,
                    ) as exc:
                        warning = f"Checkout probe expiration failed: {stripe_error_message(exc)}"
                        report["warnings"].append(warning)
                        report["checks"]["checkout_expiration"] = (
                            summarize_checkout_expiration_failure(
                                session_id,
                                warning,
                            )
                        )
        except (OSError, urllib.error.URLError, json.JSONDecodeError, ValueError) as exc:
            report["errors"].append(f"Checkout probe failed: {exc}")

    if args.require_webhook:
        if not args.supabase_url or not args.service_role_key:
            report["errors"].append(
                "--require-webhook needs --supabase-url and --service-role-key."
            )
        else:
            try:
                rows = fetch_supporter_webhook_rows(
                    args.supabase_url,
                    args.service_role_key,
                    args.timeout,
                )
                webhook_summary = summarize_webhook_rows(rows)
                report["checks"]["webhook"] = webhook_summary
                report["errors"].extend(
                    validate_webhook_evidence(
                        webhook_summary,
                        min_charge_jpy=args.min_charge_jpy,
                    )
                )
            except (OSError, urllib.error.URLError, json.JSONDecodeError, ValueError) as exc:
                report["errors"].append(f"Webhook evidence probe failed: {exc}")

    if args.bank_evidence:
        try:
            bank_summary = summarize_bank_evidence(load_json_file(args.bank_evidence))
            report["checks"]["bank"] = bank_summary
            report["errors"].extend(validate_bank_evidence(bank_summary))
        except (OSError, json.JSONDecodeError, ValueError) as exc:
            report["errors"].append(f"Bank evidence check failed: {exc}")
    elif args.require_bank:
        report["errors"].append("--require-bank needs --bank-evidence.")

    ok = not report["errors"]
    report["ok"] = ok
    report["completion"] = classify_revenue_stage(
        report,
        min_charge_jpy=args.min_charge_jpy,
    )

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print("First revenue readiness:", "PASS" if ok else "FAIL")
        for name, summary in report["checks"].items():
            print(f"\n{name}:")
            for key, value in summary.items():
                print(f"  {key}: {value}")
        if report["errors"]:
            print("\nerrors:")
            for error in report["errors"]:
                print(f"  - {error}")
        if report["warnings"]:
            print("\nwarnings:")
            for warning in report["warnings"]:
                print(f"  - {warning}")
        completion = report["completion"]
        print("\ncompletion:")
        print(f"  stage: {completion['stage']}")
        print(f"  goal_complete: {completion['goal_complete']}")
        print(f"  next_action: {completion['next_action']}")

    return 0 if ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
