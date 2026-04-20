---
title: "Turn AI Dependency Into a Portfolio — Claude / Codex / Jibun Inc. on a Balance Sheet"
tags: AI,Claude,OpenAI,buildinpublic,webdev
published: false
---

# Turn AI Dependency Into a Portfolio — Claude / Codex / Jibun Inc. on a Balance Sheet

## Where This Post Sits

In the earlier post "[Claude Code vs OpenAI Codex Desktop vs Your Life Hub — A 3-Layer Design for Bundling AI](https://my-web-app-b67f4.web.app/)" I mapped how three tools operate on different layers and therefore don't compete.

This post is the sequel: **"why bundling is the rational choice, told through accounting."** Pretend you keep a mental balance sheet (BS) as a personal CEO, and decompose AI dependency into "assets" and "liabilities."

## Shared Fact Base (2026-04-17 Event)

On 2026-04-17, OpenAI Codex Desktop shipped Computer Use + 20+ plugins + MCP servers. Initial headlines claimed Codex had reached plugin parity with Claude, but a cross-source check gives the real numbers:

- **Claude Code: 423 plugins / 2,849 skills / 177 agents** (43 marketplaces / 834 total)
- **OpenAI Codex: 20+ plugins (no self-serve publish yet)**

→ Claude leads plugins by **~20×**. What Codex caught up on is **Computer Use only**.

Keep these numbers in mind for the next section.

## The Personal-CEO BS Principle (Jibun Inc. Principle #7)

Principle #7 of Jibun Inc.'s 9 principles is "Asset/Liability Balance Sheet." Clean definition:

> Things that **increase** future revenue / time / autonomy = Asset
> Things that **decrease** future revenue / time / autonomy = Liability

Every daily choice thickens one side of the BS — employee or indie dev. AI tool choice is no exception.

## Decompose AI Tools on a BS

Single-vendor lock-in, viewed through accounting, is a **short-term liability with extremely low liquidity**. Why:

1. **Switching cost**: memory / skill / plugin / workflow are vendor-specific → rebuild cost on exit
2. **Price risk**: zero veto on price hikes (recall Anthropic $20 → $100/seat)
3. **Availability risk**: outages stop your work (no redundant staff for a solo CEO)
4. **Roadmap risk**: vendor strategy pivots can obsolete your workflow

Concrete mapping:

| AI Tool | Short-Term Liability (-) | Hidden Asset (+) | Net |
|---|---|---|---|
| Claude Code single-dep | Anthropic total dependency / 423 plugins become useless if Anthropic pulls them | World's largest plugin ecosystem | **Liability dominant** |
| OpenAI Codex single-dep | ChatGPT ecosystem dependency / Computer Use 1-month head start | 3M weekly DAU info stream | **Liability dominant** |
| Cursor single-dep | Anysphere dep + IDE lock-in | Seamless in-IDE UX | **Liability dominant** |
| **Jibun Inc. (ai-hub distributed)** | Initial build cost | Command post bundling Claude + OpenAI + Gemini + fallback / auto-failover on outage | **Asset dominant** |

"Claude is strong at 423 plugins" is a fact. It does **not** justify single-vendor dependency. If anything, 423 > 20 amplifies the other face: **higher exit cost = tighter lock-in that narrows future options**.

### Sidebar: credit-metered pricing = monthly consumptive liability

On 2026-05-04, Notion Custom Agents switches to **$10 / 1,000 credits** (triangulation lands a conservative **$0.11–$0.33 per agent run**). Credit-based metered pricing has an extra liability characteristic in accounting terms:

- **Monthly reset**: unused credits evaporate → not a deferrable asset (the logic "I prepaid so this month is cheaper" does not apply)
- **Usage pressure**: end-of-month "I need to burn remaining credits" is a perverse incentive where saving budget and using AI become zero-sum
- **Personal CEO's time capital**: ~100 seconds/day spent checking credit balance × 365 = ~10 hours/year of "balance-check labor"

Unlike flat-rate subscription, **credit-metered pricing belongs on the BS as "short-term, non-deferrable, usage-pressure liability."**
By contrast, Jibun Inc. (Supabase + Flutter Web) has **zero credit concept → structurally does not carry this liability**.

