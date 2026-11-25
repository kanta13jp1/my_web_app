#!/usr/bin/env python3
"""Validate required Supabase Edge Function secrets without exposing values (#2669).

Reads the canonical `supabase/required_secrets.json` manifest, cross-checks
`Deno.env.get(...)` and `envKey: "..."` references across `supabase/functions/`,
evaluates secret presence via safe boolean `HAS_<KEY>` flags or explicit key-name
lists (never printing secret values), and emits structured logs/annotations and
optional SSRF-pinned HTTPS alert payloads when credentials are missing.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import http.client
import ipaddress
import json
import os
from pathlib import Path
import re
import socket
import ssl
import sys
from typing import Mapping
import urllib.parse


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = Path("supabase/required_secrets.json")
DEFAULT_FUNCTIONS_DIR = Path("supabase/functions")

_DENO_ENV_RE = re.compile(r"""Deno\.env\.get\(\s*(['"])([A-Z][A-Z0-9_]+)\1""")
_ENVKEY_PROP_RE = re.compile(r"""envKey\s*:\s*(['"])([A-Z][A-Z0-9_]+)\1""")
_CREDENTIAL_NAME_RE = re.compile(
    r"(?:_KEY|_TOKEN|_SECRET|_PASSWORD|_PAT|WEBHOOK_URL|^SUPABASE_URL$|^SERVICE_ROLE_KEY$)$"
)
_CGNAT_NET = ipaddress.ip_network("100.64.0.0/10")

_TRUTHY_FLAGS = frozenset({"1", "true", "yes", "present", "set"})
_FALSY_FLAGS = frozenset({"", "0", "false", "no", "missing", "unset"})


@dataclass(frozen=True)
class SecretSpec:
    name: str
    requirement: str
    category: str
    tier: str
    description: str


@dataclass(frozen=True)
class SecretStatus:
    name: str
    requirement: str
    category: str
    tier: str
    present: bool
    source_count: int
    sample_sources: list[str]
    description: str


def load_manifest(manifest_path: Path) -> list[SecretSpec]:
    if not manifest_path.exists():
        raise FileNotFoundError(f"Manifest not found: {manifest_path}")
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise ValueError("Manifest must be a JSON object with schema_version == 1")
    raw_items = payload.get("secrets")
    if not isinstance(raw_items, list) or not raw_items:
        raise ValueError("Manifest must declare a non-empty 'secrets' array")

    specs: list[SecretSpec] = []
    seen: set[str] = set()
    for item in raw_items:
        if not isinstance(item, dict):
            raise ValueError("Each manifest entry must be a JSON object")
        name = str(item.get("name", "")).strip()
        if not re.fullmatch(r"[A-Z][A-Z0-9_]+", name):
            raise ValueError(f"Invalid secret identifier in manifest: {name!r}")
        if name in seen:
            raise ValueError(f"Duplicate secret identifier in manifest: {name}")
        seen.add(name)
        requirement = str(item.get("requirement", "required")).strip().lower()
        if requirement not in ("required", "recommended"):
            raise ValueError(
                f"Invalid requirement {requirement!r} for {name}; expected required/recommended"
            )
        specs.append(
            SecretSpec(
                name=name,
                requirement=requirement,
                category=str(item.get("category", "general")).strip() or "general",
                tier=str(item.get("tier", "core")).strip() or "core",
                description=str(item.get("description", "")).strip(),
            )
        )
    return specs


def scan_edge_function_secret_refs(functions_dir: Path, *, root: Path) -> dict[str, list[str]]:
    refs: dict[str, set[str]] = {}
    if not functions_dir.exists():
        return {}

    for ts_file in sorted(functions_dir.rglob("*.ts")):
        if ts_file.name.endswith("_test.ts") or ts_file.name.endswith(".test.ts"):
            continue
        try:
            rel = ts_file.relative_to(root).as_posix()
        except ValueError:
            rel = ts_file.as_posix()
        text = ts_file.read_text(encoding="utf-8", errors="ignore")
        for match in _DENO_ENV_RE.finditer(text):
            refs.setdefault(match.group(2), set()).add(rel)
        for match in _ENVKEY_PROP_RE.finditer(text):
            refs.setdefault(match.group(2), set()).add(rel)

    return {key: sorted(paths) for key, paths in sorted(refs.items())}


def parse_present_keys_file(path: Path) -> set[str]:
    raw = path.read_text(encoding="utf-8-sig").strip()
    if not raw:
        return set()
    if raw.startswith("[") or raw.startswith("{"):
        parsed = json.loads(raw)
        if isinstance(parsed, list):
            keys: set[str] = set()
            for item in parsed:
                if isinstance(item, str) and item.strip():
                    keys.add(item.strip())
                elif isinstance(item, dict) and str(item.get("name", "")).strip():
                    # Matches `supabase secrets list --output json` objects; ignores digest.
                    keys.add(str(item["name"]).strip())
            return keys
        if isinstance(parsed, dict) and isinstance(parsed.get("secrets"), list):
            return {
                str(item).strip()
                for item in parsed["secrets"]
                if str(item).strip()
            }
        raise ValueError("Unsupported JSON layout in keys file")

    keys = set()
    for line in raw.splitlines():
        cleaned = line.strip()
        if not cleaned or cleaned.startswith("#"):
            continue
        if "=" in cleaned:
            key_name, val = cleaned.split("=", 1)
            if val.strip():
                keys.add(key_name.strip())
        else:
            keys.add(cleaned.split()[0].strip())
    return keys


def secret_present(
    name: str,
    env: Mapping[str, str],
    present_key_names: set[str] | None = None,
) -> bool:
    for flag_name in (f"HAS_{name}", f"SUPABASE_SECRET_HAS_{name}"):
        if flag_name in env:
            value = env[flag_name].strip().lower()
            if value in _TRUTHY_FLAGS:
                return True
            if value in _FALSY_FLAGS:
                return False

    if present_key_names is not None and name in present_key_names:
        return True

    return bool(env.get(name, "").strip())


def _is_blocked_ip(ip_str: str) -> bool:
    ip_obj = ipaddress.ip_address(ip_str)
    while isinstance(ip_obj, ipaddress.IPv6Address) and ip_obj.ipv4_mapped is not None:
        ip_obj = ip_obj.ipv4_mapped
    return (
        not ip_obj.is_global
        or ip_obj.is_private
        or ip_obj.is_loopback
        or ip_obj.is_link_local
        or ip_obj.is_multicast
        or ip_obj.is_reserved
        or ip_obj.is_unspecified
        or (isinstance(ip_obj, ipaddress.IPv4Address) and ip_obj in _CGNAT_NET)
    )


def _sanitize_url_for_log(raw_url: str) -> str:
    parsed = urllib.parse.urlsplit(raw_url)
    host = parsed.hostname or "unknown"
    port = f":{parsed.port}" if parsed.port else ""
    return f"{parsed.scheme}://{host}{port}{parsed.path}"


def validate_and_resolve_https_url(url: str) -> tuple[urllib.parse.SplitResult, str]:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname:
        raise ValueError("Only explicit https URLs with a valid hostname are allowed")
    port = parsed.port or 443
    infos = socket.getaddrinfo(parsed.hostname, port, type=socket.SOCK_STREAM)
    pinned_ip = ""
    for info in infos:
        addr = info[4][0]
        if _is_blocked_ip(addr):
            raise ValueError(
                f"Blocked outbound HTTPS target resolving to non-global address: {_sanitize_url_for_log(url)}"
            )
        if not pinned_ip:
            pinned_ip = addr
    if not pinned_ip:
        raise ValueError(f"Could not resolve global IP for {_sanitize_url_for_log(url)}")
    return parsed, pinned_ip


class _PinnedHTTPSConnection(http.client.HTTPSConnection):
    """HTTPSConnection connecting to a pinned public IP while verifying TLS SNI/Host."""

    def __init__(
        self,
        *,
        connect_ip: str,
        server_hostname: str,
        port: int,
        timeout: int,
        context: ssl.SSLContext,
    ) -> None:
        super().__init__(
            host=server_hostname,
            port=port,
            timeout=timeout,
            context=context,
        )
        self._connect_ip = connect_ip

    def connect(self) -> None:
        sock = socket.create_connection(
            (self._connect_ip, self.port),
            self.timeout,
            self.source_address,
        )
        if self._tunnel_host:
            self.sock = sock
            self._tunnel()
        self.sock = self._context.wrap_socket(sock, server_hostname=self.host)


def post_json_pinned_https(
    url: str,
    payload: dict[str, object],
    *,
    timeout: int = 10,
) -> dict[str, object]:
    parsed, pinned_ip = validate_and_resolve_https_url(url)
    hostname = parsed.hostname or ""
    port = parsed.port or 443
    path = parsed.path or "/"
    if parsed.query:
        path = f"{path}?{parsed.query}"

    ctx = ssl.create_default_context()
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.verify_mode = ssl.CERT_REQUIRED
    ctx.check_hostname = True

    req_headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Host": hostname if port == 443 else f"{hostname}:{port}",
    }
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    conn = _PinnedHTTPSConnection(
        connect_ip=pinned_ip,
        server_hostname=hostname,
        port=port,
        timeout=timeout,
        context=ctx,
    )
    try:
        conn.request("POST", path, body=body, headers=req_headers)
        resp = conn.getresponse()
        raw_resp = resp.read().decode("utf-8", errors="replace")
        if 300 <= resp.status < 400:
            raise RuntimeError(
                f"Redirect blocked ({resp.status}) for {_sanitize_url_for_log(url)}"
            )
        if resp.status < 200 or resp.status >= 300:
            raise RuntimeError(
                f"HTTPS POST failed ({resp.status}) for {_sanitize_url_for_log(url)}"
            )
        if not raw_resp.strip():
            return {}
        loaded = json.loads(raw_resp)
        return loaded if isinstance(loaded, dict) else {"data": loaded}
    finally:
        conn.close()


def evaluate(
    *,
    root: Path,
    manifest_path: Path,
    functions_dir: Path,
    strict_mode: bool,
    strict_recommended: bool = False,
    env: Mapping[str, str],
    present_key_names: set[str] | None = None,
) -> dict[str, object]:
    specs = load_manifest(manifest_path)
    code_refs = scan_edge_function_secret_refs(functions_dir, root=root)

    statuses: list[SecretStatus] = []
    missing_required: list[str] = []
    missing_recommended: list[str] = []
    manifest_names = {spec.name for spec in specs}
    unreferenced_manifest_keys: list[str] = []

    for spec in specs:
        sources = code_refs.get(spec.name, [])
        if not sources:
            unreferenced_manifest_keys.append(spec.name)
        present = secret_present(spec.name, env, present_key_names)
        statuses.append(
            SecretStatus(
                name=spec.name,
                requirement=spec.requirement,
                category=spec.category,
                tier=spec.tier,
                present=present,
                source_count=len(sources),
                sample_sources=sources[:3],
                description=spec.description,
            )
        )
        if not present:
            if spec.requirement == "required":
                missing_required.append(spec.name)
            else:
                missing_recommended.append(spec.name)

    uncatalogued_credential_refs = [
        key
        for key in sorted(code_refs)
        if key not in manifest_names and _CREDENTIAL_NAME_RE.search(key)
    ]

    should_fail = (strict_mode and bool(missing_required)) or (
        strict_recommended and bool(missing_recommended)
    )
    should_warn = bool(missing_required) or bool(missing_recommended)
    status = "fail" if should_fail else ("warn" if should_warn else "pass")

    missing_by_tier: dict[str, list[str]] = {}
    for entry in statuses:
        if not entry.present:
            missing_by_tier.setdefault(entry.tier, []).append(entry.name)

    remediation_hints = [
        f"Configure {name} via Supabase Dashboard -> Edge Functions -> Secrets"
        for name in missing_required
    ]
    alert_payload: dict[str, object] = {
        "event": "supabase_secrets_validation",
        "issue": 2669,
        "status": status,
        "strict_mode": strict_mode,
        "missing_required": missing_required,
        "missing_recommended_count": len(missing_recommended),
        "missing_by_tier": missing_by_tier,
        "message": (
            f"Supabase required secrets missing ({len(missing_required)}): {', '.join(missing_required)}"
            if missing_required
            else "All required Supabase secrets configured."
        ),
        "remediation_hints": remediation_hints,
    }

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "status": status,
        "strict_mode": strict_mode,
        "strict_recommended": strict_recommended,
        "total_manifest_items": len(statuses),
        "present_count": sum(1 for s in statuses if s.present),
        "missing_required": missing_required,
        "missing_recommended": missing_recommended,
        "missing_by_tier": missing_by_tier,
        "edge_function_referenced_keys": len(code_refs),
        "unreferenced_manifest_keys": unreferenced_manifest_keys,
        "uncatalogued_credential_refs": uncatalogued_credential_refs,
        "entries": [asdict(item) for item in statuses],
        "alert_payload": alert_payload,
    }


def render_markdown(report: dict[str, object]) -> str:
    missing_req = report["missing_required"]
    missing_rec = report["missing_recommended"]
    assert isinstance(missing_req, list)
    assert isinstance(missing_rec, list)
    lines = [
        "### Supabase Secrets Validation Report (#2669)",
        f"- Status: `{report['status']}`",
        f"- Fail-Closed Mode: `{report['strict_mode']}`",
        f"- Manifest Keys Checked: `{report['total_manifest_items']}` (Present: `{report['present_count']}`)",
        f"- Missing Required (`{len(missing_req)}`): `{', '.join(missing_req) if missing_req else 'none'}`",
        f"- Missing Recommended (`{len(missing_rec)}`): `{', '.join(missing_rec) if missing_rec else 'none'}`",
        f"- Unreferenced Manifest Keys: `{report['unreferenced_manifest_keys']}`",
        "",
    ]
    return "\n".join(lines)


def emit_annotations(report: dict[str, object]) -> None:
    missing_req = report["missing_required"]
    missing_rec = report["missing_recommended"]
    assert isinstance(missing_req, list)
    assert isinstance(missing_rec, list)
    if missing_req:
        level = "error" if report["status"] == "fail" else "warning"
        print(
            f"::{level}::Supabase required secrets missing ({len(missing_req)}): {', '.join(missing_req)}",
            file=sys.stderr,
        )
    if missing_rec:
        print(
            f"::warning::Supabase recommended secrets missing ({len(missing_rec)}): {', '.join(missing_rec)}",
            file=sys.stderr,
        )


def write_github_outputs(path: Path, report: dict[str, object]) -> None:
    missing_req = report["missing_required"]
    missing_rec = report["missing_recommended"]
    assert isinstance(missing_req, list)
    assert isinstance(missing_rec, list)
    lines = [
        f"status={report['status']}",
        f"total_manifest_items={report['total_manifest_items']}",
        f"present_count={report['present_count']}",
        f"missing_required_count={len(missing_req)}",
        f"missing_recommended_count={len(missing_rec)}",
        f"missing_required={','.join(missing_req)}",
    ]
    with path.open("a", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


def run_self_test() -> dict[str, object]:
    manifest_path = ROOT / DEFAULT_MANIFEST
    functions_dir = ROOT / DEFAULT_FUNCTIONS_DIR
    specs = load_manifest(manifest_path)
    spec_names = {s.name for s in specs}
    for critical_key in (
        "DEEPINFRA_API_KEY",
        "GROQ_API_KEY",
        "GEMINI_API_KEY",
        "OPENAI_API_KEY",
        "ANTHROPIC_API_KEY",
        "SUPABASE_SERVICE_ROLE_KEY",
    ):
        if critical_key not in spec_names:
            raise AssertionError(f"Missing critical key {critical_key} in {manifest_path}")

    strict_missing = evaluate(
        root=ROOT,
        manifest_path=manifest_path,
        functions_dir=functions_dir,
        strict_mode=True,
        env={},
        present_key_names=set(),
    )
    if strict_missing["status"] != "fail" or "DEEPINFRA_API_KEY" not in strict_missing["missing_required"]:  # type: ignore[operator]
        raise AssertionError("Self-test strict missing check failed")

    all_present = evaluate(
        root=ROOT,
        manifest_path=manifest_path,
        functions_dir=functions_dir,
        strict_mode=True,
        env={},
        present_key_names=spec_names,
    )
    if all_present["status"] != "pass":
        raise AssertionError("Self-test full present check failed")

    return {
        "self_test": "passed",
        "manifest_items": len(specs),
        "edge_function_refs": strict_missing["edge_function_referenced_keys"],
        "strict_missing_status": strict_missing["status"],
        "all_present_status": all_present["status"],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--manifest", type=Path, default=None)
    parser.add_argument("--functions-dir", type=Path, default=None)
    parser.add_argument(
        "--env-keys-file",
        "--supabase-secrets-json",
        dest="keys_file",
        type=Path,
        default=None,
        help="Optional path to newline key list or `supabase secrets list --output json` file (reads key names only).",
    )
    parser.add_argument(
        "--require-secrets",
        dest="strict_mode",
        action="store_true",
    )
    parser.add_argument(
        "--require-recommended",
        dest="strict_recommended",
        action="store_true",
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--webhook-url", default="")
    parser.add_argument("--json-out", "--report", dest="json_out", type=Path, default=None)
    parser.add_argument("--markdown-out", type=Path, default=None)
    parser.add_argument("--github-output", type=Path, default=None)
    parser.add_argument("--self-test", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.self_test:
        result = run_self_test()
        print(json.dumps(result, ensure_ascii=False))
        return 0

    root = args.root.resolve()
    manifest_path = (args.manifest or (root / DEFAULT_MANIFEST)).resolve()
    functions_dir = (args.functions_dir or (root / DEFAULT_FUNCTIONS_DIR)).resolve()
    present_key_names = parse_present_keys_file(args.keys_file) if args.keys_file else None

    report = evaluate(
        root=root,
        manifest_path=manifest_path,
        functions_dir=functions_dir,
        strict_mode=args.strict_mode,
        strict_recommended=args.strict_recommended,
        env=dict(os.environ),
        present_key_names=present_key_names,
    )

    emit_annotations(report)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    if args.markdown_out:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(render_markdown(report), encoding="utf-8")
    if args.github_output:
        write_github_outputs(args.github_output, report)

    mode = "live" if args.live and not args.dry_run else "dry-run"
    if (
        mode == "live"
        and args.webhook_url.strip()
        and (report["missing_required"] or report["missing_recommended"])
    ):
        payload = report["alert_payload"]
        assert isinstance(payload, dict)
        post_json_pinned_https(args.webhook_url.strip(), payload)

    print(render_markdown(report))
    return 1 if report["status"] == "fail" else 0


if __name__ == "__main__":
    raise SystemExit(main())
