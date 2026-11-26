# AI System Prompt History Intake & Diff Spec (`#4135`)

## 1. Purpose

Provide a deterministic knowledge intake, snapshot normalization, and version
diff workflow for tracking external AI system prompt changes across:

- `supabase/functions/_shared/prompt_history_intake.ts`
- `scripts/prompt_history_intake.py`

## 2. Snapshot Normalization & Diff Classification

1. **Snapshot Normalization**:
   - Normalizes provider names (lowercase), ISO-8601 timestamps (UTC), section
     key ordering, and line endings (`\r\n` -> `\n`) to compute a deterministic
     `contentDigest`.
   - Defaults `verificationStatus` to `未確認` unless explicitly verified from
     primary documentation.
2. **Diff Severity**:
   - `breaking`: Any section removed or modified.
   - `additive`: New sections added without removing or modifying existing ones.
   - `metadata`: No section text changes.
3. **Dry-Run Investigation Issue Payload**:
   - When `changed` is `true`, generates a deterministic
     `DryRunInvestigationIssuePayload` (`dryRun: true`) for operator triage.
   - Automated tests never invoke live `gh issue create`.

## 3. External Archive Verification Status

- External prompt archive claims from the originating NotebookLM notebook
  (`Claude System Prompt Version History and Model Archives`, `#4135`) were not
  verified against external primary archive sources in this task and remain
  recorded as `未確認`.
