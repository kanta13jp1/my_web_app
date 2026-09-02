# Supabase Compute and Database Capacity Plan

Status: proposed operational baseline for Issue #2861

Owner: repository owner / production database owner

Last verified against vendor documentation: 2026-09-03

## 1. Scope and safety boundary

This runbook covers hosted Supabase Postgres compute and database capacity. It
does not authorize a production query, data deletion, plan change, compute
resize, disk resize, Spend Cap change, or credential creation. Those actions
need the explicit approvals in section 6 and a separate reviewed change record.

The Issue describes the project as Free. That assertion must be rechecked in
the Supabase organization and project dashboards at every review. If current
plan evidence is unavailable, use the Free limits below as the conservative
planning baseline and record the actual plan as `unknown`; never assume that a
paid quota or automatic disk scaling is available.

## 2. Vendor baseline

As of the verification date, the official Supabase documentation states:

| Resource | Free baseline | Planning consequence |
| --- | --- | --- |
| Compute | Nano, shared CPU, up to 0.5 GB memory | Treat sustained CPU, memory, swap, or I/O pressure as a right-sizing signal. |
| Database size | 500 MB per project | A Free project can enter read-only mode when database size exceeds 500 MB. |
| Physical disk | 1 GB included for a Free project | Free enforcement is based on the 500 MB database-size quota, not physical disk utilization. |
| Connections | 60 direct database connections and 200 pooler clients for Nano | Use the current configured limit if it differs; these vendor values are the default planning baseline. |

Database and disk are different measurements. Database size is tables,
indexes, and materialized views. Disk also includes WAL and system files.
Supabase's disk metrics are updated daily, so a single dashboard point is not a
real-time alert and must not be presented as one.

Primary sources:

