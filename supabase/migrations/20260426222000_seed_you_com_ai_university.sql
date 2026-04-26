-- PS#3 S68: AI大学 230→231社化 — You.com 追加
-- You.com: AI検索エンジン / パーソナルAIアシスタント / YouCode/YouWrite/YouImagine / プライバシー重視

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'you-com',
  'overview',
  'You.com — AIパーソナル検索エンジン (YouCode/YouWrite/YouImagine/プライバシー重視/$45M)',
  $$## You.com — AIパーソナル検索エンジン

**カテゴリ**: AI Search Engine / Personal AI Assistant / Productivity Suite
**設立**: 2020年 / 本社: Palo Alto, CA / 資金調達: ~$45M (Salesforce Ventures / Marc Benioff / DAG Ventures)
**特徴**: プライバシーファースト設計の次世代AI検索エンジン。単なる検索を超えて、YouCode (コード)・YouWrite (文章)・YouImagine (画像生成) を統合したAll-in-One AI Suiteを提供
**ユーザー**: 開発者 / ライター / 研究者 / プライバシー意識の高いユーザー
**評価**: 8/9

### 概要
You.com は **「検索 + AI生成 + プライバシー」を三位一体で提供する** AIサーチエンジン。Googleの代替として2020年に登場し、検索履歴を収集・販売しないプライバシーポリシーと、AIが直接回答を生成するチャット形式UIで急成長した。

2023年以降、単なる検索エンジンから **「AI Productivity Suite」** へ進化。YouCode (コード質問)・YouWrite (マーケティング文章)・YouImagine (Stable Diffusion画像) を無料で提供し、「すべての創造的作業をYou.comで完結」を目指す。

### 主な機能

**YouChat (AIチャット検索)**
- ChatGPT風チャットUI + リアルタイムWeb検索を統合
- 回答に引用ソース (URL) を必ず付与 (ハルシネーション対策)
- GPT-4 / Claude / Gemini から選択可能 (Pro)
- 日本語対応 / 多言語回答生成

**YouCode (開発者向け)**
- コーディング質問に特化: Stack Overflow / GitHub / 公式ドキュメントを横断検索
- コードブロック自動シンタックスハイライト
- 「このエラーを修正して」→ コード修正例を直接提示
- VS Code 拡張 (You.com Companion) 経由でIDE内検索可能

**YouWrite (AIライティング)**
- マーケティングコピー / ブログ記事 / SNS投稿を30+テンプレートで生成
- トーン調整 (professional / casual / persuasive / etc.)
- SEO最適化モード: キーワード密度 / メタデスク自動生成

**YouImagine (AI画像生成)**
- Stable Diffusion XL統合 (無料枠あり)
- 独自スタイルプリセット (photorealistic / anime / oil painting / etc.)
- 商用利用OK (You.com利用規約準拠)

**プライバシー設計**
- デフォルトで検索履歴を収集しない
- アカウントなしで全機能使用可能
- クロスサイトトラッキングをブロック
- EU GDPR準拠 / CCPA準拠

### 競合との差別化
| 項目 | You.com | Perplexity | Google AI Overview | ChatGPT Search |
|------|---------|-----------|-------------------|----------------|
| プライバシー保護 | ✅ 強 | △ | ❌ | △ |
| 無料AI生成スイート | ✅ (Code/Write/Image) | ❌ | ❌ | ❌ |
| ソース引用 | ✅ 必須 | ✅ | ✅ | ✅ |
| LLM選択 | ✅ (Pro) | △ | ❌ | ❌ |
| 広告なし | ✅ (Free) | ✅ | ❌ | ✅ |

### 導入コスト
- **Free**: YouChat / YouCode / YouWrite / YouImagine (制限あり)
- **You.com Pro**: 月$20 / GPT-4 Turbo + Claude 3.5 + Gemini 1.5 / 無制限生成 / 優先レスポンス$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'you-com',
  'api',
  'You.com API — AI検索・RAG・Web検索統合・スニペット取得 (Python/TypeScript)',
  $$## You.com API / 統合

