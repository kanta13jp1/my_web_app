---
title: "Building an AI Learning Platform with 54 Providers in 3 Days (Flutter + Supabase)"
tags: Flutter,Supabase,buildinpublic,AI,productivity
published: false
---

# Building an AI Learning Platform with 54 Providers in 3 Days (Flutter + Supabase)

## The Problem

By 2026, the AI landscape is overwhelming. Every week brings new models, providers, and APIs:

- Giants: OpenAI / Anthropic / Google / Microsoft / Meta
- Specialized: ElevenLabs (voice) / Runway (video) / Midjourney (image)
- Open-source: Mistral / LLaMA / DeepSeek
- Emerging: Sakana AI / Coze / Zhipu AI / Allen AI ...

Keeping track of what each service does, what models they offer, and how their APIs work is a full-time job. So I built **AI University** — an in-app learning platform that covers all of them.

**Current coverage: 54 providers.**

---

## Architecture: DB-Driven + Auto-Update

### Content Storage

All content lives in Supabase's `ai_university_content` table:

```sql
CREATE TABLE ai_university_content (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  provider     text NOT NULL,  -- 'openai', 'anthropic', 'gemini' ...
  category     text NOT NULL,  -- 'overview', 'models', 'api', 'news'
  title        text NOT NULL,
  content      text NOT NULL,  -- Markdown
  published_at date,
  UNIQUE (provider, category)
);
```

### Two-Layer Auto-Update for News

The `news` category is automatically refreshed by two independent systems:

| Layer | Frequency | What it does |
|-------|-----------|--------------|
| GitHub Actions (`ai-university-update.yml`) | Every 2 hours | Fetches latest 5 article titles + summary from RSS |
| Claude Code Schedule | Every 4 hours | NotebookLM Deep Research → richer explanation (overwrites GH Actions version) |

The later writer wins. Morning gets the quick RSS update. Afternoon gets Claude's enriched version.

### Flutter UI: Dynamic Tabs from DB

No hardcoded provider list. The UI reads from DB at runtime:

```dart
// providers = list fetched from Supabase
final tabs = providers.map((p) => Tab(
  child: Row(children: [
    Text(_providerMeta[p]?['emoji'] ?? '🤖'),
    SizedBox(width: 4),
    Text(_providerMeta[p]?['name'] ?? p),
  ]),
)).toList();
```

Add a new provider to DB → tab appears automatically. No Flutter rebuild needed.

---

## 54 Providers in 3 Days

| Day | Count Added | Examples |
|-----|-------------|---------|
| Day 1 | 9 | OpenAI, Anthropic, Google, Microsoft, Meta, X/xAI, DeepSeek, Mistral, Perplexity |
| Day 2 | 30 | Groq, Cohere, Amazon, Stability AI, HuggingFace, NVIDIA, IBM, Sakana AI, Baidu, Oracle... |
| Day 3 | 15 | Midjourney, Hailuo, Adobe Firefly, Apple, Databricks, Samsung, Allen AI, Naver... |

Each provider: one SQL migration file with `overview`, `models`, and `api` content seeded.

The secret to speed: **Windows App Claude Code instance** owns `supabase/migrations/` exclusively. It added 2 providers per session, ~6 sessions per day = 12 providers/day at peak velocity.

---

## Gamification: Making Learning Sticky

### Quiz + Score Tracking

```sql
CREATE TABLE ai_university_scores (
  user_id   uuid REFERENCES auth.users,
  provider  text NOT NULL,
  score     int DEFAULT 0,
  UNIQUE (user_id, provider)
);
```

Answering quizzes upserts directly via Supabase RLS — no Edge Function needed for simple writes.

### Daily Streak System

```dart
final alreadyStudied = lastStudiedDate == today;
if (!alreadyStudied) {
  newStreak = currentStreak + 1;
  // RPC call: increment_streak(user_id)
}
```

Streaks reset after 1 missed day. 7-day / 30-day / 100-day badges planned.

### Leaderboard (SQL View)

```sql
CREATE VIEW ai_university_leaderboard AS
SELECT
  user_id,
  SUM(score)               AS total_score,
  COUNT(DISTINCT provider) AS providers_studied,
  RANK() OVER (ORDER BY SUM(score) DESC) AS rank
FROM ai_university_scores
GROUP BY user_id;
```

The Flutter ranking page queries this view directly.

---

## Share Cards (OGP-style)

Users can share their progress — "I've mastered 15 AI providers!" — as a downloadable image:

```dart
// Capture widget as PNG in Flutter Web
final boundary = _shareKey.currentContext!
    .findRenderObject() as RenderRepaintBoundary;
final image = await boundary.toImage(pixelRatio: 2.0);
final bytes = await image.toByteData(format: ImageByteFormat.png);

// Download via package:web/web.dart
final anchor = web.HTMLAnchorElement()
  ..href = 'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}'
  ..download = 'ai-university-progress.png';
anchor.click();
```

---

## Study Reminder (GitHub Actions)

A daily GitHub Actions workflow fires at 09:00 JST and calls `notification-center` Edge Function:

```yaml
on:
  schedule:
    - cron: "0 0 * * *"  # 00:00 UTC = 09:00 JST

# Targets users who haven't studied in 3-30 days
# send_study_reminders action in notification-center EF
```

Users who've been idle 3+ days get a personalized reminder based on their streak and progress.

---

## What's Next

| Priority | Feature | Status |
|----------|---------|--------|
| High | Learning reminders (daily batch) | ✅ Live |
| Medium | Cross-device quiz sync (SharedPrefs → Supabase) | Planned |
| Medium | 60th provider (Adept AI / TII Falcon candidates) | Evaluating |
| Low | Social: see what friends are studying | Not started |

---

## Summary

| Feature | Status |
|---------|--------|
| 54 providers with content | ✅ DB + auto-update |
| Quiz + score persistence | ✅ Supabase RLS direct upsert |
| Leaderboard | ✅ SQL view + Flutter UI |
| Streak system | ✅ Daily tracking + badges |
| Share card (OGP) | ✅ RenderRepaintBoundary → PNG |
| Study reminder | ✅ GitHub Actions daily |

All of this in a solo project, in 3 days. The multiplier: three parallel Claude Code instances with strict file ownership. But that's a [different article](https://dev.to/kanta13jp1/running-3-parallel-claude-code-instances-to-triple-my-solo-dev-velocity-2g2p).

---

Building in public: https://my-web-app-b67f4.web.app/

#Flutter #Supabase #buildinpublic #AI #productivity
