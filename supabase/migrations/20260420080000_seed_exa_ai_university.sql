-- PS版#3 Session 15: Exa.ai — エージェント向け embeddings-first セマンティック検索 API
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'exa',
  'overview',
  'Exa.ai — AI エージェント専用セマンティック検索 ($17M Lightspeed / Cursor @web 採用)',
  $md$## Exa.ai とは

Exa は 2024 年創業、サンフランシスコ拠点の **AI エージェント向け検索エンジン** スタートアップ。
**「LLM のために web を再設計する」** がコア信条で、キーワードマッチではなく
**embeddings (neural search)** をベースに query 意図を理解して結果を返す。

**採用実績**: Cursor の `@web` 機能・Notion AI のニュース検索などに組み込まれ、
AI エージェント系プロダクトのバックエンド検索として業界標準化しつつある。

## 既存 132 社との差別化軸

| 観点 | Exa.ai | Perplexity | Google 検索 |
|------|--------|-----------|------------|
| **設計思想** | 🔍 **エージェント/LLM 向け** | ユーザー向け回答生成 | 人間向け検索 UI |
| **ランキング** | Neural embeddings | Sonar + Retrieval | PageRank / BERT |
| **API ファースト** | ✅ 最優先 | ✅ Sonar API あり | ❌ 非公式のみ |
| **レイテンシ** | ⚡ **sub-200ms** (fast search) | 1-3 秒 | < 500ms |
| **コンテンツ抽出** | 🧹 **クリーン text** (HTML 削除) | インライン | raw HTML |
| **Deep Research** | 最大 60 秒 async mode | 10-30 秒 | なし |

## 3 つの検索モード

```text
┌─────────────────────────────────────────────┐
│  Exa API Modes                              │
│  ─────────────                              │
│  1. /search        : sub-200ms instant      │
│     └ ブラウザ風クエリで即返答               │
│  2. /search?type=neural                     │
│     └ embeddings フル活用で意図解析強化      │
│  3. /research     : 最大 60s deep search    │
│     └ 多段クエリ + 複数ソース統合            │
│                                             │
│  全モードに content extraction 組込          │
│  → raw HTML ではなく clean markdown 返却    │
└─────────────────────────────────────────────┘
```

## 創業・資金

- 設立: 2023 年 (Metaphor Systems として / 2024 Exa に rebrand)
- 共同創業者: Will Bryk (CEO) + Jeff Wang (CTO)
- Series A: **$17M** (2024-09) — Lightspeed Venture Partners リード
- シードから 1 年で Cursor / Notion AI / Replit など統合実績

## なぜ今この組織が重要か

1. **AI エージェント必須インフラ** — Cursor / Claude Code / Agentforce は外部検索が core
2. **「LLM 向け検索」カテゴリの先行者** — Bing/Google より agent-friendly
3. **embeddings-native** — GPT-4o/Claude の思考に query を合わせてくれる
4. **コスト効率** — Free 1K searches/月 → 小規模プロダクトは無料で完結
5. **開発者体験** — TypeScript/Python SDK + ドキュメントが web の中でも最高水準

## 日本語クエリ対応

