---
title: "Zero-Config New AI Provider Tabs: DB-Driven Dynamic Tabs in Flutter + Supabase"
tags: Flutter,Supabase,buildinpublic,Dart,AI
published: false
---

# Zero-Config New AI Provider Tabs: DB-Driven Dynamic Tabs in Flutter + Supabase

## The Problem

[自分株式会社](https://my-web-app-b67f4.web.app/) has an "AI University" feature covering 66+ AI providers. Every time a new AI company releases something interesting — LMSYS, Black Forest Labs, Liquid AI — you want to add a new tab.

With hardcoded tabs, adding a provider means:
1. Edit the `TabController` length
2. Add a tab header widget
3. Add a tab body widget
4. Add the content
5. Lint, build, deploy

With DB-driven tabs, adding a provider means:
1. Insert a row in `ai_university_content`

That's it. The tab appears automatically.

---

## Architecture: DB as the Source of Truth

```
Supabase DB: ai_university_content
  provider: 'lmsys'
  category: 'overview'
  content: '## LMSYS / Chatbot Arena\n...'
      ↓
Flutter: fetch distinct providers
      ↓
Dynamic TabController(length: providers.length)
      ↓
Tab per provider, content loaded on demand
```

The `_providerMeta` map in Flutter is *optional* — it adds display color and emoji. Providers not in the map get a default icon. New providers appear in tabs without any Flutter code changes.

---

## Supabase: ai_university_content Table

```sql
CREATE TABLE ai_university_content (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  provider     text        NOT NULL,
  category     text        NOT NULL,
    -- 'overview' | 'models' | 'api' | 'news' | 'quiz'
  title        text        NOT NULL,
  content      text        NOT NULL,
  published_at date,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, category)
);
```

The `UNIQUE (provider, category)` constraint enables UPSERT without duplicates:

```sql
INSERT INTO ai_university_content (provider, category, title, content)
VALUES ('lmsys', 'overview', 'LMSYS / Chatbot Arena', '## What is LMSYS?...')
ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      updated_at = now();
```

---

## Flutter: Dynamic Tab Controller

```dart
class _GeminiUniversityV2PageState extends State<GeminiUniversityV2Page>
    with TickerProviderStateMixin {

  late TabController _tabController;
  List<String> _providers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final data = await Supabase.instance.client
        .from('ai_university_content')
        .select('provider')
        .eq('category', 'overview')
        .order('provider');

    final providers = (data as List)
        .map((e) => (e as Map<String, dynamic>)['provider'] as String)
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _providers = providers;
      _tabController.dispose();
      _tabController = TabController(length: providers.length, vsync: this);
    });
  }
}
```

Key: `_tabController.dispose()` before creating a new one. Skipping the dispose causes a `TickerProvider` leak.

---

## Flutter: _providerMeta (Optional Display Config)

```dart
class _ProviderMeta {
  final String name;
  final String emoji;
  final Color color;
  final String officialUrl;
  const _ProviderMeta({required this.name, required this.emoji,
      required this.color, required this.officialUrl});
}

final Map<String, _ProviderMeta> _providerMeta = {
  'openai':  _ProviderMeta(name: 'OpenAI',  emoji: '🤖', color: Color(0xFF10A37F), officialUrl: 'https://openai.com/'),
  'google':  _ProviderMeta(name: 'Google',  emoji: '🔷', color: Color(0xFF4285F4), officialUrl: 'https://ai.google/'),
  'lmsys':   _ProviderMeta(name: 'LMSYS / Chatbot Arena', emoji: '🏆', color: Color(0xFF1E40AF), officialUrl: 'https://lmsys.org/'),
  'black_forest_labs': _ProviderMeta(name: 'Black Forest Labs (FLUX)', emoji: '🌲', color: Color(0xFF111827), officialUrl: 'https://blackforestlabs.ai/'),
  // ... 60+ more
};

// Fallback for providers not in the map
_ProviderMeta _getMeta(String provider) {
  return _providerMeta[provider] ?? _ProviderMeta(
    name: provider.replaceAll('_', ' ').toUpperCase(),
    emoji: '🤖',
    color: Colors.grey.shade600,
    officialUrl: 'https://google.com/search?q=$provider+AI',
  );
}
```

New providers get a grey robot emoji and a Google search link until `_providerMeta` is updated. This graceful degradation means the tab is usable immediately after DB insertion.

---

## Tab Header with Dynamic Color Badge

```dart
Tab _buildTab(String provider) {
  final meta = _getMeta(provider);
  return Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: meta.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(meta.emoji),
        const SizedBox(width: 4),
        Text(meta.name, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}
```

Colored dot + emoji + name. The color dot is a `BoxDecoration` circle, not a `CircleAvatar` — zero boilerplate.

---

## Content Loading: On-Demand per Tab

```dart
Future<String> _loadContent(String provider, String category) async {
  final cached = _contentCache['$provider:$category'];
  if (cached != null) return cached;

  final data = await Supabase.instance.client
      .from('ai_university_content')
      .select('content')
      .eq('provider', provider)
      .eq('category', category)
      .maybeSingle();

  final content = (data?['content'] as String?) ?? _getFallback(provider);
  _contentCache['$provider:$category'] = content;
  return content;
}
```

`maybeSingle()` returns `null` instead of throwing when no row matches — avoids a 406 error when a provider exists in `overview` but not `news`.

`_contentCache` is a simple `Map<String, String>` — no `flutter_cache_manager` needed. Content changes rarely; an in-memory cache for the session lifetime is enough.

---

## Adding a New Provider (Complete Workflow)

```bash
# 1. Create the migration
cat > supabase/migrations/20260417000000_seed_newco_ai_university.sql << 'EOF'
INSERT INTO ai_university_content (provider, category, title, content)
VALUES
  ('newco', 'overview', 'NewCo AI', '## NewCo AI\n\nNew AI company...'),
  ('newco', 'models',   'NewCo Models', '## Models\n\n- Model A\n- Model B'),
  ('newco', 'api',      'NewCo API', '## API\n\n```bash\ncurl ...\n```')
ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content, updated_at = now();
EOF

# 2. Apply (local)
supabase db reset  # or db push in prod

# 3. Optional: add to _providerMeta in Flutter
# (if skipped, tab still appears with default styling)
```

No `TabController` length change. No widget list update. The tab appears after the next DB fetch.

---

## Summary

| Pattern | Benefit |
|---------|---------|
| DB-driven tab list | New provider = DB INSERT only |
| `_providerMeta` optional map | Graceful degradation, no crashes |
| `_tabController.dispose()` before recreate | No TickerProvider leak |
| `maybeSingle()` for optional rows | No 406 on missing categories |
| In-memory content cache | Zero extra deps, session-lifetime TTL |

66 providers. Zero `TabController.length` hardcoding.

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #AI
