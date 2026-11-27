# Dynamic System Prompt Specification (`#4133`)

## 1. Purpose

Standardize dynamic system prompt composition across Supabase Edge Functions
(`supabase/functions/_shared/dynamic_system_prompt.ts`) and Flutter client
services (`lib/services/dynamic_system_prompt_service.dart`).

## 2. Prompt-Cache Friendly Ordering (Static Prefix First)

To preserve prompt-cache prefix hits across requests:

1. **Static Prefix (Cacheable)**:
   - Shared identity & prompt-injection boundary preamble (`AI_CHARACTER_PREAMBLE`
     on Edge Functions / `baseIdentityPreamble` on Flutter).
   - App-specific static instructions (`staticInstructions`, with validated
     `{{key}}` template variables).
   - Output format directive (`markdown` with fenced code blocks + language tag,
     `json_schema` with optional schema name, or `plain_text`).
2. **Dynamic Suffix (Request-Time Tail)**:
   - `現在日付 (UTC): YYYY-MM-DD`
   - `現在時刻 (UTC, ISO 8601): <utcIso>`
   - `現在時刻 (JST, ISO 8601): <jstIso>` (`+09:00`)

Placing volatile timestamps at the tail guarantees `prompt.startsWith(staticPrefix)`
remains invariant when only the request clock changes.

## 3. Deterministic Template Validation

`validateSystemPromptTemplate` (TS) and `DynamicSystemPromptService.validateTemplate`
(Dart) deterministically reject:

- Empty or whitespace-only templates
- Unclosed `{{` or stray `}}` placeholder braces
- Invalid placeholder identifiers outside `[a-zA-Z0-9_.-]+`
- Missing or blank `templateVars` / `templateVariables` values
- Embedded `<<<USER_DATA>>>` or `<<<END>>>` boundary markers inside static templates

## 4. External Reference Status

- External claims regarding Anthropic's internal system-prompt version history or
  model archives (referenced in the originating NotebookLM intake `#4133`) were
  **not** verified against external primary archive documents in this task and
  are recorded as `未確認`.
