# Daily Report Freshness Guard

Issue: #1447

## Problem

The 2026-04-30 daily report was generated, but a schedule monitor opened a
false alarm because it relied on a narrow git-log query. The durable completion
signals are not a single author or commit subject.

## Source Of Truth

`daily-report` is considered fresh when the current JST date has a report file
and at least one corroborating signal:

- `docs/daily-reports/YYYY-MM-DD.md`
- `docs/schedule-logs/daily-report-YYYY-MM-DD-00.json`
- `docs/metrics/daily-metrics.json`

Use `scripts/check_daily_report_freshness.py` instead of author-only grep:

```bash
git fetch origin main --quiet
python scripts/check_daily_report_freshness.py --ref origin/main --json
```

## Automation

`cs-check.yml` now runs the freshness guard every hour and records the result in
both the GitHub Step Summary and `schedule_task_runs` summary. A stale
daily-report result downgrades the CS check status to `partial` without failing
the whole workflow, leaving room for the existing recovery lanes to continue.

## Agent Handoff

- Codex #2 owns deterministic schedule monitors and false-positive reduction.
- Claude Schedule owns the narrative report and AI analysis sections.
- Claude Code `/ultrareview` is only needed if this guard grows into a broader
  schedule recovery redesign.
