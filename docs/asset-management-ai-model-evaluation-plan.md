# Asset Management AI Model Evaluation Plan

Last updated: 2026-08-29

## Purpose

Do not treat social-media "best model" lists as fixed truth. The asset
management roadmap should evaluate AI models on repeatable project tasks and
route models by measured fit, not by general hype.

## Candidate Sources

Use official or primary sources first:

- OpenAI GPT-5.5 announcement:
  https://openai.com/index/introducing-gpt-5-5/
- OpenAI GPT-5.5 API model docs:
  https://developers.openai.com/api/docs/models/gpt-5.5
- Anthropic Claude Opus 4.7:
  https://www.anthropic.com/news/claude-opus-4-7
- Kimi K2.6 API model list:
  https://platform.kimi.ai/docs/models
- xAI Grok 4.3 model docs:
  https://docs.x.ai/developers/models/grok-4.3
- Seedance 2.0 paper:
  https://arxiv.org/abs/2604.14148

Model claims that cannot be verified from official docs or a reproducible
benchmark should be treated as hypotheses.

The executable bench foundation lives in:

- `docs/ai-bench/v1_spec.md`
- `docs/ai-bench/results/template.json`
- `scripts/internal_ai_bench.py`

## Evaluation Tasks

| Track | Task | Expected Proof |
| --- | --- | --- |
| Backend | Modify asset-liability repository/sync logic with tests | Passing service tests and small diff |
| Frontend | Add a compact asset-management UI panel | Render-safe Flutter diff and golden/manual smoke note |
| Agent | Issue to branch to PR to CI summary | Complete PR body, checks, and cleanup |
| Research | Summarize model/source changes into WBS actions | Source links and non-duplicated Issue routing |
| Advice suppression | Respect a card's completed one-shot-payment change record | No repeated setup-change prompt; deterministic monthly payoff target remains |

## Metrics

| Metric | Notes |
| --- | --- |
| Correctness | Does the output satisfy the acceptance criteria? |
| Test quality | Does it add or update the right tests? |
| Diff discipline | Does it avoid unrelated churn? |
| Tool use | Does it use repository patterns and deterministic checks? |
| Latency | Wall-clock time for the task. |
| Cost | Estimated API/runtime cost. |
| Safety | No PII leaks, no direct money calculation by AI, no unsafe production write. |
| Thinking budget | Reasoning-effort continuity, token usage, and cost discipline. |

## Routing Policy

- GPT / Claude / Gemini can be used for production-facing summarization only
  through feature flags and existing provider boundaries.
- #2521 foundation routing is represented in code as a feature-flagged
  `Claude Opus 4.7 -> GPT-5 -> Gemini 3.1 Pro -> local deterministic`
  fallback chain for summary, risk explanation, developer suggestion, and
  reconciliation-help use cases.
- Kimi / DeepSeek / Grok are candidates until local benchmark results justify
  integration.
- Image/video models are not part of money calculation. They can support docs,
  demos, or user education after compliance review.
- Money calculations remain deterministic Dart/SQL logic.
- Card usage policy (`card_usage_policies`) is deterministic application state,
  not model memory. When `enforce_one_shot` is true, prompts must omit further
  instructions to call the issuer or change the payment setting for that card.
  The calculated balance-reduction monthly target must remain in the report.
- Evaluation fixtures must cover reload of `changed_at` and the audit memo,
  suppression for only the matching card ID, and restoration of the ordinary
  setup advice when the completion flag is turned off.
- AI can explain already-calculated values, generate checklists, or propose
  developer tasks.
- #2521 routing defaults must cite a `scripts/internal_ai_bench.py` report or
  stay behind feature flags.
- Asset-management AI prompts must use redacted categories and bands. Exact
  balances, account identifiers, and user IDs stay inside deterministic
  Dart/Supabase code and are not sent to external model providers.
- Provider routing changes that touch `ai-hub` or migrations require PR-level
  security, rollback, migration, prod-smoke, and observability evidence before
  merge.

## Linked Issues

- #2520: official AI model comparison benchmark foundation
- #2521: asset-management AI provider routing for GPT/Gemini/Claude Opus
- #2522: model cost/quality telemetry and monthly review
- #2523: `/goal` WBS execution and wrap-up standardization

## Review Cadence

- Run model-source watch at session start with `scripts/ai_tool_watch.py`.
- Convert official model changes into existing Issues before creating new ones.
- Review model routing monthly or when a model changes price, context window,
  tool-use behavior, or safety constraints.