### Stage 2: mandatory consumption commits (Anthropic Enterprise, 2025-11)

Around the same time, Anthropic Enterprise moved from $200 flat to $20/seat + usage (verified across Anthropic's own pricing + The Register + 4 more = 6 sources). The structural core is the **mandatory consumption commit**:

- Pre-pay Anthropic-estimated monthly token volume → **if actual usage falls below, you're still billed the full amount**
- Prior 10–15% volume discounts are gone
- Redress Compliance estimates heavy users land at **2–3× cost increase**

On the BS, **commit pricing is a "monthly mandatory liability"** — arguably worse than credit-metered. With credits you can at least "burn them by month-end for parity"; with commits, the under-consumption is simply lost — **zero deferral + no penalty for using less** = fully one-sided.

Looking at Notion (credit-metered / monthly reset) + Anthropic (commit-based / monthly mandatory) as a **two-stage rocket**, the pattern is clear: vendors stabilize their revenue via metered + commit pricing; users absorb the unpredictability.

The counter is simple: **don't bet on one AI vendor**. Bundle via ai-hub so any single pricing update dilutes rather than detonates your BS.

## How Jibun Inc. Implements This

### ai-hub: Sit On the Side That Doesn't Pick

```dart
// Pseudocode: Flutter Web call
final response = await supabase.functions.invoke('ai-hub', body: {
  'action': 'provider.chat_auto',
  'messages': [...],
  'intent': 'design_decision', // → routes to Claude
});
```

Edge Function routes by intent:

| intent | 1st choice | fallback 1 | fallback 2 |
|---|---|---|---|
| `design_decision` (long memory) | Claude Sonnet | GPT-4.1 | Gemini 2.5 Pro |
| `computer_use_required` | Codex (plugin) | Claude Computer Use | — |
| `cost_sensitive_bulk` | Haiku | Gemini Flash | DeepSeek |
| `fallback_any` | Gemini Flash | Haiku | Mistral Small |

### cost-hub: 4-Stage Circuit Breaker

1. **green**: normal (all models)
2. **yellow**: per-session cost > $0.50 → sonnet → haiku downgrade
3. **orange**: $1.50 → force downgrade to flash / deepseek-v3
4. **red**: $3.00 → stop calls + alert

→ Single-vendor price hikes can't whip you around. If Anthropic raises prices, traffic shifts to Gemini / DeepSeek.

### Let Supabase Own the History

The tool layer stays vendor-agnostic; **Jibun Inc.'s PostgreSQL holds history**:

- Sleep / expenses / learning / health / KPIs → Supabase tables
- Claude sessions are volatile / Codex plugin invocations are one-shot
- → "Switch AIs, keep your past self's data." Fixed asset that doesn't depreciate.

## The Accounting View

Personal-CEO BS (capital = time / attention / autonomy), simple T-account:

```
【Assets (+)】                            【Liabilities (-)】
- 6-dept KPI history (Supabase)           - Single-vendor AI dep
- ai-hub routing asset                    - Manual credit-balance watching
- Hand-rolled hooks / workflows           - Silent pauses (billing flip)
- Cross-searchable memory/                - English-first UX cognitive cost

【Net worth】
= Assets − Liabilities
= ai-hub × 6-dept integration × Japanese-native UX
```

Cancel a single-tool subscription → Jibun Inc.'s net worth doesn't drop. That's the core of the "bundle" design.

## Conclusion

- "Which AI to pick" = a decision about the composition of your short-term liabilities
- "Do I have a hub that bundles AIs" = a decision about whether you own a fixed asset
- The rational play for a personal CEO is the latter: **thicken the asset side of your own BS**

Claude's 423 plugins are amazing. Codex's Computer Use is amazing. But there's zero reason to bet on one. **Bundle them, and both strengths land on your asset side.**

## References

- Companion piece (3-layer map): [Claude Code vs OpenAI Codex Desktop vs Your Life Hub](https://my-web-app-b67f4.web.app/)
- 9 principles: <https://my-web-app-b67f4.web.app/philosophy>
- 21-competitor comparison: <https://my-web-app-b67f4.web.app/comparison>
- Live: <https://my-web-app-b67f4.web.app/>
