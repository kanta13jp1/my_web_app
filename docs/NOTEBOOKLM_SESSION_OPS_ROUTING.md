# NotebookLM Session-Ops Routing

Issue: #1638

This runbook keeps Claude Code operations notebooks useful without letting
NotebookLM become an unreviewed source of implementation facts.

## Operating Rule

NotebookLM is advisory memory. A NotebookLM item can influence repo work only
when it is connected to at least one of these:

- an official source signal captured by `docs/ai-tool-watch/latest-report.md`
- an AI Tool Watch routing group such as `hooks`, `schedule`, or `quality-cost`
- an existing GitHub Issue, repo doc, hook, script, config, or workflow

The current route manifest is:

- `config/notebooklm-session-ops-routes.json`

The validation command is:

```powershell
python scripts/check_notebooklm_session_ops_routes.py
```

## Two-Instance Boundary

Active development lanes are only:

- Claude Code #1: ambiguous design, review policy, architecture, and local
  Claude settings that require interactive confirmation.
- Codex #1: scoped implementation, CI proof, repo config, docs, scripts, and
  GitHub Actions checks.

Old Codex #2/#3 lanes must stay dormant. If an old NotebookLM route mentions a
legacy lane, Codex #1 absorbs the implementation side and records the active
two-instance owner in the manifest.

## Route Groups

The manifest maps session-ops notebooks into concrete repo surfaces:

- agentic workflow: `docs/CLAUDE_CODE_MASTERCLASS_AGENTIC_WORKFLOW.md`,
  `docs/DEV_PROCESS_MULTI_AI.md`, and `config/context-injection-map.json`
- schedule automation: `docs/SCHEDULE_TASKS.md` and
  `.github/workflows/schedule-resilience-watch.yml`
- memory and hooks: `docs/CODEX_MEMORY_AUTOMATIONS.md`,
  `docs/PRECOMPACT_MEMORY_BACKUP_SPEC.md`, and `scripts/codex_session_check.py`
- Remote Control: `docs/INSTANCE_CONFIG.md` and
  `scripts/codex_session_check.py`
- blog/news automation: `docs/BLOG_NEWS_AUTOMATION_RUNBOOK.md` and
  `.github/workflows/blog-news-prod-smoke.yml`
- Second Brain: `docs/SECOND_BRAIN_PRINCIPLES.md`,
  `docs/OBSIDIAN_INGEST_PIPELINE.md`, and `docs/NOTEBOOKLM_GUIDE.md`
- cost controls: `docs/AI_FALLBACK_RUNBOOK.md` and
  `docs/AGENT_TOOL_POLICY.md`

## Session Checklist

1. Read `docs/notebooklm-intake/latest-report.md`.
2. Confirm the item is routed to an existing Issue or has an explicit skip.
3. Read `docs/ai-tool-watch/latest-report.md` for official source signals.
4. Update the manifest only when the target doc/config/workflow exists.
5. Run `python scripts/check_notebooklm_session_ops_routes.py`.
6. Put the PR through normal CI and keep #1638 open unless every route has
   shipped and any local Claude settings are manually verified.