### 概要
You.com は Web Search API + RAG API を提供。外部アプリにAI検索機能を組み込める。

### セットアップ
```bash
export YOU_API_KEY="your_api_key_here"
export YOU_BASE_URL="https://api.ydc-index.io"
```

### Web Search API
```python
import requests
import os

YOU_API_KEY = os.environ["YOU_API_KEY"]
YOU_BASE_URL = os.environ["YOU_BASE_URL"]

HEADERS = {"X-API-Key": YOU_API_KEY}

def search_web(query: str, num_results: int = 5) -> dict:
    """You.com Web検索APIでリアルタイム検索"""
    resp = requests.get(
        f"{YOU_BASE_URL}/search",
        headers=HEADERS,
        params={
            "query": query,
            "num_web_results": num_results,
        },
    )
    resp.raise_for_status()
    return resp.json()

# 競合AI最新動向を検索
results = search_web("AI productivity tools market 2026 latest funding")
for hit in results.get("hits", []):
    print(f"[{hit['title']}] {hit['url']}")
    print(hit['snippets'][:1])  # 最初のスニペット
    print()
```

### RAG API (AI回答生成 + 引用付き)
```python
def ai_search_with_rag(query: str) -> dict:
    """You.com RAG APIでAI回答+引用ソース取得"""
    resp = requests.get(
        f"{YOU_BASE_URL}/rag",
        headers=HEADERS,
        params={
            "query": query,
            "num_web_results": 5,
        },
    )
    resp.raise_for_status()
    data = resp.json()
    return {
        "answer": data.get("answer", ""),
        "sources": [
            {"title": ctx["title"], "url": ctx["url"]}
            for ctx in data.get("context", [])
        ],
    }

# AI大学のコンテンツ調査 (引用付き)
result = ai_search_with_rag(
    "What are the best AI tools for knowledge management and productivity 2026?"
)
print(f"Answer: {result['answer'][:300]}")
print(f"\nSources:")
for src in result["sources"]:
    print(f"  - {src['title']}: {src['url']}")
```

### News Search API
```python
def search_news(query: str, country: str = "JP") -> list:
    """You.com ニュース検索 (最新記事取得)"""
    resp = requests.get(
        f"{YOU_BASE_URL}/news",
        headers=HEADERS,
        params={
            "query": query,
            "count": 10,
            "country": country,
        },
    )
    resp.raise_for_status()
    return resp.json().get("news", {}).get("results", [])

# 日本語AIニュース取得
articles = search_news("AI 生成AI 最新 2026", country="JP")
for article in articles[:3]:
    print(f"[{article['publishedDate'][:10]}] {article['title']}")
    print(f"  {article['url']}")
```

### TypeScript / Deno Edge Function統合
```typescript
// supabase/functions/ai-news-search/index.ts
// You.com News API を呼び出して最新AIニュースを返すEF

const YOU_API_KEY = Deno.env.get("YOU_API_KEY")!;
const YOU_BASE_URL = "https://api.ydc-index.io";

Deno.serve(async (req: Request) => {
  const { query = "AI tools productivity 2026" } = await req.json();

  const url = new URL(`${YOU_BASE_URL}/search`);
  url.searchParams.set("query", query);
  url.searchParams.set("num_web_results", "5");

  const response = await fetch(url.toString(), {
    headers: { "X-API-Key": YOU_API_KEY },
  });

  if (!response.ok) {
    return new Response(
      JSON.stringify({ error: "You.com API error", status: response.status }),
      { status: response.status, headers: { "Content-Type": "application/json" } },
    );
  }

  const data = await response.json();
  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
});
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'you-com',
  'models',
  'You.com AI技術詳細 — マルチLLMオーケストレーション + プライバシーアーキテクチャ + 検索エンジン進化史',
  $$## You.com AI 技術詳細

### アーキテクチャ: マルチLLMオーケストレーション
```
[You.com の検索→回答パイプライン]

