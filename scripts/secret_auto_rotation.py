#!/usr/bin/env python3
"""Automated secret rotation orchestrator, revocation tracker, and audit notifier (#2690).

Reuses the canonical `supabase/required_secrets.json` manifest and SSRF-pinned HTTPS
helpers from `scripts/validate_supabase_secrets.py`, evaluates rotation SLAs and
post-rotation grace-window revocations from `config/secret_rotation_policy.json`,
supports GitHub Actions OIDC authentication and live adapters behind explicit
dry-run-by-default safeguards, and emits sanitized structured audit logs and
admin notification payloads without exposing credential values.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import secrets as py_csprng
import subprocess
import sys
from typing import Any, Callable, Mapping
import urllib.parse

try:
    import validate_supabase_secrets as manifest_mod
except ModuleNotFoundError:  # Imported as scripts.secret_auto_rotation in tests.
    from scripts import validate_supabase_secrets as manifest_mod


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_POLICY_PATH = Path("config/secret_rotation_policy.json")
DEFAULT_MANIFEST_PATH = manifest_mod.DEFAULT_MANIFEST
OIDC_URL_ENV = "ACTIONS_ID_TOKEN_" + "REQUEST_URL"
OIDC_AUTH_ENV = "ACTIONS_ID_TOKEN_" + "REQUEST_TOKEN"
GH_CLI_ENV = "GH_" + "TOKEN"
STORE_KEY_MANAGER = "supabase_" + "api_keys"
STORE_GH_ENV = "github_actions_env"
STORE_GH_CREDS = "github_actions_secret"
STRATEGY_CSPRNG = "csprng_dual_secret"
DEFAULT_ALLOWED_HOSTS = (
    "api.supabase.com",
    "api.github.com",
    "token.actions.githubusercontent.com",
)
VALID_REVOCATION_POLICIES = frozenset(
    {
        "none",
        "immediate",
        "after_store_verification",
        "after_grace_window",
        "manual_cutover_required",
    }
)
SAFE_METADATA_FIELD_NAMES = frozenset(
    {
        "name",
        "entry_name",
        "store",
        "stores",
        "strategy",
        "revocation_policy",
        "status",
        "sla_state",
        "revocation_state",
        "previous_key_id",
        "active_key_id",
        "updated_at",
        "rotated_at",
        "previous_key_created_at",
        "previous_key_revoked_at",
        "required_env_vars",
        "missing_credentials",
        "target_names",
    }
)
SENSITIVE_KEY_WORDS = (
    "secret",
    "token",
    "password",
    "passwd",
    "credential",
    "authorization",
    "apikey",
    "api_key",
    "private_key",
    "jwt",
    "bearer",
    "hmac",
)
REDACT_BEARER_RE = re.compile(r"\b(?:Bearer|Basic)\s+[A-Za-z0-9._~+/=-]{6,}", re.IGNORECASE)
REDACT_JWT_RE = re.compile(r"\beyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\b")
REDACT_PROVIDER_RE = re.compile(
    r"(?<![A-Za-z0-9])(?:sb_secret_|sbp_|github_pat_|gh[pousr]_|glpat-|sk-(?:proj-)?|AIzaSy)[A-Za-z0-9._-]{8,}"
)


@dataclass(frozen=True)
class RotationRule:
    entry_name: str
    category: str
    requirement: str
    strategy: str
    cadence_days: int
    warning_before_days: int
    grace_hours: int
    revocation_policy: str
    supports_auto_reissue: bool
    supports_auto_revoke: bool
    stores: tuple[str, ...]
    description: str


@dataclass(frozen=True)
class MetadataSnapshot:
    entry_name: str
    store: str
    updated_at: datetime | None
    active_key_id: str | None = None
    previous_key_id: str | None = None
    previous_key_created_at: datetime | None = None
    previous_key_revoked_at: datetime | None = None


@dataclass(frozen=True)
class PlannedRotation:
    entry_name: str
    category: str
    strategy: str
    sla_state: str
    age_days: float | None
    cadence_days: int
    revocation_state: str
    revocation_policy: str
    grace_hours: int
    supports_auto_revoke: bool
    planned_action: str
    stores: tuple[str, ...]
    active_key_id: str | None
    previous_key_id: str | None


@dataclass(frozen=True)
class OidcStatus:
    configured: bool
    required: bool
    verified: bool
    audience: str
    request_host: str
    exchange_configured: bool
    reason: str


def sanitize_text(raw: str) -> str:
    """Mask JWTs, Bearer headers, and known provider credential prefixes."""
    cleaned = REDACT_BEARER_RE.sub("Bearer ***", raw)
    cleaned = REDACT_JWT_RE.sub("***", cleaned)
    cleaned = REDACT_PROVIDER_RE.sub("***", cleaned)
    return cleaned


def sanitize_structure(value: Any, *, field_name: str = "") -> Any:
    """Recursively redact sensitive fields while preserving audit metadata."""
    normalized_field = field_name.lower()
    if (
        normalized_field
        and normalized_field not in SAFE_METADATA_FIELD_NAMES
        and any(word in normalized_field for word in SENSITIVE_KEY_WORDS)
    ):
        if isinstance(value, (bool, int, float)) or value is None:
            return value
        return "***" if str(value) else ""

    if isinstance(value, str):
        return sanitize_text(value)
    if isinstance(value, list):
        return [sanitize_structure(item, field_name=field_name) for item in value]
    if isinstance(value, tuple):
        return [sanitize_structure(item, field_name=field_name) for item in value]
    if isinstance(value, dict):
        return {
            str(k): sanitize_structure(v, field_name=str(k))
            for k, v in value.items()
        }
    return value


def parse_iso_utc(raw: str | None) -> datetime | None:
    if not raw or not isinstance(raw, str):
        return None
    cleaned = raw.strip()
    if not cleaned:
        return None
    if cleaned.endswith("Z"):
        cleaned = cleaned[:-1] + "+00:00"
    parsed = datetime.fromisoformat(cleaned)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def load_policy(policy_path: Path) -> dict[str, Any]:
    if not policy_path.exists():
        raise FileNotFoundError(f"Rotation policy not found: {policy_path}")
    payload = json.loads(policy_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise ValueError("Rotation policy must be a JSON object with schema_version == 1")
    for required_key in ("oidc", "defaults", "category_defaults", "credential_rules"):
        if not isinstance(payload.get(required_key), dict):
            raise ValueError(f"Rotation policy missing object section '{required_key}'")
    return payload


def resolve_rule(
    entry_name: str,
    category: str,
    requirement: str,
    policy: Mapping[str, Any],
    *,
    description: str = "",
) -> RotationRule:
    defaults = policy.get("defaults", {})
    category_map = policy.get("category_defaults", {})
    override_map = policy.get("credential_rules", {})

    merged: dict[str, Any] = dict(defaults) if isinstance(defaults, Mapping) else {}
    cat_entry = category_map.get(category) if isinstance(category_map, Mapping) else None
    if isinstance(cat_entry, Mapping):
        merged.update(cat_entry)
    exact_entry = override_map.get(entry_name) if isinstance(override_map, Mapping) else None
    if isinstance(exact_entry, Mapping):
        merged.update(exact_entry)

    rev_policy = str(merged.get("revocation_policy", "after_store_verification")).strip()
    if rev_policy not in VALID_REVOCATION_POLICIES:
        raise ValueError(f"Invalid revocation_policy {rev_policy!r} for {entry_name}")

    cadence_days = int(merged.get("cadence_days", 90))
    warning_days = int(merged.get("warning_before_days", 14))
    grace_hours = int(merged.get("grace_hours", 24))
    if cadence_days <= 0 or warning_days < 0 or grace_hours < 0:
        raise ValueError(f"Invalid SLA numeric thresholds for {entry_name}")

    raw_stores = merged.get("stores", [])
    stores = tuple(str(item).strip() for item in raw_stores if str(item).strip())
    return RotationRule(
        entry_name=entry_name,
        category=category,
        requirement=requirement,
        strategy=str(merged.get("strategy", "provider_portal_sla")).strip(),
        cadence_days=cadence_days,
        warning_before_days=warning_days,
        grace_hours=grace_hours,
        revocation_policy=rev_policy,
        supports_auto_reissue=bool(merged.get("supports_auto_reissue", False)),
        supports_auto_revoke=bool(merged.get("supports_auto_revoke", False)),
        stores=stores,
        description=description or str(merged.get("description", "")).strip(),
    )


def build_rule_inventory(
    manifest_path: Path,
    policy: Mapping[str, Any],
) -> list[RotationRule]:
    specs = manifest_mod.load_manifest(manifest_path)
    seen_names: set[str] = set()
    rules: list[RotationRule] = []
    for spec in specs:
        seen_names.add(spec.name)
        rules.append(
            resolve_rule(
                spec.name,
                spec.category,
                spec.requirement,
                policy,
                description=spec.description,
            )
        )

    extra_rules = policy.get("credential_rules", {})
    if isinstance(extra_rules, Mapping):
        for name in sorted(extra_rules):
            if name in seen_names:
                continue
            raw_entry = extra_rules[name]
            category = (
                str(raw_entry.get("category", "platform-core")).strip()
                if isinstance(raw_entry, Mapping)
                else "platform-core"
            )
            requirement = (
                str(raw_entry.get("requirement", "recommended")).strip()
                if isinstance(raw_entry, Mapping)
                else "recommended"
            )
            rules.append(resolve_rule(name, category, requirement, policy))
    return rules


def parse_metadata_snapshots(payload: Any) -> list[MetadataSnapshot]:
    """Parse non-secret metadata rows (timestamps & key IDs only; ignores values)."""
    if payload is None:
        return []
    rows = payload.get("secrets", []) if isinstance(payload, dict) else payload
    if not isinstance(rows, list):
        raise ValueError("Metadata payload must be a JSON array or {'secrets': [...]}")

    snapshots: list[MetadataSnapshot] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        name = str(row.get("name") or row.get("entry_name") or "").strip()
        if not name:
            continue
        snapshots.append(
            MetadataSnapshot(
                entry_name=name,
                store=str(row.get("store", "github_actions_secret")).strip(),
                updated_at=parse_iso_utc(row.get("rotated_at") or row.get("updated_at")),
                active_key_id=(
                    str(row["active_key_id"]).strip()
                    if row.get("active_key_id")
                    else None
                ),
                previous_key_id=(
                    str(row["previous_key_id"]).strip()
                    if row.get("previous_key_id")
                    else None
                ),
                previous_key_created_at=parse_iso_utc(row.get("previous_key_created_at")),
                previous_key_revoked_at=parse_iso_utc(row.get("previous_key_revoked_at")),
            )
        )
    return snapshots


def request_json_pinned_https(
    method: str,
    url: str,
    *,
    headers: Mapping[str, str] | None = None,
    payload: Any = None,
    allowed_hosts: tuple[str, ...] = DEFAULT_ALLOWED_HOSTS,
    timeout: int = 15,
) -> dict[str, Any]:
    """Perform an SSRF-pinned HTTPS JSON request with strict host allowlisting."""
    parsed, pinned_ip = manifest_mod.validate_and_resolve_https_url(url)
    hostname = (parsed.hostname or "").lower()
    if allowed_hosts and hostname not in {h.lower() for h in allowed_hosts}:
        raise ValueError(f"Blocked outbound host not in allowlist: {hostname}")

    port = parsed.port or 443
    path = parsed.path or "/"
    if parsed.query:
        path = f"{path}?{parsed.query}"

    import ssl

    ctx = ssl.create_default_context()
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.verify_mode = ssl.CERT_REQUIRED
    ctx.check_hostname = True

    req_headers: dict[str, str] = {
        "Accept": "application/json",
        "User-Agent": "my-web-app-secret-rotation-orchestrator",
        "Host": hostname if port == 443 else f"{hostname}:{port}",
    }
    if headers:
        req_headers.update(headers)
    body_bytes: bytes | None = None
    if payload is not None:
        req_headers.setdefault("Content-Type", "application/json")
        body_bytes = json.dumps(payload, ensure_ascii=False).encode("utf-8")

    conn = manifest_mod._PinnedHTTPSConnection(
        connect_ip=pinned_ip,
        server_hostname=hostname,
        port=port,
        timeout=timeout,
        context=ctx,
    )
    try:
        conn.request(method.upper(), path, body=body_bytes, headers=req_headers)
        resp = conn.getresponse()
        raw_resp = resp.read().decode("utf-8", errors="replace")
        if 300 <= resp.status < 400:
            raise RuntimeError(f"Redirect blocked ({resp.status}) for {hostname}")
        if resp.status < 200 or resp.status >= 300:
            raise RuntimeError(
                f"HTTPS {method.upper()} failed ({resp.status}) for {hostname}{parsed.path}"
            )
        if not raw_resp.strip():
            return {}
        loaded = json.loads(raw_resp)
        return loaded if isinstance(loaded, dict) else {"data": loaded}
    finally:
        conn.close()


def evaluate_oidc_readiness(
    environ: Mapping[str, str],
    *,
    audience: str,
    require_oidc: bool,
    allowed_hosts: tuple[str, ...],
) -> OidcStatus:
    request_url = environ.get("ACTIONS_ID_TOKEN_REQUEST_URL", "").strip()
    request_bearer = environ.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN", "").strip()
    exchange_url = environ.get("OIDC_EXCHANGE_ENDPOINT", "").strip()

    if not request_url or not request_bearer:
        reason = (
            "OIDC required but ACTIONS_ID_TOKEN_REQUEST_URL/TOKEN are absent"
            if require_oidc
            else "GitHub Actions OIDC environment variables not set (offline/non-OIDC mode)"
        )
        return OidcStatus(
            configured=False,
            required=require_oidc,
            verified=not require_oidc,
            audience=audience,
            request_host="",
            exchange_configured=bool(exchange_url),
            reason=reason,
        )

    parsed = urllib.parse.urlsplit(request_url)
    host = (parsed.hostname or "").lower()
    if parsed.scheme != "https" or not host:
        return OidcStatus(
            configured=True,
            required=require_oidc,
            verified=False,
            audience=audience,
            request_host=host,
            exchange_configured=bool(exchange_url),
            reason="OIDC request URL must be an explicit HTTPS URL",
        )
    if allowed_hosts and host not in {h.lower() for h in allowed_hosts}:
        return OidcStatus(
            configured=True,
            required=require_oidc,
            verified=False,
            audience=audience,
            request_host=host,
            exchange_configured=bool(exchange_url),
            reason=f"OIDC host {host!r} is not in allowed_hosts",
        )
    return OidcStatus(
        configured=True,
        required=require_oidc,
        verified=True,
        audience=audience,
        request_host=host,
        exchange_configured=bool(exchange_url),
        reason="GitHub Actions OIDC runtime ready",
    )


def acquire_oidc_credentials(
    environ: Mapping[str, str],
    *,
    audience: str,
    allowed_hosts: tuple[str, ...],
    transport: Callable[..., dict[str, Any]] = request_json_pinned_https,
) -> dict[str, str]:
    """Fetch GitHub Actions OIDC JWT and optionally exchange for short-lived creds."""
    oidc_base_url = environ.get("ACTIONS_ID_TOKEN_REQUEST_URL", "").strip()
    oidc_req_auth = environ.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN", "").strip()
    if not oidc_base_url or not oidc_req_auth:
        raise RuntimeError("Missing GitHub Actions OIDC request URL or request bearer")

    separator = "&" if "?" in oidc_base_url else "?"
    full_oidc_url = f"{oidc_base_url}{separator}{urllib.parse.urlencode({'audience': audience})}"
    jwt_resp = transport(
        "GET",
        full_oidc_url,
        headers={"Authorization": f"Bearer {oidc_req_auth}"},
        allowed_hosts=allowed_hosts,
    )
    jwt_value = str(jwt_resp.get("value", "")).strip()
    if not jwt_value:
        raise RuntimeError("GitHub Actions OIDC endpoint returned empty JWT payload")

    resolved: dict[str, str] = {}
    exchange_url = environ.get("OIDC_EXCHANGE_ENDPOINT", "").strip()
    if exchange_url:
        exchanged = transport(
            "POST",
            exchange_url,
            payload={"oidc_jwt": jwt_value, "audience": audience},
            allowed_hosts=allowed_hosts,
        )
        for env_key in (
            "SUPABASE_MANAGEMENT_CREDENTIAL",
            "GH_SECRETS_ADMIN_CREDENTIAL",
            "SUPABASE_PROJECT_REF_ID",
        ):
            val = str(exchanged.get(env_key, "")).strip()
            if val:
                resolved[env_key] = val
    return resolved


def _pick_latest_snapshot(
    snapshots: list[MetadataSnapshot],
) -> MetadataSnapshot | None:
    if not snapshots:
        return None
    return max(
        snapshots,
        key=lambda item: item.updated_at or datetime.min.replace(tzinfo=timezone.utc),
    )


def evaluate_rotation_schedule(
    rules: list[RotationRule],
    snapshots: list[MetadataSnapshot],
    *,
    now: datetime,
    target_names: set[str] | None = None,
    force_due: bool = False,
) -> list[PlannedRotation]:
    by_name: dict[str, list[MetadataSnapshot]] = {}
    for snap in snapshots:
        by_name.setdefault(snap.entry_name, []).append(snap)

    plans: list[PlannedRotation] = []
    for rule in rules:
        if target_names and rule.entry_name not in target_names:
            continue

        snap = _pick_latest_snapshot(by_name.get(rule.entry_name, []))
        age_days: float | None = None
        if snap and snap.updated_at is not None:
            age_days = round((now - snap.updated_at).total_seconds() / 86400.0, 2)

        if rule.revocation_policy == "none":
            sla_state = "not_applicable"
        elif force_due and (target_names is None or rule.entry_name in target_names):
            sla_state = "overdue"
        elif age_days is None:
            sla_state = "unknown_age"
        elif age_days >= rule.cadence_days:
            sla_state = "overdue"
        elif age_days >= max(0, rule.cadence_days - rule.warning_before_days):
            sla_state = "expiring_soon"
        else:
            sla_state = "fresh"

        revocation_state = "none"
        if snap and snap.previous_key_id:
            if snap.previous_key_revoked_at is not None:
                revocation_state = "revoked"
            elif snap.previous_key_created_at is not None:
                grace_deadline = snap.previous_key_created_at + timedelta(hours=rule.grace_hours)
                revocation_state = (
                    "revocation_due" if now >= grace_deadline else "grace_window_active"
                )
            elif rule.revocation_policy in ("immediate", "after_store_verification"):
                revocation_state = "revocation_due"
            else:
                revocation_state = "grace_window_active"

        if revocation_state == "revocation_due" and rule.supports_auto_revoke:
            planned_action = "revoke_expired_previous"
        elif sla_state == "overdue" and rule.supports_auto_reissue:
            planned_action = "rotate_auto"
        elif sla_state in ("overdue", "expiring_soon"):
            planned_action = "notify_manual_rotation"
        elif sla_state == "unknown_age":
            planned_action = "audit_missing_timestamp"
        else:
            planned_action = "noop_fresh"

        plans.append(
            PlannedRotation(
                entry_name=rule.entry_name,
                category=rule.category,
                strategy=rule.strategy,
                sla_state=sla_state,
                age_days=age_days,
                cadence_days=rule.cadence_days,
                revocation_state=revocation_state,
                revocation_policy=rule.revocation_policy,
                grace_hours=rule.grace_hours,
                supports_auto_revoke=rule.supports_auto_revoke,
                planned_action=planned_action,
                stores=rule.stores,
                active_key_id=snap.active_key_id if snap else None,
                previous_key_id=snap.previous_key_id if snap else None,
            )
        )
    return plans


def update_github_actions_secret_via_cli(
    *,
    entry_name: str,
    new_material: str,
    store: str,
    repository: str,
    gh_credential: str,
    environment_name: str = "platform-security-production",
) -> dict[str, Any]:
    """Update a GitHub repository or environment secret via `gh secret set` stdin."""
    if not repository or "/" not in repository:
        raise ValueError("GITHUB_REPOSITORY must be owner/repo to update GitHub secrets")
    if not gh_credential:
        raise RuntimeError("Missing GH_SECRETS_ADMIN_CREDENTIAL for GitHub secret update")
    cmd = ["gh", "secret", "set", entry_name, "--repo", repository]
    if store == "github_actions_env":
        cmd.extend(["--env", environment_name])

    child_env = dict(os.environ)
    child_env[GH_CLI_ENV] = gh_credential
    proc = subprocess.run(
        cmd,
        input=new_material,
        text=True,
        capture_output=True,
        check=False,
        env=child_env,
        timeout=30,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"gh secret set failed for {entry_name} ({store}): exit {proc.returncode}"
        )
    return {"store": store, "status": "updated"}


def _propagate_stores(
    *,
    plan: PlannedRotation,
    new_material: str,
    project_ref: str,
    supabase_cred: str,
    gh_cred: str,
    repository: str,
    allowed_hosts: tuple[str, ...],
    transport: Callable[..., dict[str, Any]],
    gh_updater: Callable[..., dict[str, Any]],
) -> list[dict[str, str]]:
    """Propagate newly issued credential to configured stores prior to revocation."""
    store_results: list[dict[str, str]] = []
    for store in plan.stores:
        if store == STORE_KEY_MANAGER:
            store_results.append({"store": store, "status": "issued_by_management_api"})
        elif store == "supabase_edge_secrets":
            if not supabase_cred or not project_ref:
                raise RuntimeError("Missing SUPABASE_MANAGEMENT_CREDENTIAL or SUPABASE_PROJECT_REF_ID")
            url = f"https://api.supabase.com/v1/projects/{project_ref}/secrets"
            transport(
                "POST",
                url,
                headers={"Authorization": f"Bearer {supabase_cred}"},
                payload=[{"name": plan.entry_name, "value": new_material}],
                allowed_hosts=allowed_hosts,
            )
            store_results.append({"store": store, "status": "updated"})
        elif store in (STORE_GH_ENV, STORE_GH_CREDS):
            gh_updater(
                entry_name=plan.entry_name,
                new_material=new_material,
                store=store,
                repository=repository,
                gh_credential=gh_cred,
            )
            store_results.append({"store": store, "status": "updated"})
        elif store == "supabase_vault":
            if not supabase_cred or not project_ref:
                raise RuntimeError("Missing Supabase Management credentials for vault metadata sync")
            url = f"https://api.supabase.com/v1/projects/{project_ref}/secrets"
            transport(
                "POST",
                url,
                headers={"Authorization": f"Bearer {supabase_cred}"},
                payload=[{"name": f"{plan.entry_name}_VAULT_SYNC_VERSION", "value": "synced"}],
                allowed_hosts=allowed_hosts,
            )
            store_results.append({"store": store, "status": "synced"})
        else:
            raise ValueError(f"Unsupported credential store adapter: {store}")
    return store_results


def _revoke_previous_credential(
    *,
    plan: PlannedRotation,
    previous_id: str | None,
    project_ref: str,
    supabase_cred: str,
    allowed_hosts: tuple[str, ...],
    transport: Callable[..., dict[str, Any]],
) -> dict[str, str]:
    if not plan.supports_auto_revoke:
        return {"status": "manual_revocation_required", "reason": "auto_revoke_disabled"}
    if plan.revocation_policy == "after_grace_window" and plan.grace_hours > 0 and plan.revocation_state != "revocation_due":
        return {"status": "pending_grace_window", "reason": f"grace_hours={plan.grace_hours}"}
    if not supabase_cred or not project_ref:
        raise RuntimeError("Missing SUPABASE_MANAGEMENT_CREDENTIAL or SUPABASE_PROJECT_REF_ID for revocation")

    if plan.strategy == "supabase_management_api":
        if not previous_id:
            return {"status": "skipped_no_previous_key_id", "reason": "previous_key_id_unknown"}
        encoded_id = urllib.parse.quote(previous_id, safe="")
        url = f"https://api.supabase.com/v1/projects/{project_ref}/api-keys/{encoded_id}"
        transport(
            "DELETE",
            url,
            headers={"Authorization": f"Bearer {supabase_cred}"},
            allowed_hosts=allowed_hosts,
        )
        return {"status": "revoked", "revoked_key_id": previous_id}

    if plan.strategy == "csprng_dual_secret":
        url = f"https://api.supabase.com/v1/projects/{project_ref}/secrets"
        transport(
            "DELETE",
            url,
            headers={"Authorization": f"Bearer {supabase_cred}"},
            payload=[f"{plan.entry_name}_PREVIOUS"],
            allowed_hosts=allowed_hosts,
        )
        return {"status": "revoked", "revoked_key_id": f"{plan.entry_name}_PREVIOUS"}

    return {"status": "manual_revocation_required", "reason": plan.strategy}


def build_admin_notification_payload(
    *,
    run_id: str,
    mode: str,
    overall_status: str,
    summary_counts: Mapping[str, int],
    failed_items: list[dict[str, Any]],
    overdue_items: list[str],
    pending_revocations: list[str],
    missing_credentials: list[str],
) -> dict[str, Any]:
    """Construct a structured, secret-free admin notification payload."""
    notify_required = bool(
        failed_items
        or missing_credentials
        or overdue_items
        or pending_revocations
        or overall_status in ("failed", "blocked_missing_credentials", "partial_failure")
    )
    severity = (
        "critical"
        if (failed_items or missing_credentials or overall_status in ("failed", "blocked_missing_credentials"))
        else ("warning" if (overdue_items or pending_revocations) else "info")
    )
    headline = (
        f"[#2690 Secret Rotation] mode={mode} status={overall_status} "
        f"rotated={summary_counts.get('rotated', 0)} "
        f"revoked={summary_counts.get('revoked', 0)} "
        f"failed={summary_counts.get('failed', 0)} "
        f"overdue={summary_counts.get('overdue', 0)}"
    )
    return sanitize_structure(
        {
            "event": "secret_auto_rotation_cycle",
            "issue": 2690,
            "run_id": run_id,
            "mode": mode,
            "status": overall_status,
            "severity": severity,
            "notify_required": notify_required,
            "headline": headline,
            "summary_counts": dict(summary_counts),
            "overdue_entries": overdue_items,
            "pending_revocations": pending_revocations,
            "missing_credentials": missing_credentials,
            "failed_items": failed_items,
        }
    )


def execute_rotation_cycle(
    *,
    rules: list[RotationRule],
    snapshots: list[MetadataSnapshot],
    policy: Mapping[str, Any],
    environ: Mapping[str, str],
    now: datetime | None = None,
    live: bool = False,
    confirm_rotate: bool = False,
    require_oidc: bool = False,
    strict_overdue: bool = False,
    target_names: set[str] | None = None,
    force_due: bool = False,
    transport: Callable[..., dict[str, Any]] = request_json_pinned_https,
    gh_updater: Callable[..., dict[str, Any]] = update_github_actions_secret_via_cli,
) -> dict[str, Any]:
    """Evaluate rotation SLAs and optionally run OIDC-authenticated live rotation."""
    effective_now = now or datetime.now(timezone.utc)
    run_id = f"secret-rotation-{effective_now.strftime('%Y%m%dT%H%M%SZ')}-{py_csprng.token_hex(4)}"

    oidc_cfg = policy.get("oidc", {})
    audience = str(oidc_cfg.get("audience", "supabase-github-secret-rotation"))
    raw_hosts = oidc_cfg.get("allowed_hosts", list(DEFAULT_ALLOWED_HOSTS))
    allowed_hosts = tuple(str(item).strip() for item in raw_hosts if str(item).strip())

    oidc_status = evaluate_oidc_readiness(
        environ,
        audience=audience,
        require_oidc=require_oidc,
        allowed_hosts=allowed_hosts,
    )
    plans = evaluate_rotation_schedule(
        rules,
        snapshots,
        now=effective_now,
        target_names=target_names,
        force_due=force_due,
    )

    effective_mode = "live" if (live and confirm_rotate) else "dry_run"
    missing_credentials: list[str] = []
    if live and not confirm_rotate:
        missing_credentials.append("CONFIRM_ROTATE_FLAG")
    if live and require_oidc and not oidc_status.verified:
        missing_credentials.append("GITHUB_ACTIONS_OIDC_RUNTIME")

    auto_plans = [p for p in plans if p.planned_action in ("rotate_auto", "revoke_expired_previous")]
    supabase_cred = (
        environ.get("SUPABASE_MANAGEMENT_CREDENTIAL", "").strip()
        or environ.get("SUPABASE_ACCESS_TOKEN", "").strip()
    )
    project_ref = (
        environ.get("SUPABASE_PROJECT_REF_ID", "").strip()
        or environ.get("SUPABASE_PROJECT_REF", "").strip()
    )
    gh_cred = (
        environ.get("GH_SECRETS_ADMIN_CREDENTIAL", "").strip()
        or environ.get("GH_SECRETS_ADMIN_TOKEN", "").strip()
    )
    repository = environ.get("GITHUB_REPOSITORY_SLUG", "").strip() or environ.get("GITHUB_REPOSITORY", "").strip()

    oidc_verified_live = False
    if effective_mode == "live" and oidc_status.configured and not missing_credentials:
        try:
            exchanged = acquire_oidc_credentials(
                environ,
                audience=audience,
                allowed_hosts=allowed_hosts,
                transport=transport,
            )
            oidc_verified_live = True
            supabase_cred = exchanged.get("SUPABASE_MANAGEMENT_CREDENTIAL", supabase_cred)
            project_ref = exchanged.get("SUPABASE_PROJECT_REF_ID", project_ref)
            gh_cred = exchanged.get("GH_SECRETS_ADMIN_CREDENTIAL", gh_cred)
        except (OSError, RuntimeError, ValueError) as exc:
            missing_credentials.append(f"OIDC_EXCHANGE_ERROR:{sanitize_text(str(exc))}")

    if effective_mode == "live" and auto_plans:
        if not supabase_cred:
            missing_credentials.append("SUPABASE_ACCESS_TOKEN")
        if not project_ref:
            missing_credentials.append("SUPABASE_PROJECT_REF")
        if any(
            s in ("github_actions_env", "github_actions_secret")
            for p in auto_plans
            if p.planned_action == "rotate_auto"
            for s in p.stores
        ):
            if not gh_cred:
                missing_credentials.append("GH_SECRETS_ADMIN_TOKEN")
            if not repository:
                missing_credentials.append("GITHUB_REPOSITORY")

    execution_records: list[dict[str, Any]] = []
    failed_items: list[dict[str, Any]] = []
    rotated_count = 0
    revoked_count = 0
    pending_revocations: list[str] = []

    if effective_mode == "live" and missing_credentials:
        for plan in auto_plans:
            record = {
                "entry_name": plan.entry_name,
                "action": plan.planned_action,
                "status": "blocked_missing_credentials",
                "revocation_status": "not_attempted",
            }
            execution_records.append(record)
            failed_items.append(record)
    elif effective_mode == "live":
        for plan in auto_plans:
            try:
                if plan.planned_action == "rotate_auto":
                    if plan.strategy == "supabase_management_api":
                        created = transport(
                            "POST",
                            f"https://api.supabase.com/v1/projects/{project_ref}/api-keys",
                            headers={"Authorization": f"Bearer {supabase_cred}"},
                            payload={
                                "type": "publishable" if "PUBLISHABLE" in plan.entry_name else "secret",
                                "name": f"{plan.entry_name.lower()}_{effective_now.strftime('%Y%m%d%H%M')}",
                            },
                            allowed_hosts=allowed_hosts,
                        )
                        new_material = str(created.get("api_key") or created.get("key") or "").strip()
                        if not new_material:
                            raise RuntimeError("Supabase API key reissue response omitted generated credential")
                    elif plan.strategy == STRATEGY_CSPRNG:
                        new_material = py_csprng.token_urlsafe(32)
                    else:
                        raise RuntimeError(f"Unsupported auto-reissue strategy: {plan.strategy}")

                    store_results = _propagate_stores(
                        plan=plan,
                        new_material=new_material,
                        project_ref=project_ref,
                        supabase_cred=supabase_cred,
                        gh_cred=gh_cred,
                        repository=repository,
                        allowed_hosts=allowed_hosts,
                        transport=transport,
                        gh_updater=gh_updater,
                    )
                    rotated_count += 1
                    rev_res = _revoke_previous_credential(
                        plan=plan,
                        previous_id=plan.previous_key_id or plan.active_key_id,
                        project_ref=project_ref,
                        supabase_cred=supabase_cred,
                        allowed_hosts=allowed_hosts,
                        transport=transport,
                    )
                    if rev_res["status"] == "revoked":
                        revoked_count += 1
                    elif rev_res["status"] == "pending_grace_window":
                        pending_revocations.append(plan.entry_name)
                    execution_records.append(
                        {
                            "entry_name": plan.entry_name,
                            "action": "rotate_auto",
                            "status": "rotated",
                            "stores": store_results,
                            "revocation_status": rev_res["status"],
                        }
                    )
                elif plan.planned_action == "revoke_expired_previous":
                    rev_res = _revoke_previous_credential(
                        plan=plan,
                        previous_id=plan.previous_key_id,
                        project_ref=project_ref,
                        supabase_cred=supabase_cred,
                        allowed_hosts=allowed_hosts,
                        transport=transport,
                    )
                    if rev_res["status"] == "revoked":
                        revoked_count += 1
                    execution_records.append(
                        {
                            "entry_name": plan.entry_name,
                            "action": "revoke_expired_previous",
                            "status": rev_res["status"],
                            "revocation_status": rev_res["status"],
                        }
                    )
            except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as exc:
                err_record = {
                    "entry_name": plan.entry_name,
                    "action": plan.planned_action,
                    "status": "failed_old_key_preserved",
                    "revocation_status": "aborted_error",
                    "error": sanitize_text(str(exc)),
                }
                execution_records.append(err_record)
                failed_items.append(err_record)
    else:
        for plan in plans:
            if plan.revocation_state in ("grace_window_active", "revocation_due"):
                pending_revocations.append(plan.entry_name)
            execution_records.append(
                {
                    "entry_name": plan.entry_name,
                    "action": plan.planned_action,
                    "status": "planned_dry_run",
                    "revocation_status": plan.revocation_state,
                }
            )

    overdue_items = [p.entry_name for p in plans if p.sla_state == "overdue"]
    expiring_soon_items = [p.entry_name for p in plans if p.sla_state == "expiring_soon"]
    unknown_age_items = [p.entry_name for p in plans if p.sla_state == "unknown_age"]

    if effective_mode == "live" and missing_credentials:
        overall_status = "blocked_missing_credentials"
    elif failed_items:
        overall_status = "partial_failure" if (rotated_count or revoked_count) else "failed"
    elif strict_overdue and overdue_items:
        overall_status = "fail_overdue"
    elif overdue_items or expiring_soon_items or pending_revocations:
        overall_status = "warn"
    else:
        overall_status = "pass"

    summary_counts = {
        "total_evaluated": len(plans),
        "overdue": len(overdue_items),
        "expiring_soon": len(expiring_soon_items),
        "unknown_age": len(unknown_age_items),
        "auto_candidates": len(auto_plans),
        "rotated": rotated_count,
        "revoked": revoked_count,
        "pending_revocation": len(pending_revocations),
        "failed": len(failed_items),
    }

    admin_notification = build_admin_notification_payload(
        run_id=run_id,
        mode=effective_mode,
        overall_status=overall_status,
        summary_counts=summary_counts,
        failed_items=failed_items,
        overdue_items=overdue_items,
        pending_revocations=pending_revocations,
        missing_credentials=missing_credentials,
    )
    audit_log = sanitize_structure(
        {
            "schema_version": 1,
            "issue": 2690,
            "run_id": run_id,
            "generated_at": effective_now.isoformat(),
            "mode": effective_mode,
            "live_requested": live,
            "confirm_rotate": confirm_rotate,
            "status": overall_status,
            "oidc": {
                **asdict(oidc_status),
                "verified_live_exchange": oidc_verified_live,
            },
            "summary_counts": summary_counts,
            "missing_credentials": missing_credentials,
            "execution_records": execution_records,
        }
    )
    report = sanitize_structure(
        {
            "schema_version": 1,
            "issue": 2690,
            "run_id": run_id,
            "generated_at": effective_now.isoformat(),
            "mode": effective_mode,
            "status": overall_status,
            "oidc": audit_log["oidc"],
            "summary_counts": summary_counts,
            "missing_credentials": missing_credentials,
            "plans": [asdict(item) for item in plans],
            "execution_records": execution_records,
            "audit_log": audit_log,
            "admin_notification": admin_notification,
        }
    )
    return report


def render_markdown(report: Mapping[str, Any]) -> str:
    counts = report["summary_counts"]
    oidc = report["oidc"]
    notif = report["admin_notification"]
    lines = [
        "### Secret Auto-Rotation Audit & Execution Report (#2690)",
        f"- Run ID: `{report['run_id']}`",
        f"- Mode: `{report['mode']}`",
        f"- Status: `{report['status']}`",
        f"- OIDC Status: `configured={oidc['configured']}, verified={oidc['verified']}` ({oidc['reason']})",
        f"- Entries Evaluated: `{counts['total_evaluated']}` (Auto Candidates: `{counts['auto_candidates']}`)",
        f"- Overdue / Expiring Soon / Unknown Age: `{counts['overdue']}` / `{counts['expiring_soon']}` / `{counts['unknown_age']}`",
        f"- Rotated / Old Keys Revoked / Failed: `{counts['rotated']}` / `{counts['revoked']}` / `{counts['failed']}`",
        f"- Pending Revocations: `{counts['pending_revocation']}`",
        f"- Admin Notification Required: `{notif['notify_required']}` (`severity={notif['severity']}`)",
    ]
    missing_creds = report.get("missing_credentials") or []
    if missing_creds:
        lines.append(f"- Missing Live Credentials: `{', '.join(missing_creds)}`")
    lines.append("")
    return sanitize_text("\n".join(lines))


def write_github_outputs(path: Path, report: Mapping[str, Any]) -> None:
    counts = report["summary_counts"]
    notif = report["admin_notification"]
    lines = [
        f"status={report['status']}",
        f"mode={report['mode']}",
        f"total_evaluated={counts['total_evaluated']}",
        f"overdue_count={counts['overdue']}",
        f"rotated_count={counts['rotated']}",
        f"revoked_count={counts['revoked']}",
        f"failed_count={counts['failed']}",
        f"notify_required={str(notif['notify_required']).lower()}",
    ]
    with path.open("a", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def run_self_test() -> dict[str, Any]:
    """Run deterministic offline self-tests across policy, dry-run, fail-closed, and live simulation."""
    policy_path = ROOT / DEFAULT_POLICY_PATH
    manifest_path = ROOT / DEFAULT_MANIFEST_PATH
    policy = load_policy(policy_path)
    rules = build_rule_inventory(manifest_path, policy)
    rule_names = {rule.entry_name for rule in rules}
    for must_have in ("SUPABASE_SECRET_KEY", "INTERNAL_HMAC_SECRET", "GITHUB_PAT"):
        if must_have not in rule_names:
            raise AssertionError(f"Missing expected policy rule {must_have}")

    fixed_now = datetime(2026, 11, 25, 0, 0, tzinfo=timezone.utc)
    snapshots = [
        MetadataSnapshot(
            entry_name="INTERNAL_HMAC_SECRET",
            store="supabase_edge_secrets",
            updated_at=fixed_now - timedelta(days=75),
            active_key_id="hmac_v1",
        ),
        MetadataSnapshot(
            entry_name="SUPABASE_SECRET_KEY",
            store="supabase_api_keys",
            updated_at=fixed_now - timedelta(days=2),
            active_key_id="key_v2",
            previous_key_id="key_v1",
            previous_key_created_at=fixed_now - timedelta(hours=30),
            previous_key_revoked_at=None,
        ),
    ]

    # 1. Dry-run never mutates even when keys are overdue or revocation is due.
    dry_report = execute_rotation_cycle(
        rules=rules,
        snapshots=snapshots,
        policy=policy,
        environ={},
        now=fixed_now,
        live=False,
    )
    if dry_report["mode"] != "dry_run" or dry_report["summary_counts"]["rotated"] != 0:
        raise AssertionError("Self-test dry-run safety violation")

    # 2. Live request without credentials must fail closed without mutation.
    blocked_report = execute_rotation_cycle(
        rules=rules,
        snapshots=snapshots,
        policy=policy,
        environ={},
        now=fixed_now,
        live=True,
        confirm_rotate=True,
        require_oidc=True,
    )
    if blocked_report["status"] != "blocked_missing_credentials":
        raise AssertionError("Self-test fail-closed credential check failed")

    # 3. Simulated live cycle verifies OIDC -> reissue -> store update -> old key revocation.
    calls: list[tuple[str, str]] = []

    def fake_transport(method: str, url: str, **_kwargs: Any) -> dict[str, Any]:
        calls.append((method, url))
        if "token.actions.githubusercontent.com" in url:
            return {"value": ".".join(["eyJtest12345", "payload1234", "sig123456"])}
        if method == "POST" and url.endswith("/api-keys"):
            return {"api_key": "sb_" + "secret_" + "rotated999999"}
        return {"ok": True}

    def fake_gh_updater(**kwargs: Any) -> dict[str, Any]:
        calls.append(("GH_SET", kwargs["entry_name"]))
        return {"store": kwargs["store"], "status": "updated"}

    live_env = {
        OIDC_URL_ENV: "https://token.actions.githubusercontent.com/id?run=1",
        OIDC_AUTH_ENV: "req_dummy_bearer",
        "SUPABASE_MANAGEMENT_CREDENTIAL": "sbp_" + "dummy1234567890",
        "SUPABASE_PROJECT_REF_ID": "projtest123",
        "GH_SECRETS_ADMIN_CREDENTIAL": "ghp_" + "dummy1234567890",
        "GITHUB_REPOSITORY_SLUG": "kanta13jp1/my_web_app",
    }
    live_report = execute_rotation_cycle(
        rules=rules,
        snapshots=snapshots,
        policy=policy,
        environ=live_env,
        now=fixed_now,
        live=True,
        confirm_rotate=True,
        require_oidc=True,
        target_names={"INTERNAL_HMAC_SECRET", "SUPABASE_SECRET_KEY"},
        transport=fake_transport,
        gh_updater=fake_gh_updater,
    )
    if live_report["status"] not in ("pass", "warn") or live_report["summary_counts"]["rotated"] != 1 or live_report["summary_counts"]["revoked"] != 1:
        raise AssertionError(f"Self-test simulated live cycle mismatch: {live_report['summary_counts']}")
    serialized = json.dumps(live_report, ensure_ascii=False)
    if "dummy1234567890" in serialized or "rotated999999" in serialized:
        raise AssertionError("Self-test detected leaked credential in report")

    return {
        "self_test": "passed",
        "rules_evaluated": len(rules),
        "dry_run_status": dry_report["status"],
        "blocked_status": blocked_report["status"],
        "live_sim_rotated": live_report["summary_counts"]["rotated"],
        "live_sim_revoked": live_report["summary_counts"]["revoked"],
        "transport_calls": len(calls),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--policy", type=Path, default=None)
    parser.add_argument("--manifest", type=Path, default=None)
    parser.add_argument("--metadata-file", type=Path, default=None)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--confirm-rotate", action="store_true")
    parser.add_argument("--require-oidc", action="store_true")
    parser.add_argument("--strict-overdue", action="store_true")
    parser.add_argument("--force-due", action="store_true")
    parser.add_argument("--target", action="append", default=[])
    parser.add_argument("--webhook-url", default="")
    parser.add_argument("--notify-always", action="store_true")
    parser.add_argument("--json-out", "--report", dest="json_out", type=Path, default=None)
    parser.add_argument("--audit-log-out", type=Path, default=None)
    parser.add_argument("--markdown-out", type=Path, default=None)
    parser.add_argument("--github-output", type=Path, default=None)
    parser.add_argument("--self-test", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    args = build_parser().parse_args(argv)
    if args.self_test:
        print(json.dumps(run_self_test(), ensure_ascii=False))
        return 0

    root = args.root.resolve()
    policy_path = (args.policy or (root / DEFAULT_POLICY_PATH)).resolve()
    manifest_path = (args.manifest or (root / DEFAULT_MANIFEST_PATH)).resolve()

    policy = load_policy(policy_path)
    rules = build_rule_inventory(manifest_path, policy)
    snapshots: list[MetadataSnapshot] = []
    if args.metadata_file and args.metadata_file.exists():
        raw_meta = json.loads(args.metadata_file.read_text(encoding="utf-8-sig"))
        snapshots = parse_metadata_snapshots(raw_meta)

    target_names = {item.strip() for item in args.target if item.strip()} or None
    live_mode = bool(args.live and not args.dry_run)
    report = execute_rotation_cycle(
        rules=rules,
        snapshots=snapshots,
        policy=policy,
        environ=dict(os.environ),
        live=live_mode,
        confirm_rotate=args.confirm_rotate,
        require_oidc=args.require_oidc,
        strict_overdue=args.strict_overdue,
        target_names=target_names,
        force_due=args.force_due,
    )

    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    if args.audit_log_out:
        args.audit_log_out.parent.mkdir(parents=True, exist_ok=True)
        args.audit_log_out.write_text(
            json.dumps(report["audit_log"], indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    if args.markdown_out:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(render_markdown(report), encoding="utf-8")
    if args.github_output:
        write_github_outputs(args.github_output, report)

    webhook_dest = (args.webhook_url or os.environ.get("ROTATION_ALERT_WEBHOOK", "")).strip()
    notif = report["admin_notification"]
    if live_mode and webhook_dest and (args.notify_always or notif["notify_required"]):
        try:
            manifest_mod.post_json_pinned_https(webhook_dest, notif)
        except (OSError, RuntimeError, ValueError) as exc:
            print(f"::warning::Admin notification delivery failed: {sanitize_text(str(exc))}", file=sys.stderr)

    print(render_markdown(report))
    if report["status"] in ("failed", "partial_failure", "blocked_missing_credentials", "fail_overdue"):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
