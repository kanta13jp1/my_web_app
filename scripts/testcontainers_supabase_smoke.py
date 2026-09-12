#!/usr/bin/env python3
"""Run a deterministic Testcontainers smoke for DB + Edge runtime work.

The smoke intentionally avoids production Supabase credentials. It starts a
disposable Postgres container, applies a small migration/seed fixture, verifies
the Issue #2773 fail-closed RLS migration, Issue #2484 asset-chat isolation,
Issue #4091 app-analytics write boundary, and Issue #1202 voice-dubbing quota
state machine, Issue #1233 resource-optimizer tenant/analysis/quota contracts,
Issue #4956 WBS administrator/review contracts, Issue #2921 agent module
role/handoff contracts, Issue #4927 recurring-cost
tombstone concurrency, Issue #2844 account-deletion retention contracts, checks
the real Edge Function import policy, Issue #2668 note-comment authorization,
and runs a Deno HTTP fixture against the container.
Logs are written as
artifacts so CI failures point to the migration, function, or seed boundary that
broke.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import socket
import subprocess
import sys
import threading
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
APP_ANALYTICS_EDGE_FUNCTION = ROOT / "supabase" / "functions" / "growth-hub" / "index.ts"
APP_ANALYTICS_EDGE_TESTS = (
    ROOT / "supabase" / "functions" / "growth-hub" / "acquisition_signals_test.ts",
    ROOT / "supabase" / "functions" / "growth-hub" / "analytics_actor_test.ts",
)
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
TAX_RECORDS_MIGRATION = (
    ROOT / "supabase" / "migrations" / "20260820023000_create_tax_records.sql"
)
TAX_RECORDS_TABLES = ("tax_records",)
TAX_RECORD_1 = "00000000-0000-4000-8000-000000002489"
TAX_RECORD_2 = "00000000-0000-4000-8000-000000002490"
APP_ANALYTICS_SECURITY_MIGRATION = (
    ROOT
    / "supabase"
    / "migrations"
    / "20260827003000_harden_app_analytics_writes.sql"
)
NOTE_COMMENTS_SECURITY_MIGRATION = (
    ROOT
    / "supabase"
    / "migrations"
    / "20260827032000_harden_note_comments_authorization.sql"
)
GENERATED_MEMO_REPAIR_MIGRATION = (
    ROOT
    / "supabase"
    / "migrations"
    / "20260830021402_restore_generated_public_memo_publishing.sql"
)
PUBLIC_MEMO_RETURNING_RLS_MIGRATION = (
    ROOT
    / "supabase"
    / "migrations"
    / "20260830063839_fix_public_memo_returning_rls.sql"
)
NOTE_OWNER = "00000000-0000-4000-8000-000000002668"
NOTE_PUBLIC_VIEWER = "00000000-0000-4000-8000-000000002669"
NOTE_TEAM_MEMBER = "00000000-0000-4000-8000-000000002670"
NOTE_OUTSIDER = "00000000-0000-4000-8000-000000002671"
NOTE_OWNER_ADDED_MEMBER = "00000000-0000-4000-8000-000000002672"
NOTE_TEAM_ID = "00000000-0000-4000-8000-000000002673"
NOTE_INVITE_CODE = "26682668266826682668266826682668"
NOTE_PRIVATE_ID = 266801
NOTE_PUBLIC_ID = 266802
NOTE_TEAM_ID_VALUE = 266803
GENERATED_MEMO_NOTE_ID = 90000007002027
AI_UNIVERSITY_MIGRATION = (
    ROOT
    / "supabase"
    / "migrations"
    / "20260824135127_add_ai_university_evidence_and_content_analytics.sql"
)
AI_UNIVERSITY_LEGACY_ROW = "00000000-0000-4000-8000-000000004738"
AGENTLESS_COURSE_MIGRATION = (
    ROOT
    / "supabase"
    / "migrations"
    / "20260830120000_remediate_agentless_course.sql"
)
AGENTLESS_COURSE_ID = "50609809-2da6-41ba-9c35-4bbec9668493"
AGENTLESS_TASK_VERSION = "agentless_lab_20260830_v1"
AGENTLESS_COMPLETION_INSERT_SQL = (
    "insert into public.ai_university_agentless_lab_events ("
    "event_name, task_version, python_version, agentless_release, "
    "agentless_revision, dataset, dataset_revision, instance_id, model, "
    "candidate_count, max_threads, prompt_tokens, completion_tokens, "
    "embedding_tokens, api_cost_usd, predicted_api_cost_usd, "
    "wall_time_seconds, localization_correct, regression_result, "
    "reproduction_result, test_result, reproducibility_result, "
    "workplace_application) values ("
    "'lab_completed', %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, "
    "%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"
)
VOICE_DUBBING_BOOTSTRAP = (
    ROOT / "supabase" / "tests" / "voice_dubbing_bootstrap.sql"
)
BILLING_MIGRATION = (
    ROOT / "supabase" / "migrations" / "20260505203000_create_billing_tables.sql"
)
VOICE_DUBBING_MIGRATION = (
    ROOT
    / "supabase"
    / "migrations"
    / "20260814160000_add_voice_dubbing_usage.sql"
)
VOICE_DUBBING_CONTRACT = (
    ROOT / "supabase" / "tests" / "voice_dubbing_quota_contract.sql"
)
ISSUE_1233_RESOURCE_OPTIMIZER_SQL_FILES = (
    ROOT / "supabase" / "tests" / "issue1233_resource_optimizer_bootstrap.sql",
    ROOT / "supabase" / "migrations" / "20260412025000_create_hub_data_table.sql",
    ROOT / "supabase" / "migrations" / "20260327000012_create_daily_habits.sql",
    ROOT / "supabase" / "migrations" / "20260721235500_add_habit_resource_optimization.sql",
    ROOT / "supabase" / "migrations" / "20260827040000_resource_optimizer_ai_quota.sql",
    ROOT / "supabase" / "tests" / "issue1233_resource_optimizer_contract.sql",
)
ISSUE_1233_REAPPLIED_MIGRATIONS = ISSUE_1233_RESOURCE_OPTIMIZER_SQL_FILES[3:5]
ISSUE_1233_CONCURRENT_USER = "00000000-0000-4000-8000-000000001235"
ISSUE_4956_WBS_ADMIN_REVIEW_SQL_FILES = (
    ROOT / "supabase" / "tests" / "issue4956_wbs_admin_review_bootstrap.sql",
    ROOT
    / "supabase"
    / "migrations"
    / "20260828153722_repair_wbs_admin_review_contract.sql",
    ROOT / "supabase" / "tests" / "issue4956_wbs_admin_review_contract.sql",
)
ISSUE_2921_AGENT_MODULE_HANDOFF_SQL_FILES = (
    ROOT / "supabase" / "tests" / "issue2921_agent_module_bootstrap.sql",
    ROOT
    / "supabase"
    / "migrations"
    / "20260903093652_agent_module_role_handoffs.sql",
    ROOT / "supabase" / "tests" / "issue2921_agent_module_handoff_contract.sql",
)
ISSUE_4927_RECURRING_TOMBSTONE_SQL_FILES = (
    ROOT / "supabase" / "migrations" / "20260612230000_asset_pref_mirror.sql",
    ROOT
    / "supabase"
    / "migrations"
    / "20260828164000_atomic_recurring_fixed_cost_tombstones.sql",
    ROOT / "supabase" / "tests" / "issue4927_recurring_tombstone_contract.sql",
)
ISSUE_4927_USER = "00000000-0000-4000-8000-000000004927"
ISSUE_2844_ACCOUNT_DELETION_SQL_FILES = (
    ROOT / "supabase" / "tests" / "issue2844_account_deletion_bootstrap.sql",
    ROOT
    / "supabase"
     / "migrations"
     / "20260829095836_account_retention_and_deletion.sql",
    ROOT
    / "supabase"
    / "migrations"
    / "20260830054326_account_deletion_rollout_preflight.sql",
    ROOT / "supabase" / "tests" / "issue2844_account_deletion_contract.sql",
    ROOT
    / "supabase"
    / "tests"
    / "issue2844_account_deletion_rollout_contract.sql",
)
VIDEO_ARTIFACT_SQL_FILES = (
    ROOT / "supabase" / "tests" / "video_service_bootstrap.sql",
    ROOT / "supabase" / "migrations" / "20260819165405_create_first_party_video_service.sql",
    ROOT / "supabase" / "tests" / "video_artifact_review_loop_pre_migration.sql",
    ROOT / "supabase" / "migrations" / "20260822084126_add_video_artifact_review_loop.sql",
    ROOT / "supabase" / "tests" / "first_party_video_service_contract.sql",
    ROOT / "supabase" / "tests" / "video_artifact_review_loop_contract.sql",
    ROOT
    / "supabase"
    / "migrations"
    / "20260830053403_video_improvement_authorization_envelopes.sql",
    ROOT
    / "supabase"
    / "migrations"
    / "20260830123038_allow_authorized_video_retry_after_failure.sql",
    ROOT
    / "supabase"
    / "migrations"
    / "20260830123552_allow_authorized_video_retry_index.sql",
    ROOT
    / "supabase"
    / "migrations"
    / "20260830162041_persist_pending_video_improvement_authorizations.sql",
    ROOT / "supabase" / "tests" / "video_improvement_authorization_contract.sql",
    ROOT / "supabase" / "tests" / "video_publication_pre_migration.sql",
    ROOT
    / "supabase"
    / "migrations"
    / "20260830151707_create_video_publication_authorizations.sql",
    ROOT / "supabase" / "tests" / "video_publication_authorization_contract.sql",
)
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
    statements: list[str] = []
    current: list[str] = []
    index = 0
    state = "normal"
    dollar_tag = ""

    while index < len(sql):
        char = sql[index]
        next_char = sql[index + 1] if index + 1 < len(sql) else ""

        if state == "single_quote":
            current.append(char)
            if char == "'" and next_char == "'":
                current.append(next_char)
                index += 2
                continue
            if char == "'":
                state = "normal"
            index += 1
            continue

        if state == "double_quote":
            current.append(char)
            if char == '"' and next_char == '"':
                current.append(next_char)
                index += 2
                continue
            if char == '"':
                state = "normal"
            index += 1
            continue

        if state == "line_comment":
            current.append(char)
            if char == "\n":
                state = "normal"
            index += 1
            continue

        if state == "block_comment":
            current.append(char)
            if char == "*" and next_char == "/":
                current.append(next_char)
                index += 2
                state = "normal"
                continue
            index += 1
            continue

        if state == "dollar_quote":
            if sql.startswith(dollar_tag, index):
                current.append(dollar_tag)
                index += len(dollar_tag)
                state = "normal"
                continue
            current.append(char)
            index += 1
            continue

        if char == "-" and next_char == "-":
            current.extend((char, next_char))
            index += 2
            state = "line_comment"
            continue
        if char == "/" and next_char == "*":
            current.extend((char, next_char))
            index += 2
            state = "block_comment"
            continue
        if char == "'":
            current.append(char)
            index += 1
            state = "single_quote"
            continue
        if char == '"':
            current.append(char)
            index += 1
            state = "double_quote"
            continue
        if char == "$":
            match = re.match(r"\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$", sql[index:])
            if match:
                dollar_tag = match.group(0)
                current.append(dollar_tag)
                index += len(dollar_tag)
                state = "dollar_quote"
                continue
        if char == ";":
            statement = "".join(current).strip()
            if statement:
                statements.append(statement)
            current.clear()
            index += 1
            continue

        current.append(char)
        index += 1

    trailing = "".join(current).strip()
    if trailing:
        statements.append(trailing)
    return statements


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
        "tax_records_migration": TAX_RECORDS_MIGRATION.relative_to(ROOT).as_posix(),
        "tax_records_checks": [
            "tax_records has owner-only RLS",
            "anon has no table privileges",
            "authenticated users see only their own tax records",
            "authenticated users cannot forge another owner",
            "authenticated owner CRUD succeeds",
        ],
        "app_analytics_migration": APP_ANALYTICS_SECURITY_MIGRATION.relative_to(
            ROOT
        ).as_posix(),
        "app_analytics_checks": [
            "browser roles see aggregate rows and columns only",
            "raw browser INSERT, UPDATE, and DELETE are denied",
            "browser roles cannot execute analytics write RPCs",
            "Edge service-role events are atomic and idempotent per actor/day",
            "one actor cannot submit more than 32 source keys per JST day",
            "unsupported source keys and oversized increments are rejected",
            "poisoned legacy counters cannot overflow new event writes",
            "service_role retains required aggregate DML privileges",
            "migration applies twice without reopening public writes",
        ],
        "note_comments_migration": NOTE_COMMENTS_SECURITY_MIGRATION.relative_to(
            ROOT
        ).as_posix(),
        "note_comments_checks": [
            "all eight permissive legacy policies are replaced by four canonical policies",
            "anonymous users can read only valid public-note comments",
            "authenticated note owners and verified workspace members have scoped access",
            "body user_id forgery and writes to unrelated private notes are denied",
            "direct self-join and forged public/workspace shares cannot grant access",
            "invite-code attempts are actor-scoped and rate-limited",
            "comment authors can update content and delete only their own rows",
            "migration applies twice without reopening legacy authorization paths",
        ],
        "generated_memo_repair_migration": (
            GENERATED_MEMO_REPAIR_MIGRATION.relative_to(ROOT).as_posix()
        ),
        "generated_memo_repair_checks": [
            "orphaned generated public memos receive owner-backed notes",
            "legacy synthetic IDs remain readable during the client rollout",
            "owner-scoped source keys are unique and reusable",
            "public memo foreign key is validated after repair",
            "forged legacy publications remain inaccessible",
            "migration applies twice without duplicating backing notes",
        ],
        "public_memo_returning_rls_migration": (
            PUBLIC_MEMO_RETURNING_RLS_MIGRATION.relative_to(ROOT).as_posix()
        ),
        "public_memo_returning_rls_checks": [
            "owner insert with RETURNING succeeds for a fresh public memo",
            "owner conflict update with RETURNING succeeds",
            "anonymous readers see only valid public-note rows",
            "outsiders cannot conflict-update another owner's publication",
            "the SELECT policy does not self-read the row being written",
            "migration applies twice without widening access",
        ],
        "ai_university_migration": AI_UNIVERSITY_MIGRATION.relative_to(ROOT).as_posix(),
        "ai_university_checks": [
            "migration applies twice without losing legacy rows",
            "course evidence is nullable but all-or-none when populated",
            "anon and authenticated can insert only allowlisted event fields",
            "clients cannot select events or supply server-owned fields",
            "event table has RLS and no user/session/error payload columns",
        ],
        "agentless_course_migration": AGENTLESS_COURSE_MIGRATION.relative_to(
            ROOT
        ).as_posix(),
        "agentless_course_checks": [
            "the exact Agentless course row receives the versioned evidence block and fixed lab manifest",
            "the migration creates no learner outcome rows",
            "anon and authenticated can insert only bounded manifest columns",
            "malformed and incomplete completion manifests fail closed",
            "clients cannot read events or the service-role-only aggregate view",
            "service_role can read aggregate start, completion, cost, reproducibility, and workplace metrics",
            "the migration applies twice without widening privileges or duplicating evidence",
        ],
        "voice_dubbing_sql": [
            VOICE_DUBBING_BOOTSTRAP.relative_to(ROOT).as_posix(),
            BILLING_MIGRATION.relative_to(ROOT).as_posix(),
            VOICE_DUBBING_MIGRATION.relative_to(ROOT).as_posix(),
            VOICE_DUBBING_CONTRACT.relative_to(ROOT).as_posix(),
        ],
        "voice_dubbing_checks": [
            "migration applies twice in the disposable database",
            "authenticated cannot execute service-role quota RPCs",
            "duplicate in-progress claims do not consume quota twice",
            "completed requests replay their stored result without rebilling",
            "failed jobs release only unbilled reserved characters",
            "TTL reconciliation bills started chunks and releases unstarted chunks",
            "over-limit claims create no job and consume no additional quota",
        ],
        "issue_1233_resource_optimizer_sql": [
            path.relative_to(ROOT).as_posix()
            for path in ISSUE_1233_RESOURCE_OPTIMIZER_SQL_FILES
        ],
        "issue_1233_resource_optimizer_checks": [
            "both Issue #1233 migrations apply twice in the disposable database",
            "two authenticated users see and mutate only their own habits, logs, "
            "goals, and AI quota",
            "PUBLIC and anon cannot execute either resource-optimizer RPC",
            "habit-default proxy rows are excluded from analysis",
            "correlations and Pareto remain disabled below seven samples or without variance",
            "seven varied self-reported samples enable correlations and Pareto",
            "parallel AI quota consumes at the daily boundary are atomic with "
            "exactly one winner",
            "cooldown and ten-request UTC daily limit do not affect another user",
        ],
        "issue_4956_wbs_admin_review_sql": [
            path.relative_to(ROOT).as_posix()
            for path in ISSUE_4956_WBS_ADMIN_REVIEW_SQL_FILES
        ],
        "issue_4956_wbs_admin_review_checks": [
            "both WBS admin policies use user_profiles.user_id through the hardened helper",
            "non-admin writes remain denied even when a legacy profile id collides",
            "administrator task and milestone writes succeed through authenticated RLS",
            "OPEN Issues preserve in_progress/100/requested review readiness",
            "pending/100 auto-requests review regardless of trigger ordering",
            "rejected OPEN Issues cannot become completed/100",
            "blank and NULL Issue sync states fail closed until explicitly CLOSED",
            "manual_override is accepted only as an explicit administrator write",
            "migration applies twice in the disposable database",
        ],
        "issue_2921_agent_module_handoff_sql": [
            path.relative_to(ROOT).as_posix()
            for path in ISSUE_2921_AGENT_MODULE_HANDOFF_SQL_FILES
        ],
        "issue_2921_agent_module_handoff_checks": [
            "front-office and management agents use independent trusted JWT identities",
            "module-governed task reads and writes require the assigned module and agent",
            "human owners retain legacy task mutations and organization-wide audit reads",
            "direct assignment rewrites and cross-tenant access fail closed",
            "request and acceptance RPCs atomically transfer work with append-only events",
            "anon and authenticated clients have no direct handoff-table write privileges",
            "migration applies twice in the disposable database",
        ],
        "issue_4927_recurring_tombstone_sql": [
            path.relative_to(ROOT).as_posix()
            for path in ISSUE_4927_RECURRING_TOMBSTONE_SQL_FILES
        ],
        "issue_4927_recurring_tombstone_checks": [
            "RPC normalizes empty, whitespace, duplicate, and NULL IDs",
            "add/remove of the same ID is fail-closed with removal winning",
            "mixed-type malformed mirror values are rejected without overwrite",
            "authenticated INSERT, UPDATE, rename, DELETE, and spoofed-GUC writes are rejected",
            "unrelated-key CRUD remains allowed",
            "RPC guard state is restored after success",
            "initial concurrent additions and a concurrent add/remove preserve the exact set",
            "migration applies twice in the disposable database",
        ],
        "issue_2844_account_deletion_sql": [
            path.relative_to(ROOT).as_posix()
            for path in ISSUE_2844_ACCOUNT_DELETION_SQL_FILES
        ],
        "issue_2844_account_deletion_checks": [
            "queue and RPC access is service-role only",
            "due requests are claimed atomically",
            "direct auth.users CASCADE references are accepted",
            "populated unclassified user references fail closed",
            "Storage owner metadata and approved user path conventions are inventoried",
            "failed work records a bounded retry",
            "completed request evidence removes user_id",
            "preflight is non-mutating and exposes no user identifier",
            "exact-id canary preserves the control tenant",
            "target residual is zero except the documented audit retention",
        ],
        "video_artifact_contract": [
            path.relative_to(ROOT).as_posix() for path in VIDEO_ARTIFACT_SQL_FILES
        ],
        "video_artifact_checks": [
            "existing successful jobs are backfilled as private sale candidates",
            "reviews advance rights/privacy readiness without auto-publishing",
            "next-generation jobs preserve source artifact and review lineage",
            "original provenance is immutable and lifecycle evidence is append-only",
            "publication packets are immutable, owner-scoped and exact-source",
            "shop activation follows inactive staging and supports rollback",
        ],
        "edge_db_fixture": edge_fixture.relative_to(ROOT).as_posix(),
        "actual_edge_checks": [
            "scripts/check_edge_function_imports.py --root supabase/functions",
            f"deno check --config supabase/functions/deno.json {actual_edge_function.relative_to(ROOT).as_posix()}",
            f"deno check --config supabase/functions/deno.json {APP_ANALYTICS_EDGE_FUNCTION.relative_to(ROOT).as_posix()}",
            "deno test --config supabase/functions/deno.json "
            + " ".join(path.relative_to(ROOT).as_posix() for path in APP_ANALYTICS_EDGE_TESTS),
            f"deno check {edge_fixture.relative_to(ROOT).as_posix()}",
        ],
        "artifacts": [
            ".testcontainers-logs/summary.json",
            ".testcontainers-logs/edge-imports.log",
            ".testcontainers-logs/deno-check-health-check.log",
            ".testcontainers-logs/deno-check-app-analytics-edge.log",
            ".testcontainers-logs/deno-test-app-analytics-edge.log",
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


def check_issue_4927_tombstone_concurrency(
    conn: Any,
    connection_url: str,
    connect: Any,
) -> dict[str, Any]:
    """Race two authenticated additions and require an atomic server union."""

    with conn.cursor() as cur:
        cur.execute("select set_config('app.recurring_tombstone_rpc', 'on', false)")
        cur.execute(
            "delete from public.asset_pref_mirror "
            "where user_id = %s::uuid "
            "and pref_key = 'recurring_fixed_costs_deleted'",
            (ISSUE_4927_USER,),
        )
        cur.execute("select set_config('app.recurring_tombstone_rpc', 'off', false)")
    conn.commit()

    barrier = threading.Barrier(2)

    def apply_once(additions: list[str], removals: list[str]) -> None:
        with connect(connection_url, connect_timeout=10) as worker_conn:
            with worker_conn.cursor() as cur:
                cur.execute("set role authenticated")
                cur.execute(
                    "select set_config('request.jwt.claim.sub', %s, false)",
                    (ISSUE_4927_USER,),
                )
                cur.execute(
                    "select set_config('request.jwt.claim.role', 'authenticated', false)"
                )
                barrier.wait(timeout=10)
                cur.execute(
                    "select public.apply_recurring_fixed_cost_tombstones"
                    "(%s, %s)",
                    (additions, removals),
                )
            worker_conn.commit()

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        futures = [
            executor.submit(apply_once, ["concurrent-a"], []),
            executor.submit(apply_once, ["concurrent-b"], []),
        ]
        for future in futures:
            future.result(timeout=30)

    with conn.cursor() as cur:
        cur.execute(
            "select value -> 'ids' from public.asset_pref_mirror "
            "where user_id = %s::uuid and pref_key = 'recurring_fixed_costs_deleted'",
            (ISSUE_4927_USER,),
        )
        row = cur.fetchone()
    conn.commit()
    if row is None:
        raise AssertionError("Issue #4927 tombstone mirror row is missing")
    ids = set(row[0] or [])
    expected = {"concurrent-a", "concurrent-b"}
    if ids != expected:
        raise AssertionError(
            f"Issue #4927 initial concurrent union mismatch: {sorted(ids)}"
        )

    barrier = threading.Barrier(2)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        futures = [
            executor.submit(apply_once, ["concurrent-c"], []),
            executor.submit(apply_once, [], ["concurrent-a"]),
        ]
        for future in futures:
            future.result(timeout=30)

    with conn.cursor() as cur:
        cur.execute(
            "select value -> 'ids' from public.asset_pref_mirror "
            "where user_id = %s::uuid and pref_key = 'recurring_fixed_costs_deleted'",
            (ISSUE_4927_USER,),
        )
        row = cur.fetchone()
    conn.commit()
    ids = set(row[0] or []) if row is not None else set()
    final_expected = {"concurrent-b", "concurrent-c"}
    if ids != final_expected:
        raise AssertionError(
            f"Issue #4927 concurrent add/remove mismatch: {sorted(ids)}"
        )
    return {
        "initial_concurrent_ids": sorted(expected),
        "server_ids": sorted(ids),
    }


def check_issue_1233_ai_quota_concurrency(
    conn: Any,
    connection_url: str,
    connect: Any,
) -> dict[str, Any]:
    """Race two authenticated consumes and require exactly one quota winner."""

    barrier = threading.Barrier(2)

    def consume_once() -> tuple[bool, str, int, int]:
        with connect(connection_url, connect_timeout=10) as worker_conn:
            with worker_conn.cursor() as cur:
                cur.execute("set role authenticated")
                cur.execute(
                    "select set_config('request.jwt.claim.sub', %s, false)",
                    (ISSUE_1233_CONCURRENT_USER,),
                )
                cur.execute(
                    "select set_config('request.jwt.claim.role', 'authenticated', false)"
                )
                barrier.wait(timeout=10)
                cur.execute(
                    "select allowed, reason, remaining_daily, retry_after_seconds "
                    "from public.consume_resource_optimizer_ai_quota()"
                )
                row = cur.fetchone()
                if row is None:
                    raise AssertionError("Issue #1233 quota RPC returned no row")
                return bool(row[0]), str(row[1]), int(row[2]), int(row[3])

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        futures = [executor.submit(consume_once) for _ in range(2)]
        results = [future.result(timeout=30) for future in futures]

    allowed = [result for result in results if result[0]]
    denied = [result for result in results if not result[0]]
    if len(allowed) != 1 or allowed[0][1:] != ("allowed", 0, 0):
        raise AssertionError(f"Issue #1233 concurrent allowed results mismatch: {results}")
    if len(denied) != 1 or denied[0][1:] != ("daily_limit", 0, 0):
        raise AssertionError(f"Issue #1233 concurrent denial mismatch: {results}")

    with conn.cursor() as cur:
        cur.execute(
            "select request_count from public.resource_optimizer_ai_quota "
            "where user_id = %s::uuid "
            "and usage_date = timezone('UTC', clock_timestamp())::date",
            (ISSUE_1233_CONCURRENT_USER,),
        )
        row = cur.fetchone()
    if row is None or int(row[0]) != 10:
        raise AssertionError(f"Issue #1233 concurrent quota ledger mismatch: {row}")

    return {
        "allowed": len(allowed),
        "daily_limit": len(denied),
        "request_count": int(row[0]),
    }


def seed_ai_university_legacy_fixture(conn: Any) -> None:
    with conn.cursor() as cur:
        # The compact Testcontainers fixture predates the production course
        # catalog shape. Add only the columns consumed by the remediation so
        # the real migration is exercised without loading the full seed set.
        cur.execute(
            "alter table public.ai_university_content "
            "add column if not exists provider text, "
            "add column if not exists category text, "
            "add column if not exists content text, "
            "add column if not exists source_url text, "
            "add column if not exists published_at date"
        )
        cur.execute(
            "insert into public.ai_university_content (id, title) values (%s::uuid, %s)",
            (AI_UNIVERSITY_LEGACY_ROW, "legacy course"),
        )
        cur.execute(
            "insert into public.ai_university_content "
            "(id, provider, category, title, content, source_url, published_at) "
            "values (%s::uuid, 'agentless', 'overview', %s, %s, %s, date '2024-07-01')",
            (
                AGENTLESS_COURSE_ID,
                "Agentless legacy course",
                "unversioned legacy benchmark claim",
                "https://github.com/OpenAutoCoder/Agentless",
            ),
        )
    conn.commit()


def check_ai_university_migration(conn: Any) -> dict[str, Any]:
    evidence_columns = {
        "target_audience",
        "observable_learning_outcome",
        "assessment_verification_method",
        "evidence_source_url",
        "evidence_verified_at",
    }
    event_columns = {"id", "event_name", "surface", "occurred_at"}
    with conn.cursor() as cur:
        cur.execute(
            "select column_name from information_schema.columns "
            "where table_schema = 'public' and table_name = 'ai_university_content'"
        )
        actual_content_columns = {row[0] for row in cur.fetchall()}
        cur.execute(
            "select column_name from information_schema.columns "
            "where table_schema = 'public' "
            "and table_name = 'ai_university_content_events'"
        )
        actual_event_columns = {row[0] for row in cur.fetchall()}
        cur.execute(
            "select target_audience, observable_learning_outcome, "
            "assessment_verification_method, evidence_source_url, evidence_verified_at "
            "from public.ai_university_content where id = %s::uuid",
            (AI_UNIVERSITY_LEGACY_ROW,),
        )
        legacy_evidence = cur.fetchone()
        cur.execute(
            "select c.relrowsecurity from pg_class c "
            "join pg_namespace n on n.oid = c.relnamespace "
            "where n.nspname = 'public' and c.relname = 'ai_university_content_events'"
        )
        rls_enabled = bool(cur.fetchone()[0])
        cur.execute(
            "select policyname from pg_policies where schemaname = 'public' "
            "and tablename = 'ai_university_content_events' order by policyname"
        )
        policies = [row[0] for row in cur.fetchall()]
    conn.commit()

    if not evidence_columns.issubset(actual_content_columns):
        raise AssertionError(
            f"missing AI University evidence columns: {sorted(evidence_columns - actual_content_columns)}"
        )
    if actual_event_columns != event_columns:
        raise AssertionError(f"unexpected event payload columns: {sorted(actual_event_columns)}")
    if legacy_evidence is None or any(value is not None for value in legacy_evidence):
        raise AssertionError(f"legacy evidence was manufactured: {legacy_evidence}")
    if not rls_enabled:
        raise AssertionError("AI University event table does not have RLS enabled")
    expected_policy = "anonymous clients insert allowlisted content events"
    if policies != [expected_policy]:
        raise AssertionError(f"unexpected AI University event policies: {policies}")

    try:
        with conn.transaction():
            with conn.cursor() as cur:
                cur.execute(
                    "update public.ai_university_content set target_audience = 'learners' "
                    "where id = %s::uuid",
                    (AI_UNIVERSITY_LEGACY_ROW,),
                )
    except Exception as exc:
        if getattr(exc, "sqlstate", None) != "23514":
            raise AssertionError(f"partial evidence failed unexpectedly: {exc}") from exc
        partial_evidence_sqlstate = "23514"
    else:
        raise AssertionError("partial AI University evidence unexpectedly succeeded")

    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute(
                "update public.ai_university_content set "
                "target_audience = 'new AI learners', "
                "observable_learning_outcome = 'build one verified workflow', "
                "assessment_verification_method = 'review the produced workflow', "
                "evidence_source_url = 'https://example.invalid/course', "
                "evidence_verified_at = now() where id = %s::uuid",
                (AI_UNIVERSITY_LEGACY_ROW,),
            )

    with conn.cursor() as cur:
        for role in ("anon", "authenticated"):
            for column in ("event_name", "surface"):
                cur.execute(
                    "select has_column_privilege(%s, %s, %s, 'INSERT')",
                    (role, "public.ai_university_content_events", column),
                )
                if not bool(cur.fetchone()[0]):
                    raise AssertionError(f"{role} lacks INSERT on allowlisted column {column}")
            for column in ("id", "occurred_at"):
                cur.execute(
                    "select has_column_privilege(%s, %s, %s, 'INSERT')",
                    (role, "public.ai_university_content_events", column),
                )
                if bool(cur.fetchone()[0]):
                    raise AssertionError(f"{role} can INSERT server-owned column {column}")
            cur.execute(
                "select has_table_privilege(%s, %s, 'SELECT')",
                (role, "public.ai_university_content_events"),
            )
            if bool(cur.fetchone()[0]):
                raise AssertionError(f"{role} can SELECT anonymous event rows")
    conn.commit()

    for role, event_name in (("anon", "fallback_shown"), ("authenticated", "retry_succeeded")):
        with conn.transaction():
            with conn.cursor() as cur:
                cur.execute(f"set local role {role}")
                cur.execute(
                    "insert into public.ai_university_content_events (event_name, surface) "
                    "values (%s, 'ai_university_content')",
                    (event_name,),
                )

    denied_select_sqlstate = issue_2773_expect_denied(
        conn,
        role="anon",
        user_id=None,
        statement="select count(*) from public.ai_university_content_events",
    )
    denied_server_field_sqlstate = issue_2773_expect_denied(
        conn,
        role="authenticated",
        user_id=None,
        statement=(
            "insert into public.ai_university_content_events "
            "(event_name, surface, occurred_at) "
            "values ('retry_failed', 'ai_university_content', now())"
        ),
    )
    with conn.cursor() as cur:
        cur.execute("select count(*) from public.ai_university_content_events")
        event_count = int(cur.fetchone()[0])
    conn.commit()
    if event_count != 2:
        raise AssertionError(f"unexpected AI University event count: {event_count}")

    return {
        "evidence_columns": sorted(evidence_columns),
        "event_columns": sorted(event_columns),
        "legacy_evidence": "preserved as NULL",
        "partial_evidence_sqlstate": partial_evidence_sqlstate,
        "complete_evidence": "accepted",
        "rls_enabled": rls_enabled,
        "policies": policies,
        "client_event_inserts": event_count,
        "client_select_sqlstate": denied_select_sqlstate,
        "server_field_insert_sqlstate": denied_server_field_sqlstate,
    }


def agentless_expect_sqlstate(
    conn: Any,
    *,
    role: str,
    statement: str,
    expected_sqlstate: str,
    params: tuple[Any, ...] = (),
) -> str:
    if role not in {"anon", "authenticated", "service_role"}:
        raise ValueError(f"unexpected role for Agentless contract query: {role}")
    try:
        with conn.transaction():
            with conn.cursor() as cur:
                cur.execute(f"set local role {role}")
                cur.execute(statement, params)
    except Exception as exc:  # psycopg is loaded only for the integration run.
        sqlstate = getattr(exc, "sqlstate", None)
        if sqlstate != expected_sqlstate:
            raise AssertionError(
                f"expected SQLSTATE {expected_sqlstate}, got {sqlstate}: {exc}"
            ) from exc
        return sqlstate
    raise AssertionError(
        f"Agentless contract operation unexpectedly succeeded for role {role}"
    )


def check_agentless_course_migration(conn: Any) -> dict[str, Any]:
    completion_columns = {
        "python_version",
        "agentless_release",
        "agentless_revision",
        "dataset",
        "dataset_revision",
        "instance_id",
        "model",
        "candidate_count",
        "max_threads",
        "prompt_tokens",
        "completion_tokens",
        "embedding_tokens",
        "api_cost_usd",
        "predicted_api_cost_usd",
        "wall_time_seconds",
        "localization_correct",
        "regression_result",
        "reproduction_result",
        "test_result",
        "reproducibility_result",
        "workplace_application",
    }
    event_columns = {
        "id",
        "event_name",
        "task_version",
        "occurred_at",
        *completion_columns,
    }
    client_columns = {"event_name", "task_version", *completion_columns}

    with conn.cursor() as cur:
        cur.execute(
            "select content, source_url, published_at, target_audience, "
            "observable_learning_outcome, assessment_verification_method, "
            "evidence_source_url, evidence_verified_at "
            "from public.ai_university_content "
            "where id = %s::uuid and provider = 'agentless' and category = 'overview'",
            (AGENTLESS_COURSE_ID,),
        )
        course = cur.fetchone()
        cur.execute(
            "select column_name from information_schema.columns "
            "where table_schema = 'public' "
            "and table_name = 'ai_university_agentless_lab_events'"
        )
        actual_event_columns = {row[0] for row in cur.fetchall()}
        cur.execute(
            "select c.relrowsecurity from pg_class c "
            "join pg_namespace n on n.oid = c.relnamespace "
            "where n.nspname = 'public' "
            "and c.relname = 'ai_university_agentless_lab_events'"
        )
        rls_row = cur.fetchone()
        cur.execute(
            "select policyname, cmd from pg_policies "
            "where schemaname = 'public' "
            "and tablename = 'ai_university_agentless_lab_events'"
        )
        policies = cur.fetchall()
        cur.execute(
            "select reloptions from pg_class c "
            "join pg_namespace n on n.oid = c.relnamespace "
            "where n.nspname = 'public' "
            "and c.relname = 'ai_university_agentless_lab_summary'"
        )
        view_options_row = cur.fetchone()
        cur.execute("select count(*) from public.ai_university_agentless_lab_events")
        seeded_event_count = int(cur.fetchone()[0])
    conn.commit()

    if course is None:
        raise AssertionError("the exact Agentless course row was not remediated")
    content = str(course[0])
    required_markers = (
        "Versioned evidence block v1",
        "96/300 (32.00%)",
        "82/300 (27.3%)",
        "60分lab v1: `django__django-10914`",
        AGENTLESS_TASK_VERSION,
        "公開時点のseed証拠: 未収集",
    )
    missing_markers = [marker for marker in required_markers if marker not in content]
    if missing_markers:
        raise AssertionError(f"Agentless course evidence markers missing: {missing_markers}")
    if course[1] != "https://github.com/OpenAutoCoder/Agentless/tree/v1.5.0":
        raise AssertionError(f"unexpected Agentless source URL: {course[1]}")
    if str(course[2]) != "2026-08-30":
        raise AssertionError(f"unexpected Agentless published date: {course[2]}")
    if any(value is None for value in course[3:]):
        raise AssertionError("Agentless evidence metadata is incomplete")
    if actual_event_columns != event_columns:
        raise AssertionError(
            "unexpected Agentless event payload columns: "
            f"{sorted(actual_event_columns)}"
        )
    if rls_row is None or not bool(rls_row[0]):
        raise AssertionError("Agentless lab event table does not have RLS enabled")
    if policies != [
        ("anonymous clients insert bounded Agentless lab evidence", "INSERT")
    ]:
        raise AssertionError(f"unexpected Agentless event policies: {policies}")
    view_options = set(view_options_row[0] or []) if view_options_row else set()
    if "security_invoker=true" not in view_options:
        raise AssertionError(f"Agentless summary is not security-invoker: {view_options}")
    if seeded_event_count != 0:
        raise AssertionError(f"Agentless migration manufactured learner rows: {seeded_event_count}")

    with conn.cursor() as cur:
        for role in ("anon", "authenticated"):
            for column in client_columns:
                cur.execute(
                    "select has_column_privilege(%s, %s, %s, 'INSERT')",
                    (role, "public.ai_university_agentless_lab_events", column),
                )
                if not bool(cur.fetchone()[0]):
                    raise AssertionError(f"{role} lacks Agentless INSERT column {column}")
            for column in ("id", "occurred_at"):
                cur.execute(
                    "select has_column_privilege(%s, %s, %s, 'INSERT')",
                    (role, "public.ai_university_agentless_lab_events", column),
                )
                if bool(cur.fetchone()[0]):
                    raise AssertionError(f"{role} can write server-owned column {column}")
            for privilege in ("SELECT", "UPDATE", "DELETE"):
                cur.execute(
                    "select has_table_privilege(%s, %s, %s)",
                    (role, "public.ai_university_agentless_lab_events", privilege),
                )
                if bool(cur.fetchone()[0]):
                    raise AssertionError(
                        f"{role} unexpectedly has Agentless {privilege} privilege"
                    )
            cur.execute(
                "select has_table_privilege(%s, %s, 'SELECT')",
                (role, "public.ai_university_agentless_lab_summary"),
            )
            if bool(cur.fetchone()[0]):
                raise AssertionError(f"{role} can read the Agentless summary view")
        for relation in (
            "public.ai_university_agentless_lab_events",
            "public.ai_university_agentless_lab_summary",
        ):
            cur.execute(
                "select has_table_privilege('service_role', %s, 'SELECT')",
                (relation,),
            )
            if not bool(cur.fetchone()[0]):
                raise AssertionError(f"service_role cannot read {relation}")
    conn.commit()

    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute("set local role anon")
            cur.execute(
                "insert into public.ai_university_agentless_lab_events "
                "(event_name, task_version) values ('lab_started', %s)",
                (AGENTLESS_TASK_VERSION,),
            )

    incomplete_sqlstate = agentless_expect_sqlstate(
        conn,
        role="authenticated",
        statement=(
            "insert into public.ai_university_agentless_lab_events "
            "(event_name, task_version) values ('lab_completed', %s)"
        ),
        params=(AGENTLESS_TASK_VERSION,),
        expected_sqlstate="23514",
    )
    server_field_sqlstate = agentless_expect_sqlstate(
        conn,
        role="anon",
        statement=(
            "insert into public.ai_university_agentless_lab_events "
            "(id, event_name, task_version) "
            "values (gen_random_uuid(), 'lab_started', %s)"
        ),
        params=(AGENTLESS_TASK_VERSION,),
        expected_sqlstate="42501",
    )
    event_select_sqlstate = agentless_expect_sqlstate(
        conn,
        role="anon",
        statement="select count(*) from public.ai_university_agentless_lab_events",
        expected_sqlstate="42501",
    )
    summary_select_sqlstate = agentless_expect_sqlstate(
        conn,
        role="authenticated",
        statement="select * from public.ai_university_agentless_lab_summary",
        expected_sqlstate="42501",
    )

    completed_values = (
        "3.11.9",
        "v1.5.0",
        "b150f28465a77a81a7f4776384957a4271f5bd69",
        "princeton-nlp/SWE-bench_Lite",
        "6ec7bb89b9342f664a54a6e0a6ea6501d3437cc2",
        "django__django-10914",
        "gpt-4o-2024-05-13",
        4,
        10,
        1000,
        250,
        0,
        0.7000,
        0.7000,
        1800,
        True,
        "passed",
        "passed",
        "resolved",
        "reproduced",
        "planned",
    )
    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute("set local role authenticated")
            cur.execute(
                AGENTLESS_COMPLETION_INSERT_SQL,
                (AGENTLESS_TASK_VERSION, *completed_values),
            )

    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute("set local role service_role")
            cur.execute(
                "select start_count, completion_count, completion_rate_percent, "
                "localization_correct_percent, resolved_percent, "
                "average_cost_prediction_error_percent, reproduced_percent, "
                "workplace_applied_percent "
                "from public.ai_university_agentless_lab_summary "
                "where task_version = %s",
                (AGENTLESS_TASK_VERSION,),
            )
            summary = cur.fetchone()
    expected_summary = (1, 1, 100.0, 100.0, 100.0, 0.0, 100.0, 0.0)
    if summary is None or tuple(float(value) for value in summary) != tuple(
        float(value) for value in expected_summary
    ):
        raise AssertionError(f"unexpected Agentless summary metrics: {summary}")

    return {
        "course_id": AGENTLESS_COURSE_ID,
        "task_version": AGENTLESS_TASK_VERSION,
        "event_columns": sorted(event_columns),
        "seeded_event_count": seeded_event_count,
        "rls_enabled": bool(rls_row[0]),
        "policy": policies[0][0],
        "incomplete_manifest_sqlstate": incomplete_sqlstate,
        "server_field_sqlstate": server_field_sqlstate,
        "client_event_select_sqlstate": event_select_sqlstate,
        "client_summary_select_sqlstate": summary_select_sqlstate,
        "runtime_summary": [float(value) for value in summary],
    }


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


def note_comments_run_as(
    conn: Any,
    *,
    role: str,
    user_id: str | None,
    statement: str,
    params: tuple[Any, ...] = (),
) -> list[tuple[Any, ...]]:
    if role not in {"anon", "authenticated", "service_role"}:
        raise ValueError(f"unexpected role for note-comments query: {role}")
    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute(f"set local role {role}")
            cur.execute(
                "select set_config('request.jwt.claim.sub', %s, true)",
                (user_id or "",),
            )
            cur.execute(statement, params)
            if cur.description is None:
                return []
            return [tuple(row) for row in cur.fetchall()]


def note_comments_expect_sqlstate(
    conn: Any,
    *,
    role: str,
    user_id: str | None,
    statement: str,
    expected: str,
    params: tuple[Any, ...] = (),
) -> str:
    try:
        note_comments_run_as(
            conn,
            role=role,
            user_id=user_id,
            statement=statement,
            params=params,
        )
    except Exception as exc:  # psycopg is loaded only for the integration run.
        sqlstate = getattr(exc, "sqlstate", None)
        if sqlstate != expected:
            raise AssertionError(
                f"expected SQLSTATE {expected}, got {sqlstate}: {exc}"
            ) from exc
        return str(sqlstate)
    raise AssertionError(f"note-comments operation unexpectedly succeeded ({expected})")


def seed_note_comments_security_fixture(conn: Any) -> None:
    with conn.cursor() as cur:
        cur.executemany(
            "insert into auth.users (id) values (%s::uuid)",
            [
                (NOTE_OWNER,),
                (NOTE_PUBLIC_VIEWER,),
                (NOTE_TEAM_MEMBER,),
                (NOTE_OUTSIDER,),
                (NOTE_OWNER_ADDED_MEMBER,),
            ],
        )
        cur.executemany(
            "insert into public.notes (id, user_id, content) "
            "values (%s, %s::uuid, %s)",
            [
                (NOTE_PRIVATE_ID, NOTE_OWNER, "private note"),
                (NOTE_PUBLIC_ID, NOTE_OWNER, "public note"),
                (NOTE_TEAM_ID_VALUE, NOTE_OWNER, "team note"),
            ],
        )
        cur.executemany(
            "insert into public.public_memos "
            "(note_id, user_id, title, is_public) values (%s, %s::uuid, %s, true)",
            [
                (NOTE_PUBLIC_ID, NOTE_OWNER, "valid public memo"),
                (NOTE_PRIVATE_ID, NOTE_OUTSIDER, "legacy forged public memo"),
                (
                    GENERATED_MEMO_NOTE_ID,
                    NOTE_OWNER,
                    "generated election dashboard",
                ),
            ],
        )
        cur.execute(
            "insert into public.teams (id, name, owner_id, invite_code) "
            "values (%s::uuid, 'Issue 2668 team', %s::uuid, %s)",
            (NOTE_TEAM_ID, NOTE_OWNER, NOTE_INVITE_CODE),
        )
        cur.executemany(
            "insert into public.team_memberships (team_id, user_id, role) "
            "values (%s::uuid, %s::uuid, 'member')",
            [
                (NOTE_TEAM_ID, NOTE_TEAM_MEMBER),
                (NOTE_TEAM_ID, NOTE_OUTSIDER),
            ],
        )
        cur.executemany(
            "insert into public.team_shared_notes (team_id, note_id, shared_by) "
            "values (%s::uuid, %s, %s::uuid)",
            [
                (NOTE_TEAM_ID, NOTE_TEAM_ID_VALUE, NOTE_OWNER),
                (NOTE_TEAM_ID, NOTE_PRIVATE_ID, NOTE_OUTSIDER),
            ],
        )
        cur.executemany(
            "insert into public.note_comments (note_id, user_id, content) "
            "values (%s, %s::uuid, %s)",
            [
                (NOTE_PRIVATE_ID, NOTE_OWNER, "owner private comment"),
                (NOTE_PRIVATE_ID, NOTE_OUTSIDER, "legacy forged private comment"),
                (NOTE_PUBLIC_ID, NOTE_OWNER, "public comment"),
                (NOTE_TEAM_ID_VALUE, NOTE_OWNER, "team comment"),
            ],
        )
    conn.commit()


def check_note_comments_security(conn: Any) -> dict[str, Any]:
    with conn.cursor() as cur:
        cur.execute(
            "select policyname, cmd, roles from pg_policies "
            "where schemaname = 'public' and tablename = 'note_comments' "
            "order by policyname"
        )
        policies = [tuple(row) for row in cur.fetchall()]
        cur.execute(
            "select n.nspname, p.proname, p.prosecdef, "
            "coalesce(p.proconfig, array[]::text[]), "
            "not exists (select 1 from aclexplode(coalesce(p.proacl, "
            "acldefault('f', p.proowner))) acl where acl.grantee = 0 "
            "and acl.privilege_type = 'EXECUTE') "
            "from pg_proc p join pg_namespace n on n.oid = p.pronamespace "
            "where (n.nspname, p.proname) in "
            "(('note_comments_private', 'owns_note'), "
            "('note_comments_private', 'owns_team'), "
            "('note_comments_private', 'can_participate_in_team'), "
            "('note_comments_private', 'is_valid_team_note_share'), "
            "('note_comments_private', 'can_access_note_comments'), "
            "('note_comments_private', 'can_read_public_memo'), "
            "('note_comments_private', 'stamp_owner_added_membership'), "
            "('public', 'join_team_with_invite_code')) "
            "order by n.nspname, p.proname"
        )
        functions = [tuple(row) for row in cur.fetchall()]
        cur.execute(
            "select coalesce(reloptions, array[]::text[]) from pg_class c "
            "join pg_namespace n on n.oid = c.relnamespace "
            "where n.nspname = 'public' and c.relname = 'note_comment_counts'"
        )
        view_options = list(cur.fetchone()[0])
    conn.commit()

    expected_policies = [
        ("note_comments_delete_author", "DELETE", ("authenticated",)),
        ("note_comments_insert_authorized", "INSERT", ("authenticated",)),
        (
            "note_comments_select_authorized",
            "SELECT",
            ("anon", "authenticated"),
        ),
        ("note_comments_update_author", "UPDATE", ("authenticated",)),
    ]
    normalized_policies = [
        (name, command, tuple(roles)) for name, command, roles in policies
    ]
    if normalized_policies != expected_policies:
        raise AssertionError(f"unexpected note_comments policies: {policies}")
    if len(functions) != 8:
        raise AssertionError(f"unexpected note authorization functions: {functions}")
    for schema, name, security_definer, proconfig, public_revoked in functions:
        if not security_definer:
            raise AssertionError(f"{schema}.{name} is not SECURITY DEFINER")
        if not any(str(item).startswith("search_path=") for item in proconfig):
            raise AssertionError(f"{schema}.{name} search_path is not pinned: {proconfig}")
        if not public_revoked:
            raise AssertionError(f"PUBLIC retains EXECUTE on {schema}.{name}")
    if "security_invoker=true" not in view_options:
        raise AssertionError(f"note_comment_counts is not security_invoker: {view_options}")

    table_privileges: dict[str, dict[str, bool]] = {}
    with conn.cursor() as cur:
        for role in ("anon", "authenticated"):
            table_privileges[role] = {}
            for privilege in ("SELECT", "INSERT", "UPDATE", "DELETE"):
                cur.execute(
                    "select has_table_privilege(%s, 'public.note_comments', %s)",
                    (role, privilege),
                )
                table_privileges[role][privilege] = bool(cur.fetchone()[0])
        cur.execute(
            "select has_table_privilege('anon', 'public.note_comment_counts', 'SELECT'), "
            "has_table_privilege('authenticated', 'public.note_comment_counts', 'SELECT')"
        )
        view_browser_access = tuple(bool(item) for item in cur.fetchone())
        cur.execute(
            "select has_function_privilege('anon', "
            "'public.join_team_with_invite_code(text)', 'EXECUTE'), "
            "has_function_privilege('authenticated', "
            "'public.join_team_with_invite_code(text)', 'EXECUTE')"
        )
        rpc_access = tuple(bool(item) for item in cur.fetchone())
        authenticated_columns: dict[str, dict[str, bool]] = {}
        for column in ("id", "note_id", "user_id", "content", "created_at"):
            authenticated_columns[column] = {}
            for privilege in ("INSERT", "UPDATE"):
                cur.execute(
                    "select has_column_privilege('authenticated', "
                    "'public.note_comments', %s, %s)",
                    (column, privilege),
                )
                authenticated_columns[column][privilege] = bool(cur.fetchone()[0])
    conn.commit()

    expected_table_privileges = {
        "anon": {"SELECT": True, "INSERT": False, "UPDATE": False, "DELETE": False},
        "authenticated": {
            "SELECT": True,
            "INSERT": False,
            "UPDATE": False,
            "DELETE": True,
        },
    }
    if table_privileges != expected_table_privileges:
        raise AssertionError(f"unexpected note_comments ACL: {table_privileges}")
    if view_browser_access != (False, False):
        raise AssertionError(f"browser roles can read comment counts: {view_browser_access}")
    if rpc_access != (False, True):
        raise AssertionError(f"unexpected invite RPC ACL: {rpc_access}")
    expected_columns = {
        "id": {"INSERT": False, "UPDATE": False},
        "note_id": {"INSERT": True, "UPDATE": False},
        "user_id": {"INSERT": True, "UPDATE": False},
        "content": {"INSERT": True, "UPDATE": True},
        "created_at": {"INSERT": False, "UPDATE": False},
    }
    if authenticated_columns != expected_columns:
        raise AssertionError(f"unexpected note_comments column ACL: {authenticated_columns}")

    def comment_count(role: str, user_id: str | None, note_id: int) -> int:
        rows = note_comments_run_as(
            conn,
            role=role,
            user_id=user_id,
            statement="select count(*) from public.note_comments where note_id = %s",
            params=(note_id,),
        )
        return int(rows[0][0])

    initial_counts = {
        "anon_private": comment_count("anon", None, NOTE_PRIVATE_ID),
        "anon_public": comment_count("anon", None, NOTE_PUBLIC_ID),
        "owner_private": comment_count("authenticated", NOTE_OWNER, NOTE_PRIVATE_ID),
        "outsider_private": comment_count(
            "authenticated", NOTE_OUTSIDER, NOTE_PRIVATE_ID
        ),
        "unverified_member_team": comment_count(
            "authenticated", NOTE_TEAM_MEMBER, NOTE_TEAM_ID_VALUE
        ),
    }
    expected_initial_counts = {
        "anon_private": 0,
        "anon_public": 1,
        "owner_private": 2,
        "outsider_private": 0,
        "unverified_member_team": 0,
    }
    if initial_counts != expected_initial_counts:
        raise AssertionError(f"unexpected initial comment visibility: {initial_counts}")

    unverified_team_rows = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_OUTSIDER,
        statement="select invite_code from public.teams where id = %s::uuid",
        params=(NOTE_TEAM_ID,),
    )
    if unverified_team_rows:
        raise AssertionError(
            f"unverified legacy member can read invite code: {unverified_team_rows}"
        )

    denied_sqlstates = {
        "anon_write": note_comments_expect_sqlstate(
            conn,
            role="anon",
            user_id=None,
            statement=(
                "insert into public.note_comments (note_id, user_id, content) "
                "values (%s, %s::uuid, 'anon write')"
            ),
            params=(NOTE_PUBLIC_ID, NOTE_PUBLIC_VIEWER),
            expected="42501",
        ),
        "missing_claim_write": note_comments_expect_sqlstate(
            conn,
            role="authenticated",
            user_id=None,
            statement=(
                "insert into public.note_comments (note_id, user_id, content) "
                "values (%s, %s::uuid, 'missing claim')"
            ),
            params=(NOTE_PRIVATE_ID, NOTE_OWNER),
            expected="42501",
        ),
        "forged_body_user": note_comments_expect_sqlstate(
            conn,
            role="authenticated",
            user_id=NOTE_PUBLIC_VIEWER,
            statement=(
                "insert into public.note_comments (note_id, user_id, content) "
                "values (%s, %s::uuid, 'forged user')"
            ),
            params=(NOTE_PUBLIC_ID, NOTE_OUTSIDER),
            expected="42501",
        ),
        "unrelated_private_write": note_comments_expect_sqlstate(
            conn,
            role="authenticated",
            user_id=NOTE_OUTSIDER,
            statement=(
                "insert into public.note_comments (note_id, user_id, content) "
                "values (%s, %s::uuid, 'private write')"
            ),
            params=(NOTE_PRIVATE_ID, NOTE_OUTSIDER),
            expected="42501",
        ),
        "direct_self_join": note_comments_expect_sqlstate(
            conn,
            role="authenticated",
            user_id=NOTE_PUBLIC_VIEWER,
            statement=(
                "insert into public.team_memberships (team_id, user_id, role) "
                "values (%s::uuid, %s::uuid, 'member')"
            ),
            params=(NOTE_TEAM_ID, NOTE_PUBLIC_VIEWER),
            expected="42501",
        ),
        "forged_publication": note_comments_expect_sqlstate(
            conn,
            role="authenticated",
            user_id=NOTE_OUTSIDER,
            statement=(
                "insert into public.public_memos "
                "(note_id, user_id, title, is_public) "
                "values (%s, %s::uuid, 'forged', true)"
            ),
            params=(NOTE_TEAM_ID_VALUE, NOTE_OUTSIDER),
            expected="42501",
        ),
        "forged_team_share": note_comments_expect_sqlstate(
            conn,
            role="authenticated",
            user_id=NOTE_OUTSIDER,
            statement=(
                "insert into public.team_shared_notes (team_id, note_id, shared_by) "
                "values (%s::uuid, %s, %s::uuid)"
            ),
            params=(NOTE_TEAM_ID, NOTE_PUBLIC_ID, NOTE_OUTSIDER),
            expected="42501",
        ),
    }

    invalid_invite = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_OUTSIDER,
        statement="select * from public.join_team_with_invite_code('INVALID2668')",
    )
    if invalid_invite:
        raise AssertionError(f"invalid invite returned a team: {invalid_invite}")
    for attempt in range(2, 11):
        repeated_invalid = note_comments_run_as(
            conn,
            role="authenticated",
            user_id=NOTE_OUTSIDER,
            statement="select * from public.join_team_with_invite_code(%s)",
            params=(f"INVALID{attempt:04d}",),
        )
        if repeated_invalid:
            raise AssertionError(
                f"invalid invite attempt {attempt} returned a team: {repeated_invalid}"
            )
    rate_limit_sqlstate = note_comments_expect_sqlstate(
        conn,
        role="authenticated",
        user_id=NOTE_OUTSIDER,
        statement="select * from public.join_team_with_invite_code('INVALID0011')",
        expected="P0001",
    )
    with conn.cursor() as cur:
        cur.execute(
            "select attempt_count from note_comments_private.team_invite_attempts "
            "where user_id = %s::uuid",
            (NOTE_OUTSIDER,),
        )
        outsider_attempt_count = int(cur.fetchone()[0])
    conn.commit()
    if outsider_attempt_count != 10:
        raise AssertionError(f"invite attempt was not recorded: {outsider_attempt_count}")
    if comment_count("authenticated", NOTE_OUTSIDER, NOTE_TEAM_ID_VALUE) != 0:
        raise AssertionError("invalid invite verified a legacy membership")

    joined = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_TEAM_MEMBER,
        statement="select * from public.join_team_with_invite_code(%s)",
        params=(NOTE_INVITE_CODE,),
    )
    if (
        len(joined) != 1
        or str(joined[0][0]) != NOTE_TEAM_ID
        or joined[0][1] != "Issue 2668 team"
    ):
        raise AssertionError(f"invite RPC returned unexpected team: {joined}")
    if comment_count("authenticated", NOTE_TEAM_MEMBER, NOTE_TEAM_ID_VALUE) != 1:
        raise AssertionError("verified member cannot read team comments")
    verified_team_rows = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_TEAM_MEMBER,
        statement="select invite_code from public.teams where id = %s::uuid",
        params=(NOTE_TEAM_ID,),
    )
    if verified_team_rows != [(NOTE_INVITE_CODE,)]:
        raise AssertionError(f"verified member cannot read team: {verified_team_rows}")
    if comment_count("authenticated", NOTE_TEAM_MEMBER, NOTE_PRIVATE_ID) != 0:
        raise AssertionError("forged legacy team share granted private access")

    owner_added = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_OWNER,
        statement=(
            "insert into public.team_memberships (team_id, user_id, role) "
            "values (%s::uuid, %s::uuid, 'member') returning invite_verified_at"
        ),
        params=(NOTE_TEAM_ID, NOTE_OWNER_ADDED_MEMBER),
    )
    if not owner_added or owner_added[0][0] is None:
        raise AssertionError("owner-added membership was not verified")
    if comment_count(
        "authenticated", NOTE_OWNER_ADDED_MEMBER, NOTE_TEAM_ID_VALUE
    ) != 1:
        raise AssertionError("owner-added member cannot read team comments")

    member_insert = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_TEAM_MEMBER,
        statement=(
            "insert into public.note_comments (note_id, user_id, content) "
            "values (%s, %s::uuid, 'member comment') returning id"
        ),
        params=(NOTE_TEAM_ID_VALUE, NOTE_TEAM_MEMBER),
    )
    if len(member_insert) != 1:
        raise AssertionError("verified member could not create a team comment")

    public_insert = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_PUBLIC_VIEWER,
        statement=(
            "insert into public.note_comments (note_id, user_id, content) "
            "values (%s, %s::uuid, 'viewer comment') returning id"
        ),
        params=(NOTE_PUBLIC_ID, NOTE_PUBLIC_VIEWER),
    )
    public_comment_id = str(public_insert[0][0])
    updated = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_PUBLIC_VIEWER,
        statement=(
            "update public.note_comments set content = 'viewer edited' "
            "where id = %s::uuid returning content"
        ),
        params=(public_comment_id,),
    )
    if updated != [("viewer edited",)]:
        raise AssertionError(f"author content update failed: {updated}")
    owner_update = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_OWNER,
        statement=(
            "update public.note_comments set content = 'owner overwrite' "
            "where id = %s::uuid returning id"
        ),
        params=(public_comment_id,),
    )
    if owner_update:
        raise AssertionError("note owner updated another author's comment")
    denied_sqlstates["immutable_note_id"] = note_comments_expect_sqlstate(
        conn,
        role="authenticated",
        user_id=NOTE_PUBLIC_VIEWER,
        statement=(
            "update public.note_comments set note_id = %s "
            "where id = %s::uuid"
        ),
        params=(NOTE_PRIVATE_ID, public_comment_id),
        expected="42501",
    )
    owner_delete = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_OWNER,
        statement="delete from public.note_comments where id = %s::uuid returning id",
        params=(public_comment_id,),
    )
    if owner_delete:
        raise AssertionError("note owner deleted another author's comment")
    author_delete = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_PUBLIC_VIEWER,
        statement="delete from public.note_comments where id = %s::uuid returning id",
        params=(public_comment_id,),
    )
    if len(author_delete) != 1:
        raise AssertionError("comment author could not delete own comment")

    for key, content in (("blank_content", "   "), ("oversized_content", "x" * 2001)):
        denied_sqlstates[key] = note_comments_expect_sqlstate(
            conn,
            role="authenticated",
            user_id=NOTE_OWNER,
            statement=(
                "insert into public.note_comments (note_id, user_id, content) "
                "values (%s, %s::uuid, %s)"
            ),
            params=(NOTE_PRIVATE_ID, NOTE_OWNER, content),
            expected="23514",
        )

    service_rows = note_comments_run_as(
        conn,
        role="service_role",
        user_id=None,
        statement=(
            "insert into public.note_comments (note_id, user_id, content) "
            "values (%s, %s::uuid, 'service comment') returning id"
        ),
        params=(NOTE_PRIVATE_ID, NOTE_OWNER),
    )
    if len(service_rows) != 1:
        raise AssertionError("service_role note comment DML regressed")

    return {
        "policies": normalized_policies,
        "functions": [f"{schema}.{name}" for schema, name, *_ in functions],
        "table_privileges": table_privileges,
        "initial_visibility": initial_counts,
        "unverified_member_team_visibility": len(unverified_team_rows),
        "denied_sqlstates": denied_sqlstates,
        "invalid_invite_attempts": outsider_attempt_count,
        "rate_limit_sqlstate": rate_limit_sqlstate,
        "verified_member_team_comments": comment_count(
            "authenticated", NOTE_TEAM_MEMBER, NOTE_TEAM_ID_VALUE
        ),
        "service_role_dml": "passed",
    }


def check_generated_memo_repair(conn: Any) -> dict[str, Any]:
    with conn.cursor() as cur:
        cur.execute(
            "select n.id, n.user_id::text, n.source_key, count(*) over () "
            "from public.notes n "
            "join public.public_memos pm on pm.note_id = n.id "
            "where n.source_key = %s and pm.user_id = %s::uuid",
            (f"local-election:{GENERATED_MEMO_NOTE_ID}", NOTE_OWNER),
        )
        repaired_rows = [tuple(row) for row in cur.fetchall()]
        cur.execute(
            "select convalidated from pg_constraint "
            "where conname = 'public_memos_note_id_fkey' "
            "and conrelid = 'public.public_memos'::regclass"
        )
        foreign_key_validated = bool(cur.fetchone()[0])
        cur.execute(
            "select count(*) from pg_constraint "
            "where conname = 'notes_user_source_key_unique' "
            "and conrelid = 'public.notes'::regclass"
        )
        source_key_constraint_count = int(cur.fetchone()[0])
    conn.commit()

    if len(repaired_rows) != 1:
        raise AssertionError(f"generated memo backing note mismatch: {repaired_rows}")
    backing_note_id, owner_id, source_key, matching_count = repaired_rows[0]
    if not isinstance(backing_note_id, int) or not 0 < backing_note_id < 2**31:
        raise AssertionError(
            f"generated memo note ID is not an integer ID: {backing_note_id}"
        )
    if backing_note_id == GENERATED_MEMO_NOTE_ID:
        raise AssertionError("generated memo retained the out-of-range synthetic ID")
    if (
        owner_id != NOTE_OWNER
        or source_key != f"local-election:{GENERATED_MEMO_NOTE_ID}"
        or matching_count != 1
    ):
        raise AssertionError(f"generated memo backing note mismatch: {repaired_rows}")
    if not foreign_key_validated:
        raise AssertionError("public_memos note foreign key was not validated")
    if source_key_constraint_count != 1:
        raise AssertionError("owner-scoped generated note key is not unique")

    anonymous_rows = note_comments_run_as(
        conn,
        role="anon",
        user_id=None,
        statement=(
            "select note_id from public.public_memos "
            "where note_id = %s and is_public is true"
        ),
        params=(backing_note_id,),
    )
    if anonymous_rows != [(backing_note_id,)]:
        raise AssertionError(
            f"repaired generated memo is not public: {anonymous_rows}"
        )

    owner_update = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_OWNER,
        statement=(
            "update public.public_memos set title = 'generated election update' "
            "where note_id = %s returning title"
        ),
        params=(backing_note_id,),
    )
    if owner_update != [("generated election update",)]:
        raise AssertionError(f"generated memo owner update failed: {owner_update}")

    outsider_update = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_OUTSIDER,
        statement=(
            "update public.public_memos set title = 'forged update' "
            "where note_id = %s returning title"
        ),
        params=(backing_note_id,),
    )
    if outsider_update:
        raise AssertionError("outsider updated an owner-backed generated memo")

    forged_rows = note_comments_run_as(
        conn,
        role="anon",
        user_id=None,
        statement=(
            "select note_id from public.public_memos "
            "where note_id = %s and user_id = %s::uuid"
        ),
        params=(NOTE_PRIVATE_ID, NOTE_OUTSIDER),
    )
    if forged_rows:
        raise AssertionError("repair made a forged legacy publication readable")

    with conn.cursor() as cur:
        cur.execute(
            "insert into public.notes (user_id, content, source_key) "
            "values (%s::uuid, 'fresh generated memo', %s) "
            "on conflict (user_id, source_key) do update "
            "set content = excluded.content returning id",
            (NOTE_OWNER, "local-election:returning-smoke"),
        )
        fresh_note_id = int(cur.fetchone()[0])
        cur.execute(
            "select count(*) from pg_proc p "
            "join pg_namespace n on n.oid = p.pronamespace "
            "where n.nspname = 'note_comments_private' "
            "and p.proname = 'can_read_public_memo' "
            "and p.proargtypes = '20 2950 16'::oidvector"
        )
        row_aware_helper_count = int(cur.fetchone()[0])
        cur.execute(
            "select count(*) from pg_proc p "
            "join pg_namespace n on n.oid = p.pronamespace "
            "where n.nspname = 'note_comments_private' "
            "and p.proname = 'can_read_public_memo' "
            "and p.proargtypes = '20'::oidvector"
        )
        self_reading_helper_count = int(cur.fetchone()[0])
    conn.commit()

    owner_insert = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_OWNER,
        statement=(
            "insert into public.public_memos "
            "(note_id, user_id, title, content, is_public) "
            "values (%s, %s::uuid, 'fresh generated publication', "
            "'fresh generated memo', true) "
            "on conflict (note_id, user_id) do update "
            "set title = excluded.title returning note_id, title"
        ),
        params=(fresh_note_id, NOTE_OWNER),
    )
    if owner_insert != [(fresh_note_id, "fresh generated publication")]:
        raise AssertionError(
            f"fresh generated memo insert returning failed: {owner_insert}"
        )

    owner_conflict_update = note_comments_run_as(
        conn,
        role="authenticated",
        user_id=NOTE_OWNER,
        statement=(
            "insert into public.public_memos "
            "(note_id, user_id, title, content, is_public) "
            "values (%s, %s::uuid, 'fresh generated publication update', "
            "'fresh generated memo', true) "
            "on conflict (note_id, user_id) do update "
            "set title = excluded.title returning note_id, title"
        ),
        params=(fresh_note_id, NOTE_OWNER),
    )
    if owner_conflict_update != [
        (fresh_note_id, "fresh generated publication update")
    ]:
        raise AssertionError(
            "fresh generated memo conflict update returning failed: "
            f"{owner_conflict_update}"
        )

    outsider_upsert_sqlstate = note_comments_expect_sqlstate(
        conn,
        role="authenticated",
        user_id=NOTE_OUTSIDER,
        statement=(
            "insert into public.public_memos "
            "(note_id, user_id, title, content, is_public) "
            "values (%s, %s::uuid, 'forged generated publication', "
            "'forged generated memo', true) "
            "on conflict (note_id, user_id) do update "
            "set title = excluded.title returning note_id"
        ),
        params=(fresh_note_id, NOTE_OWNER),
        expected="42501",
    )

    anonymous_fresh_rows = note_comments_run_as(
        conn,
        role="anon",
        user_id=None,
        statement=(
            "select note_id, title from public.public_memos "
            "where note_id = %s"
        ),
        params=(fresh_note_id,),
    )
    if anonymous_fresh_rows != [
        (fresh_note_id, "fresh generated publication update")
    ]:
        raise AssertionError(
            f"fresh generated memo is not publicly readable: {anonymous_fresh_rows}"
        )

    if row_aware_helper_count != 1 or self_reading_helper_count != 0:
        raise AssertionError(
            "public memo read helper still depends on the row being written: "
            f"row_aware={row_aware_helper_count}, self_reading={self_reading_helper_count}"
        )

    return {
        "backing_note_id": backing_note_id,
        "source_key": source_key,
        "foreign_key_validated": foreign_key_validated,
        "owner_update": owner_update[0][0],
        "forged_publication_visible": False,
        "fresh_owner_insert_returning": owner_insert[0][1],
        "fresh_owner_conflict_update_returning": owner_conflict_update[0][1],
        "outsider_upsert_sqlstate": outsider_upsert_sqlstate,
        "row_aware_read_policy": True,
    }


def seed_app_analytics_security_fixture(conn: Any) -> None:
    with conn.cursor() as cur:
        cur.execute(
            "insert into public.app_analytics "
            "(date, landing_views, conversions, share_count, source_details) "
            "values ((timezone('Asia/Tokyo', now()))::date, "
            "10, 2, 2147483647, "
            "jsonb_build_object('public_memo_share', '99999999999999999999'))"
        )
        cur.execute(
            "insert into public.app_analytics "
            "(date, user_id, source, metadata) values "
            "(date '2000-01-02', %s::uuid, 'guitar-recording-studio', "
            "jsonb_build_object('title', 'private title', "
            "'filePath', 'private/path.wav', 'notes', 'private notes'))",
            (ISSUE_2773_USER_1,),
        )
    conn.commit()


def app_analytics_expect_event_rejected(
    conn: Any,
    *,
    source_key: str,
    share_increment: int,
    actor_hash: str = "a" * 64,
) -> str:
    try:
        with conn.transaction():
            with conn.cursor() as cur:
                cur.execute("set local role service_role")
                cur.execute(
                    "select public.record_app_analytics_event("
                    "%s, (timezone('Asia/Tokyo', now()))::date, %s, %s)",
                    (source_key, share_increment, actor_hash),
                )
    except Exception as exc:  # psycopg is loaded only for the integration run.
        sqlstate = getattr(exc, "sqlstate", None)
        if sqlstate != "P0001":
            raise AssertionError(
                f"expected analytics RPC SQLSTATE P0001, got {sqlstate}: {exc}"
            ) from exc
        return sqlstate
    raise AssertionError("invalid analytics event unexpectedly succeeded")


def check_app_analytics_security(conn: Any) -> dict[str, Any]:
    table_privileges = (
        "SELECT",
        "INSERT",
        "UPDATE",
        "DELETE",
        "TRUNCATE",
        "REFERENCES",
        "TRIGGER",
    )
    browser_roles = ("anon", "authenticated")

    with conn.cursor() as cur:
        cur.execute(
            "select policyname, cmd, roles::text from pg_policies "
            "where schemaname = 'public' and tablename = 'app_analytics' "
            "order by policyname"
        )
        policies = [tuple(row) for row in cur.fetchall()]
        cur.execute(
            "select p.proname, pg_get_function_identity_arguments(p.oid), "
            "p.prosecdef, coalesce(p.proconfig, array[]::text[]), "
            "pg_get_userbyid(p.proowner), "
            "not exists (select 1 from aclexplode(coalesce(p.proacl, "
            "acldefault('f', p.proowner))) acl where acl.grantee = 0 "
            "and acl.privilege_type = 'EXECUTE') "
            "from pg_proc p join pg_namespace n on n.oid = p.pronamespace "
            "where n.nspname = 'public' and p.proname = any(%s) "
            "order by p.proname, pg_get_function_identity_arguments(p.oid)",
            (
                [
                    "increment_app_analytics_source_detail",
                    "increment_share_count",
                    "record_app_analytics_event",
                ],
            ),
        )
        function_security = [tuple(row) for row in cur.fetchall()]
        cur.execute("select current_user")
        migration_owner = str(cur.fetchone()[0])
    conn.commit()

    expected_policies = [
        ("app_analytics_public_read", "SELECT", "{anon,authenticated}")
    ]
    if policies != expected_policies:
        raise AssertionError(f"unexpected app_analytics policies: {policies}")
    expected_signatures = {
        "increment_app_analytics_source_detail": "p_source_key text, p_event_date date, p_share_increment integer",
        "increment_share_count": "",
        "record_app_analytics_event": "p_source_key text, p_event_date date, p_share_increment integer, p_actor_hash text",
    }
    if len(function_security) != len(expected_signatures):
        raise AssertionError(f"unexpected analytics function overloads: {function_security}")
    for name, arguments, security_definer, proconfig, owner, public_revoked in function_security:
        if expected_signatures.get(name) != arguments:
            raise AssertionError(f"unexpected {name} signature: {arguments}")
        if not security_definer:
            raise AssertionError(f"{name} is not SECURITY DEFINER")
        if not any(str(item).startswith("search_path=") for item in proconfig):
            raise AssertionError(f"{name} search_path is not pinned: {proconfig}")
        if owner != migration_owner:
            raise AssertionError(f"{name} owner {owner} != {migration_owner}")
        if not public_revoked:
            raise AssertionError(f"PUBLIC retains EXECUTE on {name}")

    privileges: dict[str, dict[str, bool]] = {}
    with conn.cursor() as cur:
        for role in browser_roles:
            privileges[role] = {}
            for privilege in table_privileges:
                cur.execute(
                    "select has_table_privilege(%s, 'public.app_analytics', %s)",
                    (role, privilege),
                )
                actual = bool(cur.fetchone()[0])
                privileges[role][privilege] = actual
                expected = False
                if actual != expected:
                    raise AssertionError(
                        f"{role} {privilege} expected {expected}, got {actual}"
                    )
            for signature in (
                "public.increment_share_count()",
                "public.increment_app_analytics_source_detail(text,date,integer)",
                "public.record_app_analytics_event(text,date,integer,text)",
            ):
                cur.execute(
                    "select has_function_privilege(%s, %s, 'EXECUTE')",
                    (role, signature),
                )
                if bool(cur.fetchone()[0]):
                    raise AssertionError(f"{role} can execute {signature}")
            for column in (
                "date",
                "landing_views",
                "conversions",
                "share_count",
                "source_details",
            ):
                cur.execute(
                    "select has_column_privilege(%s, "
                    "'public.app_analytics', %s, 'SELECT')",
                    (role, column),
                )
                if not bool(cur.fetchone()[0]):
                    raise AssertionError(f"{role} cannot SELECT safe column {column}")
            for column in ("id", "user_id", "source", "metadata", "created_at"):
                cur.execute(
                    "select has_column_privilege(%s, "
                    "'public.app_analytics', %s, 'SELECT')",
                    (role, column),
                )
                if bool(cur.fetchone()[0]):
                    raise AssertionError(f"{role} can SELECT private column {column}")
    conn.commit()

    denied_sqlstates: dict[str, dict[str, str]] = {}
    for role in browser_roles:
        denied_sqlstates[role] = {
            "insert": issue_2773_expect_denied(
                conn,
                role=role,
                user_id=None,
                statement=(
                    "insert into public.app_analytics "
                    "(date, landing_views, conversions, share_count) "
                    "values (date '2000-01-01', 999, 999, 999)"
                ),
            ),
            "update": issue_2773_expect_denied(
                conn,
                role=role,
                user_id=None,
                statement=(
                    "update public.app_analytics set conversions = 999 "
                    "where date = current_date"
                ),
            ),
            "delete": issue_2773_expect_denied(
                conn,
                role=role,
                user_id=None,
                statement="delete from public.app_analytics where date = current_date",
            ),
        }

    private_column_sqlstate = issue_2773_expect_denied(
        conn,
        role="anon",
        user_id=None,
        statement="select metadata from public.app_analytics",
    )

    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute("set local role anon")
            cur.execute(
                "select date, landing_views, conversions, share_count, source_details "
                "from public.app_analytics"
            )
            anon_rows = list(cur.fetchall())

    first_actor = "a" * 64
    second_actor = "b" * 64
    quota_actor = "c" * 64
    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute("set local role service_role")
            cur.execute(
                "select public.record_app_analytics_event("
                "'public_memo_share', "
                "(timezone('Asia/Tokyo', now()))::date, 1, %s)",
                (first_actor,),
            )
            first_recorded = bool(cur.fetchone()[0])
            cur.execute(
                "select public.record_app_analytics_event("
                "'public_memo_share', "
                "(timezone('Asia/Tokyo', now()))::date, 1, %s)",
                (first_actor,),
            )
            duplicate_recorded = bool(cur.fetchone()[0])
            cur.execute(
                "select public.record_app_analytics_event("
                "'public_memo_share', "
                "(timezone('Asia/Tokyo', now()))::date, 1, %s)",
                (second_actor,),
            )
            second_recorded = bool(cur.fetchone()[0])
            cur.execute(
                "select count(*) from public.app_analytics_event_receipts "
                "where event_date = (timezone('Asia/Tokyo', now()))::date "
                "and source_key = 'public_memo_share'"
            )
            receipt_count = int(cur.fetchone()[0])
            cur.execute(
                "insert into public.app_analytics_event_receipts "
                "(event_date, source_key, actor_hash) "
                "select (timezone('Asia/Tokyo', now()))::date, "
                "'quota-fixture-' || value, %s "
                "from generate_series(1, 32) value",
                (quota_actor,),
            )
            cur.execute(
                "select public.record_app_analytics_event("
                "'public_memo_copy', "
                "(timezone('Asia/Tokyo', now()))::date, 1, %s)",
                (quota_actor,),
            )
            over_quota_recorded = bool(cur.fetchone()[0])

    invalid_source_sqlstate = app_analytics_expect_event_rejected(
        conn,
        source_key="attacker_controlled_metric",
        share_increment=0,
    )
    oversized_increment_sqlstate = app_analytics_expect_event_rejected(
        conn,
        source_key="public_memo_share",
        share_increment=2,
    )

    with conn.cursor() as cur:
        cur.execute(
            "select share_count, source_details ->> 'public_memo_share' "
            "from public.app_analytics "
            "where date = (timezone('Asia/Tokyo', now()))::date"
        )
        row = cur.fetchone()
    conn.commit()
    if row is None or int(row[0]) != 2147483647 or int(row[1]) != 2:
        raise AssertionError(f"idempotent analytics RPC returned unexpected row: {row}")
    if len(anon_rows) != 1:
        raise AssertionError(f"anon SELECT returned unsafe rows: {anon_rows}")
    if not first_recorded or duplicate_recorded or not second_recorded:
        raise AssertionError(
            "analytics receipt idempotency failed: "
            f"{first_recorded=}, {duplicate_recorded=}, {second_recorded=}"
        )
    if receipt_count != 2:
        raise AssertionError(f"expected two analytics receipts, got {receipt_count}")
    if over_quota_recorded:
        raise AssertionError("actor/day analytics quota was bypassed")

    service_role_privileges: dict[str, bool] = {}
    with conn.cursor() as cur:
        for privilege in ("SELECT", "INSERT", "UPDATE", "DELETE"):
            cur.execute(
                "select has_table_privilege('service_role', "
                "'public.app_analytics', %s)",
                (privilege,),
            )
            service_role_privileges[privilege] = bool(cur.fetchone()[0])
    conn.commit()
    if not all(service_role_privileges.values()):
        raise AssertionError(
            f"service_role app_analytics DML regressed: {service_role_privileges}"
        )

    return {
        "policies": policies,
        "browser_privileges": privileges,
        "raw_write_sqlstates": denied_sqlstates,
        "function_security": function_security,
        "private_column_sqlstate": private_column_sqlstate,
        "public_row_count": len(anon_rows),
        "service_role_privileges": service_role_privileges,
        "event_receipts": {
            "first_recorded": first_recorded,
            "duplicate_recorded": duplicate_recorded,
            "second_recorded": second_recorded,
            "receipt_count": receipt_count,
            "over_quota_recorded": over_quota_recorded,
        },
        "rpc_row": {"share_count": int(row[0]), "public_memo_share": int(row[1])},
        "invalid_source_sqlstate": invalid_source_sqlstate,
        "oversized_increment_sqlstate": oversized_increment_sqlstate,
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


def seed_tax_records_fixture(conn: Any) -> None:
    with conn.cursor() as cur:
        cur.executemany(
            "insert into public.tax_records "
            "(id, user_id, year, type, amount, category, evidence_url) "
            "values (%s::uuid, %s::uuid, %s, %s, %s, %s, %s)",
            [
                (
                    TAX_RECORD_1,
                    ISSUE_2773_USER_1,
                    2026,
                    "business",
                    "120000.0000",
                    "consulting",
                    "https://example.invalid/evidence/owner-one",
                ),
                (
                    TAX_RECORD_2,
                    ISSUE_2773_USER_2,
                    2026,
                    "furusato",
                    "20000.0000",
                    "donation",
                    None,
                ),
            ],
        )
    conn.commit()


def tax_records_role_count(
    conn: Any,
    role: str,
    user_id: str | None,
    table: str,
) -> int:
    if role not in {"anon", "authenticated", "service_role"}:
        raise ValueError(f"unexpected role for tax records query: {role}")
    if table not in TAX_RECORDS_TABLES:
        raise ValueError(f"unexpected table for tax records query: {table}")
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


def check_tax_records_rls(conn: Any) -> dict[str, Any]:
    with conn.cursor() as cur:
        cur.execute(
            "select c.relname from pg_class c "
            "join pg_namespace n on n.oid = c.relnamespace "
            "where n.nspname = 'public' and c.relname = any(%s) "
            "and c.relrowsecurity order by c.relname",
            (list(TAX_RECORDS_TABLES),),
        )
        enabled_tables = [row[0] for row in cur.fetchall()]
        cur.execute(
            "select policyname from pg_policies where schemaname = 'public' "
            "and tablename = 'tax_records' order by policyname"
        )
        policy_names = [row[0] for row in cur.fetchall()]
    conn.commit()

    if enabled_tables != ["tax_records"]:
        raise AssertionError(f"tax records RLS was not enabled: {enabled_tables}")

    expected_policies = {
        f"tax_records_{operation}_own"
        for operation in ("select", "insert", "update", "delete")
    }
    if set(policy_names) != expected_policies:
        raise AssertionError(f"unexpected tax records policy set: {policy_names}")

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
        for privilege in table_privileges:
            cur.execute(
                "select has_table_privilege(%s, %s, %s)",
                ("anon", "public.tax_records", privilege),
            )
            if bool(cur.fetchone()[0]):
                raise AssertionError(f"anon retained {privilege} on tax_records")
            cur.execute(
                "select has_table_privilege(%s, %s, %s)",
                ("authenticated", "public.tax_records", privilege),
            )
            actual = bool(cur.fetchone()[0])
            expected = privilege in authenticated_grants
            if actual != expected:
                raise AssertionError(
                    "authenticated privilege mismatch on tax_records: "
                    f"{privilege} expected {expected}, got {actual}"
                )
    conn.commit()

    missing_claim_count = tax_records_role_count(
        conn,
        "authenticated",
        None,
        "tax_records",
    )
    if missing_claim_count != 0:
        raise AssertionError(
            f"missing tenant claim exposed tax records: {missing_claim_count}"
        )

    owner_count = tax_records_role_count(
        conn,
        "authenticated",
        ISSUE_2773_USER_1,
        "tax_records",
    )
    if owner_count != 1:
        raise AssertionError(f"tax record tenant filtering failed: {owner_count}")

    forged_owner_sqlstate = issue_2773_expect_denied(
        conn,
        role="authenticated",
        user_id=ISSUE_2773_USER_1,
        statement=(
            "insert into public.tax_records "
            "(user_id, year, type, amount, category) "
            "values (%s::uuid, 2026, 'medical', 1000, 'forged owner')"
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
                "insert into public.tax_records "
                "(user_id, year, type, amount, category) "
                "values (%s::uuid, 2026, 'medical', 0, 'owner smoke') "
                "returning id",
                (ISSUE_2773_USER_1,),
            )
            temporary_record = cur.fetchone()[0]
            cur.execute(
                "update public.tax_records set category = 'owner updated' "
                "where id = %s",
                (temporary_record,),
            )
            cur.execute(
                "delete from public.tax_records where id = %s",
                (temporary_record,),
            )

    issue_2773_expect_denied(
        conn,
        role="anon",
        user_id=None,
        statement="select count(*) from public.tax_records",
    )

    return {
        "enabled_tables": enabled_tables,
        "policies": policy_names,
        "missing_claim_count": missing_claim_count,
        "owner_count": owner_count,
        "forged_owner_sqlstate": forged_owner_sqlstate,
        "owner_crud": "passed",
        "anon_access": "denied",
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

    analytics_check = run_command(
        [
            "deno",
            "check",
            "--config",
            "supabase/functions/deno.json",
            str(APP_ANALYTICS_EDGE_FUNCTION.relative_to(ROOT)),
        ],
        artifacts_dir=artifacts_dir,
        log_name="deno-check-app-analytics-edge.log",
        timeout_seconds=180,
    )
    if analytics_check.returncode != 0:
        raise RuntimeError(
            "App analytics Edge type-check failed; "
            "see deno-check-app-analytics-edge.log"
        )

    analytics_tests = run_command(
        [
            "deno",
            "test",
            "--config",
            "supabase/functions/deno.json",
            *(str(path.relative_to(ROOT)) for path in APP_ANALYTICS_EDGE_TESTS),
        ],
        artifacts_dir=artifacts_dir,
        log_name="deno-test-app-analytics-edge.log",
        timeout_seconds=180,
    )
    if analytics_tests.returncode != 0:
        raise RuntimeError(
            "App analytics Edge tests failed; see deno-test-app-analytics-edge.log"
        )


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
            seed_ai_university_legacy_fixture(conn)
            apply_sql_fixture(conn, AI_UNIVERSITY_MIGRATION, artifacts_dir)
            apply_sql_fixture(conn, AI_UNIVERSITY_MIGRATION, artifacts_dir)
            ai_university = check_ai_university_migration(conn)
            apply_sql_fixture(conn, AGENTLESS_COURSE_MIGRATION, artifacts_dir)
            apply_sql_fixture(conn, AGENTLESS_COURSE_MIGRATION, artifacts_dir)
            agentless_course = check_agentless_course_migration(conn)
            apply_sql_fixture(conn, ISSUE_2773_RLS_MIGRATION, artifacts_dir)
            seed_issue_2773_fixture(conn)
            tenant_rls = check_issue_2773_rls(conn)
            seed_app_analytics_security_fixture(conn)
            apply_sql_fixture(conn, APP_ANALYTICS_SECURITY_MIGRATION, artifacts_dir)
            apply_sql_fixture(conn, APP_ANALYTICS_SECURITY_MIGRATION, artifacts_dir)
            app_analytics_security = check_app_analytics_security(conn)
            seed_note_comments_security_fixture(conn)
            apply_sql_fixture(conn, NOTE_COMMENTS_SECURITY_MIGRATION, artifacts_dir)
            apply_sql_fixture(conn, NOTE_COMMENTS_SECURITY_MIGRATION, artifacts_dir)
            note_comments_security = check_note_comments_security(conn)
            apply_sql_fixture(conn, GENERATED_MEMO_REPAIR_MIGRATION, artifacts_dir)
            apply_sql_fixture(conn, GENERATED_MEMO_REPAIR_MIGRATION, artifacts_dir)
            apply_sql_fixture(conn, PUBLIC_MEMO_RETURNING_RLS_MIGRATION, artifacts_dir)
            apply_sql_fixture(conn, PUBLIC_MEMO_RETURNING_RLS_MIGRATION, artifacts_dir)
            generated_memo_repair = check_generated_memo_repair(conn)
            apply_sql_fixture(conn, VOICE_DUBBING_BOOTSTRAP, artifacts_dir)
            apply_sql_fixture(conn, BILLING_MIGRATION, artifacts_dir)
            apply_sql_fixture(conn, VOICE_DUBBING_MIGRATION, artifacts_dir)
            apply_sql_fixture(conn, VOICE_DUBBING_MIGRATION, artifacts_dir)
            apply_sql_fixture(conn, VOICE_DUBBING_CONTRACT, artifacts_dir)
            apply_sql_fixture(
                conn,
                ISSUE_1233_RESOURCE_OPTIMIZER_SQL_FILES[0],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_1233_RESOURCE_OPTIMIZER_SQL_FILES[1],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_1233_RESOURCE_OPTIMIZER_SQL_FILES[2],
                artifacts_dir,
            )
            for migration in ISSUE_1233_REAPPLIED_MIGRATIONS:
                apply_sql_fixture(conn, migration, artifacts_dir)
                apply_sql_fixture(conn, migration, artifacts_dir)
            apply_sql_fixture(
                conn,
                ISSUE_1233_RESOURCE_OPTIMIZER_SQL_FILES[-1],
                artifacts_dir,
            )
            issue_1233_quota_concurrency = check_issue_1233_ai_quota_concurrency(
                conn,
                connection_url,
                psycopg.connect,
            )
            apply_sql_fixture(
                conn,
                ISSUE_4956_WBS_ADMIN_REVIEW_SQL_FILES[0],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_4956_WBS_ADMIN_REVIEW_SQL_FILES[1],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_4956_WBS_ADMIN_REVIEW_SQL_FILES[1],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_4956_WBS_ADMIN_REVIEW_SQL_FILES[2],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_2921_AGENT_MODULE_HANDOFF_SQL_FILES[0],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_2921_AGENT_MODULE_HANDOFF_SQL_FILES[1],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_2921_AGENT_MODULE_HANDOFF_SQL_FILES[1],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_2921_AGENT_MODULE_HANDOFF_SQL_FILES[2],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_4927_RECURRING_TOMBSTONE_SQL_FILES[0],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_4927_RECURRING_TOMBSTONE_SQL_FILES[1],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_4927_RECURRING_TOMBSTONE_SQL_FILES[1],
                artifacts_dir,
            )
            apply_sql_fixture(
                conn,
                ISSUE_4927_RECURRING_TOMBSTONE_SQL_FILES[2],
                artifacts_dir,
            )
            issue_4927_tombstone_concurrency = (
                check_issue_4927_tombstone_concurrency(
                    conn,
                    connection_url,
                    psycopg.connect,
                )
            )
            for issue_2844_sql in ISSUE_2844_ACCOUNT_DELETION_SQL_FILES:
                apply_sql_fixture(conn, issue_2844_sql, artifacts_dir)
            apply_sql_fixture(conn, ASSET_CHAT_MIGRATION, artifacts_dir)
            seed_asset_chat_fixture(conn)
            asset_chat_rls = check_asset_chat_rls(conn)
            apply_sql_fixture(conn, TAX_RECORDS_MIGRATION, artifacts_dir)
            seed_tax_records_fixture(conn)
            tax_records_rls = check_tax_records_rls(conn)
            for video_sql in VIDEO_ARTIFACT_SQL_FILES:
                apply_sql_fixture(conn, video_sql, artifacts_dir)
            counts = {table: table_count(conn, table) for table in REQUIRED_TABLES}

        edge_result = run_edge_db_fixture(connection_url, args, artifacts_dir)

    summary = {
        "status": "passed",
        "database": {
            "url": redact_url(connection_url),
            "tables": counts,
            "tenant_rls": tenant_rls,
            "app_analytics_security": app_analytics_security,
            "note_comments_security": note_comments_security,
            "generated_memo_repair": generated_memo_repair,
            "asset_chat_rls": asset_chat_rls,
            "tax_records_rls": tax_records_rls,
            "ai_university": ai_university,
            "agentless_course": agentless_course,
            "voice_dubbing_quota_contract": "passed",
            "issue_1233_resource_optimizer_contract": "passed",
            "issue_1233_ai_quota_concurrency": issue_1233_quota_concurrency,
            "issue_4956_wbs_admin_review_contract": "passed",
            "issue_2921_agent_module_handoff_contract": "passed",
            "issue_4927_recurring_tombstone_contract": (
                issue_4927_tombstone_concurrency
            ),
            "issue_2844_account_deletion_contract": "passed",
            "video_artifact_contract": "passed",
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