ユーザークエリ入力
       ↓
Intent Classification:
  - 検索クエリ分析 (情報検索 / コード / 創作 / 画像生成)
  - パーソナライズ: アカウント設定・過去の好みに基づく
  (匿名ユーザーはセッション内のみ)
       ↓
Web Retrieval (独自インデクサー):
  - You.comの独自Webクローラー + Google/Bing APIのハイブリッド
  - リアルタイムインデクシング (最新24時間のニュースも取得)
  - ドメイン信頼スコア (信頼性・新鮮さ・関連性の複合スコア)
       ↓
LLM Routing (モデル選択):
  Free: GPT-3.5 Turbo相当の高速モデル
  Pro:  GPT-4 Turbo / Claude 3.5 Sonnet / Gemini 1.5 Pro から選択
  YouCode: コード特化プロンプトエンジニアリング
       ↓
Answer Synthesis (RAG):
  - 検索結果をコンテキストとしてLLMに入力
  - 回答は必ず検索結果からの引用を含む
  - ハルシネーション対策: 「不明な場合は不明と答える」指示
       ↓
Citation Attachment:
  - 全回答に使用したURLとタイトルを付与
  - クリックで元ページに遷移
```

### プライバシーアーキテクチャ
```
You.com プライバシー vs Google の対比:

Google (従来型):
  検索クエリ → Googleサーバーに永続保存
  → プロフィール化 (年齢/興味/収入/位置)
  → ターゲット広告 (年$2000+/ユーザー収益)
  → 第三者データブローカーへ販売
  → 政府機関への任意提供

You.com (プライバシーファースト):
  検索クエリ → セッション内のみ保持 (ブラウザ閉で消去)
  → プロフィール化なし
  → 広告ターゲティングなし
  → データ販売なし
  → 収益モデル: Proサブスク + API課金 + 非個人化広告

技術実装:
  - ユーザーIDはランダムセッショントークン (永続IDなし)
  - サーバーログは24時間で自動削除
  - EU/US サーバー分離 (GDPR対応)
```

### AI検索エンジン市場の進化
```
2000年代: Google 一強時代
  → PageRank + AdWords / 検索≒リンクリスト
  → ユーザーデータを広告に活用

2010年代: パーソナライゼーション爆発
  → Google知識グラフ / 検索≒即時回答
  → プライバシー懸念増大 (DuckDuckGo台頭)

2020年代: AI検索の分岐
  → Perplexity: 引用付きAI回答特化
  → You.com: プライバシー + AI生成統合
  → Bing AI / Google AI Overview: 既存検索にAI追加
  → 課題: SEO業界「AI Overviewが流入激減」と批判

2025年以降:
  → 「検索 = 回答の起点」から「検索 = タスク完了の起点」へ
  → You.com のAll-in-One Suite戦略が市場に合致
  → API経由でLLMに検索機能を外付けする需要急増
```

### 自分株式会社での活用可能性
- **競合モニタリング**: You.com RAG API → 競合21社の最新ニュースを毎日取得 / `competitor-monitoring.yml` の代替/補完
- **AI大学コンテンツ更新**: `ai-university-update.yml` のRSSフォールバックとしてYou.com News APIを使用
- **プライバシー訴求**: 自分株式会社の「ユーザーデータ保護」機能のベンチマーク (You.comのプライバシー設計を参照)
- **コスト比較**: Perplexity API $5/1000クエリ vs You.com API $1/1000クエリ (概算) → コスト効率高い$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 230→231社化: You.com 追加',
  'PS#3 S68。You.com (AIパーソナル検索/YouCode+YouWrite+YouImagine統合/プライバシーファースト/マルチLLM/RAG API/Salesforce Ventures/$45M/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
