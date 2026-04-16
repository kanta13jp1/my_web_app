---
title: "Building a MoneyForward-Beating AI Budget Advisor in Flutter Web (Supabase + Claude)"
tags: Flutter,Supabase,AI,buildinpublic,fintech
published: true
---

# Building a MoneyForward-Beating AI Budget Advisor in Flutter Web (Supabase + Claude)

## Why Build This

Amazon just launched "Rufus Buy for Me" — an AI that browses and purchases for you. The counter-move for a personal finance app? Make the AI work *for* your wallet, not against it.

I'm building [自分株式会社](https://my-web-app-b67f4.web.app/), an AI life management app that replaces 21 SaaS tools (Notion, Evernote, MoneyForward, Slack, etc.) with one integrated platform. Today's task: transform a 128-line stub budget page into a full AI-powered financial advisor.

## What We Built

A 4-tab budget page:

1. **Overview** — Income/expense KPIs + top 5 spending categories
2. **Budget** — 15-category budget vs. actual with progress bars
3. **AI Savings Advice** — Claude analyzes spending and generates 3 actionable tips
4. **Future Simulator** — Compound interest calculator for wealth projection

## The AI Savings Advisor

Instead of creating a new Edge Function, we reused the existing `ai-assistant` EF — just with a new prompt:

```dart
Future<void> _fetchAiAdvice() async {
  final prompt = '''
Analyze this month's ($_selectedMonth) household data and suggest 3 specific saving tips.

Total income: ¥${_fmt.format(totalIncome)}
Total expenses: ¥${_fmt.format(totalExpense)}
Spending by category:
$breakdown

Provide exactly 3 practical, actionable saving suggestions.
''';

  final response = await _supabase.functions.invoke(
    'ai-assistant',
    body: {'action': 'chat', 'message': prompt},
  );
}
```

**Prompt engineering notes:**
- Pass structured monthly data (not raw transactions — the AI doesn't need every line item)
- Constrain to "exactly 3 tips" to keep responses concise and actionable
- Ask for "practical" suggestions to avoid generic advice like "spend less"

The `ai-assistant` EF routes this to Claude Sonnet and returns suggestions like:
- "Your dining out (¥45,000) is 23% over budget — try batch cooking 3 meals/week to cut this by ¥15,000"
- "Switch your streaming subscriptions to annual billing — saves ~¥8,400/year"
- "Your transport costs suggest frequent taxis — a monthly pass would save ¥12,000"

## Compound Interest Simulator

Pure Dart implementation (no packages needed):

```dart
void _runSimulation() {
  final principal = double.tryParse(_initialAmountCtrl.text) ?? 0;
  final monthly = double.tryParse(_monthlyAddCtrl.text) ?? 0;
  final rate = (double.tryParse(_returnRateCtrl.text) ?? 0) / 100 / 12;
  final months = (int.tryParse(_yearsCtrl.text) ?? 0) * 12;

  double result = principal;
  for (int i = 0; i < months; i++) {
    result = result * (1 + rate) + monthly;
  }
  setState(() => _simResult = result);
}
```

Example: ¥1M initial + ¥30K/month + 5% annual return + 20 years = **¥15.4M**
Principal contributed: ¥8.2M → Interest earned: ¥7.2M — compound interest does the heavy lifting.

## Edge Function Pattern: Reuse `app_analytics` for Multi-Purpose Storage

Rather than creating a dedicated `budget_data` table, we use `app_analytics` with a `source` column as a discriminator:

```typescript
// In budget-financial-planner EF
await supabase.from('app_analytics').upsert({
  user_id: userId,
  source: 'budget',           // discriminator
  category: budgetCategory,
  amount: budgetAmount,
  month: targetMonth,
  metadata: { breakdown: categories }
});
```

**Why this works:** The `app_analytics` table already has `user_id`, `category`, `amount`, `metadata` columns. For budget data, we just add `source: 'budget'` and query with `.eq('source', 'budget')`. No new migration needed.

This pattern scales well when you have many feature-specific datasets that don't need complex relational queries.

## Competing with MoneyForward

MoneyForward's strengths: bank account sync, automatic categorization, long history.

Our approach: **AI-first, not data-first**. Instead of syncing every transaction, users input monthly summaries and the AI does the analysis. Less friction, more insight.

What we added that MoneyForward doesn't have:
- Natural language AI advice (not just charts)
- Integrated with the rest of your life data (tasks, goals, habits)
- Future wealth projection tied to your actual budget

## Key Takeaways

1. **Reuse existing Edge Functions** — adding a new prompt is cheaper than a new EF
2. **Constrain your AI prompts** — "exactly 3 tips" beats "give me advice"
3. **Generic tables > specific tables** — `app_analytics` with a `source` column handles dozens of use cases
4. **Compound interest is powerful** — build a simulator and show users the math

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #AI #fintech #personalfinance
