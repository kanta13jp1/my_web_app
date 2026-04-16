---
title: "From 34 to 41 AI Providers + Notion-Style Tab Blocks in Flutter Web"
tags: Flutter,Supabase,AI,buildinpublic,webdev
published: true
---

# From 34 to 41 AI Providers + Notion-Style Tab Blocks in Flutter Web

## What We Built Today

Two features shipped in one session for [自分株式会社](https://my-web-app-b67f4.web.app/):

1. **AI University expanded to 41 providers** — added Qwen (Alibaba) and Moonshot AI (Kimi)
2. **`/tabs` command in the note editor** — Notion 3.4 tab block parity in Flutter

---

## New AI Providers: Qwen and Moonshot AI

### Qwen (Alibaba Cloud)

Qwen is one of the strongest open-source LLMs available:

- **Qwen2.5-72B**: top-tier on HuggingFace open-model leaderboards
- **DashScope API**: OpenAI SDK compatible — change `base_url` only, rest stays the same
- **29 languages natively** including Japanese, Chinese, and English
- **Apache 2.0 license**: commercial use allowed without restrictions

OpenAI SDK migration example:
```python
from openai import OpenAI

client = OpenAI(
    api_key="your-dashscope-api-key",
    base_url="https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
)
# Everything else is identical to OpenAI SDK usage
```

### Moonshot AI (Kimi)

Moonshot AI's Kimi stands out for document-heavy workflows:

- **Kimi v1-128k**: 128K token context window
- **Direct file upload**: PDF and Word files processed natively — no chunking needed
- **Full OpenAI API compatibility**: same migration path as Qwen

These two bring the **Asia AI coverage** to a solid level alongside existing Baidu, Samsung, and Alibaba (via Qwen) entries.

---

## Adding a Provider: The Full Workflow

Here's the repeatable pattern for adding any new AI provider to AI University:

**Step 1: SQL migration with 3 content categories**

```sql
-- supabase/migrations/20260413XXXXXX_seed_qwen_ai_university.sql
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('qwen', 'overview', 'Qwen (Alibaba Cloud) — AI大学', '...', '2026-04-13'),
  ('qwen', 'models',   'Qwenモデル一覧', '...', '2026-04-13'),
  ('qwen', 'api',      'Qwen API ガイド', '...', '2026-04-13')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      updated_at = now();
```

**Step 2: (Optional) Add display metadata in Dart**

```dart
// gemini_university_v2_page.dart
final _providerMeta = {
  // ...existing providers...
  'qwen': ProviderMeta(emoji: '🔴', color: Color(0xFFFF6A00), name: 'Qwen'),
  'moonshot': ProviderMeta(emoji: '🌙', color: Color(0xFF6C5CE7), name: 'Moonshot'),
};
```

If you skip Step 2, the tab still appears — just with a default color and emoji.

**Step 3: Push and let GitHub Actions pick it up**

The `ai-university-update.yml` workflow runs every 2 hours and refreshes the `news` category for all providers automatically.

---

## Notion-Style `/tabs` Command in the Flutter Note Editor

Notion 3.4 introduced tab blocks — a way to organize related content under clickable tabs inside a note. We implemented the equivalent `/tabs` command in our Flutter Markdown editor.

### Implementation

```dart
void _appendTabsBlock() {
  const tabsTemplate =
      '## Tab 1\n\n(content here)\n\n---\n\n'
      '## Tab 2\n\n(content here)\n\n---\n\n'
      '## Tab 3\n\n(content here)';

  final current = _contentController.text.trimRight();
  final nextContent =
      current.isEmpty ? tabsTemplate : '$current\n\n$tabsTemplate';

  _setContentText(nextContent);
}
```

When the user types `/tabs` and selects the command:
1. Three Markdown H2 sections separated by `---` are appended
2. The user fills in content under each tab header
3. On render, these become a tabbed view

### Why Markdown-Based Tabs

Pure Markdown means:
- **Zenn-compatible**: Zenn natively supports `---` as section separators
- **GitHub-compatible**: renders as horizontal rules with headers — readable even without the tab UI
- **Export-safe**: no proprietary format lock-in

The rendering side uses `flutter_markdown` with a custom block parser that detects `---` between H2 headers and wraps them in a `DefaultTabController`.

---

## Current Provider Count: 41

```
Asia bloc (8):    qwen, moonshot, baidu, samsung, zhipu, naver, hailuo, coze
US mega (9):      google, openai, anthropic, microsoft, meta, x, deepseek, mistral, perplexity
Specialized (11): groq, cohere, amazon, oracle, reka, aleph_alpha, together_ai,
                  fireworks_ai, replicate, writer, ai21
Infrastructure(5):voyage, elevenlabs, openrouter, ollama, ideogram
Multimodal (8):   runway, suno, udio, luma, kling, pika, stability, huggingface
```

The pattern that's emerging: each region's AI ecosystem is developing distinct strengths. US = foundation models + enterprise APIs. China = open weights + cost efficiency. Europe = compliance + open source (Mistral). Building a platform that covers all three makes the learning genuinely useful.

---

## Key Takeaways

1. **OpenAI SDK compatibility is the new standard** — Qwen, Moonshot, and most new providers now support it. Migration cost = change one line.
2. **DB-driven UI = zero Dart changes for new content** — tab count scales from 9 to 41 to 66 without touching widget code.
3. **Markdown-based rich features age better** — proprietary block formats break; Markdown survives export to any platform.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #AI #webdev
