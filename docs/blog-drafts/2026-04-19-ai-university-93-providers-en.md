---
title: "Building an AI Provider Encyclopedia with Supabase + Flutter — 93 Providers and Counting"
tags: Flutter,Supabase,AI,buildinpublic,webdev
published: true
---

# Building an AI Provider Encyclopedia with Supabase + Flutter

## What is "AI University"?

AI University is a learning feature in 自分株式会社 (Jibun Kabushiki Kaisha) that covers 93 AI providers:

```
Google / OpenAI / Anthropic / Mistral / DeepSeek / Groq /
Nebius / DeepInfra / Fireworks AI / SambaNova / ... (93 total)
```

For each provider: overview, available models, API usage guide. With quizzes, scores, leaderboards, and badges to make it a game.

## The Schema That Scales

```sql
CREATE TABLE ai_university_content (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  provider text NOT NULL,
  category text NOT NULL,  -- "overview" | "models" | "api" | "news"
  title text NOT NULL,
  content text NOT NULL,   -- Markdown
  published_at date,
  UNIQUE(provider, category)
);
```

The `UNIQUE(provider, category)` constraint means each provider has exactly one record per category. `ON CONFLICT DO UPDATE` makes upserts idempotent — run the same migration twice with no side effects.

## DB-Driven Tabs in Flutter

```dart
Future<List<String>> _fetchProviders() async {
  final response = await Supabase.instance.client
      .from('ai_university_content')
      .select('provider')
      .order('provider')
      .limit(200);

  return (response as List)
      .map((r) => r['provider'] as String)
      .toSet()
      .toList();
}
```

No hardcoded tab list. Add a DB record → tab appears automatically. This is why we could go from 9 to 93 providers without touching UI code.

## Adding a Provider: 15 Minutes Per Entry

1. **WebSearch** for latest info (models, API, pricing)
2. **Write migration SQL** (3 categories: overview, models, api)
3. **Apply**: `supabase db push`
4. **Flutter**: nothing to change

```sql
-- Example: adding GMI Cloud
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('gmi_cloud', 'overview', 'GMI Cloud Overview', '## What is GMI Cloud\n\nGPU cloud...', '2026-04-19'),
  ('gmi_cloud', 'models',   'GMI Cloud Models',   '## Available Models\n\n...', '2026-04-19'),
  ('gmi_cloud', 'api',      'GMI Cloud API',       '## API Usage\n\n...', '2026-04-19')
ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
```

## Automatic News Updates (Every 2 Hours)

```yaml
# ai-university-update.yml
on:
  schedule:
    - cron: '0 */2 * * *'

jobs:
  update:
    steps:
      - name: Fetch and upsert news
        # Fetches each provider's RSS / blog → upserts news category
```

93 providers × every 2 hours. The "news" tab always shows current information.

## The Learning Flow

```
Select provider
  → Read overview / models / api
  → Quiz (3 questions)
  → Score recorded (ai_university_scores)
  → Badge awarded (ai_university_badges)
  → Leaderboard updated
```

FSRS (spaced repetition algorithm) calculates review due dates. A streak counter shows consecutive learning days to motivate daily habits.

## Why This Architecture Works at Scale

| Design decision | Why it scales |
|----------------|---------------|
| UNIQUE(provider, category) | Upserts are safe; no duplicate content |
| DB-driven tabs | Adding provider = adding DB record |
| Markdown content | Rich formatting without schema changes |
| Auto-update cron | Content stays fresh without manual work |

Going from 9 to 93 providers required zero UI code changes. The investment in DB-driven architecture paid off at provider #10 and compounded every provider after.

---
Building in public: https://my-web-app-b67f4.web.app/
#Flutter #Supabase #AI #buildinpublic
