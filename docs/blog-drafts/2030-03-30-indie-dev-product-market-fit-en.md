---
title: "Indie Dev Product-Market Fit — User Interviews and Feedback Loops in Practice"
tags: indiedev,webdev,flutter,productivity
published: true
---

# Indie Dev Product-Market Fit — User Interviews and Feedback Loops in Practice

"Built it but nobody uses it" is the most common trap for indie developers. Achieving Product-Market Fit (PMF) requires understanding users before writing code, and continuously collecting feedback after launch.

## What Is PMF?

Sean Ellis defined PMF as "the state where 40%+ of users say they'd be very disappointed if they could no longer use your product."

For indie developers, a more actionable goal is: **find 10 people who use it every day and would genuinely miss it.**

```
PMF Early Signals:
✅ Users spontaneously refer others
✅ Requests shift from new features to stability
✅ Churned users return on their own
✅ Multiple users say "I can't do X without this"
```

## Designing User Interviews

### Good vs. Bad Questions

```
❌ Bad questions (leading, hypothetical):
"Do you think this dashboard feature is useful?"
"Would you use it if we added feature X?"

✅ Good questions (past behavior, specific):
"When did you last run into this kind of problem?"
"How did you solve it at the time?"
"What frustrates you most about the tools you currently use?"
```

### Jobs-to-be-Done Framework

Users "hire" products to do a job:

```
Situation (When): When I'm preparing the weekly report
Motivation (I want): Without gathering data from multiple tools
Expected Outcome (So that): I can pull the numbers for my manager in 30 minutes
```

Design your questions around this frame:

```
Sample Interview Script:
1. "Walk me through your current workflow step by step."
2. "Which part of that process takes the most time?"
3. "In the past month, can you describe a specific situation where this problem caused you pain?"
4. "What tools or workarounds do you currently use?"
5. "What would your ideal solution look like? Are there existing tools that come close?"
```

### Finding Interview Participants

```bash
# Where to find users for interviews
- Search Twitter/X for problem-related tweets → DM for participation
- Post a recruit thread in relevant Reddit communities
- Email your first 100 users (they're your most valuable signal)
- Comment sections on Product Hunt / Hacker News
- Discord / Slack communities related to your niche
```

Run 30–45 minute sessions, ask for recording permission. **5–10 interviews reveal clear patterns.**

## Automating the Feedback Loop

### In-App Feedback Collection

```dart
// NPS survey implementation in Flutter
class NpsSurvey extends StatefulWidget {
  const NpsSurvey({super.key, required this.onSubmit});
  final void Function(int score, String? reason) onSubmit;

  @override
  State<NpsSurvey> createState() => _NpsSurveyState();
}

class _NpsSurveyState extends State<NpsSurvey> {
  int? _score;
  final _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How likely are you to recommend this app to a friend?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(11, (i) => _ScoreButton(
            score: i,
            isSelected: _score == i,
            onTap: () => setState(() => _score = i),
          )),
        ),
        if (_score != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              hintText: _score! >= 9
                  ? 'What do you like most about it?'
                  : 'What could we improve?',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => widget.onSubmit(_score!, _reasonController.text),
            child: const Text('Submit'),
          ),
        ],
      ],
    );
  }
}
```

### Auto-Classifying Feedback

```typescript
// supabase/functions/classify-feedback/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CATEGORIES = {
  bug: ['bug', 'error', 'crash', 'broken', 'not working', 'fails'],
  feature: ['feature', 'wish', 'want', 'add', 'could you', 'would be great'],
  ux: ['confusing', 'complicated', 'hard to', 'unclear', 'difficult'],
  praise: ['love', 'great', 'perfect', 'amazing', 'helpful', 'awesome'],
};

function classify(text: string): string {
  const lower = text.toLowerCase();
  for (const [category, keywords] of Object.entries(CATEGORIES)) {
    if (keywords.some(kw => lower.includes(kw))) return category;
  }
  return 'other';
}

Deno.serve(async (req) => {
  const { feedbackId, text } = await req.json();
  const category = classify(text);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  await supabase
    .from('feedback')
    .update({ category })
    .eq('id', feedbackId);

  return Response.json({ category });
});
```

### Feedback Dashboard in Supabase

```sql
-- Weekly feedback summary view
CREATE VIEW feedback_weekly_summary AS
SELECT
  date_trunc('week', created_at) AS week,
  category,
  count(*) AS count,
  avg(nps_score) FILTER (WHERE nps_score IS NOT NULL) AS avg_nps,
  count(*) FILTER (WHERE nps_score >= 9) AS promoters,
  count(*) FILTER (WHERE nps_score <= 6) AS detractors
FROM feedback
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;
```

## Quantifying PMF Signals

### Retention Curve Analysis

True PMF shows up as a retention curve that flattens horizontally.

```
% retained
100 |
 80 |  \
 60 |    \
 40 |      \_____________________  ← Has PMF (curve flattens)
 20 |
  0 |        \___________________  ← No PMF (converges to zero)
    +--+--+--+--+--+--+--+--+--→ weeks after signup
```

```sql
-- Cohort retention calculation in Supabase
WITH cohort AS (
  SELECT
    user_id,
    date_trunc('week', created_at) AS cohort_week
  FROM users
),
activity AS (
  SELECT
    user_id,
    date_trunc('week', created_at) AS activity_week
  FROM user_events
)
SELECT
  c.cohort_week,
  EXTRACT(EPOCH FROM (a.activity_week - c.cohort_week)) / 604800 AS weeks_since_signup,
  count(DISTINCT a.user_id)::float / count(DISTINCT c.user_id) AS retention_rate
FROM cohort c
LEFT JOIN activity a USING (user_id)
GROUP BY 1, 2
ORDER BY 1, 2;
```

### Setting Your North Star Metric

```
Example North Star Metrics:
- Note app: Weekly active notes created
- Todo app: Weekly tasks completed
- SaaS: Monthly active users × core feature usage rate
```

The North Star measures **evidence that users got value**. Session count and pageviews are vanity metrics.

## Behavior Changes Before vs. After PMF

### Pre-PMF: Discovery Phase

```
Do:
✅ Run 2+ user interviews per week
✅ Remove features, don't add them
✅ Focus on one narrow user segment
✅ Support users manually (Concierge MVP)

Don't:
❌ Think about scaling
❌ Invest in paid marketing
❌ Try to serve multiple personas
```

### Post-PMF: Optimization Phase

```
Do:
✅ Identify your growth engine (Paid/Viral/Sticky)
✅ Improve onboarding (increase activation rate)
✅ Run pricing experiments
✅ Automate and scale
```

## Key Takeaways

PMF isn't "build it and they will come" — it's a continuous process of verifying that you're genuinely solving someone's problem.

1. **Validate the problem with interviews** → understand the problem before building the solution
2. **Automate feedback loops** → continuous signal collection without manual effort
3. **Watch the retention curve** → the most honest PMF signal
4. **Set a North Star Metric** → connect usage to business outcomes

Scaling before PMF means scaling failure. Find 10 people who love what you built first.

---

*Building a life-management app that replaces 21 competing SaaS tools with Flutter + Supabase. Follow the journey → [@kanta13jp1](https://x.com/kanta13jp1)*
