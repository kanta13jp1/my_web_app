# AI Tool Watch Report

- Checked at: `2026-05-18T21:43:40Z`
- Previous check: `2026-05-17T21:36:13Z`
- Changed/new official sources: `3`
- Active routing groups: `codex-runtime, hooks, integration, quality-cost, schedule`

## Session Start Summary
- `changed` Codex changelog: 2026-05-18 / Codex CLI 0.131.0 pre
- `changed` Cursor changelog: 3.4 / May 13, 2026
- `changed` Devin release notes: May 17, 2026

## Recommended Actions
- **codex-runtime** (#1422, #1377, #1375, #1408): Route to Codex execution: use newer models for broad refactors, in-app browser for UI verification, and worktrees for parallel fixes.
- **hooks** (#1422, #1337, #1350): Route to Claude Code quality gates: SessionStart/UserPromptSubmit for session context, PostToolUse/Stop for lint-test feedback.
- **integration** (#1339, #1335, #1405): Route to connector reliability: MCP/Slack/GitHub integration checks and NotebookLM knowledge capture.
- **quality-cost** (#1380, #1374, #1336, #1352): Route to cost and safety controls: deny-by-default checks, budget routing, and telemetry before wider automation.
- **schedule** (#1422, #862, #1307, #1372): Route to GitHub Actions or Codex Automations: daily source watch, merge-backlog triage, and deterministic CI/deploy checks.

## Official Source Signals
- **Claude Code changelog** (HTTP 200)
  - URL: https://code.claude.com/docs/en/changelog
  - Latest signal: 2.1.143 / May 15, 2026
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
  - Latest signal: 2026-05-18 / Codex CLI 0.131.0 pre
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Changelog – Codex | OpenAI Developers Home API Docs Guides and concepts for the OpenAI API API reference Endpoints, parameters, and responses Codex Docs Guides, concepts, and...
  - Short signal: ( #19068 , #22375 ) Plugin workflows gained marketplace CLI commands, version-aware sharing, share checkout, clearer shared-workspace buckets, and default-enabled plugin hooks.
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
  - Latest signal: 3.4 / May 13, 2026
  - Keyword groups: schedule, codex-runtime, integration, quality-cost
  - Short signal: What's New in Cursor — Latest Updates & Release Notes Skip to content Cursor Product ↓ Agents Code Review Cloud Tab CLI Marketplace ↗ Enterprise Pricing Resources ↓ Changelog...
  - Short signal: 3.4 May 13, 2026 · Changelog Development environments for cloud agents To take engineering tasks from start to finish, agents need a development environment similar to the setup...
- **Gemini Code Assist release notes** (HTTP 200)
  - URL: https://developers.google.com/gemini-code-assist/resources/release-notes
  - Latest signal: VS Code Gemini Code Assist 2.82.0 / May 14, 2026
  - Keyword groups: hooks, schedule, integration, quality-cost
  - Short signal: Gemini Code Assist release notes | Google for Developers Skip to main content Gemini Code Assist / English Deutsch Español Français Indonesia Português – Brasil Русский 中文 – 简体...
  - Short signal: Page Summary outlined_flag As of October 14, 2025, Gemini Code Assist tools are no longer available and are replaced by agent mode (Preview).
- **Devin release notes** (HTTP 200)
  - URL: https://docs.devin.ai/release-notes
  - Latest signal: May 17, 2026
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Default Member Roles Enterprise admins can now configure default roles that are automatically assigned to new organization members on join, with badge display in the members...
  - Short signal: GHES App Registration Restriction GitHub Enterprise Server app registration is now restricted to one app per account and host combination, preventing duplicate registrations...

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
