---
title: "AI University: 3-File Pattern to Add Any AI Provider + Offline Fallback Content"
tags: Flutter,Supabase,buildinpublic,Dart,AI
published: true
---

# AI University: 3-File Pattern to Add Any AI Provider + Offline Fallback Content

## What Is AI University

[自分株式会社](https://my-web-app-b67f4.web.app/) includes "AI University" — a tab-based learning UI for 20+ AI providers (OpenAI, Google, Anthropic, Meta, xAI, Mistral, DeepSeek, etc.):

- Overview / Models / API / News tabs per provider
- Quiz for comprehension check
- Learning scores stored in Supabase + leaderboard
- Share card generation (RenderRepaintBoundary → PNG)
- Consecutive learning streaks

This post covers the 3-file pattern to add any new provider in under 15 minutes.

---

## The 3-File Pattern

Adding a new AI provider requires exactly 3 changes:

### 1. Supabase Migration (seed SQL)

```sql
-- supabase/migrations/20260412000001_seed_reka_ai_university.sql
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('reka', 'overview',
   'Reka AI — Multimodal-First LLM',
   '## What is Reka AI\n\nReka AI is a 2023 AI startup specializing in multimodal models...',
   '2026-04-12'),
  ('reka', 'models',
   'Reka Core / Flash / Edge Model Family',
   '## Model Overview\n\n### Reka Core\n- Largest model in the family...',
   '2026-04-12')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
```

`ON CONFLICT ... DO UPDATE` makes the migration idempotent — safe to re-run.

### 2. Flutter `_providerMeta` Map

```dart
// lib/pages/gemini_university_v2_page.dart
static const Map<String, _ProviderMeta> _providerMeta = {
  // ... existing entries
  'reka': _ProviderMeta(
    displayName: 'Reka AI',
    emoji: '🦁',
    color: Color(0xFF7B2FF7),
  ),
};
```

This controls how the provider tab renders: name, emoji, accent color. If omitted, the tab still appears (driven by DB), just with default styling.

### 3. Fallback Content

In case the Edge Function is unavailable (network error, EF not deployed yet):

```dart
static const Map<String, String> _fallback = {
  // ... existing entries
  'reka': '''## Reka AI

Multimodal-first AI startup focused on Reka Core, Flash, and Edge models.

**Key strengths**: Image + text understanding, competitive with GPT-4V.
''',
};
```

The fallback renders as Markdown. Users get content even offline.

---

## 20 Providers Added in One Session

| Category | Providers |
|----------|-----------|
| Big Tech | Google, Microsoft, Meta, Apple |
| AI Startups | OpenAI, Anthropic, xAI (Grok), Mistral, Perplexity, DeepSeek |
| Enterprise | Amazon (Nova/Bedrock), Cohere, IBM (watsonx) |
| Cloud/HW | NVIDIA, Samsung, Baidu (ERNIE) |
| Emerging | Groq, Oracle (OCI), Reka AI |
| Asia | Qwen (Alibaba) |

Each took ~10 minutes: write the SQL seed, add `_providerMeta` entry, add fallback string.

---

## DB-Driven Tab Generation

The UI reads providers from `ai_university_content` — no hardcoded tab list:

```dart
// Fetch distinct providers from DB
final data = res.data as Map<String, dynamic>?;
final providers = (data?['providers'] as List?)
    ?.cast<String>() ?? [];

// TabController sized to actual provider count
_tabController = TabController(length: providers.length, vsync: this);
```

Add a provider to the DB → tab appears automatically. Remove from DB → tab disappears. No Flutter rebuild required.

---

## Auto-Update Architecture

The AI University content stays current via a two-layer update pipeline:

| Layer | Frequency | Method |
|-------|-----------|--------|
| GitHub Actions `ai-university-update.yml` | Every 2 hours | RSS feeds per provider |
| Claude Schedule | Every 4 hours | NotebookLM Deep Research |

Both upsert to the same `ai_university_content` table. The later-written record wins — Claude Schedule's richer content overwrites the GHA RSS summary.

---

## Offline Fallback vs Live Data

```dart
Future<void> _loadContent(String provider, String category) async {
  try {
    final res = await _supabase.functions.invoke(
      'ai-university-content',
      body: {'action': 'get', 'provider': provider, 'category': category},
    );
    final data = res.data as Map<String, dynamic>?;
    setState(() => _content = data?['content'] as String? ?? _fallback[provider] ?? '');
  } catch (_) {
    setState(() => _content = _fallback[provider] ?? 'Content unavailable');
  }
}
```

The fallback chain: EF response → `_fallback[provider]` → hardcoded error string. Users always see something.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #AI #Dart
