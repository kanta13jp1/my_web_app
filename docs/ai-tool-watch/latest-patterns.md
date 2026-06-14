# News Pattern Detector Report

- Generated at: `2026-06-14T21:45:25Z`
- Sources: `docs/ai-tool-watch/latest-report.json`
- Entries scanned: `9`
- Patterns: `3`
- Issue candidates: `2`

## Patterns
- **multi-source / agentic-workflows**: 8 entries, confidence=0.97, risk=normal
  - Action: Review repeated signal for a scoped follow-up issue only if source confidence stays high.
  - Evidence: Claude Code changelog
  - Evidence: Claude Code hooks reference
  - Evidence: Claude Code GitHub Actions
- **anthropic / agentic-workflows**: 3 entries, confidence=0.97, risk=normal
  - Action: Review anthropic movement for competitor-monitoring follow-up.
  - Evidence: Claude Code changelog
  - Evidence: Claude Code hooks reference
  - Evidence: Claude Code GitHub Actions
- **openai / agentic-workflows**: 2 entries, confidence=0.97, risk=normal
  - Action: Review openai movement for competitor-monitoring follow-up.
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
    "source_http_problem": 1
  }
}
```
