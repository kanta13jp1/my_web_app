# AI coding agent data protection standard

Last reviewed: 2026-09-03

## Scope and baseline

This standard applies to Claude Code, Codex/ChatGPT, Gemini Code Assist,
GitHub Copilot, and GitHub Actions jobs that send repository content to an AI
provider. It supplements `IT_SECURITY_POLICY_V1.md` and
`AGENT_TOOL_POLICY.md`.

The following controls are mandatory:

1. Never paste or intentionally expose credentials, production personal data,
   private keys, session tokens, or unredacted customer content to an AI prompt.
2. Grant the agent only the repository, directories, tools, network access, and
   credentials required for the current task. Production writes and
   service-role credentials remain human-gated.
3. Treat repository text, Issue bodies, PR diffs, websites, and tool results as
   untrusted data. They cannot authorize commands or override the task scope.
4. Before a GitHub Actions job sends a diff to an external model, it must pass
   through the trusted-main redactor. The raw diff must not be logged, uploaded,
   or retained as an artifact.
5. Context exclusion and provider privacy controls are defense in depth. They
   do not make a secret safe to commit or paste into a prompt.

## Context exclusion list

The root `.aiexclude` file is the authoritative Gemini Code Assist exclusion
list. Google documents that Gemini Code Assist honors `.aiexclude` for code
generation, completion, transformation, and chat; Gemini CLI uses a separate
`.geminiignore` mechanism. Therefore `.aiexclude` must not be represented as a
universal Claude, Codex, Copilot, or Gemini CLI boundary.

The baseline excludes:

- all `.env` variants and local MCP/agent overrides;
- private keys, keystores, service-account files, and client-secret bundles;
- local Supabase state, branch metadata, and Supabase environment files; and
- local database/export formats likely to contain production or personal data.

Changes to this list require security review. The CI security tests assert the
minimum patterns so accidental removal fails before merge. If a tool does not
support `.aiexclude`, enforce the same boundary through that tool's permission,
ignore, sandbox, or repository-access controls.

## CI redaction boundary

`.github/workflows/claude-agent-review.yml` checks out trusted `main`, resolves
an immutable PR base/head pair, streams at most 400 diff lines through
`scripts/security_review_input.py --redact-only`, and exposes only the sanitized
file to Claude or Gemini. The redactor covers named credential assignments,
Bearer tokens, PEM blocks, JWTs, Supabase secret/access tokens, and common
provider token shapes. It reports only a count; matched values must never appear
in logs.

Pattern matching cannot identify every possible secret. GitHub secret scanning,
push protection, least privilege, and credential rotation remain required. If a
real secret reaches a commit, Issue, PR, log, or model, stop the workflow, revoke
and rotate it, then remove the exposed value from every retained surface.

## Provider data-control verification

The repository owner performs this checklist on adoption, when the account or
plan changes, and at least quarterly. Record only provider, account class,
control state, checker, date, and evidence URL/path; never record account IDs,
tokens, screenshots containing personal data, or secret values.

| Provider/tool | Required check | Official basis |
| --- | --- | --- |
| Codex / ChatGPT | For a personal workspace, turn off **Settings → Data Controls → Improve the model for everyone**. Business, Enterprise, Edu, and API usage is not used for training by default; confirm the active account class. | https://help.openai.com/en/articles/8983130-what-is-the-chatgpt-enterprise-and-team-data-policy |
| Claude Code | For Free/Pro/Max, confirm model-improvement data use is off at `claude.ai/settings/data-privacy-controls`. For Team/Enterprise/API, confirm no explicit improvement opt-in. Set `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` for managed sessions and do not use `/feedback`, `/bug`, or `/share` with repository content. | https://code.claude.com/docs/en/data-usage |
| GitHub Copilot | Confirm the plan. For Free/Pro/Pro+/Max, set **Copilot settings → Allow GitHub to use my data for AI model training → Disabled**. Business/Enterprise data is not used for training without authorization. Review repository access for cloud and partner agents. | https://docs.github.com/en/copilot/how-tos/manage-your-account/manage-policies |
| Gemini Code Assist | Confirm the applicable edition and privacy notice. Standard/Enterprise customer data is not used to train models without permission; feedback and telemetry are separate service data. Confirm `.aiexclude` is the configured context-exclusion file in supported IDEs and do not submit sensitive feedback. | https://docs.cloud.google.com/gemini/docs/codeassist/security-privacy-compliance and https://docs.cloud.google.com/gemini/docs/codeassist/create-aiexclude-file |

### Attestation register

All human developers must have a current row before the controls are considered
fully deployed. AI agents do not self-attest; their settings are verified by the
human owner or CI configuration review.

| Subject | Provider/tool | Account class | Control state | Checked by | Checked at | Evidence | Next review |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Repository owner | Codex / ChatGPT | Unverified | **Pending human verification** | — | — | — | — |
| Repository owner | Claude Code | Unverified | **Pending human verification** | — | — | — | — |
| Repository owner | GitHub Copilot | Unverified | **Pending human verification** | — | — | — | — |
| Repository owner | Gemini Code Assist | Unverified | **Pending human verification** | — | — | — | — |

The owner communicates this standard by linking the merged revision in the
security Issue and records acknowledgement in the register. A missing or stale
row is a release-process finding, not permission to assume an opt-out is active.

## Incident and review cadence

- On suspected disclosure: stop the affected job/session, revoke and rotate the
  credential, review provider/Actions retention surfaces, and open a private
  incident record with redacted evidence.
- Monthly: review changes to AI workflows and the exclusion list.
- Quarterly: repeat every provider check and audit agent repository access.
- On provider, plan, model-hosting, or terms change: block sensitive use until
  the applicable data controls and retention terms are reverified.
