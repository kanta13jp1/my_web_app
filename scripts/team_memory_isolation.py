#!/usr/bin/env python3
"""Pre-save Team Memory sanitizer, scope-isolation verifier, and DB contract auditor (#2686).

Enforces pre-persistence secret/PII/code-block abstraction, validates strict SQL RLS/RPC
isolation boundaries in `20261124003700_create_team_memory_patterns.sql` and TypeScript
`_shared/team_memory_isolation.ts`, and verifies zero cross-scope leakage.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCOPE_TYPES = {"agent", "org", "project"}
PATTERN_TYPES = {"anti_pattern", "success_rule", "guardrail", "workflow_pattern"}
SCOPE_ID_RE = re.compile(r"^[a-zA-Z0-9_.:-]{2,120}$")
MIGRATION_REL = "supabase/migrations/20261124003700_create_team_memory_patterns.sql"
TS_MODULE_REL = "supabase/functions/_shared/team_memory_isolation.ts"

KV_MARKER_PATTERN = re.compile(
    r"(?i)([A-Za-z0-9_.-]*(?:secret|token|password|passwd|api[_-]?key|apikey|credential|service_role))\s*[:=]\s*(['\"]?)[^\s,'\"`;\)]{4,}\2",
)
BEARER_PATTERN = re.compile(r"(?i)\b(?:Bearer|Basic)\s+[A-Za-z0-9\-._~+/]+=*")
JWT_PATTERN = re.compile(r"\beyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\b")
PREFIXED_MARKER_PATTERN = re.compile(
    r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{10,}\b"
    r"|\bgithub_pat_[A-Za-z0-9_]{10,}\b"
    r"|\bsk-[A-Za-z0-9_-]{10,}\b"
    r"|\bxox[baprs]-[A-Za-z0-9-]{10,}\b"
    r"|\bAIza[0-9A-Za-z_-]{10,}\b"
    r"|\bsb_(?:secret|publishable)_[A-Za-z0-9_-]{10,}\b"
    r"|\b(?:pk|rk)_(?:live|test)_[A-Za-z0-9]{10,}\b",
)
EMAIL_PATTERN = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
CODE_FENCE_PATTERN = re.compile(r"```[\s\S]*?```")
INLINE_SQL_PATTERN = re.compile(
    r"(?i)\b(?:SELECT|INSERT\s+INTO|UPDATE|DELETE\s+FROM|CREATE\s+TABLE|ALTER\s+TABLE)\b[^.;\n]{4,}[;\n]?",
)
CODE_SNIPPET_PATTERN = re.compile(
    r"\b(?:import\s+['\"][^'\"]+['\"];?|class\s+[A-Za-z0-9_]+\s*(?:extends|implements)\s+[A-Za-z0-9_]+|const\s+[A-Za-z0-9_]+\s*=\s*\{[^}]+\})",
)
WIN_PATH_PATTERN = re.compile(r"(?i)[A-Za-z]:\\(?:Users|tmp|home|var)\\[^\s\"'`\)]+")
UNIX_PATH_PATTERN = re.compile(r"/(?:Users|home|etc|var|root)/[^\s\"'`\)]+")
PRIVATE_IPV4_PATTERN = re.compile(
    r"\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|127\.\d{1,3}\.\d{1,3}\.\d{1,3}|169\.254\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})\b",
)
RESIDUAL_FORBIDDEN_PATTERN = re.compile(
    r"```|ghp_|github_pat_|sk-[A-Za-z0-9_-]{8,}|xox[baprs]-|AIza[0-9A-Za-z_-]{8,}|sb_secret_|Bearer\s+[A-Za-z0-9._-]{8,}|eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}",
    re.IGNORECASE,
)


def sanitize_text(raw: str) -> tuple[str, int]:
    """Strip credentials, PII, local paths, and raw code blocks before team memory persistence."""
    if not raw or not raw.strip():
        return "", 0
    hits = 0
    current = raw

    def _sub(pattern: re.Pattern[str], repl: Any, text: str) -> str:
        nonlocal hits
        new_text, count = pattern.subn(repl, text)
        hits += count
        return new_text

    current = _sub(BEARER_PATTERN, "***", current)
    current = _sub(JWT_PATTERN, "***", current)
    current = _sub(KV_MARKER_PATTERN, lambda m: f"{m.group(1)}=***", current)
    current = _sub(PREFIXED_MARKER_PATTERN, "***", current)
    current = _sub(CODE_FENCE_PATTERN, "[abstracted_code_block]", current)
    current = _sub(CODE_SNIPPET_PATTERN, "[abstracted_snippet]", current)
    current = _sub(INLINE_SQL_PATTERN, "[abstracted_query]", current)
    current = _sub(EMAIL_PATTERN, "***", current)
    current = _sub(WIN_PATH_PATTERN, "[local_path]", current)
    current = _sub(UNIX_PATH_PATTERN, "[local_path]", current)
    current = _sub(PRIVATE_IPV4_PATTERN, "[internal_ip]", current)

    normalized = re.sub(r"\s+", " ", current).strip()
    return normalized, hits


def detect_residual_sensitive_material(text: str) -> str | None:
    match = RESIDUAL_FORBIDDEN_PATTERN.search(text)
    return match.group(0) if match else None


@dataclass(frozen=True)
class TeamMemoryEntry:
    scope_type: str
    scope_id: str
    pattern_type: str
    abstract_rule: str
    sanitized_summary: str
    redaction_count: int
    source_session_hash: str
    is_sanitized: bool = True


def prepare_pattern_entry(
    *,
    scope_type: str,
    scope_id: str,
    pattern_type: str,
    raw_summary: str,
    raw_rule: str = "",
    session_id: str = "session-default",
    llm_abstractor: Any = None,
) -> TeamMemoryEntry:
    """Sanitize, optionally LLM-abstract with post-redaction, and validate a pattern entry."""
    norm_scope_type = scope_type.strip().lower()
    norm_scope_id = scope_id.strip()
    norm_pattern_type = pattern_type.strip().lower()

    if norm_scope_type not in SCOPE_TYPES:
        raise ValueError(f"unsupported scope_type: {scope_type!r}")
    if not SCOPE_ID_RE.fullmatch(norm_scope_id):
        raise ValueError(f"invalid scope_id: {scope_id!r}")
    if norm_pattern_type not in PATTERN_TYPES:
        raise ValueError(f"unsupported pattern_type: {pattern_type!r}")

    sanitized_summary, sum_hits = sanitize_text(raw_summary)
    rule_input = raw_rule.strip() or raw_summary.strip()
    sanitized_rule, rule_hits = sanitize_text(rule_input)
    total_hits = sum_hits + rule_hits

    if llm_abstractor is not None:
        abstracted = str(llm_abstractor(sanitized_rule))
        sanitized_rule, post_hits = sanitize_text(abstracted)
        total_hits += post_hits

    if len(sanitized_summary) < 10 or len(sanitized_rule) < 10:
        raise ValueError("sanitized summary and abstract rule must be at least 10 characters")

    if detect_residual_sensitive_material(sanitized_summary) is not None:
        raise ValueError("residual sensitive marker survived in sanitized_summary")
    if detect_residual_sensitive_material(sanitized_rule) is not None:
        raise ValueError("residual sensitive marker survived in abstract_rule")

    session_hash = hashlib.sha256(session_id.encode("utf-8")).hexdigest()[:32]
    return TeamMemoryEntry(
        scope_type=norm_scope_type,
        scope_id=norm_scope_id,
        pattern_type=norm_pattern_type,
        abstract_rule=sanitized_rule[:1000],
        sanitized_summary=sanitized_summary[:2000],
        redaction_count=total_hits,
        source_session_hash=session_hash,
        is_sanitized=True,
    )


class IsolationBoundaryStore:
    """In-memory scope boundary simulator mirroring PostgreSQL RLS + RPC constraints."""

    def __init__(self) -> None:
        self._memberships: dict[str, set[tuple[str, str]]] = {}
        self._entries: list[TeamMemoryEntry] = []

    def grant_scope(self, agent_id: str, scope_type: str, scope_id: str) -> None:
        if scope_type not in SCOPE_TYPES or not SCOPE_ID_RE.fullmatch(scope_id):
            raise ValueError(f"invalid scope binding: {scope_type}:{scope_id}")
        self._memberships.setdefault(agent_id, set()).add((scope_type, scope_id))

    def publish(self, agent_id: str, entry: TeamMemoryEntry) -> None:
        if not entry.is_sanitized:
            raise PermissionError("unsanitized entries cannot be stored")
        if (entry.scope_type, entry.scope_id) not in self._memberships.get(agent_id, set()):
            raise PermissionError(f"agent {agent_id!r} cannot publish to {entry.scope_type}:{entry.scope_id}")
        if detect_residual_sensitive_material(entry.abstract_rule) or detect_residual_sensitive_material(
            entry.sanitized_summary,
        ):
            raise ValueError("residual sensitive data blocked before persistence")
        self._entries.append(entry)

    def query(self, agent_id: str, scope_type: str, scope_id: str) -> list[TeamMemoryEntry]:
        if (scope_type, scope_id) not in self._memberships.get(agent_id, set()):
            raise PermissionError(f"cross-scope query blocked for {agent_id!r} -> {scope_type}:{scope_id}")
        return [
            item
            for item in self._entries
            if item.scope_type == scope_type and item.scope_id == scope_id and item.is_sanitized
        ]


def inspect_isolation_contracts(repo_root: Path) -> dict[str, Any]:
    """Audit SQL migration and TS isolation module for required RLS, search_path, and masking guards."""
    violations: list[str] = []

    mig_path = repo_root / MIGRATION_REL
    if not mig_path.exists():
        violations.append(f"{MIGRATION_REL} missing")
    else:
        sql = mig_path.read_text(encoding="utf-8-sig")
        for required_fragment, label in (
            ("alter table public.team_memory_scopes enable row level security", "RLS enabled on team_memory_scopes"),
            ("alter table public.team_memory_patterns enable row level security", "RLS enabled on team_memory_patterns"),
            ("revoke all on table public.team_memory_scopes from public, anon, authenticated", "scopes table revoke"),
            ("revoke all on table public.team_memory_patterns from public, anon, authenticated", "patterns table revoke"),
            ("revoke all on function public.guard_team_memory_scopes() from public, anon, authenticated", "scopes trigger revoke"),
            ("revoke all on function public.guard_team_memory_patterns() from public, anon, authenticated", "patterns trigger revoke"),
            ("pg_temp", "search_path pg_temp guard"),
            ("v_claims := '{}'::jsonb", "22P02-safe JWT claims fallback"),
            ("is_sanitized = true", "fail-closed sanitized row check constraint"),
        ):
            if required_fragment not in sql:
                violations.append(f"{MIGRATION_REL}: missing {label}")
        if re.search(r"auth\.role\s*\(", sql, re.IGNORECASE):
            violations.append(f"{MIGRATION_REL}: must not use deprecated auth.role()")

    ts_path = repo_root / TS_MODULE_REL
    if not ts_path.exists():
        violations.append(f"{TS_MODULE_REL} missing")
    else:
        ts_text = ts_path.read_text(encoding="utf-8-sig")
        for fn_name in (
            "sanitizeLearningPattern",
            "abstractAndSanitizePattern",
            "detectResidualSensitiveMaterial",
            "filterPatternsForScope",
        ):
            if fn_name not in ts_text:
                violations.append(f"{TS_MODULE_REL}: missing {fn_name}")

    return {
        "contracts_ok": len(violations) == 0,
        "violations": violations,
    }


def run_self_test(repo_root: Path) -> dict[str, Any]:
    contracts = inspect_isolation_contracts(repo_root)
    if not contracts["contracts_ok"]:
        raise RuntimeError(f"team memory contract failure: {contracts['violations']}")

    store = IsolationBoundaryStore()
    store.grant_scope("agent-alpha", "org", "org:alpha")
    store.grant_scope("agent-alpha-2", "org", "org:alpha")
    store.grant_scope("agent-beta", "org", "org:beta")

    fake_token = "".join(["ghp", "_SelfTestSecretValue99999"])
    entry = prepare_pattern_entry(
        scope_type="org",
        scope_id="org:alpha",
        pattern_type="anti_pattern",
        raw_summary=f"Never commit {fake_token} from ```dart\nfinal x = '{fake_token}';\n```",
        raw_rule=f"Always redact credentials such as {fake_token} before storing rules.",
        session_id="sess-alpha-1",
    )
    assert "SelfTestSecretValue99999" not in entry.abstract_rule
    assert "SelfTestSecretValue99999" not in entry.sanitized_summary
    assert "```" not in entry.abstract_rule
    assert entry.redaction_count > 0

    store.publish("agent-alpha", entry)
    shared_rows = store.query("agent-alpha-2", "org", "org:alpha")
    assert len(shared_rows) == 1

    try:
        store.query("agent-beta", "org", "org:alpha")
    except PermissionError:
        pass
    else:
        raise AssertionError("cross-scope leakage must raise PermissionError")

    return {"self_test": "passed", "contracts_ok": True, "scenarios_verified": 4}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--check-contracts", action="store_true", default=False)
    parser.add_argument("--dry-run", action="store_true", default=False)
    parser.add_argument("--self-test", action="store_true", default=False)
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--markdown-out", type=Path, default=None)
    parser.add_argument("--github-output", type=Path, default=None)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = args.repo_root.resolve()

    if args.self_test:
        print(json.dumps(run_self_test(root), ensure_ascii=False))
        return 0

    audit = inspect_isolation_contracts(root)
    report = {
        "issue": 2686,
        "status": "ok" if audit["contracts_ok"] else "failed",
        "contracts_ok": audit["contracts_ok"],
        "violations": audit["violations"],
        "dry_run": args.dry_run,
    }
    md = "\n".join(
        [
            "### Team Memory Isolation Audit (#2686)",
            f"- Status: `{report['status']}` | Contracts OK: `{report['contracts_ok']}`",
            *[f"- Violation: {v}" for v in report["violations"]],
        ],
    ) + "\n"
    print(md, end="")

    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.markdown_out is not None:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(md, encoding="utf-8")
    if args.github_output is not None:
        args.github_output.parent.mkdir(parents=True, exist_ok=True)
        with args.github_output.open("a", encoding="utf-8") as handle:
            handle.write(f"contracts_ok={str(report['contracts_ok']).lower()}\n")
            handle.write(f"status={report['status']}\n")

    if args.dry_run:
        return 0
    return 0 if report["contracts_ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
