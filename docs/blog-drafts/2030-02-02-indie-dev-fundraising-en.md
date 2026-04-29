---
title: "Indie SaaS Fundraising — Bootstrapping, Crowdfunding, and MRR-Based Loans"
tags: dart,flutter,webdev,indiedev
published: true
---

## Introduction

"Do I need outside funding?" is a question every indie SaaS founder eventually faces. The goal isn't to raise from VCs — it's to **choose the funding mechanism that fits your business**. This article covers the decision framework and practical patterns, from bootstrapping to crowdfunding, revenue-based financing, and equity-light investments.

---

## 1. Bootstrapping vs. External Funding — Decision Framework

Before raising, ask: "Do I actually need external capital at this stage?"

| Dimension | Bootstrap-friendly | External funding makes sense |
|-----------|-------------------|------------------------------|
| Control | Want to own product direction entirely | Targeting a large market that must be captured fast |
| Growth speed | Organic growth / word-of-mouth is enough | Intense competition requires rapid expansion |
| Monetization | Revenue model is clear before PMF | Prioritize growth over early profitability |
| Exit strategy | Micro-SaaS acquisition or lifestyle business | IPO or large M&A |

Most indie SaaS products can reach MRR $1,000–$10,000 through bootstrapping alone. Bringing in outside money before that stage often means **trading away control and agility** for capital you don't yet need.

---

## 2. Crowdfunding on Kickstarter / Campfire

Crowdfunding is the lowest-risk way to validate demand with pre-orders before writing a single line of production code.

**Pre-launch checklist for a successful campaign**:

1. **Build a teaser list**: Aim for 500–1,000 email subscribers before the campaign launches
2. **Video under 3 minutes**: Lead with Problem → Solution → Why Now
3. **Early Bird pricing**: Drive 30% of revenue in the first 48 hours — this feeds the platform's algorithm
4. **Stretch goals**: Promise additional features at 150% and 200% of your funding target

Track campaign registrations with Supabase:

```sql
CREATE TABLE campaign_waitlist (
  id         BIGSERIAL PRIMARY KEY,
  email      TEXT UNIQUE NOT NULL,
  tier       TEXT NOT NULL DEFAULT 'standard',  -- 'earlybird' | 'standard' | 'pro'
  referrer   TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Aggregate signups by tier
SELECT tier, COUNT(*) AS count
FROM campaign_waitlist
GROUP BY tier;
```

---

## 3. MRR-Based Revenue Financing (Pipe, Clearco, Capchase)

Once your MRR exceeds $5,000–$10,000, **revenue-based financing** lets you raise capital without giving up equity.

| Service | Mechanism | Typical raise | Repayment |
|---------|-----------|--------------|-----------|
| **Pipe** | Advance on ARR | Up to 100% of ARR | Auto-deducted monthly |
| **Clearco** | Advance on months of ARR | $10K–$10M | 1–10% of monthly revenue |
| **Capchase** | Prepayment on annual contracts | ARR × multiplier | Monthly deduction |

The biggest advantage: **no equity dilution**. The downside: you need stable, predictable MRR to qualify, and the effective APR can be high if growth slows.

Build an MRR view in Supabase to have investor-ready data at all times:

```sql
-- Monthly MRR trend view
CREATE VIEW mrr_monthly AS
SELECT
  DATE_TRUNC('month', created_at) AS month,
  SUM(amount_cents) / 100.0 AS mrr_usd,
  COUNT(DISTINCT user_id) AS active_subscribers
FROM subscriptions
WHERE status = 'active'
GROUP BY 1
ORDER BY 1 DESC;
```

---

## 4. YC / Earnest Capital — Equity-Free and Equity-Light Options

### YC SAFE (Simple Agreement for Future Equity)

YC's Post-Money SAFE is now the standard for early-stage funding. It converts to equity at your next priced round, not immediately. Even solo indie founders who go through YC Startup School can realistically target a $500K SAFE.

### Earnest Capital / Indie.vc

These funds prioritize **founder returns first**, not VC-style growth-at-all-costs:

- **Earnest Capital SHARED EARNINGS AGREEMENT**: Repay the investment from profits, after which no equity transfers
- **Tiny Capital**: Acquires profitable bootstrapped SaaS businesses outright — a viable exit path for founders who don't want to raise at all

---

## 5. Cash Flow Management with a Supabase Billing Table

No matter which funding path you choose, **visibility into your cash flow is the prerequisite**. Here's a practical billing schema:

```sql
CREATE TABLE billing_transactions (
  id               BIGSERIAL PRIMARY KEY,
  user_id          UUID REFERENCES auth.users(id),
  amount_cents     INTEGER NOT NULL,
  currency         TEXT NOT NULL DEFAULT 'usd',
  transaction_type TEXT NOT NULL,  -- 'subscription' | 'one_time' | 'refund'
  stripe_charge_id TEXT UNIQUE,
  processed_at     TIMESTAMPTZ DEFAULT NOW()
);

-- One query to get MRR, ARR, and churn for the current month
SELECT
  SUM(CASE WHEN transaction_type = 'subscription'
           THEN amount_cents ELSE 0 END) / 100.0 AS mrr,
  SUM(CASE WHEN transaction_type = 'subscription'
           THEN amount_cents ELSE 0 END) / 100.0 * 12 AS arr,
  SUM(CASE WHEN transaction_type = 'refund'
           THEN ABS(amount_cents) ELSE 0 END) / 100.0 AS churn_amount
FROM billing_transactions
WHERE processed_at >= DATE_TRUNC('month', NOW());
```

Surface this data in an admin dashboard so you can walk into any investor conversation with live numbers.

---

## Summary

Fundraising isn't "the earlier the better" — it's **"raise the right amount with the right instrument at the right time."**

1. **MRR $0–$5K**: Bootstrap hard. Use crowdfunding to validate initial demand.
2. **MRR $5K–$30K**: Revenue-based financing accelerates growth without equity dilution.
3. **MRR $30K+**: YC, Earnest Capital, or institutional VCs become realistic options.

Keep your cash flow metrics live in Supabase, and you'll always have the data you need to negotiate from a position of strength — whether you choose to raise or not.
