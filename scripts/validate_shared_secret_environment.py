#!/usr/bin/env python3
"""Validate one GitHub Environment's migrated credentials without mutating data."""

from __future__ import annotations

import argparse
import os
import sys
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from urllib.parse import urlparse
from urllib.request import Request, urlopen


@dataclass(frozen=True)
class ValidationResult:
    environment: str
    anthropic_present: bool
    supabase_status: int | None
    public_read_statuses: tuple[int, ...]


def validate_environment(
    *,
    environment: str,
    expect_anthropic: bool,
    expect_supabase: bool,
    expect_public_reads: bool = False,
    environ: Mapping[str, str] = os.environ,
    opener: Callable[..., object] = urlopen,
) -> ValidationResult:
    """Fail closed when a required secret is absent or Supabase auth is rejected."""

    anthropic_key = environ.get("ANTHROPIC_API_KEY", "")
    service_role_key = environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    anon_key = environ.get("SUPABASE_ANON_KEY", "")
    supabase_url = environ.get("SUPABASE_URL", "").rstrip("/")

    if expect_anthropic and not anthropic_key:
        raise ValueError(f"{environment}: ANTHROPIC_API_KEY did not resolve")
    if expect_supabase and not service_role_key:
        raise ValueError(f"{environment}: SUPABASE_SERVICE_ROLE_KEY did not resolve")
    if expect_public_reads and not anon_key:
        raise ValueError(f"{environment}: SUPABASE_ANON_KEY did not resolve")

    status: int | None = None
    if expect_supabase or expect_public_reads:
        parsed = urlparse(supabase_url)
        if parsed.scheme != "https" or not parsed.netloc:
            raise ValueError(f"{environment}: SUPABASE_URL must be an https URL")
    if expect_supabase:
        request = Request(
            f"{supabase_url}/rest/v1/",
            headers={
                "apikey": service_role_key,
                "Authorization": f"Bearer {service_role_key}",
                "Accept": "application/openapi+json, application/json",
                "User-Agent": "my-web-app-shared-secret-migration",
            },
        )
        with opener(request, timeout=20) as response:  # type: ignore[attr-defined]
            status = int(response.status)  # type: ignore[attr-defined]
            response.read(1)  # type: ignore[attr-defined]
        if status != 200:
            raise ValueError(
                f"{environment}: Supabase read-only credential canary returned HTTP {status}"
            )

    public_read_statuses: list[int] = []
    if expect_public_reads:
        public_paths = (
            "/rest/v1/competitors?select=id,display_name&is_active=eq.true&limit=1",
            "/rest/v1/ai_circuit_breaker?provider=eq.anthropic&select=state,expires_at",
        )
        for path in public_paths:
            request = Request(
                f"{supabase_url}{path}",
                headers={
                    "apikey": anon_key,
                    "Authorization": f"Bearer {anon_key}",
                    "Accept": "application/json",
                    "User-Agent": "my-web-app-shared-secret-migration",
                },
            )
            with opener(request, timeout=20) as response:  # type: ignore[attr-defined]
                public_status = int(response.status)  # type: ignore[attr-defined]
                response.read(1)  # type: ignore[attr-defined]
            if public_status != 200:
                raise ValueError(
                    f"{environment}: Supabase anon read canary returned HTTP {public_status}"
                )
            public_read_statuses.append(public_status)

    return ValidationResult(
        environment=environment,
        anthropic_present=bool(anthropic_key) if expect_anthropic else False,
        supabase_status=status,
        public_read_statuses=tuple(public_read_statuses),
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--environment", required=True)
    parser.add_argument("--expect-anthropic", action="store_true")
    parser.add_argument("--expect-supabase", action="store_true")
    parser.add_argument("--expect-public-reads", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if (
        not args.expect_anthropic
        and not args.expect_supabase
        and not args.expect_public_reads
    ):
        print("at least one credential expectation is required", file=sys.stderr)
        return 2
    try:
        result = validate_environment(
            environment=args.environment,
            expect_anthropic=args.expect_anthropic,
            expect_supabase=args.expect_supabase,
            expect_public_reads=args.expect_public_reads,
        )
    except (OSError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1

    checks: list[str] = []
    if args.expect_anthropic:
        checks.append("anthropic=present-no-provider-call")
    if result.supabase_status is not None:
        checks.append(f"supabase_read_only_http={result.supabase_status}")
    if result.public_read_statuses:
        checks.append(
            f"supabase_anon_read_canaries={len(result.public_read_statuses)}"
        )
    print(f"OK: {result.environment}: {', '.join(checks)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
