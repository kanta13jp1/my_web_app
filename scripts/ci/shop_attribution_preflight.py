"""Validate CI source identity and fixture-only settings before attribution tests.

No API calls, credentials, deployment, or DB connections. This guards the test
configuration; it is not a sandbox for malicious changes to the workflow itself.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from collections.abc import Mapping


SHA = re.compile(r"[0-9a-f]{40}")
BRANCH_PREFIX = "refs/heads/codex/hexciv-post-attribution-"
RUNTIME_SETTINGS = (
    "SUPABASE_URL", "SUPABASE_ANON_KEY", "SERVICE_ROLE_KEY",
    "SUPABASE_SERVICE_ROLE_KEY", "STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET",
    "DATABASE_URL", "SUPABASE_DB_URL",
)


def validate_context(
    env: Mapping[str, str], actual_sha: str, *, database: bool = False
) -> dict[str, str]:
    if env.get("GITHUB_ACTIONS") != "true":
        raise ValueError("This runner entry point is for GitHub Actions only")
    if not SHA.fullmatch(actual_sha) or actual_sha != env.get("GITHUB_SHA"):
        raise ValueError("Checked-out revision does not match the event SHA")
    event = env.get("GITHUB_EVENT_NAME", "")
    ref = env.get("GITHUB_REF", "")
    if event == "pull_request":
        if not re.fullmatch(r"refs/pull/[1-9][0-9]*/merge", ref):
            raise ValueError("PR validation must check the merge ref, not a head fallback")
    elif event in {"push", "workflow_dispatch"}:
        if not ref.startswith(BRANCH_PREFIX) or ref == BRANCH_PREFIX:
            raise ValueError("Use a scoped attribution verification branch")
        if event == "workflow_dispatch":
            expected = env.get("EXPECTED_HEAD_SHA", "")
            if not SHA.fullmatch(expected) or expected != actual_sha:
                raise ValueError("Manual handoff SHA is missing, invalid or stale")
    else:
        raise ValueError("Unsupported event for fixture-only validation")
    if any(env.get(name) for name in RUNTIME_SETTINGS):
        # Never include actual values, even in an error message or CI artifact.
        raise ValueError("Runtime service/DB settings must not enter this fixture job")
    if database:
        required = {
            "PGHOST": "127.0.0.1", "PGPORT": "5432", "PGUSER": "postgres",
            "PGDATABASE": "hexciv_attribution_ci",
            "PGPASSWORD": "ephemeral-attribution-only",
        }
        if any(env.get(name) != value for name, value in required.items()):
            raise ValueError("Only the loopback disposable PostgreSQL fixture is allowed")
        if any(env.get(name) for name in ("PGSERVICE", "PGSERVICEFILE", "PGOPTIONS")):
            raise ValueError("PostgreSQL service/options overrides are not allowed")
    return {
        "schema": "shop-attribution-ci-source/v1",
        "event": event,
        "checked_sha": actual_sha,
        "scope": "disposable-sql-fixture" if database else "synthetic-tests",
        "production_validation": "not-performed",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", action="store_true")
    args = parser.parse_args()
    actual_sha = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], text=True
    ).strip()
    try:
        result = validate_context(os.environ, actual_sha, database=args.database)
    except ValueError as error:
        print(str(error))
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