- [Compute and Disk](https://supabase.com/docs/guides/platform/compute-and-disk)
- [Understanding Database and Disk Size](https://supabase.com/docs/guides/platform/database-size)
- [Reports](https://supabase.com/docs/guides/monitoring-and-debugging/reports)
- [Metrics API](https://supabase.com/docs/guides/monitoring-and-debugging/metrics)
- [Billing on Supabase](https://supabase.com/docs/guides/platform/billing-on-supabase)

The values above are a dated snapshot, not a price guarantee. Recheck all
limits, prices, downtime warnings, and plan behavior from those primary sources
before approving a change.

## 3. Capacity evidence and alert thresholds

### Evidence cadence

The production owner records one capacity snapshot every Monday and also:

- before and 24 hours after a release, import, or backfill expected to change
  database size by at least 5%;
- immediately after a Supabase quota, read-only, resource exhaustion, or
  sustained latency notification;
- daily while any metric is at `ACTION` or `CRITICAL`.

The snapshot contains no row data or secrets. Record only: project reference,
observed plan and compute size, collection time in UTC, database bytes, disk
distribution, 7-day and 30-day growth, CPU and memory percentiles, swap,
connections, disk I/O budget, source URL or screenshot location, collector,
and related Issue. Store privileged Metrics API credentials only in an approved
secret manager. The API is beta, so metric-name changes must fail closed and
open an operator task rather than silently reporting green.

For a Free 500 MB database quota, apply these thresholds:

| State | Database-size trigger | Forecast trigger | Required action |
| --- | --- | --- | --- |
| `NORMAL` | below 70% (below 350 MB) | more than 30 days to quota | Keep weekly evidence. |
| `WATCH` | at least 70% (350 MB) | 30 days or less to quota | Inspect largest tables and growth source within two business days. |
| `ACTION` | at least 80% (400 MB) | 14 days or less to quota | Open/update one capacity Issue, freeze nonessential imports, and prepare cleanup or scale approval. |
| `CRITICAL` | at least 90% (450 MB) | 7 days or less to quota | Same-day owner decision and incident readiness; do not wait for the weekly review. |
| `INCIDENT` | at least 100% (500 MB), read-only, or quota response | quota reached | Follow the incident SOP and vendor recovery guidance. |

Forecast days are `remaining quota bytes / max(7-day daily growth, 30-day
daily growth)`. If history is missing or growth is zero/negative, record the
forecast as `unknown`; a missing forecast never lowers a size-based state.

Use these internal compute thresholds with the built-in Database report or an
approved Metrics API collector. They are operational thresholds, not Supabase
contractual limits:

| Signal | `WATCH` | `ACTION` | `CRITICAL` |
| --- | --- | --- | --- |
| CPU or memory | p95 at least 70% for 30 minutes | p95 at least 80% for 30 minutes in two review windows | p95 at least 90% for 15 minutes, or sustained swap for 15 minutes |
| Direct connections (Free baseline 60) | 42 | 48 | 54 |
| Pooler clients (Free baseline 200) | 140 | 160 | 180 |
| Daily `Disk IO % consumed` | above 1% | at least 25% on two consecutive days | at least 80% once, or 100% exhausted |

Any production error or latency regression can raise the state even when these
numbers are lower. Alerts must identify the metric, value, duration, project,
threshold version, and evidence time, and must never contain credentials or
customer data. Deduplicate on project + metric + state; notify only on state
change, recovery, failure, or required owner action.

### Read-only inspection

The Database report is the default collection surface. If the database owner
approves SQL inspection, use read-only size queries such as
`pg_database_size(current_database())` and `pg_total_relation_size(...)`.
Do not embed a database password or service-role key in a report, workflow,
artifact, or Issue.

## 4. Cleanup batch requirements

Cleanup is a separately reviewed production database change, not an automatic
reaction to an alert. Each candidate dataset must have all of the following
before a delete job can be enabled:

1. A named data owner and a documented product, tax, legal, audit, privacy, and
   account-deletion retention decision. An unset retention period means
   deletion is blocked.
2. A read-only dry-run that reports candidate row count, estimated bytes,
   oldest/newest timestamp, tenant scope, and exclusion reasons without row
   content.
3. A verified backup/export and restore test that covers the candidate data.
4. A reviewed predicate, immutable cutoff timestamp, stable cursor, tenant and
   RLS boundary, idempotency rule, and rollback/reconciliation procedure.
5. Bounded execution: at most 1,000 rows and 30 seconds per transaction, at
   most 10,000 rows per run, a two-second pause between batches, and immediate
   stop on timeout, lock contention, replica lag, error, or threshold breach.
6. Before/after row counts and database bytes, run ID, approver, code SHA, and
   next cursor retained as evidence. Partial runs resume from the saved cursor;
   they do not restart an unbounded delete.

Candidate classes are expired idempotency/event records, superseded derived
snapshots, orphaned temporary uploads, and historical operational logs. They
remain `BLOCKED` until the actual repository table, owner, and retention period
are mapped in a dedicated Issue and migration/worker PR.

Keep autovacuum enabled. A normal `VACUUM (ANALYZE)` may be scheduled after a
large reviewed deletion, but deletion does not guarantee an immediate decrease
in physical disk. `VACUUM FULL` takes an exclusive table lock and is prohibited
during normal production operation; it requires its own downtime plan,
capacity headroom check, backup evidence, and explicit database-owner approval.

## 5. Decision rules

- Prefer query/index correction, payload reduction, retention enforcement, or
  safe archival when evidence identifies waste.
- Do not delete authoritative business, financial, account, audit, or consent
  data merely to return a graph to green.
- Start scale review at one `CRITICAL` snapshot, two consecutive `ACTION`
  snapshots, or a forecast of 14 days or less.
- Select compute for measured CPU/memory/connection/I/O pressure and database
  capacity for measured data growth. Increasing one does not automatically fix
  the other.
- Free-to-paid and add-on prices are re-quoted at approval time. No workflow or
  agent may accept charges or disable a Spend Cap on the owner's behalf.

## 6. Scale-up approval and change procedure

1. **Evidence** — production database owner attaches the current plan, compute
   size, quota, 7/30-day trend, largest contributors, report screenshots, and
   affected service-level evidence to one Issue.
2. **Options** — compare no-change, optimization/cleanup, archival, and paid
   scale paths. Record monthly and worst-case cost, quota, operational limits,
   downtime, data-protection impact, and why the selected option is necessary.
3. **Approvals** — repository owner acknowledges the production change;
   database/security owner approves data and credential handling; budget owner
   explicitly approves any subscription, compute, disk, IOPS, throughput, or
   Spend Cap cost. One person may fill multiple roles, but every acknowledgement
   must be recorded separately in the Issue.
4. **Preflight** — recheck vendor documentation, confirm backup plus restore
   evidence using `SUPABASE_BACKUP_RESTORE_RUNBOOK.md`, capture a baseline,
   announce a maintenance window, freeze migrations/imports, and define abort
   criteria. A compute-size change can incur downtime.
5. **Change** — the human project owner makes the approved change in Supabase
   Compute and Disk / Infrastructure settings. Automation may observe and
   verify but may not purchase, resize, or change billing controls.
6. **Verify** — confirm availability, writes, migrations, RLS smoke evidence,
   CPU/memory/connections/I/O, database size, billing configuration, and the
   Supabase operation status. Observe for at least one normal traffic window.
7. **Close** — attach before/after evidence and the invoice estimate. Update
   this runbook if the new plan or limits make the Free thresholds obsolete.

Disk increases cannot be treated as automatically reversible. If validation
fails, stop new write-heavy jobs, execute the approved application rollback or
restore plan, contact Supabase support when the platform change is incomplete,
and keep the incident open. Do not improvise a downgrade or project migration
during an outage.

## 7. Review checklist

- [ ] Current organization plan and project compute size are evidenced, not
      copied from an old Issue.
- [ ] Current vendor limits and pricing were rechecked from primary sources.
- [ ] Weekly database-size and growth evidence exists and is no more than eight
      days old.
- [ ] Every `ACTION` or `CRITICAL` state has exactly one live Issue and owner.
- [ ] Cleanup remains blocked without retention, backup/restore, dry-run, and
      explicit approval evidence.
- [ ] No database, billing, Spend Cap, compute, disk, IOPS, or throughput change
      ran automatically.

Related runbooks: [production monitoring](PRODUCTION_MONITORING_RUNBOOK.md),
[incident response](ONCALL_INCIDENT_SOP.md), and
[backup/restore](SUPABASE_BACKUP_RESTORE_RUNBOOK.md).
