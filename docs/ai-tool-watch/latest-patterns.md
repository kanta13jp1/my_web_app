# News Pattern Detector Report

- Generated at: `2026-07-21T22:12:46Z`
- Sources: `docs/ai-tool-watch/latest-report.json`
- Entries scanned: `9`
- Patterns: `4`
- Issue candidates: `0`

## Patterns
- **multi-source / agentic-workflows**: 5 entries, confidence=0.956, risk=review
  - Action: Hold for human review before creating issues or blog drafts.
  - Evidence: Claude Code changelog
  - Evidence: Claude Code hooks reference
  - Evidence: Claude Code GitHub Actions
- **anthropic / agentic-workflows**: 3 entries, confidence=0.947, risk=review
  - Action: Hold for human review before creating issues or blog drafts.
  - Evidence: Claude Code changelog
  - Evidence: Claude Code hooks reference
  - Evidence: Claude Code GitHub Actions
- **openai / ci-quality**: 2 entries, confidence=0.97, risk=normal
  - Action: Route to CI/readiness gate owners if repeated failures or quality gates are affected.
  - Evidence: Codex changelog
  - Evidence: Codex use cases
- **multi-source / ci-quality**: 2 entries, confidence=0.97, risk=normal
  - Action: Route to CI/readiness gate owners if repeated failures or quality gates are affected.
  - Evidence: Codex changelog
  - Evidence: Codex use cases

## Filter Summary

```json
{
  "total": 9,
  "by_verdict": {
    "pass": 9,
    "review": 0,
    "drop": 0
  },
  "risk_flags": {
    "source_http_problem": 1,
    "unverified_language": 1
  }
}
```
