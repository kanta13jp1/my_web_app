# AI Output Copyright & Safety Validation Spec (`#4137`)

## 1. Purpose

Provide deterministic copyright quote-overlap detection and prohibited safety
topic filtering for AI outputs in:

- `supabase/functions/_shared/ai_output_safety_validator.ts`
- `scripts/ai_output_copyright_safety_check.py`

## 2. Deterministic Validation Rules

1. **Copyright / Verbatim Quote Overlap**:
   - Maximum verbatim overlap per quote: `15` words (`maxWordsPerQuote = 15`).
   - Maximum quotes from a single source: `1` (`maxQuotesPerSource = 1`,
     counted for matches of `>= 6` consecutive words).
2. **Prohibited Safety Categories**:
   - `csae` (Child Sexual Abuse and Exploitation)
   - `self_harm` (Self-Harm or Suicide Instruction)
   - `illicit_drugs` (Illicit Drug Manufacturing or Trafficking)
   - `cyber_attack` (Cyberattack or Malware Exploitation)
   - `violence` (Severe Violence or Weapons Instruction)
3. **Dry-Run GitHub Issue Alert Payload**:
   - On any violation, validators build a deterministic `DryRunIssueAlertPayload`
     (`dryRun: true`) containing `title`, `labels`, and `body`.
   - Automated tests never execute live `gh issue create`.

## 3. Legal & External Reference Caveat

- Copyright compliance thresholds and third-party prompt policies require
  formal legal review before production enforcement.
- External claims from the originating NotebookLM notebook
  (`Claude Fable 5 System Prompt and Implementation Guide`, `#4137`) were not
  verified against external primary sources in this task and are recorded as
  `未確認`.
