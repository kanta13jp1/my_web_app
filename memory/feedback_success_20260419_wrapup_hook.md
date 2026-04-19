---
name: PostToolUse wrapup-nudge hook — regex tightening verified
description: Narrowed git commit/push matcher avoids heredoc/echo false positives; settings.json `if: "Bash(git *)"` adds second guard. Verified by hook firing on real `git commit` + `git push` during this session.
type: feedback
---

## What worked

- Regex `(^|[;&|]\s*)(PYTHONUTF8=[^ ]+ +)?(env +[A-Z_]+=[^ ]+ +)*git +(commit|push)\b` matches `git commit -m "..."`, `PYTHONUTF8=1 git push`, `&& git push` — but NOT strings inside heredocs or `echo "git commit"`.
- Adding `"if": "Bash(git *)"` in `.claude/settings.json` under the PostToolUse hook prefiltered non-git commands before the script ran (belt + suspenders).
- Verified live: after `git commit` and `git push -u origin …`, the hook emitted `[auto-rule] git commit/push を実行しました…` both times, triggering /wrap-up as designed.

**Why:** Earlier iterations of this hook fired on any bash command containing the substring "git commit" (e.g. `echo "remember git commit"`), producing noise. The session data now shows the tightened pattern is both selective and reliable.

**How to apply:** When writing hook matchers, combine (a) settings.json `if:` scope filter + (b) a grep regex that anchors on shell statement boundaries (`^`, `;`, `&&`, `||`, `|`). Always verify by running a matching and a deliberately-non-matching command in the same session.
