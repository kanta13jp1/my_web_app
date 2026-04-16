---
title: "Building an AI Learning Platform for 34 Providers in Flutter Web + Supabase (Auto-Updated Every 2 Hours)"
tags: Flutter,Supabase,AI,buildinpublic,webdev
published: true
---

# Building an AI Learning Platform for 34 Providers in Flutter Web + Supabase (Auto-Updated Every 2 Hours)

## Why Build This

The AI landscape is overwhelming. Google, OpenAI, Anthropic, Meta, DeepSeek, Mistral — new providers and models drop every week. Instead of trying to keep up manually, I built **AI University**: a learning platform inside my app [自分株式会社](https://my-web-app-b67f4.web.app/) that covers **34 AI providers** with auto-updating content.

This post covers:
1. The DB schema and architecture
2. The 2-layer auto-update system (GitHub Actions RSS + Claude Schedule + NotebookLM)
3. Flutter's dynamic tab implementation (new providers = new tabs with zero code changes)
4. Gamification: scores, streaks, badges, and SNS share cards

---

## The Core DB Schema

```sql
-- Content table
CREATE TABLE ai_university_content (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  provider text NOT NULL,          -- 'google', 'openai', etc.
  category text NOT NULL,          -- 'overview', 'models', 'api', 'news'
  title text NOT NULL,
  content text NOT NULL,           -- Markdown
  published_at date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(provider, category)       -- enables UPSERT
);

-- Score tracking
CREATE TABLE ai_university_scores (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users NOT NULL,
  provider text NOT NULL,
  quiz_id text NOT NULL,
  correct boolean NOT NULL,
  studied_at timestamptz DEFAULT now(),
  UNIQUE(user_id, provider, quiz_id)
);

-- Streak tracking
CREATE TABLE ai_university_streaks (
  user_id uuid REFERENCES auth.users PRIMARY KEY,
  current_streak int DEFAULT 0,
  max_streak int DEFAULT 0,
  last_studied_date date
);
```

The `UNIQUE(provider, category)` constraint is the key — it enables `ON CONFLICT DO UPDATE` upserts without duplicates. (I learned this the hard way when a missing UNIQUE constraint crashed our production deploy — [full story here](https://dev.to/kanta13jp1/how-a-missing-unique-constraint-broke-our-production-supabase-deploy-postgresql-on-conflict-3i9a).)

---

## 34 Providers, Organized by Tier

```
Mega Players (9):
  google, openai, anthropic, microsoft, meta,
  x (xAI/Grok), deepseek, mistral, perplexity

Specialized AI (11):
  groq, cohere, amazon, oracle, reka,
  aleph_alpha, together_ai, fireworks_ai, replicate,
  writer, ai21

AI Infrastructure (5):
  voyage, elevenlabs, openrouter, ollama, ideogram

Multimodal (5):
  runway, suno, udio, luma, kling

Others (4):
  pika, stability, huggingface, nvidia
```

Each provider has 4 content categories: `overview`, `models`, `api`, `news`. That's 136 content records — all automatically maintained.

---

## 2-Layer Auto-Update Architecture

Content freshness is handled by two independent systems running in parallel:

### Layer 1: GitHub Actions (every 2 hours, RSS-driven)

```yaml
# .github/workflows/ai-university-update.yml
on:
  schedule:
    - cron: '0 */2 * * *'

steps:
  - name: Update news content
    run: |
      curl -X POST \
        "https://{project}.supabase.co/functions/v1/schedule-hub" \
        -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
        -d '{"action":"ai_university.upsert_news","provider":"google","content":"..."}'
```

This is fast and lightweight — it pulls RSS feeds from official blogs and upserts the `news` category.

### Layer 2: Claude Code Schedule (every 4 hours, NotebookLM Deep Research)

```bash
notebooklm use jibun-master-brain
notebooklm source add-research "Google Gemini OpenAI GPT Anthropic Claude latest 2026"
notebooklm research wait
notebooklm ask "Summarize each AI provider's latest news"
```

The Claude Schedule writes richer, more analyzed content than raw RSS. Since both layers upsert the same records, whichever ran more recently wins — which is always the Claude Schedule's deeper content.

**Cost insight**: This keeps ~34 providers' content current with zero manual effort. GitHub Actions handles the high-frequency lightweight updates; Claude handles the depth.

---

## Flutter: Dynamic Tabs from DB

The key design decision: tabs are generated from the DB, not hardcoded. Add a new provider via SQL migration → tab appears automatically.

```dart
class _GeminiUniversityV2PageState extends State<GeminiUniversityV2Page>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<String> _providers = [];

  Future<void> _loadProviders() async {
    final response = await Supabase.instance.client
        .from('ai_university_content')
        .select('provider')
        .eq('category', 'overview');

    final providers = (response as List)
        .map((e) => e['provider'] as String)
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _providers = providers;
      _tabController = TabController(length: providers.length, vsync: this);
    });
  }
}
```

No rebuild required for new providers. The UI scales from 9 to 34 to 66 providers without touching Dart code.

---

## Score Writing with RLS Direct UPSERT

Rather than going through an Edge Function for score writes, we write directly to Supabase with RLS:

```dart
await Supabase.instance.client
    .from('ai_university_scores')
    .upsert({
      'user_id': userId,
      'provider': provider,
      'quiz_id': quizId,
      'correct': isCorrect,
      'studied_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,provider,quiz_id');
```

RLS policy:
```sql
CREATE POLICY "Users can insert own scores"
ON ai_university_scores FOR INSERT
WITH CHECK (auth.uid() = user_id);
```

Direct DB writes for user-owned data = fewer Edge Functions, lower latency.

---

## Learning Streaks via Supabase RPC

Streak logic runs in Postgres, not in the client:

```sql
CREATE OR REPLACE FUNCTION update_ai_university_streak(p_user_id uuid)
RETURNS TABLE(current_streak int, max_streak int) AS $$
DECLARE
  v_last_date date;
  v_current int;
  v_max int;
BEGIN
  SELECT last_studied_date, current_streak, max_streak
  INTO v_last_date, v_current, v_max
  FROM ai_university_streaks WHERE user_id = p_user_id;

  IF v_last_date = CURRENT_DATE - 1 THEN
    v_current := v_current + 1;      -- consecutive day
  ELSIF v_last_date = CURRENT_DATE THEN
    NULL;                              -- already studied today
  ELSE
    v_current := 1;                   -- streak reset
  END IF;

  v_max := GREATEST(v_max, v_current);

  UPDATE ai_university_streaks
  SET current_streak = v_current, max_streak = v_max,
      last_studied_date = CURRENT_DATE
  WHERE user_id = p_user_id;

  RETURN QUERY SELECT v_current, v_max;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

Calling from Dart: `await supabase.rpc('update_ai_university_streak', params: {'p_user_id': userId})`.

---

## SNS Share Card (Flutter Web → PNG)

After completing a quiz session, users can share a card showing their progress:

```dart
Future<void> _shareProgress() async {
  final boundary = _shareCardKey.currentContext!
      .findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ImageByteFormat.png);

  // Web: encode as base64 and trigger download
  final base64 = base64Encode(byteData!.buffer.asUint8List());
  final anchor = web.HTMLAnchorElement()
    ..href = 'data:image/png;base64,$base64'
    ..download = 'ai-university-progress.png'
    ..click();
}
```

Key: `package:web` (not `dart:html`) for Flutter Web. The `RenderRepaintBoundary` → PNG → base64 → `HTMLAnchorElement` pattern works cleanly without any JS interop.

---

## Results

| Feature | Implementation |
|---------|---------------|
| Providers covered | 34 (expanding) |
| Content freshness | Updated every 2h (RSS) + 4h (Claude + NotebookLM) |
| Score tracking | `ai_university_scores` with RLS direct writes |
| Streaks | Supabase RPC `update_ai_university_streak` |
| Badges | `ai_university_badges` table, EF auto-issued |
| Share cards | Flutter Web → PNG → base64 |

The AI landscape's fragmentation turned into a product feature: instead of one LLM, users learn *all* of them and build a cross-provider mental model.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #AI #webdev
