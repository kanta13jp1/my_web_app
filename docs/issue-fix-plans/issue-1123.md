# Issue Fix Plan #1123

- Issue: [#1123](https://github.com/kanta13jp1/my_web_app/issues/1123)
- Title: LRM self-correcting planner for AI officer tasks
- Labels: enhancement, priority:high, automation
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25411090656

## Goal

Add an optional Goal-Plan-Action planning mode for AI officer work so a CEO
request becomes structured JSON, draft actions, and a visible self-correction
review before any external write.

## Implemented Slice

- Added `LrmSelfCorrectionPlannerService` as a deterministic planner.
- The planner emits:
  - `goal`: success criteria, constraints, completion signals.
  - `plan`: owner-ready substeps with required data and done conditions.
  - `actions`: draft app task, GitHub Issue, and WBS outputs.
  - `self_review`: missing info, overscope warnings, risks, safety checks, and
    approval requirement.
- Added an optional `LRM Goal-Plan-Action` section to `AgentOrgPage`.
- The UI posts the structured plan to the executive board and queues only the
  reversible internal app-task draft. GitHub/WBS outputs remain draft JSON.
- Added service tests for JSON shape, approval gating, and small-roster fallback.

## Minimal E2E Declaration

- The E2E test is implementation-detail independent.
- The plan is minimal, about three I/O cases.
- E2E mechanism: widget/service test coverage plus existing public Playwright
  smoke in CI.
- E2E-Exception: no new browser-only flow is required for this first slice; the
  three validation cases are successful GPA JSON generation, dangerous external
  operation approval gating, and small active-agent roster fallback.

## Checklist

- [x] Reproduction is clear.
- [x] Smallest safe fix is implemented.
- [ ] Analyze/tests/CI are checked.
- [ ] PR notes explain the change and the remaining risk.
