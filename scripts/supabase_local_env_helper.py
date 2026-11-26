#!/usr/bin/env python3
"""Preflight & dry-run helper for local Supabase emulator workflow (#2803)."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import sys
import tomllib
from typing import Any

REQUIRED_ENV_KEYS: tuple[str, ...] = (
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
)

PLACEHOLDER_PREFIXES: tuple[str, ...] = (
    "your_",
    "<",
    "replace_",
    "changeme",
)


@dataclass(frozen=True)
class ConfigCheckResult:
    valid: bool
    project_id: str
    api_port: int | None
    db_port: int | None
    db_major_version: int | None
    studio_port: int | None
    errors: list[str]


@dataclass(frozen=True)
class EnvCheckResult:
    valid: bool
    present_keys: list[str]
    missing_keys: list[str]
    placeholder_keys: list[str]
    non_local_url: bool
    errors: list[str]


def validate_supabase_config(config_path: Path) -> ConfigCheckResult:
    """Validate supabase/config.toml readiness for local emulator startup."""
    if not config_path.is_file():
        return ConfigCheckResult(
            valid=False,
            project_id="",
            api_port=None,
            db_port=None,
            db_major_version=None,
            studio_port=None,
            errors=[f"Missing config file: {config_path}"],
        )

    data = tomllib.loads(config_path.read_text(encoding="utf-8"))
    errors: list[str] = []

    project_id = str(data.get("project_id", "")).strip()
    if not project_id:
        errors.append("Missing top-level project_id in supabase/config.toml.")

    api = data.get("api", {})
    db = data.get("db", {})
    studio = data.get("studio", {})

    api_port = api.get("port") if isinstance(api, dict) else None
    db_port = db.get("port") if isinstance(db, dict) else None
    db_major = db.get("major_version") if isinstance(db, dict) else None
    studio_port = studio.get("port") if isinstance(studio, dict) else None

    if not isinstance(api_port, int):
        errors.append("Missing integer [api].port in supabase/config.toml.")
    if not isinstance(db_port, int):
        errors.append("Missing integer [db].port in supabase/config.toml.")
    if not isinstance(db_major, int):
        errors.append("Missing integer [db].major_version.")

    return ConfigCheckResult(
        valid=len(errors) == 0,
        project_id=project_id,
        api_port=api_port if isinstance(api_port, int) else None,
        db_port=db_port if isinstance(db_port, int) else None,
        db_major_version=db_major if isinstance(db_major, int) else None,
        studio_port=studio_port if isinstance(studio_port, int) else None,
        errors=errors,
    )


def parse_env_lines(raw_text: str) -> dict[str, str]:
    """Parse KEY=VALUE lines from a .env file, ignoring comments."""
    parsed: dict[str, str] = {}
    for raw_line in raw_text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        clean_key = key.strip()
        clean_val = val.strip().strip('"').strip("'")
        if clean_key:
            parsed[clean_key] = clean_val
    return parsed


def _is_local_url(url: str) -> bool:
    lowered = url.lower()
    return (
        lowered.startswith("http://127.0.0.1:")
        or lowered.startswith("http://localhost:")
    )


def validate_env_file(
    env_path: Path,
    required_keys: tuple[str, ...] = REQUIRED_ENV_KEYS,
    require_local: bool = True,
) -> EnvCheckResult:
    """Validate required keys and local-emulator URL safety in an env file."""
    if not env_path.is_file():
        return EnvCheckResult(
            valid=False,
            present_keys=[],
            missing_keys=list(required_keys),
            placeholder_keys=[],
            non_local_url=False,
            errors=[f"Missing env file: {env_path}"],
        )

    values = parse_env_lines(env_path.read_text(encoding="utf-8"))
    missing: list[str] = []
    placeholders: list[str] = []
    errors: list[str] = []

    for key in required_keys:
        if key not in values or not values[key]:
            missing.append(key)
            continue
        val_lower = values[key].lower()
        if any(val_lower.startswith(prefix) for prefix in PLACEHOLDER_PREFIXES):
            placeholders.append(key)

    if missing:
        errors.append(f"Missing required keys: {', '.join(missing)}")
    if placeholders:
        errors.append(
            f"Placeholder values detected for: {', '.join(placeholders)}"
        )

    url_val = values.get("SUPABASE_URL", "")
    non_local_url = bool(require_local and url_val and not _is_local_url(url_val))
    if non_local_url:
        errors.append(
            "SUPABASE_URL must point to 127.0.0.1 or localhost when "
            "require_local=True."
        )

    return EnvCheckResult(
        valid=len(errors) == 0,
        present_keys=sorted(values.keys()),
        missing_keys=missing,
        placeholder_keys=placeholders,
        non_local_url=non_local_url,
        errors=errors,
    )


def build_local_workflow_plan(
    env_file: str = ".env.local",
    include_functions: bool = True,
) -> list[dict[str, str]]:
    """Return ordered dry-run commands for local Supabase + Flutter startup."""
    plan: list[dict[str, str]] = [
        {
            "step": "verify_docker",
            "command": "docker info",
            "purpose": "Confirm Docker Desktop daemon is running.",
        },
        {
            "step": "start_supabase",
            "command": "supabase start",
            "purpose": "Start local Postgres, Auth, Storage, Studio containers.",
        },
        {
            "step": "reset_and_seed_db",
            "command": "supabase db reset",
            "purpose": "Apply local migrations and seed.sql cleanly.",
        },
        {
            "step": "inspect_local_keys",
            "command": "supabase status",
            "purpose": "Read local API URL and anon key into .env.local.",
        },
    ]
    if include_functions:
        plan.append(
            {
                "step": "serve_edge_functions",
                "command": f"supabase functions serve --env-file {env_file}",
                "purpose": "Serve Edge Functions locally against emulator DB.",
            }
        )
    plan.append(
        {
            "step": "run_flutter_web",
            "command": (
                f"flutter run -d chrome --dart-define-from-file={env_file}"
            ),
            "purpose": "Launch Flutter Web connected to local Supabase.",
        }
    )
    return plan


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate local Supabase emulator setup and emit plan.",
    )
    parser.add_argument(
        "--repo-root",
        default=".",
        help="Repository root containing supabase/config.toml.",
    )
    parser.add_argument(
        "--env-file",
        default=".env.example",
        help="Relative or absolute path to env file to validate.",
    )
    parser.add_argument(
        "--require-local",
        action="store_true",
        help="Require SUPABASE_URL to target localhost or 127.0.0.1.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit structured JSON output.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv if argv is not None else sys.argv[1:])
    root = Path(args.repo_root).resolve()
    config_res = validate_supabase_config(root / "supabase" / "config.toml")
    env_candidate = Path(args.env_file)
    if not env_candidate.is_absolute():
        env_candidate = root / env_candidate
    env_res = validate_env_file(
        env_candidate,
        require_local=args.require_local,
    )
    plan = build_local_workflow_plan(env_file=args.env_file)

    payload: dict[str, Any] = {
        "config": asdict(config_res),
        "env": asdict(env_res),
        "plan": plan,
    }
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(f"config_valid={config_res.valid} env_valid={env_res.valid}")
        for item in plan:
            print(f"- {item['step']}: {item['command']}")
    return 0 if (config_res.valid and env_res.valid) else 1


if __name__ == "__main__":
    raise SystemExit(main())
