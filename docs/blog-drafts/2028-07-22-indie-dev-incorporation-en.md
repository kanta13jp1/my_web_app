---
title: "Indie Dev Incorporation — When Should You Form a Company?"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie Dev Incorporation — When Should You Form a Company?

The "should I incorporate?" question has a break-even answer rooted in tax math.

## Sole Proprietor vs Corporation Tax Rates (Japan)

```
Sole proprietor (income tax + resident tax + business tax):
  Taxable income ¥3.3M–¥6.95M:  20% + 10% = ~30%
  Taxable income ¥6.95M–¥9M:    23% + 10% = ~33%
  Taxable income ¥9M–¥18M:      33% + 10% = ~43%

Corporation (corporate tax + local taxes):
  Annual income ≤ ¥8M:   corporate tax 15% + local = effective ~21%
  Annual income > ¥8M:   corporate tax 23.2% + local = effective ~30%
```

**Rule of thumb break-even: annual profit ¥6M–¥8M**

```
At ¥6M annual profit:
  Sole prop: ~¥1.8M in taxes (30%)
  Corp: set executive salary to split income → effective rate 20–25%
  → Saves ¥300K–¥600K / year

Setup cost (LLC): ~¥100K
Recouped in year one.
```

## Main Benefits of Incorporating

```
1. Split income via executive salary
   Corporate profit → executive salary (employment income deduction applies)
   → lowers effective tax rate

2. Broader expense deductions
   Portion of rent / car / insurance / employee benefits

3. Loss carryforward period
   Sole prop: 3 years → Corporation: 10 years

4. Business credibility
   B2B contracts, API agreements, bank loans

5. Retirement savings
   Small business mutual aid + executive retirement bonus (large tax-free allowance)
```

## LLC vs Corporation (Japan)

```
LLC (Godo-kaisha):
  Setup cost: ~¥60K (no notary required for articles)
  Financial disclosure: not required
  External investment: harder to accept
  Best for indie devs: tax savings + low cost + simple structure

Corporation (Kabushiki-kaisha):
  Setup cost: ~¥250K
  Credibility: higher
  Equity funding / IPO: supported
  Choose this if you're building a startup
```

## Incorporation Decision Checklist

```dart
// Consider incorporating when 2+ of these apply
final shouldIncorporate = [
  annualProfit > 6_000_000,       // tax benefit kicks in
  hasBToBClients,                 // corporate entity often required
  planningToHire,                 // triggers social insurance obligations
  seekingExternalFunding,         // need to issue equity
].where((c) => c).length >= 2;
```

## Summary

```
Break-even      → annual profit ¥6M–¥8M is the rule of thumb
Entity type     → LLC for indie devs (¥60K setup / simple structure)
Key benefits    → income splitting + broader expenses + 10-year loss carryforward
Timing signal   → 2+ of: profit threshold / B2B / hiring / funding
```

Incorporation is not just about taxes — it also signals that the business is serious.
