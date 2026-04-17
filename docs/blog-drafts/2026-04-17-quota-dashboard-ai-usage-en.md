---
title: "AI Usage Quota Dashboard in Flutter + Supabase: Real-Time Token Tracking Across Models"
tags: Flutter,Supabase,buildinpublic,Dart,AI
published: false
---

# AI Usage Quota Dashboard in Flutter + Supabase: Real-Time Token Tracking Across Models

## The Problem

You're using multiple AI providers — Claude, Gemini, OpenAI. You have no idea how many tokens you've consumed today. Until you hit a limit and everything stops.

The fix: log token usage to a Supabase table after every AI call, and visualize it in a Flutter dashboard.

---

## Schema: ai_quota_usage

```sql
CREATE TABLE ai_quota_usage (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        REFERENCES auth.users(id) ON DELETE CASCADE,
  model        text        NOT NULL,
  -- e.g. 'claude-sonnet-4-6', 'gemini-2.0-flash', 'gpt-4o'
  input_tokens  int        NOT NULL DEFAULT 0,
  output_tokens int        NOT NULL DEFAULT 0,
  total_tokens  int        GENERATED ALWAYS AS (input_tokens + output_tokens) STORED,
  feature       text,
  -- e.g. 'ai-university', 'daily-judgment', 'horse-racing'
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON ai_quota_usage (user_id, created_at DESC);
CREATE INDEX ON ai_quota_usage (model, created_at DESC);
```

`total_tokens` is a `GENERATED ALWAYS AS` column — the DB computes it, not your app. Index on `(user_id, created_at DESC)` makes daily range queries fast.

---

## Recording Usage: Fire-and-Forget

After every AI call, record usage without blocking the response:

```typescript
// In your Edge Function, after getting the AI response:
const usage = aiResponse.usage;

// Fire-and-forget — don't await, don't crash if it fails
supabase.from('ai_quota_usage').insert({
  model: 'claude-sonnet-4-6',
  input_tokens: usage.input_tokens,
  output_tokens: usage.output_tokens,
  feature: 'ai-university',
}).then(() => {}).catch(() => {});
```

This keeps the AI response latency clean. If the logging fails (network blip, DB hiccup), the AI call still succeeds.

---

## Flutter: Dashboard Page

```dart
class _QuotaDashboardPageState extends State<QuotaDashboardPage> {
  List<Map<String, dynamic>> _modelStats = [];
  int _totalTokensToday = 0;
  bool _loading = true;

  Future<void> _loadQuota() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final response = await Supabase.instance.client
        .from('ai_quota_usage')
        .select('model, input_tokens, output_tokens')
        .gte('created_at', today);

    // Aggregate client-side (small dataset, < 1000 rows/day)
    final stats = <String, Map<String, int>>{};
    for (final row in (response as List)) {
      final model = row['model'] as String;
      stats[model] ??= {'input': 0, 'output': 0};
      stats[model]!['input'] =
          stats[model]!['input']! + (row['input_tokens'] as int);
      stats[model]!['output'] =
          stats[model]!['output']! + (row['output_tokens'] as int);
    }

    setState(() {
      _modelStats = stats.entries
          .map((e) => {
                'model': e.key,
                'input': e.value['input'],
                'output': e.value['output'],
                'total': e.value['input']! + e.value['output']!,
              })
          .toList()
        ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
      _totalTokensToday =
          _modelStats.fold(0, (sum, s) => sum + (s['total'] as int));
      _loading = false;
    });
  }
}
```

---

## Flutter: Usage Bar Widget

```dart
Widget _buildModelRow(Map<String, dynamic> stat) {
  final colorScheme = Theme.of(context).colorScheme;
  final total = stat['total'] as int;
  final fraction = _totalTokensToday > 0 ? total / _totalTokensToday : 0.0;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stat['model'] as String,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${_formatTokens(total)} tokens',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        ),
      ],
    ),
  );
}

String _formatTokens(int tokens) {
  if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
  if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
  return '$tokens';
}
```

---

## Client-Side Cost Estimation

Keep a model→rate map in Flutter to show estimated cost without an API key:

```dart
const Map<String, double> _costPer1kTokens = {
  'claude-sonnet-4-6': 0.003,
  'claude-haiku-4-5':  0.00025,
  'gemini-2.0-flash':  0.00015,
  'gpt-4o':            0.005,
};

double _estimateCost(String model, int tokens) {
  final rate = _costPer1kTokens[model] ?? 0.001;
  return tokens / 1000 * rate;
}
```

This is an approximation — actual billing depends on which API endpoints you're hitting — but it gives a useful order-of-magnitude signal.

---

## Why Client-Side Aggregation vs. DB Aggregate

For daily dashboards with < 1000 rows per user:

```dart
// Option A: fetch rows and aggregate client-side
final response = await supabase
    .from('ai_quota_usage')
    .select('model, input_tokens, output_tokens')
    .gte('created_at', today);
// group in Dart

// Option B: PostgreSQL aggregate query (via RPC)
final response = await supabase.rpc('get_daily_quota', params: {'day': today});
```

Option A is simpler and fast enough. Option B is better if users have high-volume usage (thousands of rows/day) or if you want to add breakdowns by `feature` without returning all rows.

---

## Summary

| Pattern | Benefit |
|---------|---------|
| `GENERATED ALWAYS AS total_tokens` | DB computes totals — no app-side arithmetic |
| Fire-and-forget logging | Zero impact on AI response latency |
| `(user_id, created_at DESC)` index | Fast daily range scans |
| Per-model progress bars | Instant visual breakdown of which model costs most |
| Client-side cost map | Estimated cost without a billing API |

Turn AI costs from invisible to manageable. On a $20/month plan, visibility is the difference between staying in budget and a surprise bill.

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #AI
