# Copilot Custom Agents Design

This directory is a design registry for future GitHub Copilot Custom Agents. It
does not enable autonomous project execution by itself.

## Current Policy

- Claude Code #1 owns adoption decisions, risk review, and product/process
  judgment for new AI-tool capabilities.
- Codex #1 owns scoped implementation PRs, CI repair, merge follow-up, WBS sync
  verification, branch/worktree cleanup, and local memory/disk hygiene.
- GitHub Copilot Custom Agents are advisory only. They may suggest changes in
  GitHub or the editor, but they must not merge, deploy, write production data,
  rotate secrets, or run side-effecting automation.
- Old Codex #2/#3 and PowerShell lane ownership is historical. Do not start
  those lanes for WBS work; Codex #1 absorbs implementable CI/GHA/Edge/docs
  tasks under the two-instance policy.

## Candidate Agent Shapes

| Agent | Intended scope | Guardrail |
| --- | --- | --- |
| `ci-triage-agent` | Summarize failing workflow logs and propose a minimal patch. | Codex #1 must inspect logs, implement the patch, and confirm CI green. |
| `docs-routing-agent` | Draft documentation deltas from official AI-tool release notes. | Claude Code #1 must approve adopt/defer/ignore; Codex #1 owns the PR. |
| `calendar-ui-agent` | Suggest UI copy or test cases for calendar surfaces. | No direct deploy or production data mutation. |

## Activation Checklist

1. Link an Issue and WBS row with an explicit owner.
2. Confirm the release signal from an official source or `docs/ai-tool-changelog`.
3. Keep the output advisory unless Codex #1 converts it into a normal scoped PR.
4. Record memory/disk hygiene and close all task-originated processes before
   wrap-up.
