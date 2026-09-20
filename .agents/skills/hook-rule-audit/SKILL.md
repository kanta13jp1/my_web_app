---
name: hook-rule-audit
description: Audit the repository's injected Claude and Codex rules for drift, duplication, stale operating-model assumptions, unsupported commands, and excessive context cost. Use for a monthly hook-rule audit, inject-rules cleanup, rule consolidation, or after AGENTS.md changes. Default to a read-only report and require explicit approval before changing or synchronizing home-level hook files.
---

# Hook Rule Audit

Audit rules against current repository behavior. Do not preserve a rule merely because an old session label cited it.

## 1. Verify canonical and home state

```powershell
$env:PYTHONUTF8 = '1'
python scripts/sync_inject_rules.py --verify
python scripts/sync_inject_rules.py --json
```

Treat `.claude/inject-rules.txt` as the repository canonical file. Treat `~/.claude/hooks/inject-rules.txt` as a local runtime copy. Report drift direction; do not synchronize either direction without explicit approval.

## 2. Build the review set

Read:

- `AGENTS.md`;
- `docs/AGENT_DELEGATION_PROTOCOL.md`;
- `docs/SUBAGENT_ORCHESTRATION_POLICY.md`;
- current hook configuration under `.claude/`;
- git history for each rule under review.

Do not use private-memory reference counts as proof that a rule is unused. A safety rule may be important precisely because it rarely fires.

## 3. Classify every rule

Use one decision:

- **keep**: current, unique, testable, and still required;
- **rewrite**: required intent but stale wording, path, command, owner, or threshold;
- **merge**: meaningfully duplicated by another rule;
- **retire**: contradicted by current policy or obsolete under the two-instance model.

Check specifically for:

- dormant PS, WEB, mobile, Gemini, Copilot, or extra-Codex ownership;
- commands or paths that fail in the current Windows environment;
- rules duplicated by `AGENTS.md` or deterministic scripts;
- destructive actions, direct-main pushes, hidden external writes, and secret exposure;
- vague rules that cannot be validated;
- context-heavy history that can move to docs or git history.

## 4. Report before editing

Return a table with rule, decision, evidence, replacement text if needed, and validation impact. Separate safe wording fixes from policy changes that require Claude Code or user approval.

## 5. Apply only approved changes

Edit the repository canonical file first. Re-run:

```powershell
$env:PYTHONUTF8 = '1'
python scripts/sync_inject_rules.py --verify
git diff --check
```

Synchronize canonical to the home hook only when the user explicitly approves that external change:

```powershell
python scripts/sync_inject_rules.py --apply
```

Record the audit in the relevant Issue or PR. Do not append routine audit noise to the product roadmap.
