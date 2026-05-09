# AI Tool Watch Report

- Checked at: `2026-05-09T21:30:36Z`
- Previous check: `2026-05-08T21:37:47Z`
- Changed/new official sources: `4`
- Active routing groups: `codex-runtime, hooks, integration, quality-cost, schedule`

## Session Start Summary
- `changed` Claude Code changelog: 2.1.138 / May 9, 2026
- `changed` Codex changelog: 2026-05-07 / Codex for Chrome With the new extension for Chrome, Codex is even better at working with ap
- `changed` Gemini Code Assist release notes: VS Code Gemini Code Assist 2.81.0 / May 08, 2026
- `changed` Devin release notes: May 8, 2026

## Recommended Actions
- **codex-runtime** (#1422, #1377, #1375, #1408): Route to Codex execution: use newer models for broad refactors, in-app browser for UI verification, and worktrees for parallel fixes.
- **hooks** (#1422, #1337, #1350): Route to Claude Code quality gates: SessionStart/UserPromptSubmit for session context, PostToolUse/Stop for lint-test feedback.
- **integration** (#1339, #1335, #1405): Route to connector reliability: MCP/Slack/GitHub integration checks and NotebookLM knowledge capture.
- **quality-cost** (#1380, #1374, #1336, #1352): Route to cost and safety controls: deny-by-default checks, budget routing, and telemetry before wider automation.
- **schedule** (#1422, #862, #1307, #1372): Route to GitHub Actions or Codex Automations: daily source watch, merge-backlog triage, and deterministic CI/deploy checks.

## Official Source Signals
- **Claude Code changelog** (HTTP 200)
  - URL: https://code.claude.com/docs/en/changelog
  - Latest signal: 2.1.138 / May 9, 2026
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Navigation Getting started Changelog Getting started Build with Claude Code Administration Configuration Reference Agent SDK What's New Resources Getting started Overview...
  - Short signal: This page is generated from the CHANGELOG.md on GitHub .
- **Claude Code hooks reference** (HTTP 200)
  - URL: https://code.claude.com/docs/en/hooks
  - Latest signal: Hooks reference - Claude Code Docs Skip to main content Claude Code Docs home page English
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Hooks reference - Claude Code Docs Skip to main content Claude Code Docs home page English Search...
  - Short signal: Navigation Reference Hooks reference Getting started Build with Claude Code Administration Configuration Reference Agent SDK What's New Resources Reference CLI reference...
- **Claude Code GitHub Actions** (HTTP 200)
  - URL: https://code.claude.com/docs/en/github-actions
  - Latest signal: Claude Code GitHub Actions - Claude Code Docs Skip to main content Claude Code Docs home pa
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Claude Code GitHub Actions - Claude Code Docs Skip to main content Claude Code Docs home page English Search...
  - Short signal: Navigation Code review & CI/CD Claude Code GitHub Actions Getting started Build with Claude Code Administration Configuration Reference Agent SDK What's New Resources Getting...
- **Codex changelog** (HTTP 200)
  - URL: https://developers.openai.com/codex/changelog
  - Latest signal: 2026-05-07 / Codex for Chrome With the new extension for Chrome, Codex is even better at working with ap
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Changelog – Codex | OpenAI Developers Home API Docs Guides and concepts for the OpenAI API API reference Endpoints, parameters, and responses Codex Docs Guides, concepts, and...
  - Short signal: April 2026 li+li]:mt-12"> 2026-04-23 GPT-5.5 and Codex app updates GPT-5.5 is now available in Codex as OpenAI’s newest frontier model for complex coding, computer use,...
- **Codex use cases** (HTTP 200)
  - URL: https://developers.openai.com/codex/use-cases/
  - Latest signal: Codex use cases Home API Docs Guides and concepts for the OpenAI API API reference Endpoint
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Codex use cases Home API Docs Guides and concepts for the OpenAI API API reference Endpoints, parameters, and responses Codex Docs Guides, concepts, and product docs for Codex...
  - Short signal: Web development Turn design inputs into responsive UI, and iterate on the frontend with scoped changes and fast reviews.
- **Codex overview** (HTTP 403)
  - URL: https://openai.com/codex/
  - Latest signal: No title detected
  - Keyword groups: none
- **Cursor changelog** (HTTP 200)
  - URL: https://cursor.com/changelog
  - Latest signal: 3.3 / May 7, 2026
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: What's New in Cursor — Latest Updates & Release Notes Skip to content Cursor Product ↓ Agents Code Review Cloud ↗ Tab CLI Marketplace ↗ Enterprise Pricing Resources ↓ Changelog...
  - Short signal: # PR review A new PR review experience is now available in Cursor 3.
- **Gemini Code Assist release notes** (HTTP 200)
  - URL: https://developers.google.com/gemini-code-assist/resources/release-notes
  - Latest signal: VS Code Gemini Code Assist 2.81.0 / May 08, 2026
  - Keyword groups: hooks, schedule, integration, quality-cost
  - Short signal: Gemini Code Assist release notes | Google for Developers Skip to main content Gemini Code Assist / English Deutsch Español Français Indonesia Português – Brasil Русский 中文 – 简体...
  - Short signal: Page Summary outlined_flag As of October 14, 2025, Gemini Code Assist tools are no longer available and are replaced by agent mode (Preview).
- **Devin release notes** (HTTP 200)
  - URL: https://docs.devin.ai/release-notes
  - Latest signal: May 8, 2026
  - Keyword groups: schedule, codex-runtime, integration, quality-cost
  - Short signal: ​ May 8, 2026 Devin Review API You can now trigger Devin Review programmatically via the REST API.
  - Short signal: Use POST /v3/organizations/{org_id}/pr-reviews with a service user token or PAT to initiate reviews from CI pipelines, scripts, or custom integrations.

## NotebookLM Harness Mapping
- Source notebook: `Codex vs Claude Code: The Ultimate AI Development Synergy` (`bc58b50b-5fc4-4840-9a62-b397d6d3b65a`)
- **Claude Code**: Claude Code #1 owns problem framing, architecture, review gates, and hook design.
- **Codex #1**: Owns cross-cutting implementation, SQL/migration review, UI/browser QA, CI repair, Edge Functions, GitHub Actions, and legacy Codex #2/#3 implementation lanes.
- **GitHub Actions**: Owns reproducible proof: lint, tests, deploy checks, stale-audit jobs, and report artifacts.
- **NotebookLM**: Acts as external memory and Master Brain; it informs routing but does not replace repository checks.
- Practical rule: every detected tool change must become a WBS route, GitHub issue, hook, workflow check, or PR; notes alone are not complete.

## 2-Instance Routing Reminder
- Claude Code #1 takes ambiguous design, architecture, review policy, and cross-instance coordination.
- Codex #1 takes scoped implementation, CI/deploy unblockers, Edge Functions, GitHub Actions, and broad repo scans that need a clean worktree.
- Legacy Codex #2/#3 lanes are absorbed by Codex #1; do not start extra instances for changelog follow-up work.
- Rebalance owners when the WBS top-20 contains repeated manual work, repeated CI failures, or stale handoffs.

<!-- generated-by: scripts/ai_tool_watch.py -->
