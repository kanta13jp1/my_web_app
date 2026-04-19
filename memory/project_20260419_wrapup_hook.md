---
name: PostToolUse hook wiring — `.claude/settings.json` + `.claude/scripts/post-git-wrapup-nudge.sh`
description: How the auto /wrap-up nudge is plumbed. Hook lives in settings.json under PostToolUse, scoped via `if: "Bash(git *)"`, delegating to a shell script that inspects `tool_input.command` JSON and emits hookSpecificOutput.
type: project
---

## Discovered wiring

- **`.claude/settings.json`** registers a PostToolUse entry whose `command` points at `.claude/scripts/post-git-wrapup-nudge.sh` with `timeout: 5` and a new `if: "Bash(git *)"` prefilter.
- **`.claude/scripts/post-git-wrapup-nudge.sh`** reads stdin as JSON, extracts `.tool_input.command` via `jq`, regex-matches real git commit/push invocations, and prints a JSON `hookSpecificOutput` that becomes an additional system reminder after the Bash tool result.
- Hook output is plain JSON on stdout — no special envelope needed. The harness merges `hookSpecificOutput` into the next assistant turn as `<system-reminder>…</system-reminder>`.

## Current regex (after this session)

```regex
(^|[;&|]\s*)(PYTHONUTF8=[^ ]+ +)?(env +[A-Z_]+=[^ ]+ +)*git +(commit|push)\b
```

Matches: `git commit`, `git commit -m "..."`, `PYTHONUTF8=1 git push`, `… && git push origin …`, `env FOO=bar git commit`.
Does NOT match: `echo "git commit"`, heredoc bodies containing "git commit", `git commit-tree` (word-boundary enforced).

**Why:** Useful reference when adding more PostToolUse hooks (e.g. auto-deploy nudge, /rule17-wf-health nudge). Reuse the same JSON-in / JSON-out pattern and the same statement-boundary regex strategy.

**How to apply:** For any new PostToolUse hook that should trigger on a subset of Bash commands:
1. Add an `if: "Bash(<prefix> *)"` in settings.json to cheap-filter.
2. In the script, read stdin, `jq -r '.tool_input.command // ""'`, regex-match with statement-boundary anchors.
3. Emit `{"hookSpecificOutput": {...}}` on stdout.
4. Verify with a matching command AND a deliberately-non-matching command in the same session.
