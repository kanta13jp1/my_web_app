---
name: ai-university-add-provider
description: Research and add an AI provider to the my_web_app AI University using current official sources, the live repository schema, an idempotent Supabase migration, and the existing update workflow. Use when asked to evaluate new AI providers, add a named provider, refresh provider coverage, or review whether a provider belongs in AI University. Discovery is read-only; implementation requires a scoped worktree and repository validation.
---

# Add an AI University Provider

Use current repository and official-source evidence. Never rely on a hard-coded provider count or an old provider list in this skill.

## Discovery mode

1. Determine registered providers from the current repository and, when authorized credentials are available, the live `ai_university_content.provider` values.
2. Search official provider documentation, model documentation, pricing, release notes, and API availability. Use third-party coverage only as a secondary signal.
3. Reject providers without a usable public product or API, unclear provenance, or insufficient differentiation.
4. Compare candidates on technical differentiation, API availability, user relevance, source freshness, operational cost, and overlap with existing providers.
5. Return the top candidates, evidence links, unknowns, and one recommendation. Do not edit files in discovery mode.

## Add mode

### 1. Start safely

Run `session-start-check`. Work from a clean `codex/` worktree based on current `origin/main`. Search for an existing Issue, migration, provider row, workflow entry, or active PR before creating anything.

Normalize the provider ID to lowercase letters, digits, and hyphens. Confirm the display name and canonical official URLs.

### 2. Confirm the current data contract

Inspect the table-creation and constraint migrations before writing SQL. The expected contract is:

```text
provider, category, title, content, source_url, published_at, sort_order, is_active
UNIQUE(provider, category)
```

If the repository schema differs, follow the current migration rather than this summary and report the drift.

### 3. Create an idempotent seed migration

Create a collision-free timestamped migration under `supabase/migrations/`. Add only categories supported by reliable sources, normally `overview`, `models`, and `api`.

- Write original Japanese learning content.
- Cite canonical official URLs in `source_url`.
- Include source dates for pricing or model limits.
- Use dollar-quoted Markdown safely.
- Use `ON CONFLICT (provider, category) DO UPDATE` or `DO NOTHING` deliberately and explain the choice.
- Never insert guessed prices, context limits, model names, or code examples.

### 4. Update automation only when supported

Inspect `.github/workflows/ai-university-update.yml`. Add the provider only when the current workflow has a compatible update contract and a stable official feed or endpoint. Do not add a knowingly invalid RSS URL merely to satisfy a template.

Update a documented provider registry only if the current repository explicitly identifies it as canonical. Do not add provider inventory to `AGENTS.md`.

### 5. Validate

Run the repository's current migration timestamp and SQL structure checks, YAML validation for a changed workflow, focused AI University tests, and `git diff --check`. Inspect the final migration for duplicate provider/category pairs and unsupported schema columns.

### 6. Hand off

Leave the scoped branch ready for review with official sources, schema decision, migration path, workflow decision, validation results, and rollback approach. Do not commit or push directly to `main`, apply the production migration locally, or mark WBS complete before merge proof.
