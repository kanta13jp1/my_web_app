# AI Tool Watch Report

- Checked at: `2026-07-18T22:08:40Z`
- Previous check: `2026-07-17T22:07:58Z`
- Changed/new official sources: `4`
- Active routing groups: `codex-runtime, hooks, integration, quality-cost, schedule`

## Session Start Summary
- `changed` Claude Code changelog: 2.1.214 / July 18, 2026
- `changed` Claude Code hooks reference: Hooks reference - Claude Code Docs Documentation Index Fetch the complete documentation ind
- `changed` Codex changelog: 2026-07-18 / Codex CLI 0.144.6 pre
- `changed` Gemini Code Assist release notes: VS Code Gemini Code Assist 2.87.0 / June 19, 2026

## Recommended Actions
- **codex-runtime** (#1422, #1377, #1375, #1408): Route to Codex execution: use newer models for broad refactors, in-app browser for UI verification, and worktrees for parallel fixes.
- **hooks** (#1422, #1337, #1350): Route to Claude Code quality gates: SessionStart/UserPromptSubmit for session context, PostToolUse/Stop for lint-test feedback.
- **integration** (#1339, #1335, #1405): Route to connector reliability: MCP/Slack/GitHub integration checks and NotebookLM knowledge capture.
- **quality-cost** (#1380, #1374, #1336, #1352): Route to cost and safety controls: deny-by-default checks, budget routing, and telemetry before wider automation.
- **schedule** (#1422, #862, #1307, #1372): Route to GitHub Actions or Codex Automations: daily source watch, merge-backlog triage, and deterministic CI/deploy checks.

## Official Source Signals
- **Claude Code changelog** (HTTP 200)
  - URL: https://code.claude.com/docs/en/changelog
  - Latest signal: 2.1.214 / July 18, 2026
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Navigation Getting started Claude Code changelog Getting started Build with Claude Code Administration Configuration Reference Agent SDK What's New Resources Getting started...
  - Short signal: Copy page Copy page This page is generated from the CHANGELOG.md on GitHub .
- **Claude Code hooks reference** (HTTP 200)
  - URL: https://code.claude.com/docs/en/hooks
  - Latest signal: Hooks reference - Claude Code Docs Documentation Index Fetch the complete documentation ind
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Hooks reference - Claude Code Docs Documentation Index Fetch the complete documentation index at: /docs/llms.txt Use this file to discover all available pages before exploring...
  - Short signal: Navigation Reference Hooks reference Getting started Build with Claude Code Administration Configuration Reference Agent SDK What's New Resources Reference CLI reference...
- **Claude Code GitHub Actions** (HTTP 200)
  - URL: https://code.claude.com/docs/en/github-actions
  - Latest signal: Claude Code GitHub Actions - Claude Code Docs Documentation Index Fetch the complete docume
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Claude Code GitHub Actions - Claude Code Docs Documentation Index Fetch the complete documentation index at: /docs/llms.txt Use this file to discover all available pages before...
  - Short signal: Navigation Code review & CI/CD Claude Code GitHub Actions Getting started Build with Claude Code Administration Configuration Reference Agent SDK What's New Resources Getting...
- **Codex changelog** (HTTP 200)
  - URL: https://developers.openai.com/codex/changelog
  - Latest signal: 2026-07-18 / Codex CLI 0.144.6 pre
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Codex changelog | ChatGPT Learn ChatGPT Home API Codex Docs Guides, concepts, and product docs for Codex Use cases Example workflows and tasks teams can take on with ChatGPT or...
  - Short signal: Home Quickstart Core Concepts MCP Apps in ChatGPT MCP Server UX principles UI guidelines Plan Research use cases Define tools Design components Build Set up your server Build...
- **Codex use cases** (HTTP 200)
  - URL: https://developers.openai.com/codex/use-cases/
  - Latest signal: ChatGPT use cases ChatGPT Home API Codex Docs Guides, concepts, and product docs for Codex
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: ChatGPT use cases ChatGPT Home API Codex Docs Guides, concepts, and product docs for Codex Use cases Example workflows and tasks teams can take on with ChatGPT or Codex Docs Use...
  - Short signal: Home Quickstart Core Concepts MCP Apps in ChatGPT MCP Server UX principles UI guidelines Plan Research use cases Define tools Design components Build Set up your server Build...
- **Codex overview** (HTTP 403)
  - URL: https://openai.com/codex/
  - Latest signal: No title detected
  - Keyword groups: none
- **Cursor changelog** (HTTP 200)
  - URL: https://cursor.com/changelog
  - Latest signal: 3.11 / Jul 10, 2026
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: What's New in Cursor — Latest Updates & Release Notes Skip to content Cursor Product ↓ Agents Cloud Composer Mobile Automations CLI Marketplace ↗ Review Enterprise Pricing...
  - Short signal: We also refined how Cursor's responses look in Slack.
- **Gemini Code Assist release notes** (HTTP 200)
  - URL: https://developers.google.com/gemini-code-assist/resources/release-notes
  - Latest signal: VS Code Gemini Code Assist 2.87.0 / June 19, 2026
  - Keyword groups: hooks, schedule, integration, quality-cost
  - Short signal: Gemini Code Assist release notes | Gemini for Google Cloud | Google Cloud Documentation Skip to main content Technology areas close AI and ML Application development Application...
  - Short signal: Starting June 18, 2026, Gemini Code Assist IDE Extensions and Gemini CLI stopped serving requests for the Gemini Code Assist for individuals, Google AI Pro, and Google AI Ultra...
- **Devin release notes** (HTTP 200)
  - URL: https://docs.devin.ai/release-notes
  - Latest signal: July 15, 2026
  - Keyword groups: hooks, schedule, codex-runtime, integration, quality-cost
  - Short signal: Navigation Release Notes Recent Updates Cloud CLI Desktop Enterprise Use Cases API Federal Get Started Introducing Devin Your First Session Tutorial Library Essential Guidelines...
  - Short signal: Onboarding Devin Environment configuration Index a Repository VPN Configuration Knowledge Onboarding AGENTS.md Working with Devin Devin Review Devin Session Tools Computer Use...

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
