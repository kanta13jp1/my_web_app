#!/usr/bin/env python3
"""Run a deterministic Testcontainers smoke for DB + Edge runtime work.

The smoke intentionally avoids production Supabase credentials. It starts a
disposable Postgres container, applies a small migration/seed fixture, checks
the real Edge Function import policy, and runs a Deno HTTP fixture against the
container. Logs are written as artifacts so CI failures point to the migration,
function, or seed boundary that broke.
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
            counts = {table: table_count(conn, table) for table in REQUIRED_TABLES}

        edge_result = run_edge_db_fixture(connection_url, args, artifacts_dir)

    summary = {
        "status": "passed",
        "database": {
            "url": redact_url(connection_url),
            "tables": counts,
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
