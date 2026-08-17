#!/usr/bin/env python3
"""Run a deterministic Testcontainers smoke for DB + Edge runtime work.

The smoke intentionally avoids production Supabase credentials. It starts a
disposable Postgres container, applies a small migration/seed fixture, verifies
the Issue #2773 fail-closed RLS migration and Issue #2484 asset-chat isolation,
checks the real Edge Function import policy, and runs a Deno HTTP fixture against
the container. Logs are written as artifacts so CI failures point to the
migration, function, or seed boundary that broke.
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlparse, urlunparse


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SQL_DIR = ROOT / "test" / "fixtures" / "testcontainers" / "sql"
DEFAULT_EDGE_FIXTURE = ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts"
DEFAULT_ARTIFACTS_DIR = ROOT / ".testcontainers-logs"
DEFAULT_ACTUAL_EDGE_FUNCTION = ROOT / "supabase" / "functions" / "health-check" / "index.ts"
REQUIRED_TABLES = ("profiles", "wbs_tasks", "ai_circuit_breaker")
ISSUE_2773_RLS_MIGRATION = (
    ROOT / "supabase" / "migrations" / "20260815124052_fail_closed_rls_issue_2773.sql"
)
ISSUE_2773_RLS_TABLES = (
    "ab_assignments",
    "ab_experiments",
    "ai_benchmark_results",
    "competitor_feature_status",
    "referral_tracking",
    "viral_ad_generations",
)
ISSUE_2773_USER_1 = "00000000-0000-4000-8000-000000002773"
ISSUE_2773_USER_2 = "00000000-0000-4000-8000-000000002774"
ISSUE_2773_EXPERIMENT_1 = "00000000-0000-4000-8000-000000002775"
ISSUE_2773_EXPERIMENT_2 = "00000000-0000-4000-8000-000000002776"
ASSET_CHAT_MIGRATION = (
    ROOT / "supabase" / "migrations" / "20260817151738_create_asset_chat_tables.sql"
)
ASSET_CHAT_TABLES = ("asset_chat_messages", "asset_chat_threads")
ASSET_CHAT_THREAD_1 = "00000000-0000-4000-8000-000000002484"
ASSET_CHAT_THREAD_2 = "00000000-0000-4000-8000-000000002485"
ASSET_CHAT_TEMP_THREAD = "00000000-0000-4000-8000-000000002486"
EDGE_FIXTURE_ENV_ALLOW = (
    "DATABASE_URL",
    "PORT",
    "PGAPPNAME",
    "PGDATABASE",
    "PGHOST",
    "PGOPTIONS",
    "PGPASSWORD",
    "PGPORT",
    "PGUSER",
)


@dataclass(frozen=True)
class CommandResult:
    command: list[str]
    returncode: int
    output: str


def redact_url(raw_url: str) -> str:
    parsed = urlparse(raw_url)
    if not parsed.password:
        return raw_url
    host = parsed.hostname or ""
    if parsed.port:
        host = f"{host}:{parsed.port}"
    userinfo = parsed.username or ""
    if userinfo:
        userinfo = f"{userinfo}:***@"
    return urlunparse(parsed._replace(netloc=f"{userinfo}{host}"))


def normalize_connection_url(raw_url: str) -> str:
    return raw_url.replace("postgresql+psycopg2://", "postgresql://", 1)


def sql_files(sql_dir: Path) -> list[Path]:
    if not sql_dir.exists():
        raise FileNotFoundError(f"SQL fixture directory not found: {sql_dir}")
    files = sorted(path for path in sql_dir.glob("*.sql") if path.is_file())
    if not files:
        raise FileNotFoundError(f"No SQL fixtures found in {sql_dir}")
    return files


def sql_statements(sql: str) -> list[str]:
    return [statement.strip() for statement in sql.split(";") if statement.strip()]


def free_tcp_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def write_json(path: Path, payload: dict[str, Any]) -> None:
    write_text(path, json.dumps(payload, indent=2, sort_keys=True) + "\n")


def run_command(
    command: list[str],
    *,
    artifacts_dir: Path,
    log_name: str,
    env: dict[str, str] | None = None,
    timeout_seconds: int = 120,
) -> CommandResult:
    proc = subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout_seconds,
        check=False,
    )
    result = CommandResult(command=command, returncode=proc.returncode, output=proc.stdout or "")
    log_lines = [
        f"$ {' '.join(command)}",
        f"exit={result.returncode}",
        "",
        result.output,
    ]
    write_text(artifacts_dir / log_name, "\n".join(log_lines))
    return result


def build_plan(sql_dir: Path, edge_fixture: Path, actual_edge_function: Path) -> dict[str, Any]:
    return {
        "container": "postgres:16-alpine via testcontainers-python",
        "production_credentials_required": False,
        "sql_fixtures": [path.relative_to(ROOT).as_posix() for path in sql_files(sql_dir)],
        "tenant_rls_migration": ISSUE_2773_RLS_MIGRATION.relative_to(ROOT).as_posix(),
        "tenant_rls_checks": [
            "all six audited public tables have RLS enabled",
            "anon keeps no table privileges",
            "authenticated privileges are policy-backed and least-privilege",
            "missing tenant claims see zero rows and cannot write",
            "authenticated users see only their own tenant rows",
        ],
        "asset_chat_migration": ASSET_CHAT_MIGRATION.relative_to(ROOT).as_posix(),
        "asset_chat_checks": [
            "threads and messages have owner-only RLS",
            "anon has no table privileges",
            "authenticated users cannot insert across tenants",
            "message ownership follows the parent thread",
            "deleting an owned thread cascades to its messages",
        ],
        "edge_db_fixture": edge_fixture.relative_to(ROOT).as_posix(),
        "actual_edge_checks": [
            "scripts/check_edge_function_imports.py --root supabase/functions",
            f"deno check --config supabase/functions/deno.json {actual_edge_function.relative_to(ROOT).as_posix()}",
            f"deno check {edge_fixture.relative_to(ROOT).as_posix()}",
        ],
        "artifacts": [
            ".testcontainers-logs/summary.json",
            ".testcontainers-logs/edge-imports.log",
            ".testcontainers-logs/deno-check-health-check.log",
            ".testcontainers-logs/deno-check-edge-db-smoke.log",
            ".testcontainers-logs/edge-db-smoke.log",
            ".testcontainers-logs/failure.json",
        ],
    }


def apply_sql_fixture(conn: Any, path: Path, artifacts_dir: Path) -> None:
    sql = path.read_text(encoding="utf-8")
    log_path = artifacts_dir / "sql-fixtures.log"
    with log_path.open("a", encoding="utf-8", newline="\n") as log:
        log.write(f"\n-- applying {path.relative_to(ROOT)}\n")
        with conn.cursor() as cur:
            for statement in sql_statements(sql):
                cur.execute(statement)
        conn.commit()
        log.write("ok\n")


def table_count(conn: Any, table_name: str) -> int:
    if table_name not in REQUIRED_TABLES:
        raise ValueError(f"unexpected table for smoke query: {table_name}")
    with conn.cursor() as cur:
        cur.execute(f"select count(*) from {table_name}")
        row = cur.fetchone()
    return int(row[0])


def seed_issue_2773_fixture(conn: Any) -> None:
    with conn.cursor() as cur:
        cur.executemany(
            "insert into auth.users (id) values (%s::uuid)",
            [(ISSUE_2773_USER_1,), (ISSUE_2773_USER_2,)],
        )
        cur.executemany(
            "insert into public.ab_experiments (id, name, status) "
            "values (%s::uuid, %s, 'active')",
            [
                (ISSUE_2773_EXPERIMENT_1, "tenant isolation one"),
                (ISSUE_2773_EXPERIMENT_2, "tenant isolation two"),
            ],
        )
        cur.executemany(
            "insert into public.ab_assignments "
            "(experiment_id, user_id, variant) values (%s::uuid, %s::uuid, %s)",
            [
                (ISSUE_2773_EXPERIMENT_1, ISSUE_2773_USER_1, "control"),
                (ISSUE_2773_EXPERIMENT_1, ISSUE_2773_USER_2, "variant_a"),
            ],
        )
        cur.executemany(
            "insert into public.ai_benchmark_results "
            "(user_id, model_name, provider, vision_score, latency_ms) "
            "values (%s::uuid, %s, 'fixture', 90, 100)",
            [
                (ISSUE_2773_USER_1, "tenant-model-one"),
                (ISSUE_2773_USER_2, "tenant-model-two"),
            ],
        )
        cur.execute(
            "insert into public.referral_tracking "
            "(referrer_user_id, referred_user_id, referral_code) values (%s, %s, %s)",
            (ISSUE_2773_USER_1, ISSUE_2773_USER_2, "ISSUE2773"),
        )
        cur.execute(
            "insert into public.competitor_feature_status "
            "(competitor_id, feature_name) values ('fixture', 'tenant isolation')"
        )
        cur.execute(
            "insert into public.viral_ad_generations (template_key) values ('fixture')"
        )
    conn.commit()


def issue_2773_role_count(
    conn: Any,
    role: str,
    user_id: str | None,
    table: str,
) -> int:
    if role not in {"anon", "authenticated", "service_role"}:
        raise ValueError(f"unexpected role for tenant RLS query: {role}")
    if table not in ISSUE_2773_RLS_TABLES:
        raise ValueError(f"unexpected table for tenant RLS query: {table}")
    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute(f"set local role {role}")
            cur.execute(
                "select set_config('request.jwt.claim.sub', %s, true)",
                (user_id or "",),
            )
            cur.execute(f"select count(*) from public.{table}")
            row = cur.fetchone()
    return int(row[0])


def issue_2773_expect_denied(
    conn: Any,
    *,
    role: str,
    user_id: str | None,
    statement: str,
    params: tuple[Any, ...] = (),
) -> str:
    try:
        with conn.transaction():
            with conn.cursor() as cur:
                cur.execute(f"set local role {role}")
                cur.execute(
                    "select set_config('request.jwt.claim.sub', %s, true)",
                    (user_id or "",),
                )
                cur.execute(statement, params)
    except Exception as exc:  # psycopg is loaded only for the integration run.
        sqlstate = getattr(exc, "sqlstate", None)
        if sqlstate != "42501":
            raise AssertionError(
                f"expected SQLSTATE 42501, got {sqlstate}: {exc}"
            ) from exc
        return sqlstate
    raise AssertionError("tenant RLS operation unexpectedly succeeded")


def check_issue_2773_rls(conn: Any) -> dict[str, Any]:
    with conn.cursor() as cur:
        cur.execute(
            "select c.relname from pg_class c "
            "join pg_namespace n on n.oid = c.relnamespace "
            "where n.nspname = 'public' and c.relname = any(%s) "
            "and c.relrowsecurity order by c.relname",
            (list(ISSUE_2773_RLS_TABLES),),
        )
        enabled_tables = [row[0] for row in cur.fetchall()]
        cur.execute(
            "select policyname from pg_policies where schemaname = 'public' "
            "and tablename = any(%s) order by policyname",
            (list(ISSUE_2773_RLS_TABLES),),
        )
        policy_names = [row[0] for row in cur.fetchall()]
    conn.commit()

    if enabled_tables != sorted(ISSUE_2773_RLS_TABLES):
        raise AssertionError(
            f"RLS was not enabled on every audited table: {enabled_tables}"
        )

    expected_policies = {
        "ab_assignments_delete_own",
        "ab_assignments_insert_own",
        "ab_assignments_select_own",
        "ab_assignments_update_own",
        "ab_experiments_authenticated_read",
        "ai_benchmark_results_select_own",
        "referral_tracking_select_participant",
    }
    if set(policy_names) != expected_policies:
        raise AssertionError(f"unexpected tenant RLS policy set: {policy_names}")

    authenticated_grants = {
        "ab_assignments": {"SELECT", "INSERT", "UPDATE", "DELETE"},
        "ab_experiments": {"SELECT"},
        "ai_benchmark_results": {"SELECT"},
        "competitor_feature_status": set(),
        "referral_tracking": {"SELECT"},
        "viral_ad_generations": set(),
    }
    table_privileges = (
        "SELECT",
        "INSERT",
        "UPDATE",
        "DELETE",
        "TRUNCATE",
        "REFERENCES",
        "TRIGGER",
    )
    with conn.cursor() as cur:
        for table in ISSUE_2773_RLS_TABLES:
            for privilege in table_privileges:
                cur.execute(
                    "select has_table_privilege(%s, %s, %s)",
                    ("anon", f"public.{table}", privilege),
                )
                if bool(cur.fetchone()[0]):
                    raise AssertionError(f"anon retained {privilege} on {table}")
                cur.execute(
                    "select has_table_privilege(%s, %s, %s)",
                    ("authenticated", f"public.{table}", privilege),
                )
                actual = bool(cur.fetchone()[0])
                expected = privilege in authenticated_grants[table]
                if actual != expected:
                    raise AssertionError(
                        f"authenticated {privilege} on {table}: "
                        f"expected {expected}, got {actual}"
                    )
    conn.commit()

    missing_claim_counts = {
        table: issue_2773_role_count(conn, "authenticated", None, table)
        for table in (
            "ab_assignments",
            "ab_experiments",
            "ai_benchmark_results",
            "referral_tracking",
        )
    }
    if any(missing_claim_counts.values()):
        raise AssertionError(f"missing tenant claim exposed rows: {missing_claim_counts}")

    owner_counts = {
        table: issue_2773_role_count(
            conn,
            "authenticated",
            ISSUE_2773_USER_1,
            table,
        )
        for table in (
            "ab_assignments",
            "ab_experiments",
            "ai_benchmark_results",
            "referral_tracking",
        )
    }
    expected_owner_counts = {
        "ab_assignments": 1,
        "ab_experiments": 2,
        "ai_benchmark_results": 1,
        "referral_tracking": 1,
    }
    if owner_counts != expected_owner_counts:
        raise AssertionError(
            f"tenant filtering returned unexpected counts: {owner_counts}"
        )

    missing_write_sqlstate = issue_2773_expect_denied(
        conn,
        role="authenticated",
        user_id=None,
        statement=(
            "insert into public.ab_assignments "
            "(experiment_id, user_id, variant) values (%s::uuid, %s::uuid, 'control')"
        ),
        params=(ISSUE_2773_EXPERIMENT_2, ISSUE_2773_USER_1),
    )
    cross_tenant_sqlstate = issue_2773_expect_denied(
        conn,
        role="authenticated",
        user_id=ISSUE_2773_USER_2,
        statement=(
            "insert into public.ab_assignments "
            "(experiment_id, user_id, variant) values (%s::uuid, %s::uuid, 'control')"
        ),
        params=(ISSUE_2773_EXPERIMENT_2, ISSUE_2773_USER_1),
    )

    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute("set local role authenticated")
            cur.execute(
                "select set_config('request.jwt.claim.sub', %s, true)",
                (ISSUE_2773_USER_1,),
            )
            cur.execute(
                "insert into public.ab_assignments "
                "(experiment_id, user_id, variant) values (%s::uuid, %s::uuid, 'control')",
                (ISSUE_2773_EXPERIMENT_2, ISSUE_2773_USER_1),
            )

    for table in ISSUE_2773_RLS_TABLES:
        issue_2773_expect_denied(
            conn,
            role="anon",
            user_id=None,
            statement=f"select count(*) from public.{table}",
        )

    return {
        "enabled_tables": enabled_tables,
        "policies": policy_names,
        "missing_claim_counts": missing_claim_counts,
        "owner_counts": owner_counts,
        "missing_write_sqlstate": missing_write_sqlstate,
        "cross_tenant_sqlstate": cross_tenant_sqlstate,
        "anon_access": "denied on all audited tables",
    }


def seed_asset_chat_fixture(conn: Any) -> None:
    with conn.cursor() as cur:
        cur.executemany(
            "insert into public.asset_chat_threads (id, user_id, title) "
            "values (%s::uuid, %s::uuid, %s)",
            [
                (ASSET_CHAT_THREAD_1, ISSUE_2773_USER_1, "owner one thread"),
                (ASSET_CHAT_THREAD_2, ISSUE_2773_USER_2, "owner two thread"),
            ],
        )
        cur.executemany(
            "insert into public.asset_chat_messages "
            "(thread_id, role, content, tokens_in, tokens_out, model) "
            "values (%s::uuid, %s, %s, %s, %s, %s)",
            [
                (ASSET_CHAT_THREAD_1, "user", "owner one message", 12, 0, None),
                (
                    ASSET_CHAT_THREAD_2,
                    "assistant",
                    "owner two response",
                    20,
                    8,
                    "fixture-model",
                ),
            ],
        )
    conn.commit()


def asset_chat_role_count(
    conn: Any,
    role: str,
    user_id: str | None,
    table: str,
) -> int:
    if role not in {"anon", "authenticated", "service_role"}:
        raise ValueError(f"unexpected role for asset chat query: {role}")
    if table not in ASSET_CHAT_TABLES:
        raise ValueError(f"unexpected table for asset chat query: {table}")
    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute(f"set local role {role}")
            cur.execute(
                "select set_config('request.jwt.claim.sub', %s, true)",
                (user_id or "",),
            )
            cur.execute(f"select count(*) from public.{table}")
            row = cur.fetchone()
    return int(row[0])


def check_asset_chat_rls(conn: Any) -> dict[str, Any]:
    with conn.cursor() as cur:
        cur.execute(
            "select c.relname from pg_class c "
            "join pg_namespace n on n.oid = c.relnamespace "
            "where n.nspname = 'public' and c.relname = any(%s) "
            "and c.relrowsecurity order by c.relname",
            (list(ASSET_CHAT_TABLES),),
        )
        enabled_tables = [row[0] for row in cur.fetchall()]
        cur.execute(
            "select policyname from pg_policies where schemaname = 'public' "
            "and tablename = any(%s) order by policyname",
            (list(ASSET_CHAT_TABLES),),
        )
        policy_names = [row[0] for row in cur.fetchall()]
    conn.commit()

    if enabled_tables != sorted(ASSET_CHAT_TABLES):
        raise AssertionError(
            f"asset chat RLS was not enabled on every table: {enabled_tables}"
        )

    expected_policies = {
        f"{table}_{operation}_own"
        for table in ASSET_CHAT_TABLES
        for operation in ("select", "insert", "update", "delete")
    }
    if set(policy_names) != expected_policies:
        raise AssertionError(f"unexpected asset chat policy set: {policy_names}")

    authenticated_grants = {"SELECT", "INSERT", "UPDATE", "DELETE"}
    table_privileges = (
        "SELECT",
        "INSERT",
        "UPDATE",
        "DELETE",
        "TRUNCATE",
        "REFERENCES",
        "TRIGGER",
    )
    with conn.cursor() as cur:
        for table in ASSET_CHAT_TABLES:
            for privilege in table_privileges:
                cur.execute(
                    "select has_table_privilege(%s, %s, %s)",
                    ("anon", f"public.{table}", privilege),
                )
                if bool(cur.fetchone()[0]):
                    raise AssertionError(
                        f"anon retained {privilege} on asset chat table {table}"
                    )
                cur.execute(
                    "select has_table_privilege(%s, %s, %s)",
                    ("authenticated", f"public.{table}", privilege),
                )
                actual = bool(cur.fetchone()[0])
                expected = privilege in authenticated_grants
                if actual != expected:
                    raise AssertionError(
                        f"authenticated {privilege} on {table}: "
                        f"expected {expected}, got {actual}"
                    )
    conn.commit()

    missing_claim_counts = {
        table: asset_chat_role_count(conn, "authenticated", None, table)
        for table in ASSET_CHAT_TABLES
    }
    if any(missing_claim_counts.values()):
        raise AssertionError(
            f"missing tenant claim exposed asset chat rows: {missing_claim_counts}"
        )

    owner_counts = {
        table: asset_chat_role_count(
            conn,
            "authenticated",
            ISSUE_2773_USER_1,
            table,
        )
        for table in ASSET_CHAT_TABLES
    }
    expected_owner_counts = {
        "asset_chat_messages": 1,
        "asset_chat_threads": 1,
    }
    if owner_counts != expected_owner_counts:
        raise AssertionError(f"asset chat tenant filtering failed: {owner_counts}")

    cross_thread_sqlstate = issue_2773_expect_denied(
        conn,
        role="authenticated",
        user_id=ISSUE_2773_USER_1,
        statement=(
            "insert into public.asset_chat_messages (thread_id, role, content) "
            "values (%s::uuid, 'user', 'cross-tenant write')"
        ),
        params=(ASSET_CHAT_THREAD_2,),
    )
    forged_owner_sqlstate = issue_2773_expect_denied(
        conn,
        role="authenticated",
        user_id=ISSUE_2773_USER_1,
        statement=(
            "insert into public.asset_chat_threads (user_id, title) "
            "values (%s::uuid, 'forged owner')"
        ),
        params=(ISSUE_2773_USER_2,),
    )

    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute("set local role authenticated")
            cur.execute(
                "select set_config('request.jwt.claim.sub', %s, true)",
                (ISSUE_2773_USER_1,),
            )
            cur.execute(
                "insert into public.asset_chat_threads (id, user_id, title) "
                "values (%s::uuid, %s::uuid, 'cascade smoke')",
                (ASSET_CHAT_TEMP_THREAD, ISSUE_2773_USER_1),
            )
            cur.execute(
                "insert into public.asset_chat_messages (thread_id, role, content) "
                "values (%s::uuid, 'user', 'delete with thread')",
                (ASSET_CHAT_TEMP_THREAD,),
            )
            cur.execute(
                "delete from public.asset_chat_threads where id = %s::uuid",
                (ASSET_CHAT_TEMP_THREAD,),
            )

    with conn.cursor() as cur:
        cur.execute(
            "select count(*) from public.asset_chat_messages "
            "where thread_id = %s::uuid",
            (ASSET_CHAT_TEMP_THREAD,),
        )
        cascade_remaining = int(cur.fetchone()[0])
    conn.commit()
    if cascade_remaining != 0:
        raise AssertionError("asset chat thread deletion left orphan messages")

    for table in ASSET_CHAT_TABLES:
        issue_2773_expect_denied(
            conn,
            role="anon",
            user_id=None,
            statement=f"select count(*) from public.{table}",
        )

    return {
        "enabled_tables": enabled_tables,
        "policies": policy_names,
        "missing_claim_counts": missing_claim_counts,
        "owner_counts": owner_counts,
        "cross_thread_sqlstate": cross_thread_sqlstate,
        "forged_owner_sqlstate": forged_owner_sqlstate,
        "cascade_remaining": cascade_remaining,
        "anon_access": "denied on both asset chat tables",
    }


def check_actual_edge_function(args: argparse.Namespace, artifacts_dir: Path) -> None:
    import_result = run_command(
        [sys.executable, "scripts/check_edge_function_imports.py", "--root", "supabase/functions"],
        artifacts_dir=artifacts_dir,
        log_name="edge-imports.log",
    )
    if import_result.returncode != 0:
        raise RuntimeError("Edge Function import guard failed; see edge-imports.log")

    deno_result = run_command(
        [
            "deno",
            "check",
            "--config",
            "supabase/functions/deno.json",
            str(args.actual_edge_function.relative_to(ROOT)),
        ],
        artifacts_dir=artifacts_dir,
        log_name="deno-check-health-check.log",
        timeout_seconds=180,
    )
    if deno_result.returncode != 0:
        raise RuntimeError("Deno check failed; see deno-check-health-check.log")


def check_edge_db_fixture(args: argparse.Namespace, artifacts_dir: Path) -> None:
    deno_result = run_command(
        [
            "deno",
            "check",
            str(args.edge_fixture.relative_to(ROOT)),
        ],
        artifacts_dir=artifacts_dir,
        log_name="deno-check-edge-db-smoke.log",
        timeout_seconds=180,
    )
    if deno_result.returncode != 0:
        raise RuntimeError("Deno fixture check failed; see deno-check-edge-db-smoke.log")


def log_tail(path: Path, max_chars: int = 4000) -> str:
    if not path.exists():
        return ""
    text = path.read_text(encoding="utf-8", errors="replace")
    return text[-max_chars:]


def wait_for_fixture(port: int, timeout_seconds: int) -> dict[str, Any]:
    deadline = time.monotonic() + timeout_seconds
    url = f"http://127.0.0.1:{port}/smoke?table=wbs_tasks"
    last_error: str | None = None
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=3) as response:
                body = response.read().decode("utf-8")
            return json.loads(body)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = str(exc)
            time.sleep(1)
    raise TimeoutError(f"edge DB fixture did not become healthy: {last_error}")


def run_edge_db_fixture(database_url: str, args: argparse.Namespace, artifacts_dir: Path) -> dict[str, Any]:
    port = free_tcp_port()
    env = os.environ.copy()
    env["DATABASE_URL"] = database_url
    env["PORT"] = str(port)
    env["PGAPPNAME"] = "testcontainers-smoke"
    log_path = artifacts_dir / "edge-db-smoke.log"
    deno_command = [
        "deno",
        "run",
        "--allow-net",
        f"--allow-env={','.join(EDGE_FIXTURE_ENV_ALLOW)}",
        str(args.edge_fixture),
    ]
    with log_path.open("w", encoding="utf-8", newline="\n") as log:
        log.write(f"$ {' '.join(deno_command)}\n")
        log.flush()
        proc = subprocess.Popen(
            deno_command,
            cwd=ROOT,
            env=env,
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )
        try:
            payload = wait_for_fixture(port, args.fixture_timeout_seconds)
            if payload.get("status") != "ok" or int(payload.get("count", 0)) < 1:
                raise RuntimeError(f"unexpected fixture response: {payload}")
            return {"port": port, "response": payload}
        except Exception as exc:
            log.flush()
            exit_code = proc.poll()
            tail = log_tail(log_path)
            if exit_code is not None:
                raise RuntimeError(
                    "edge DB fixture process exited "
                    f"with code {exit_code}; see edge-db-smoke.log\n{tail}"
                ) from exc
            raise RuntimeError(
                "edge DB fixture did not become healthy; see edge-db-smoke.log\n"
                f"{tail}"
            ) from exc
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)


def run_smoke(args: argparse.Namespace) -> int:
    artifacts_dir = args.artifacts_dir
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    write_json(artifacts_dir / "plan.json", build_plan(args.sql_dir, args.edge_fixture, args.actual_edge_function))

    try:
        from testcontainers.postgres import PostgresContainer
        import psycopg
    except ImportError as exc:
        raise RuntimeError(
            "Missing dependencies. Install: python -m pip install "
            "'testcontainers[postgres]>=4.8,<5' 'psycopg[binary]>=3.2,<4'"
        ) from exc

    check_actual_edge_function(args, artifacts_dir)
    check_edge_db_fixture(args, artifacts_dir)

    with PostgresContainer("postgres:16-alpine") as postgres:
        raw_url = postgres.get_connection_url()
        connection_url = normalize_connection_url(raw_url)
        with psycopg.connect(connection_url) as conn:
            for fixture in sql_files(args.sql_dir):
                apply_sql_fixture(conn, fixture, artifacts_dir)
            apply_sql_fixture(conn, ISSUE_2773_RLS_MIGRATION, artifacts_dir)
            seed_issue_2773_fixture(conn)
            tenant_rls = check_issue_2773_rls(conn)
            apply_sql_fixture(conn, ASSET_CHAT_MIGRATION, artifacts_dir)
            seed_asset_chat_fixture(conn)
            asset_chat_rls = check_asset_chat_rls(conn)
            counts = {table: table_count(conn, table) for table in REQUIRED_TABLES}

        edge_result = run_edge_db_fixture(connection_url, args, artifacts_dir)

    summary = {
        "status": "passed",
        "database": {
            "url": redact_url(connection_url),
            "tables": counts,
            "tenant_rls": tenant_rls,
            "asset_chat_rls": asset_chat_rls,
        },
        "edge_fixture": {
            "path": args.edge_fixture.relative_to(ROOT).as_posix(),
            "response": edge_result["response"],
        },
        "actual_edge_function": args.actual_edge_function.relative_to(ROOT).as_posix(),
        "production_credentials_required": False,
    }
    write_json(artifacts_dir / "summary.json", summary)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", action="store_true", help="Print topology and exit without Docker.")
    parser.add_argument("--sql-dir", type=Path, default=DEFAULT_SQL_DIR)
    parser.add_argument("--edge-fixture", type=Path, default=DEFAULT_EDGE_FIXTURE)
    parser.add_argument("--actual-edge-function", type=Path, default=DEFAULT_ACTUAL_EDGE_FUNCTION)
    parser.add_argument("--artifacts-dir", type=Path, default=DEFAULT_ARTIFACTS_DIR)
    parser.add_argument("--fixture-timeout-seconds", type=int, default=90)
    args = parser.parse_args(argv)
    args.sql_dir = args.sql_dir.resolve()
    args.edge_fixture = args.edge_fixture.resolve()
    args.actual_edge_function = args.actual_edge_function.resolve()
    args.artifacts_dir = args.artifacts_dir.resolve()
    return args


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.plan:
        print(json.dumps(build_plan(args.sql_dir, args.edge_fixture, args.actual_edge_function), indent=2))
        return 0

    try:
        return run_smoke(args)
    except Exception as exc:  # noqa: BLE001 - CI artifact should capture the failed boundary.
        args.artifacts_dir.mkdir(parents=True, exist_ok=True)
        write_json(args.artifacts_dir / "failure.json", {"status": "failed", "error": str(exc)})
        print(f"testcontainers smoke failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
