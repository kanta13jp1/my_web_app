#!/usr/bin/env python3
"""Validate managed MCP access control and session-start warnings.

Issue #1586 requires a repo-managed allow/deny register for MCP servers. This
script keeps the contract deterministic: it validates the management JSON and
can also scan local agent settings for unmanaged servers, auth warnings, and
dangerous permission knobs without printing secrets.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tomllib
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = REPO_ROOT / "config" / "managed-mcp.json"

REQUIRED_ALLOWED_FIELDS = {
    "id",
    "displayName",
    "aliases",
    "purpose",
    "permissions",
    "dataClassification",
    "approver",
    "humanApprovalRequiredFor",
    "auditLog",
    "allowedReason",
    "auth",
}

REQUIRED_DENIED_FIELDS = {
    "id",
    "displayName",
    "aliases",
    "deniedReason",
    "approver",
    "reviewAfter",
}

REQUIRED_INTEGRATIONS = {
    "github",
    "notion",
    "slack",
    "google-drive",
    "notebooklm",
    "context7",
}

SECRET_KEYS = {
    "key",
    "token",
    "secret",
    "password",
    "authorization",
    "credential",
}


@dataclass(frozen=True)
class SessionFinding:
    severity: str
    kind: str
    source: str
    server: str
    message: str


def normalize_id(value: str) -> str:
    normalized = value.strip().lower().replace("\\", "/")
    normalized = normalized.replace("@", "-at-")
    normalized = re.sub(r"[^a-z0-9._/-]+", "-", normalized)
    normalized = re.sub(r"-+", "-", normalized).strip("-")
    return normalized


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def load_policy(path: Path = DEFAULT_CONFIG) -> dict[str, Any]:
    return load_json(path)


def string_list(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(isinstance(item, str) for item in value)


def policy_ids(policy: dict[str, Any], key: str) -> list[str]:
    entries = policy.get(key)
    if not isinstance(entries, list):
        return []
    return [entry.get("id", "") for entry in entries if isinstance(entry, dict)]


def entry_aliases(entry: dict[str, Any]) -> list[str]:
    aliases = entry.get("aliases", [])
    if not isinstance(aliases, list):
        aliases = []
    return [str(entry.get("id", "")), *[str(alias) for alias in aliases]]


def alias_maps(policy: dict[str, Any]) -> tuple[dict[str, str], dict[str, str]]:
    allowed: dict[str, str] = {}
    denied: dict[str, str] = {}
    for key, target in [("allowedMcpServers", allowed), ("deniedMcpServers", denied)]:
        entries = policy.get(key, [])
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            entry_id = str(entry.get("id", ""))
            for alias in entry_aliases(entry):
                target[normalize_id(alias)] = entry_id
    return allowed, denied


def validate_policy(policy: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    if policy.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1.")
    if policy.get("status") != "active":
        errors.append("status must be active.")
    if policy.get("defaultDecision") != "deny":
        errors.append("defaultDecision must be deny.")

    owner = policy.get("ownerModel")
    if not isinstance(owner, dict):
        errors.append("ownerModel must be an object.")
    else:
        active = owner.get("activeInstances")
        if active != ["Claude Code #1", "Codex #1"]:
            errors.append("ownerModel.activeInstances must be Claude Code #1 + Codex #1 only.")

    high_risk = policy.get("highRiskScopes")
    if not string_list(high_risk):
        errors.append("highRiskScopes must be a non-empty string array.")
        high_risk_set: set[str] = set()
    else:
        high_risk_set = {item.lower() for item in high_risk}

    danger_patterns = policy.get("dangerousPermissionPatterns")
    if not string_list(danger_patterns):
        errors.append("dangerousPermissionPatterns must be a non-empty string array.")
    else:
        for pattern in danger_patterns:
            try:
                re.compile(pattern, flags=re.IGNORECASE)
            except re.error as exc:
                errors.append(f"dangerousPermissionPatterns contains invalid regex `{pattern}`: {exc}.")

    allowed = policy.get("allowedMcpServers")
    denied = policy.get("deniedMcpServers")
    if not isinstance(allowed, list) or not allowed:
        errors.append("allowedMcpServers must be a non-empty array.")
        allowed = []
    if not isinstance(denied, list) or not denied:
        errors.append("deniedMcpServers must be a non-empty array.")
        denied = []

    seen_ids: set[str] = set()
    seen_aliases: dict[str, str] = {}

    for section, entries, required in [
        ("allowedMcpServers", allowed, REQUIRED_ALLOWED_FIELDS),
        ("deniedMcpServers", denied, REQUIRED_DENIED_FIELDS),
    ]:
        for index, entry in enumerate(entries):
            if not isinstance(entry, dict):
                errors.append(f"{section}[{index}] must be an object.")
                continue
            missing = sorted(required - set(entry))
            if missing:
                errors.append(f"{section}[{index}] is missing required fields: {', '.join(missing)}.")
                continue
            entry_id = str(entry["id"])
            normalized_entry_id = normalize_id(entry_id)
            if normalized_entry_id in seen_ids:
                errors.append(f"Duplicate MCP server id `{entry_id}`.")
            seen_ids.add(normalized_entry_id)
            if not string_list(entry.get("aliases")):
                errors.append(f"{section}.{entry_id}.aliases must be a non-empty string array.")
            for alias in entry_aliases(entry):
                normalized_alias = normalize_id(alias)
                if normalized_alias in seen_aliases and seen_aliases[normalized_alias] != entry_id:
                    errors.append(
                        f"Alias `{alias}` is shared by `{seen_aliases[normalized_alias]}` and `{entry_id}`."
                    )
                seen_aliases[normalized_alias] = entry_id

            if section == "allowedMcpServers":
                for field in [
                    "purpose",
                    "approver",
                    "auditLog",
                    "allowedReason",
                ]:
                    if not str(entry.get(field, "")).strip():
                        errors.append(f"allowedMcpServers.{entry_id}.{field} must be non-empty.")
                for field in ["permissions", "dataClassification", "humanApprovalRequiredFor"]:
                    if not string_list(entry.get(field)):
                        errors.append(f"allowedMcpServers.{entry_id}.{field} must be a non-empty string array.")
                auth = entry.get("auth")
                if not isinstance(auth, dict):
                    errors.append(f"allowedMcpServers.{entry_id}.auth must be an object.")
                else:
                    if not isinstance(auth.get("required"), bool):
                        errors.append(f"allowedMcpServers.{entry_id}.auth.required must be boolean.")
                    if auth.get("status") not in {"managed", "active", "not_required"}:
                        errors.append(
                            f"allowedMcpServers.{entry_id}.auth.status must be managed, active, or not_required."
                        )
                scopes = {str(item).lower() for item in entry.get("permissions", [])}
                if scopes & high_risk_set and not string_list(entry.get("humanApprovalRequiredFor")):
                    errors.append(
                        f"allowedMcpServers.{entry_id} has high-risk scopes but no human approval list."
                    )
            else:
                for field in ["deniedReason", "approver", "reviewAfter"]:
                    if not str(entry.get(field, "")).strip():
                        errors.append(f"deniedMcpServers.{entry_id}.{field} must be non-empty.")

    allowed_ids = {normalize_id(item) for item in policy_ids(policy, "allowedMcpServers")}
    denied_ids = {normalize_id(item) for item in policy_ids(policy, "deniedMcpServers")}
    overlap = sorted(allowed_ids & denied_ids)
    if overlap:
        errors.append("Server ids cannot be both allowed and denied: " + ", ".join(overlap) + ".")

    missing_required = sorted(REQUIRED_INTEGRATIONS - allowed_ids)
    if missing_required:
        errors.append(
            "Required issue #1586 integrations missing from allowedMcpServers: "
            + ", ".join(missing_required)
            + "."
        )

    raw_policy = json.dumps(policy, ensure_ascii=False)
    if re.search(r"\bCodex #?[23]\b", raw_policy, flags=re.IGNORECASE):
        errors.append("managed MCP policy must not assign active work to Codex #2 or Codex #3.")

    return errors


def default_session_paths(root: Path, include_home: bool = False) -> list[Path]:
    paths = [
        root / ".claude" / "settings.json",
        root / ".claude" / "settings.local.json",
    ]
    if include_home:
        home = Path.home()
        paths.extend(
            [
                home / ".claude" / "settings.json",
                home / ".claude" / "settings.local.json",
                home / ".claude" / "mcp-needs-auth-cache.json",
                home / ".codex" / "config.toml",
            ]
        )
    return paths


def sanitize_scalar(key: str, value: Any) -> str:
    lowered = key.lower()
    if any(secret in lowered for secret in SECRET_KEYS):
        return "<redacted>"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return value if len(value) <= 120 else value[:117] + "..."
    return type(value).__name__


def flatten_settings(value: Any, prefix: str = "") -> list[tuple[str, str]]:
    flattened: list[tuple[str, str]] = []
    if isinstance(value, dict):
        for key, item in value.items():
            key_str = str(key)
            path = f"{prefix}.{key_str}" if prefix else key_str
            flattened.extend(flatten_settings(item, path))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            flattened.extend(flatten_settings(item, f"{prefix}.{index}"))
    else:
        key = prefix.rsplit(".", 1)[-1]
        flattened.append((prefix, sanitize_scalar(key, value)))
    return flattened


def extract_mcp_from_permissions(permissions: Any) -> set[str]:
    servers: set[str] = set()
    if not isinstance(permissions, dict):
        return servers
    allow = permissions.get("allow", [])
    if not isinstance(allow, list):
        return servers
    for item in allow:
        if not isinstance(item, str):
            continue
        for match in re.finditer(r"\bmcp__([A-Za-z0-9_.@/-]+)__", item):
            servers.add(match.group(1))
        if "notebooklm" in item.lower():
            servers.add("notebooklm")
    return servers


def extract_servers_from_json(path: Path, data: dict[str, Any]) -> tuple[set[str], list[str]]:
    servers: set[str] = set()
    danger_evidence: list[str] = []

    mcp_servers = data.get("mcpServers")
    if isinstance(mcp_servers, dict):
        servers.update(str(key) for key in mcp_servers)

    enabled_plugins = data.get("enabledPlugins")
    if isinstance(enabled_plugins, dict):
        for key, value in enabled_plugins.items():
            if value is True:
                servers.add(str(key))

    servers.update(extract_mcp_from_permissions(data.get("permissions")))

    for key_path, value in flatten_settings(data):
        danger_evidence.append(f"{path}::{key_path}={value}")
    return servers, danger_evidence


def extract_servers_from_toml(path: Path, data: dict[str, Any]) -> tuple[set[str], list[str]]:
    servers: set[str] = set()
    danger_evidence: list[str] = []

    mcp_servers = data.get("mcp_servers")
    if isinstance(mcp_servers, dict):
        servers.update(str(key) for key in mcp_servers)

    plugins = data.get("plugins")
    if isinstance(plugins, dict):
        for key, value in plugins.items():
            if isinstance(value, dict) and value.get("enabled") is True:
                servers.add(str(key))

    for key_path, value in flatten_settings(data):
        danger_evidence.append(f"{path}::{key_path}={value}")
    return servers, danger_evidence


def auth_cache_servers(path: Path, data: dict[str, Any]) -> list[SessionFinding]:
    findings: list[SessionFinding] = []
    for key in data:
        findings.append(
            SessionFinding(
                severity="warning",
                kind="auth_required",
                source=str(path),
                server=str(key),
                message=f"Auth cache reports `{key}` needs re-authentication.",
            )
        )
    return findings


def load_settings_file(path: Path) -> tuple[set[str], list[str], list[SessionFinding]]:
    if not path.exists():
        return set(), [], []
    if path.suffix.lower() == ".json":
        data = load_json(path)
        if path.name == "mcp-needs-auth-cache.json":
            return set(data.keys()), [], auth_cache_servers(path, data)
        servers, danger = extract_servers_from_json(path, data)
        return servers, danger, []
    if path.suffix.lower() == ".toml":
        data = tomllib.loads(path.read_text(encoding="utf-8-sig"))
        servers, danger = extract_servers_from_toml(path, data)
        return servers, danger, []
    return set(), [], []


def match_policy_server(server: str, allowed: dict[str, str], denied: dict[str, str]) -> tuple[str, str | None]:
    normalized = normalize_id(server)
    if normalized in denied:
        return "denied", denied[normalized]
    if normalized in allowed:
        return "allowed", allowed[normalized]
    for aliases, status in [(denied, "denied"), (allowed, "allowed")]:
        for alias, entry_id in aliases.items():
            if alias and (normalized.endswith(alias) or alias.endswith(normalized)):
                return status, entry_id
    return "unmanaged", None


def dangerous_findings(
    evidence: list[str],
    patterns: list[str],
    max_findings: int = 25,
) -> list[SessionFinding]:
    findings: list[SessionFinding] = []
    compiled = [re.compile(pattern, flags=re.IGNORECASE) for pattern in patterns]
    for item in evidence:
        if len(findings) >= max_findings:
            findings.append(
                SessionFinding(
                    severity="warning",
                    kind="dangerous_permission",
                    source="settings",
                    server="settings",
                    message="Additional dangerous permission findings were truncated.",
                )
            )
            return findings
        for pattern in compiled:
            if pattern.search(item):
                source, _, detail = item.partition("::")
                findings.append(
                    SessionFinding(
                        severity="warning",
                        kind="dangerous_permission",
                        source=source,
                        server="settings",
                        message=f"Dangerous permission setting matched `{pattern.pattern}` at `{detail}`.",
                    )
                )
                break
    return findings


def config_auth_findings(policy: dict[str, Any]) -> list[SessionFinding]:
    findings: list[SessionFinding] = []
    today = date.today()
    for entry in policy.get("allowedMcpServers", []):
        if not isinstance(entry, dict):
            continue
        auth = entry.get("auth")
        if not isinstance(auth, dict):
            continue
        entry_id = str(entry.get("id", "unknown"))
        expires_at = auth.get("expiresAt")
        if isinstance(expires_at, str) and expires_at:
            try:
                if date.fromisoformat(expires_at) < today:
                    findings.append(
                        SessionFinding(
                            severity="warning",
                            kind="auth_expired",
                            source="managed-mcp.json",
                            server=entry_id,
                            message=f"`{entry_id}` auth expiry date `{expires_at}` is in the past.",
                        )
                    )
            except ValueError:
                findings.append(
                    SessionFinding(
                        severity="warning",
                        kind="auth_expiry_invalid",
                        source="managed-mcp.json",
                        server=entry_id,
                        message=f"`{entry_id}` auth expiry date `{expires_at}` is invalid.",
                    )
                )
    return findings


def session_findings(
    policy: dict[str, Any],
    settings_paths: list[Path],
) -> list[SessionFinding]:
    allowed, denied = alias_maps(policy)
    findings: list[SessionFinding] = []
    danger_evidence: list[str] = []
    active_servers: list[tuple[str, str]] = []

    for path in settings_paths:
        try:
            servers, danger, auth_findings = load_settings_file(path)
        except (json.JSONDecodeError, OSError, tomllib.TOMLDecodeError) as exc:
            findings.append(
                SessionFinding(
                    severity="warning",
                    kind="settings_unreadable",
                    source=str(path),
                    server="settings",
                    message=f"Could not inspect settings file: {exc}",
                )
            )
            continue
        danger_evidence.extend(danger)
        findings.extend(auth_findings)
        active_servers.extend((str(path), server) for server in sorted(servers))

    for source, server in active_servers:
        status, entry_id = match_policy_server(server, allowed, denied)
        if status == "denied":
            findings.append(
                SessionFinding(
                    severity="error",
                    kind="denied_server_active",
                    source=source,
                    server=server,
                    message=f"`{server}` is active but denied by managed MCP policy as `{entry_id}`.",
                )
            )
        elif status == "unmanaged":
            findings.append(
                SessionFinding(
                    severity="warning",
                    kind="unmanaged_server",
                    source=source,
                    server=server,
                    message=f"`{server}` is not recorded in allowedMcpServers or deniedMcpServers.",
                )
            )

    patterns = policy.get("dangerousPermissionPatterns")
    if isinstance(patterns, list):
        findings.extend(dangerous_findings(danger_evidence, [str(item) for item in patterns]))
    findings.extend(config_auth_findings(policy))
    return findings


def build_report(
    policy: dict[str, Any],
    validation_errors: list[str],
    findings: list[SessionFinding],
    config_path: Path = DEFAULT_CONFIG,
) -> dict[str, Any]:
    return {
        "config": str(config_path),
        "valid": not validation_errors,
        "validation_errors": validation_errors,
        "allowed_count": len(policy.get("allowedMcpServers", []) or []),
        "denied_count": len(policy.get("deniedMcpServers", []) or []),
        "session_findings": [asdict(finding) for finding in findings],
        "session_warning_count": sum(1 for finding in findings if finding.severity == "warning"),
        "session_error_count": sum(1 for finding in findings if finding.severity == "error"),
    }


def render_text(report: dict[str, Any]) -> str:
    lines = [
        f"Managed MCP policy: {'PASS' if report['valid'] else 'FAIL'}",
        f"Allowed servers: {report['allowed_count']}",
        f"Denied servers: {report['denied_count']}",
    ]
    if report["validation_errors"]:
        lines.append("Validation errors:")
        for error in report["validation_errors"]:
            lines.append(f"- {error}")
    if report["session_findings"]:
        lines.append("Session-start findings:")
        for item in report["session_findings"]:
            lines.append(
                f"- [{item['severity']}] {item['kind']} {item['server']}: {item['message']}"
            )
    return "\n".join(lines)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--json", action="store_true", help="Print JSON report.")
    parser.add_argument("--session-start", action="store_true", help="Scan settings files for warnings.")
    parser.add_argument("--include-home", action="store_true", help="Include ~/.claude and ~/.codex settings.")
    parser.add_argument("--settings", type=Path, action="append", default=[], help="Settings file to scan.")
    parser.add_argument(
        "--strict-session",
        action="store_true",
        help="Exit non-zero when session-start findings include warnings or errors.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    args = parse_args(argv)
    policy = load_policy(args.config)
    validation_errors = validate_policy(policy)
    findings: list[SessionFinding] = []
    if args.session_start:
        paths = args.settings or default_session_paths(REPO_ROOT, include_home=args.include_home)
        findings = session_findings(policy, paths)

    report = build_report(policy, validation_errors, findings, args.config)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(render_text(report))

    if validation_errors:
        return 1
    if args.strict_session and findings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
