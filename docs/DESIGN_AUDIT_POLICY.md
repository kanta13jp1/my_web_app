# Design accessibility audit policy

Updated: 2026-09-12. Repository owner explicitly requested that Design audit no longer be a required merge gate in PR #5391.

The audit still runs and reports its real result. Only the Design audit contract step is advisory (`continue-on-error: true`); failures produce a warning and job-summary notice, not a fabricated pass. Audit policy unit tests, the minimal E2E contract, security checks, formatting, analysis, and tests remain required as before. Branch protection settings are unchanged.

Missing plugin output does not imply accessibility compliance. Findings should still be reviewed and addressed; no claim of WCAG conformance is made by a successful workflow.
