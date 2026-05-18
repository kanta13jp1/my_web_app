# Internal AI Bench Official Source Recheck

- Issue: `#2520`
- Bench ID: `template`
- Generated at: `2026-05-18T11:01:28+00:00`
- Live provider calls: disabled
- Paid API usage: forbidden in this script
- Routing impact: none; #2521 defaults still need scored bench evidence or a feature flag

## Model Source Results

| Model | Declared status | Source recheck | Rankable after recheck | Sources |
| --- | --- | --- | --- | --- |
| `openai/gpt-5.5` | `verified` | pass | yes | https://openai.com/index/introducing-gpt-5-5/ (200, ok; required: Introducing GPT=ok, GPT=ok) ; https://developers.openai.com/api/docs/models/gpt-5.5 (200, ok; required: GPT-5.5=ok, Pricing=ok) |
| `anthropic/claude-opus-4-7` | `verified` | pass | yes | https://www.anthropic.com/news/claude-opus-4-7 (200, ok; required: Claude Opus 4.7=ok) |
| `google/gemini-3.1-pro-preview` | `verified` | pass | yes | https://ai.google.dev/gemini-api/docs/models (200, ok; required: Gemini 3.1 Pro Preview=ok) |
| `moonshot/kimi-k2.6` | `verified` | pass | yes | https://platform.kimi.ai/docs/models (200, ok; required: kimi-k2.6=ok) |
| `deepseek/deepseek-v4-flash` | `verified` | pass | yes | https://api-docs.deepseek.com/updates/ (200, ok; required: DeepSeek-V4=ok, deepseek-v4-flash=ok) ; https://api-docs.deepseek.com/quick_start/pricing/ (200, ok; required: deepseek=ok) |
| `xai/grok-4.3` | `verified` | pass | yes | https://docs.x.ai/developers/models (200, ok; required: grok-4.3=ok) |
| `bytedance/seedance-2.0` | `partial` | pass | no | https://arxiv.org/abs/2604.14148 (200, ok; required: Seedance=ok) |
| `mimo/mimo-v2.5-pro` | `unverified` | fail | no | none |

## Rejected SNS Claims

| Claim | Reason |
| --- | --- |
| `anthropic/opus-4.7-fast` | Official Anthropic source names Claude Opus 4.7; no Fast suffix is treated as a model slot. |
| `mimo/mimo-v2.5-pro` | No official source URL is attached in the bench template. |

## Warnings

- None.

## Next Gate

If this report passes, the next step is an explicitly approved live provider run with synthetic fixtures only. No production routing change should be made from source recheck evidence alone.
