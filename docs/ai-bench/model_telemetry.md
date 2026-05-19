# AI Model Telemetry and Monthly Review

Last updated: 2026-05-18

## Purpose

This document defines the #2522 telemetry layer for asset-management AI usage.
It records model cost, quality, latency, and failure signals so monthly reviews
can update model choices without treating any social-media "strongest model"
claim as permanent truth.

The telemetry layer is evidence-only. It does not call provider APIs, change
production routing, or store raw prompts, raw responses, secrets, account
numbers, or asset balances.

## Event Schema

Each usage event is a JSON object. JSONL is preferred for append-only logs.

| Field | Required | Description |
| --- | --- | --- |
| `event_id` | yes | Stable unique id for the model call or dry-run event |
| `occurred_at` | yes | ISO-8601 timestamp |
| `provider` | yes | Provider key such as `openai`, `anthropic`, `google`, `deepseek` |
| `model` | yes | Exact model id used at execution time |
| `task_type` | yes | Stable task bucket such as `asset_report_summary` |
| `feature` | no | Product feature, for example `monthly_asset_report` |
| `status` | yes | `success`, `timeout`, `error`, `rate_limited`, `blocked`, or equivalent |
| `latency_ms` | no | End-to-end call latency |
| `estimated_cost_usd` | no | Estimated USD cost for this call |
| `input_tokens` | no | Input token count |
| `output_tokens` | no | Output token count |
| `thinking_tokens` | no | Reasoning/thinking token count when exposed or estimated |
| `quality_score` | no | 0.0-1.0 evaluator or manual quality score |
| `issue` | no | Related GitHub Issue such as `#2520` or `#2521` |
| `source` | no | `manual`, `ci`, `api`, or other origin marker |

Forbidden fields include raw `prompt`, raw `response`, API keys, secrets,
account numbers, and asset balances. If those keys appear anywhere in an event,
the monthly report marks the event as a blocker.

## Monthly Metrics

Monthly review looks at each `provider/model/task_type` group:

| Metric | Use |
| --- | --- |
| event count | Avoid decisions from one-off samples |
| failure rate | Detect rate limits, timeouts, and provider instability |
| estimated cost | Catch cost growth before routing defaults change |
| average and P95 latency | Keep interactive asset workflows responsive |
| average quality score | Compare evaluator/user-rated quality over time |
| input/output/thinking tokens | Track budget drift and thinking-cost exposure |

## Alert Policy

Default thresholds in `scripts/ai_model_telemetry_report.py`:

| Alert | Default |
| --- | ---: |
| cost per provider/model/task group | `>= $10.00` |
| failure rate | `>= 20%` with at least 3 events |
| P95 latency | `>= 30000ms` |
| sensitive payload keys | blocker |

Thresholds are command-line configurable for monthly review runs. A blocker
does not delete data; it prevents the report from being treated as clean
routing evidence until the unsafe event source is fixed.

## Usage

Create a monthly report from JSONL telemetry:

```powershell
python scripts/ai_model_telemetry_report.py `
  --input docs/ai-bench/results/model_usage_events.sample.jsonl `
  --output-json docs/ai-bench/results/model_telemetry_summary.json `
  --output-md docs/ai-bench/results/model_telemetry_summary.md `
  --strict
```

The `AI Model Telemetry Monthly Review` workflow runs the same reporter against
the checked-in sample fixture and uploads the summary artifact. Production
telemetry export wiring can replace the input file later, but that must remain
PII-safe and approval-gated.

## Routing Rule

Telemetry can support #2521 provider routing only when paired with scored #2520
bench evidence. A cheaper or faster model is not automatically preferred if it
fails asset-management accuracy, safety, or deterministic money-boundary
requirements.
