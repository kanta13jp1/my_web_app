# Copilot Cloud Agent CI Evaluation

Date: 2026-05-03
Owner: Codex #2
Issue: #1707

## Decision

Do not replace `ci-auto-fix.yml` with a custom Actions image yet. Keep the
current `ubuntu-latest` workflow and use this report as the comparison baseline
until Copilot cloud-agent custom images are configured for the repository or
organization.

## Why

- GitHub's 2026-04-27 changelog says Copilot cloud agent startup is over 20%
  faster when the agent environment is prebuilt with GitHub Actions custom
  images.
- `ci-auto-fix.yml` is a normal GitHub Actions workflow, not the Copilot cloud
  agent runtime itself. Changing its `runs-on` value would not prove the Copilot
  cloud-agent startup gain.
- The safe first step is to keep deterministic CI repair stable, then measure a
  custom-image pilot from Copilot-assigned issues or `@copilot` PR mentions.

## Pilot Criteria

Adopt a custom Actions image only when all criteria are met:

- The image preinstalls Flutter stable, Deno v2, Node, and the repository's
  common caches without embedding secrets.
- A Copilot cloud-agent task using the image starts at least 15% faster than the
  default environment across five comparable issue assignments.
- The image refresh cadence is automated and visible in GitHub Actions.
- `quota-monitor.yml` shows Copilot code-review Actions minutes below 80% of the
  configured monthly budget.

## Current Integration

- `scripts/ai_tool_watch.py` now watches the Copilot custom-image changelog,
  Copilot code-review Actions minutes changelog, and Claude/Codex model
  selection changelog.
- `quota-monitor.yml` now emits a `github_copilot_code_review_minutes` gauge.
- `docs/AI_FALLBACK_RUNBOOK.md` records the 2026-06-01 billing start date and
  repository variables used by the gauge.

## Sources

- https://github.blog/changelog/2026-04-27-copilot-cloud-agent-starts-20-faster-with-actions-custom-images/
- https://github.blog/changelog/2026-04-27-github-copilot-code-review-will-start-consuming-github-actions-minutes-on-june-1-2026/
- https://github.blog/changelog/2026-04-14-model-selection-for-claude-and-codex-agents-on-github-com/
