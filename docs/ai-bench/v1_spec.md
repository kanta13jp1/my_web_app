# Internal AI Model Bench v1

Last updated: 2026-05-18

## Purpose

This bench turns official model updates and social-media model claims into
repeatable project evidence. It does not decide a fixed "strongest model".
It measures task-specific fit for this repository, then feeds routing work in
`#2521` and monthly review work in `#2522`.

## Guardrails

- Official or primary sources are required before a model can be ranked.
- `partial` and `unverified` models remain hypotheses until source evidence is
  attached.
- A model can win one task and lose another because prompts, tools, latency,
  context, safety, and price all change the result.
- Asset balances, payments, and money calculations stay deterministic in
  Dart, SQL, or Supabase functions. AI output is explanatory only.
- SNS labels such as "Fast" suffixes or "best model" claims must be copied
  into the bench only as claims, not as conclusions.

## Task Set

| ID | Track | Task | Required Proof |
| --- | --- | --- | --- |
| B1 | Backend | Asset repository month-range micro change | Analyzer/test pass with small repository-patterned diff |
| B2 | Frontend | Asset dashboard compact UI chip | Build or widget test plus screenshot/manual smoke evidence |
| B3 | Agent | Issue to branch to PR to CI procedure | Dry-runable flow with PR/check/cleanup summary |
| R1 | Research | Official model-source intake to WBS action | Official URLs, verification status, and deduplicated issue route |

## Axes

Each axis is scored from 0 to 3. Weighted totals are normalized to 100 by
`scripts/internal_ai_bench.py`.

| Axis | Weight | Meaning |
| --- | ---: | --- |
| accuracy | 3 | Spec and acceptance criteria satisfaction |
| diff_discipline | 2 | Small, repo-patterned diff with low unrelated churn |
| test_quality | 2 | Useful unit, integration, or CI evidence |
| ci_signal | 2 | First-pass green rate and recovery discipline |
| latency | 1 | Human-observed or API-measured turnaround |
| cost | 1 | Estimated token/runtime cost for the same task |
| safety | 1 | PII, secret, prompt-injection, and money-boundary safety |
| thinking_budget | 1 | Reasoning-effort continuity, token budget, and billing discipline |

## Verification Status

| Status | Ranking Rule | Example |
| --- | --- | --- |
| verified | Eligible for ranking when scores are present | Official model page and API docs are attached |
| partial | Listed but not ranked | Paper exists, but product/API or ranking claim is missing |
| unverified | Listed but not ranked | SNS-only model name or unsupported suffix |

## Initial Candidate Slots

| Provider | Model Slot | Status | Official Source |
| --- | --- | --- | --- |
| OpenAI | `gpt-5.5` | verified | https://openai.com/index/introducing-gpt-5-5/ and https://developers.openai.com/api/docs/models/gpt-5.5 |
| Anthropic | `claude-opus-4-7` | verified | https://www.anthropic.com/news/claude-opus-4-7 and https://platform.claude.com/docs/en/build-with-claude/extended-thinking |
| Google | `gemini-3.1-pro-preview` | verified | https://ai.google.dev/gemini-api/docs/models |
| Moonshot | `kimi-k2.6` | verified | https://platform.kimi.ai/docs/models |
| DeepSeek | `deepseek-v4-flash` | verified | https://api-docs.deepseek.com/updates/ and https://api-docs.deepseek.com/quick_start/pricing/ |
| xAI | `grok-4.3` | verified | https://docs.x.ai/developers/models |
| ByteDance | `seedance-2.0` | partial | https://arxiv.org/abs/2604.14148 |
| MiMo | `mimo-v2.5-pro` | unverified | none yet |

## Usage

Recheck official sources before preparing any live run:

```powershell
python scripts/internal_ai_bench_source_recheck.py `
  --input docs/ai-bench/results/template.json `
  --output-json docs/ai-bench/results/source_recheck.json `
  --output-md docs/ai-bench/results/source_recheck.md `
  --strict
```

The source recheck is also available as the `AI Bench Source Recheck` workflow.
It performs public HTTP reads only; it does not call paid model APIs and does
not change routing defaults. The workflow is report-only because some official
sites may serve different content or bot-block GitHub hosted runners; use the
CLI `--strict` flag for operator-gated live-run readiness checks.

Create a template:

```powershell
python scripts/internal_ai_bench.py --write-template docs/ai-bench/results/template.json
```

After a manual or API-collected run, write normalized outputs:

```powershell
python scripts/internal_ai_bench.py `
  --input docs/ai-bench/results/20260522_b1_backend.json `
  --output-json docs/ai-bench/results/20260522_b1_backend.normalized.json `
  --output-md docs/ai-bench/results/20260522_b1_backend.md
```

The Markdown report must be attached to `#2520` or a follow-up issue before any
`#2521` routing default changes are made.

Prepare provider execution without making live API calls:

```powershell
python scripts/internal_ai_bench_provider_manifest.py `
  --input docs/ai-bench/results/template.json `
  --output-json docs/ai-bench/results/provider_manifest.json `
  --output-md docs/ai-bench/results/provider_manifest.md `
  --strict
```

The provider manifest is a dry-run runbook only. It records eligible verified
model slots, official sources, required environment variable names, and
synthetic-input rules. Live provider calls remain gated by explicit operator
approval, current official source rechecks, and a scored bench report.

Generate model usage telemetry for #2522 monthly review:

```powershell
python scripts/ai_model_telemetry_report.py `
  --input docs/ai-bench/results/model_usage_events.sample.jsonl `
  --output-json docs/ai-bench/results/model_telemetry_summary.json `
  --output-md docs/ai-bench/results/model_telemetry_summary.md `
  --strict
```

Telemetry is not a ranking by itself. It records provider/model/task cost,
failure rate, latency, quality, and thinking-token signals so #2521 routing
changes can cite both #2520 bench scores and #2522 operating evidence.
