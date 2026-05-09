# Market Intelligence Pipeline

Issue: #1970

## Scope

The market intelligence MVP is a research-support pipeline. It collects public RSS/news items, clusters and ranks signals, preserves source links, and produces a paper-decision log skeleton. It is not investment advice and it does not connect to trading APIs.

## Flow

1. `/market-intelligence` calls `tools-hub` with `action=market_intel.analyze`.
2. `tools-hub` reuses the RSS/news ranking path, then builds market-intelligence signals from the ranked items.
3. Each signal returns evidence links, source count, watchlist matches, uncertainty, risk notes, and next-review prompts.
4. A human reviews the evidence and records any decision in paper mode before any real-world action.

## Guardrails

- `no_investment_advice=true`
- `auto_trading_enabled=false`
- `human_approval_required=true`
- single-source claims are explicitly flagged as research prompts
- no buy/sell/hold recommendation is generated
- no brokerage, exchange, or wallet API is called

## Report Fields

- `signals`: ranked research prompts
- `evidence`: source/title/url/published timestamp/score
- `confidence`: high, medium, or low based on source count and signal score
- `uncertainty`: what is still unverified
- `risk_note`: known gaps such as single-source or missing live-price confirmation
- `what_to_watch_next`: review checklist for the next human step
- `paper_decision_log`: non-trading decision skeleton

## Operating Notes

Daily reports can be saved under `docs/market-intelligence/` once an operator reviews the generated output. The first automated save workflow should keep the same guardrails and default to dry-run until source quality is stable.
