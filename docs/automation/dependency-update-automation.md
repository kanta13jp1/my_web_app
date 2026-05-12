# Dependency Update Automation

Issue: #1371

## Scope

This repository uses Dependabot to open dependency update pull requests for:

- GitHub Actions workflows
- npm packages in the repository root
- Python packages in `requirements.txt`
- Flutter/Dart packages in `pubspec.yaml`

Existing CI runs on Dependabot pull requests, so generated updates are validated by the same lint, format, test, build, security, and PR summary checks as normal changes.

## Schedule

Dependabot runs weekly on Monday morning in Asia/Tokyo:

- 09:00 GitHub Actions
- 09:10 npm
- 09:20 pip
- 09:30 pub

Patch and minor updates are grouped by ecosystem to reduce PR noise. Major updates for pip and pub are intentionally left for manual review because they can affect runtime behavior across Flutter Web and Supabase Edge Functions.

## Production Deploy Runtime

The production Firebase Hosting deployment no longer depends on `FirebaseExtended/action-hosting-deploy@v0`. The upstream action still declares a Node.js 20 runtime, while GitHub Actions is moving JavaScript actions to Node.js 24 by default on June 2, 2026 and removing Node.js 20 on September 16, 2026.

Production deploy now installs and runs `firebase-tools@latest` through Node.js 24 with the same service account secret used before. This keeps the deployment path aligned with the Node.js 24 transition while preserving the existing post-deploy version verification.

## GitHub Actions Runtime Guard

Mobile release builds use `actions/setup-java@v5` so Android artifact jobs no longer emit the Node.js 20 runtime deprecation warning observed in run `25201820274`.

`scripts/check_github_actions_node_runtime.py` is wired into CI and the weekly Dependency Audit workflow. It blocks regressions to action majors known to be below this repository's Node.js 24 transition floor, including `actions/setup-java@v4`. A scheduled Dependency Audit failure is routed through `workflow-failure-handler.yml`, which creates a GitHub Issue for follow-up.

## Agent Workflow Notes

- Codex #2 owns small, low-risk automation fixes such as Dependabot coverage, workflow runtime updates, and CI/deploy maintenance.
- Claude Code remains the preferred reviewer for high-risk changes, especially auth, database migrations, and architecture changes.
- When Codex in-app browser verification is available, UI-facing dependency updates should include a rendered smoke check in addition to CI.
- Claude Code `/ultrareview` is recommended before merging workflow changes that alter production deploy behavior.

## References

- GitHub Actions Node.js 20 deprecation: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
- Firebase Hosting deploy action release stream: https://github.com/FirebaseExtended/action-hosting-deploy/releases
- Firebase deploy action manifest: https://raw.githubusercontent.com/FirebaseExtended/action-hosting-deploy/v0.10.0/action.yml