日本語クエリも neural mode で解釈可能だが精度は英語 > 日本語。
日本語 SaaS で使う場合は以下パターン推奨:
- query は英訳して投げる (GPT-4o/Claude で翻訳 → Exa → 要約)
- 日本語 domain フィルタ (`includeDomains: ['note.com', 'qiita.com']`) 指定$md$,
  '2026-04-20'
),
(
  'exa',
  'models',
  'Exa API 詳細 (neural/fast/research モード + Pricing + SDK)',
  $md$## API エンドポイント一覧 (2026-04 時点)

| エンドポイント | レイテンシ | 用途 | $/1K calls |
|---------------|-----------|------|-----------|
| **POST /search** (fast) | ~200ms | 定型クエリ・高頻度呼出 | Pro $40/月 含む |
| **POST /search** (neural) | ~500ms | エージェント reasoning 前段 | Pro $40/月 含む |
| **POST /contents** | ~1s | URL から clean markdown 抽出 | 軽量バンドル |
| **POST /research** | 最大 60s | deep research / agent 多段思考 | Enterprise 相談 |
| **POST /findsimilar** | ~300ms | 既存 URL に類似ページ取得 | neural バンドル |

## 料金プラン (2026-04 時点)

```text
┌────────────────────────────────────────────┐
│  Exa Pricing (2026-03 simplified)          │
│  ──────────────                            │
│  Free        : 1,000 searches/月           │
│  Pro         : $40/月 / 25,000 searches    │
│  Pro+        : $100/月 / 100,000 searches  │
│  Enterprise  : カスタム (大規模 + SLA)     │
│                                            │
│  ※ 2026-03 変更: content extraction は     │
│     base search 料金に包含 (旧 +$0.001)    │
└────────────────────────────────────────────┘
```

## 主要 API パラメータ

```typescript
// POST https://api.exa.ai/search
{
  "query": "最新の AI エージェント設計論文",
  "type": "neural",                     // "neural" | "keyword" | "auto"
  "numResults": 10,
  "useAutoprompt": true,                // GPT がクエリを最適化
  "startPublishedDate": "2025-01-01",   // 日付フィルタ
  "includeDomains": ["arxiv.org", "anthropic.com"],
  "excludeDomains": ["reddit.com"],
  "contents": {
    "text": true,                       // 本文抽出
    "highlights": { "numSentences": 3 } // 要約抜粋
  }
}
```

## Response フォーマット

```json
{
  "results": [
    {
      "id": "exa-abc123",
      "url": "https://arxiv.org/abs/2512.16144",
      "title": "INTELLECT-3: Technical Report",
      "publishedDate": "2025-12-22",
      "author": "Prime Intellect Team",
      "text": "INTELLECT-3 is a 106B parameter MoE model...",
      "highlights": ["... distributed RL ...", "... AIME 90.8% ..."],
      "score": 0.89
    }
  ],
  "requestId": "req-xyz"
}
```

## 類似ページ検索 (/findsimilar)

エージェントが既に良いソースを 1 つ見つけた時、類似した他ソースを拡大探索:

```typescript
const response = await fetch("https://api.exa.ai/findsimilar", {
  method: "POST",
  headers: { "x-api-key": EXA_API_KEY, "Content-Type": "application/json" },
  body: JSON.stringify({
    url: "https://www.anthropic.com/news/claude-sonnet-4-6",
    numResults: 5,
    excludeSourceDomain: false,
  }),
});
```

## /research (deep research)

GPT-4o の "deep research" や Perplexity Deep Research と同カテゴリ:

```typescript
// 60秒以内で多段検索 + 要約生成
await fetch("https://api.exa.ai/research", {
  method: "POST",
  body: JSON.stringify({
    query: "2026 年の AI エージェント評価手法の最新動向",
    maxSubqueries: 10,
    maxSources: 30,
    format: "markdown",
  }),
});
```

## 既存検索 API との使い分け

| 用途 | 推奨 API |
|------|---------|
| エージェント web 検索 | **Exa.ai neural** (sub-200ms + clean content) |
| ユーザー向け回答生成 | Perplexity Sonar |
| 大規模クロール | Firecrawl / Apify |
| 最新ニュース特化 | Tavily AI |
| Google 公式 | Google Custom Search (高価 / 制限多) |
| コード検索 | GitHub Code Search API |

## 自分株式会社 (ai-hub) 統合例

```typescript
// supabase/functions/ai-hub/actions/search_web.ts (新規 action 候補)
export async function callExaSearch(payload: {
  query: string;
  type?: "neural" | "fast";
  num?: number;
}) {
  const response = await fetch("https://api.exa.ai/search", {
    method: "POST",
    headers: {
      "x-api-key": Deno.env.get("EXA_API_KEY")!,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      query: payload.query,
      type: payload.type ?? "neural",
      numResults: payload.num ?? 10,
      contents: { text: true, highlights: { numSentences: 3 } },
    }),
  });
  return await response.json();
}
```$md$,
  '2026-04-20'
),
(
  'exa',
  'api',
  'Exa.ai 使い方 (SDK / curl / Flutter 統合 / 競合比較)',
  $md$## SDK パス (3 つ)

### 1. Python SDK (最も充実)

```bash
pip install exa-py
```

```python
from exa_py import Exa

exa = Exa(api_key="xxx")

# 基本検索
results = exa.search(
    query="最新の日本語 LLM ベンチマーク",
    type="neural",
    num_results=5,
    use_autoprompt=True,
)

for r in results.results:
    print(f"{r.title} — {r.url} (score: {r.score:.2f})")

# コンテンツ抽出
contents = exa.get_contents(
    ids=[r.id for r in results.results[:3]],
    text=True,
    highlights={"num_sentences": 3},
)
```

### 2. TypeScript SDK

```bash
npm install exa-js
```

```typescript
import Exa from "exa-js";

const exa = new Exa(process.env.EXA_API_KEY!);

const { results } = await exa.searchAndContents(
  "Claude Sonnet 4.6 benchmarks 2026",
  {
    type: "neural",
    numResults: 10,
    text: true,
    highlights: { numSentences: 2 },
  }
);
```

### 3. Deno / Edge Function (自分株式会社 ai-hub 向け)

```typescript
// supabase/functions/ai-hub/actions/exa_search.ts
export async function exaSearch(query: string) {
  const response = await fetch("https://api.exa.ai/search", {
    method: "POST",
    headers: {
      "x-api-key": Deno.env.get("EXA_API_KEY")!,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      query,
      type: "neural",
      numResults: 10,
      contents: { text: true },
    }),
  });
  return await response.json();
}
```

## Flutter Web (自分株式会社) からの呼出例

```dart
// lib/services/exa_search_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ExaSearchService {
  static Future<List<Map<String, dynamic>>> search({
    required String query,
    int numResults = 10,
  }) async {
    final supabase = Supabase.instance.client;
    final response = await supabase.functions.invoke(
      'ai-hub',
      body: {
        'action': 'exa_search',
        'query': query,
        'num': numResults,
      },
    );
    final data = response.data as Map?;
    final results = data?['results'] as List?;
    return results?.cast<Map<String, dynamic>>() ?? [];
  }
}
```

## 自分株式会社からの活用イメージ

| 機能 | Exa.ai 適用 |
|------|------------|
| **AI 大学** | news カテゴリを Exa /research で自動最新化 (既存 WebSearch フォールバック改善) |
| **競合モニタリング** | `competitor-monitoring` EF の WebSearch を Exa neural に置換 (精度向上) |
| **daily-judgment** | ユーザー質問 → Exa deep research → Claude 統合 (Perplexity 的体験) |
| **AI アシスタント** | ai-hub `exa_search` action 追加で agent 拡張 |
| **ブログドラフト** | `/blog-draft` 内の技術情報収集を Exa に委譲 |

## 料金試算 (自分株式会社スケール)

```text
想定: AI アシスタント 100 users × 5 queries/day = 500 queries/day = 15K/月
  → Free (1K) 超過 → Pro $40/月 (25K 含む) で十分
  → deep research 利用なら Pro+ $100/月

GPT-4o WebBrowsing との比較:
  GPT-4o browsing: $2.50/M tokens × ~1500 tokens/query = $3.75/1K queries
  Exa Pro: $40/月 / 25K = $1.60/1K queries
  → Exa が 57% コスト削減
```

## 注意事項・制約

- **日本語精度**: 英語 > 日本語 — 重要クエリは英訳推奨
- **domain 偏り**: 英語 web に偏重 — qiita.com/note.com を明示指定すべき
- **rate limit**: Free 1K/月 (日割なし) / Pro は burst 対応
- **compliance**: SOC 2 Type II 取得済 (2025) — エンタープライズ利用可
- **PII**: クエリはログ保存される — 個人情報はハッシュ化推奨

## 公式リソース

- Web: https://exa.ai/
- Pricing: https://exa.ai/pricing
- Docs: https://docs.exa.ai/
- Python SDK: https://github.com/exa-labs/exa-py
- TypeScript SDK: https://github.com/exa-labs/exa-js
- Cursor 統合例: https://exa.ai/blog/cursor-integration

## 類似サービス比較

| サービス | 強み | 差別化 |
|---------|------|--------|
| **Exa.ai** | embeddings-first / sub-200ms / clean text | エージェント特化 最適 |
| Tavily AI | news 特化 + research モード | 時事性重視 |
| Firecrawl | クローラ / 構造化抽出 | カスタムスクレイピング |
| Perplexity Sonar | 生成 + retrieval 一体 | ユーザー向け UI |
| SerpAPI | Google/Bing スクレイピング | 非 neural / 単純 ranking$md$,
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
