#!/usr/bin/env python3
"""Standardized local development environment check and .env.development generator (#2724).

Reads `.fvm/fvm_config.json`, `supabase/config.toml`, and
`config/local_supabase_env_template.json`, optionally consumes
`supabase status -o env` output, generates `.env.development` safely, and
validates client Supabase config via `validate_flutter_supabase_env.py` without
logging credential values.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Mapping

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from render_web_supabase_config import normalize_public_url
from validate_flutter_supabase_env import validate_publishable_key

try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:  # pragma: no cover - Python 3.10 fallback
    tomllib = None

ROOT = SCRIPTS_DIR.parent
DEFAULT_FVM_CONFIG = Path(".fvm/fvm_config.json")
DEFAULT_TEMPLATE = Path("config/local_supabase_env_template.json")
DEFAULT_SUPABASE_CONFIG = Path("supabase/config.toml")
DEFAULT_ENV_OUTPUT = Path(".env.development")
DEFAULT_README = Path("README.md")

_SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:[-+][A-Za-z0-9.-]+)?$")
_CLIENT_ENV_ORDER = (
    "ENVIRONMENT",
    "FLUTTER_TARGET_VERSION",
    "SUPABASE_URL",
    "SUPABASE_PUBLISHABLE_KEY",
    "SUPABASE_LOCAL_STUDIO_URL",
    "SUPABASE_LOCAL_INBUCKET_URL",
    "SUPABASE_LOCAL_DB_PORT",
    "SUPABASE_LOCAL_SHADOW_PORT",
    "PUBLIC_SITE_URL",
    "ENABLE_AI_FEATURES",
    "ENABLE_ANALYTICS",
    "DEBUG_MODE",
)


def load_flutter_target_version(repo_root: Path = ROOT) -> str:
    config_path = repo_root / DEFAULT_FVM_CONFIG
    if not config_path.exists():
        raise FileNotFoundError(f"Missing Flutter version pin: {config_path}")
    payload = json.loads(config_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{config_path} must be a JSON object.")
    version = str(payload.get("flutterSdkVersion", "")).strip()
    if not _SEMVER_RE.fullmatch(version):
        raise ValueError(
            f"Invalid flutterSdkVersion in {config_path}: {version!r}"
        )
    return version


def load_local_env_template(repo_root: Path = ROOT) -> dict[str, object]:
    template_path = repo_root / DEFAULT_TEMPLATE
    if not template_path.exists():
        raise FileNotFoundError(f"Missing local env template: {template_path}")
    payload = json.loads(template_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise ValueError(f"{template_path} must have schema_version == 1.")
    defaults = payload.get("defaults")
    if not isinstance(defaults, dict):
        raise ValueError(f"{template_path} must define a 'defaults' object.")
    return payload


def _parse_toml_ports_regex(text: str) -> dict[str, object]:
    result: dict[str, object] = {
        "project_id": "my_web_app",
        "api_port": 54321,
        "db_port": 54322,
        "shadow_port": 54320,
        "studio_port": 54323,
        "inbucket_port": 54324,
    }
    section = ""
    for raw_line in text.splitlines():
        stripped = raw_line.split("#", 1)[0].strip()
        if not stripped:
            continue
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1].strip()
            continue
        if "=" not in stripped:
            continue
        key, raw_val = stripped.split("=", 1)
        k = key.strip()
        v = raw_val.strip().strip('"').strip("'")
        if section == "" and k == "project_id" and v:
            result["project_id"] = v
        elif section == "api" and k == "port" and v.isdigit():
            result["api_port"] = int(v)
        elif section == "db" and k == "port" and v.isdigit():
            result["db_port"] = int(v)
        elif section == "db" and k == "shadow_port" and v.isdigit():
            result["shadow_port"] = int(v)
        elif section == "studio" and k == "port" and v.isdigit():
            result["studio_port"] = int(v)
        elif section == "inbucket" and k == "port" and v.isdigit():
            result["inbucket_port"] = int(v)
    return result


def parse_supabase_config_toml(repo_root: Path = ROOT) -> dict[str, object]:
    config_path = repo_root / DEFAULT_SUPABASE_CONFIG
    if not config_path.exists():
        raise FileNotFoundError(f"Missing Supabase config: {config_path}")
    text = config_path.read_text(encoding="utf-8")
    if tomllib is None:  # pragma: no cover
        return _parse_toml_ports_regex(text)
    parsed = tomllib.loads(text)
    api = parsed.get("api") if isinstance(parsed.get("api"), dict) else {}
    db = parsed.get("db") if isinstance(parsed.get("db"), dict) else {}
    studio = parsed.get("studio") if isinstance(parsed.get("studio"), dict) else {}
    inbucket = (
        parsed.get("inbucket") if isinstance(parsed.get("inbucket"), dict) else {}
    )
    return {
        "project_id": str(parsed.get("project_id") or "my_web_app"),
        "api_port": int(api.get("port", 54321)),
        "db_port": int(db.get("port", 54322)),
        "shadow_port": int(db.get("shadow_port", 54320)),
        "studio_port": int(studio.get("port", 54323)),
        "inbucket_port": int(inbucket.get("port", 54324)),
    }


def parse_env_lines(raw_text: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for raw_line in raw_text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].strip()
        if "=" not in line:
            continue
        key, raw_val = line.split("=", 1)
        k = key.strip()
        v = raw_val.strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in {'"', "'"}:
            v = v[1:-1]
        if k:
            parsed[k] = v
    return parsed


def build_local_env_entries(
    repo_root: Path = ROOT,
    *,
    status_env: Mapping[str, str] | None = None,
) -> dict[str, str]:
    """Assemble client-safe local env defaults without copying server secrets."""
    flutter_version = load_flutter_target_version(repo_root)
    template = load_local_env_template(repo_root)
    ports = parse_supabase_config_toml(repo_root)

    defaults = template["defaults"]
    assert isinstance(defaults, dict)
    entries: dict[str, str] = {
        str(k): str(v) for k, v in defaults.items()
    }
    entries["FLUTTER_TARGET_VERSION"] = flutter_version
    entries["SUPABASE_URL"] = f"http://127.0.0.1:{ports['api_port']}"
    entries["SUPABASE_LOCAL_STUDIO_URL"] = (
        f"http://127.0.0.1:{ports['studio_port']}"
    )
    entries["SUPABASE_LOCAL_INBUCKET_URL"] = (
        f"http://127.0.0.1:{ports['inbucket_port']}"
    )
    entries["SUPABASE_LOCAL_DB_PORT"] = str(ports["db_port"])
    entries["SUPABASE_LOCAL_SHADOW_PORT"] = str(ports["shadow_port"])

    if status_env:
        api_url = status_env.get("API_URL", "").strip()
        if api_url:
            entries["SUPABASE_URL"] = api_url
        studio_url = status_env.get("STUDIO_URL", "").strip()
        if studio_url:
            entries["SUPABASE_LOCAL_STUDIO_URL"] = studio_url
        inbucket_url = status_env.get("INBUCKET_URL", "").strip()
        if inbucket_url:
            entries["SUPABASE_LOCAL_INBUCKET_URL"] = inbucket_url
        # Map only browser-safe publishable/anon credentials; never copy server keys.
        client_key = (
            status_env.get("PUBLISHABLE_KEY", "").strip()
            or status_env.get("ANON_KEY", "").strip()
        )
        if client_key:
            validate_publishable_key(client_key)
            entries["SUPABASE_PUBLISHABLE_KEY"] = client_key

    normalize_public_url(entries["SUPABASE_URL"])
    if entries.get("SUPABASE_PUBLISHABLE_KEY", "").strip():
        validate_publishable_key(entries["SUPABASE_PUBLISHABLE_KEY"])
    return entries


def format_env_content(entries: Mapping[str, str]) -> str:
    lines = [
        "# Generated by scripts/setup_local_dev.py (#2724)",
        "# Client-safe local development configuration for Flutter Web + Supabase CLI.",
        "",
    ]
    emitted: set[str] = set()
    for key in _CLIENT_ENV_ORDER:
        if key in entries:
            lines.append(f"{key}={entries[key]}")
            emitted.add(key)
    for key in sorted(entries):
        if key not in emitted:
            lines.append(f"{key}={entries[key]}")
    return "\n".join(lines) + "\n"


def write_env_file(
    target_path: Path,
    entries: Mapping[str, str],
    *,
    force: bool = False,
    dry_run: bool = False,
) -> bool:
    if target_path.exists() and not force:
        raise FileExistsError(
            f"{target_path} already exists; pass --force to overwrite."
        )
    content = format_env_content(entries)
    if dry_run:
        return False
    target_path.parent.mkdir(parents=True, exist_ok=True)
    target_path.write_text(content, encoding="utf-8", newline="\n")
    return True


def check_onboarding_baseline(repo_root: Path = ROOT) -> dict[str, object]:
    flutter_version = load_flutter_target_version(repo_root)
    template = load_local_env_template(repo_root)
    ports = parse_supabase_config_toml(repo_root)
    readme_path = repo_root / DEFAULT_README
    if not readme_path.exists():
        raise FileNotFoundError(f"Missing README.md at {readme_path}")
    readme_text = readme_path.read_text(encoding="utf-8")

    template_ver = str(template.get("target_flutter_version", "")).strip()
    if template_ver != flutter_version:
        raise ValueError(
            f"Template target_flutter_version ({template_ver}) != "
            f".fvm/fvm_config.json ({flutter_version})"
        )

    entries = build_local_env_entries(repo_root)
    required_markers = (
        ".fvm/fvm_config.json",
        "scripts/setup_local_dev.py",
        "supabase start",
    )
    missing_docs = [m for m in required_markers if m not in readme_text]
    if missing_docs:
        raise ValueError(
            f"README.md missing standardized onboarding commands: {missing_docs}"
        )

    return {
        "status": "ok",
        "flutter_target_version": flutter_version,
        "supabase_api_port": ports["api_port"],
        "supabase_studio_port": ports["studio_port"],
        "supabase_db_port": ports["db_port"],
        "local_supabase_url": entries["SUPABASE_URL"],
        "has_publishable_key": bool(entries.get("SUPABASE_PUBLISHABLE_KEY")),
    }


def _check_cli_versions(expected_flutter: str) -> dict[str, object]:
    expected_minor = ".".join(expected_flutter.split(".")[:2])
    report: dict[str, object] = {
        "expected_flutter_minor": expected_minor,
        "tools": {},
    }
    tools: dict[str, str] = {}
    for cmd_name, args in (
        ("flutter", ["flutter", "--version"]),
        ("supabase", ["supabase", "--version"]),
        ("deno", ["deno", "--version"]),
        ("python", [sys.executable, "--version"]),
    ):
        try:
            proc = subprocess.run(
                args, capture_output=True, text=True, timeout=10, check=False
            )
            first = (proc.stdout + proc.stderr).strip().splitlines()
            tools[cmd_name] = first[0] if first else "unknown"
        except OSError:
            tools[cmd_name] = "not-installed"
    report["tools"] = tools
    return report


def _run_self_test() -> dict[str, object]:
    baseline = check_onboarding_baseline(ROOT)
    simulated = build_local_env_entries(
        ROOT,
        status_env={
            "API_URL": "http://127.0.0.1:54321",
            "ANON_KEY": "sb_publishable_demo",
        },
    )
    return {
        "self_test": "passed",
        "baseline": baseline,
        "simulated_has_publishable_key": bool(
            simulated.get("SUPABASE_PUBLISHABLE_KEY")
        ),
        "simulated_url": simulated["SUPABASE_URL"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Standardize local Flutter + Supabase development setup (#2724)."
    )
    parser.add_argument("--repo-root", type=Path, default=ROOT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--check-tools", action="store_true")
    parser.add_argument("--write-env", action="store_true")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--status-file", type=Path, default=None)
    parser.add_argument("--status-stdin", action="store_true")
    parser.add_argument("--from-supabase", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        print(json.dumps(_run_self_test(), indent=2))
        return 0

    baseline = check_onboarding_baseline(args.repo_root)
    result: dict[str, object] = dict(baseline)

    if args.check_tools:
        result["cli_tools"] = _check_cli_versions(
            str(baseline["flutter_target_version"])
        )

    if args.write_env:
        status_env: dict[str, str] = {}
        if args.status_stdin:
            status_env = parse_env_lines(sys.stdin.read())
        elif args.status_file is not None:
            status_env = parse_env_lines(
                args.status_file.read_text(encoding="utf-8")
            )
        elif args.from_supabase:
            proc = subprocess.run(
                ["supabase", "status", "-o", "env"],
                cwd=args.repo_root,
                capture_output=True,
                text=True,
                timeout=30,
                check=True,
            )
            status_env = parse_env_lines(proc.stdout)

        entries = build_local_env_entries(
            args.repo_root,
            status_env=status_env or None,
        )
        out_path = args.output or (args.repo_root / DEFAULT_ENV_OUTPUT)
        wrote = write_env_file(
            out_path,
            entries,
            force=args.force,
            dry_run=args.dry_run,
        )
        result["env_written"] = wrote
        result["env_output_path"] = str(out_path)
        result["has_publishable_key"] = bool(
            entries.get("SUPABASE_PUBLISHABLE_KEY")
        )

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
