-- Session PS#3-S30: AI大学 154社化 — Firecrawl 追加
-- Mendable.ai (Nicolas Camara) が 2023 年にオープンソースで公開した LLM 向け Web スクレイピング API。
-- 生の HTML を LLM がそのまま消費できるクリーンな Markdown / 構造化 JSON に変換して返す。
-- Free (500 クレジット) / Hobby $16/月 / Standard $83/月 / Scale $749/月 の段階プラン。
-- GitHub 29,000+ stars / 2,000+ コントリビュータ / Python + Node.js SDK 対応。
-- 既存 153 社に空白だった「AI エージェント向け Web データ収集・クロール インフラ」軸を埋める。
-- Step 0: 9/9 (OSS・公開 API・RAG/エージェント開発で必須ツール化)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'firecrawl',
  'overview',
  'Firecrawl — AI・LLM 向けクリーンデータ Web スクレイピング API',
  $md$
# Firecrawl — The Web Scraping API for AI

2023 年 Mendable.ai チームが OSS として公開した **LLM ファーストな Web スクレイピング API**。

生の HTML を直接 LLM に食わせると余分なタグ・広告・ナビゲーションがノイズになる問題を解決。
Firecrawl はレンダリング済みページを自動的に **クリーンな Markdown または構造化 JSON** に
変換し、RAG パイプラインや AI エージェントがすぐに使えるデータとして返す。

GitHub 29,000+ stars、2,000+ コントリビュータ。
LangChain・LlamaIndex・CrewAI・Mastra などの主要フレームワークと公式インテグレーション済み。

## 主要機能
- **Scrape** — 単一 URL をクリーン Markdown / JSON に変換 (JS レンダリング対応)
- **Crawl** — サブページを再帰的にクロール (深度・URL パターン指定可)
- **Map** — サイト全体の URL 一覧を取得 (sitemap.xml + リンクグラフ)
- **Search** — DuckDuckGo / Google 経由で検索 → 結果ページを即座にスクレイプ
- **Extract** — LLM プロンプトで構造化データを抽出 (スキーマ定義不要)
- **Watch** — ページ変更をリアルタイム監視 (Webhook 通知)
- **自己ホスト** — OSS のため独自サーバーへのデプロイも可能

## 強み
- LLM に最適化された **クリーン Markdown** 出力 (余分な HTML タグ・広告除去済み)
- 動的 JS レンダリング対応 (Playwright / Headless Chrome で SPA にも対応)
- **クレジット制の透明な従量課金** — 1 クレジット = 1 ページ (基本)
- RAG・AI エージェント開発のデファクトスタンダードとして急速に普及中
$md$,
  'https://firecrawl.dev/',
  '2026-04-24',
  1
),

(
  'firecrawl',
  'models',
  'Firecrawl API エンドポイント一覧 (2026)',
  $md$
## Firecrawl API エンドポイント

Firecrawl は「モデル」ではなく「データ取得エンドポイント」を提供する。

## 主要 API エンドポイント

| エンドポイント | メソッド | 説明 | クレジット消費 |
| :--- | :--- | :--- | :--- |
| `/v1/scrape` | POST | 単一 URL をスクレイプ | 1〜9 クレジット/ページ |
| `/v1/crawl` | POST | サイト全体をクロール | 1 クレジット/ページ |
| `/v1/map` | POST | サイト URL マップ取得 | 1 クレジット/マップ |
| `/v1/search` | POST | 検索 + スクレイプ | 1 クレジット/結果 |
| `/v1/extract` | POST | LLM で構造化データ抽出 | 1〜5 クレジット/URL |

## 出力フォーマット

| フォーマット | 説明 | 用途 |
| :--- | :--- | :--- |
| **Markdown** | クリーンな本文 (デフォルト) | RAG・要約・分析 |
| **HTML** | フィルタ済み HTML | カスタム変換 |
| **JSON (Extract)** | 構造化データ | データパイプライン |
| **Screenshot** | ページのスクリーンショット | ビジュアル検証 |
| **Links** | ページ内リンク一覧 | クロール計画 |

## プラン別制限

| プラン | 月額 | クレジット | 同時リクエスト |
| :--- | :--- | :--- | :--- |
| **Free** | $0 | 500 (一回限り) | 1 |
| **Hobby** | $16 | 3,000/月 | 5 |
| **Standard** | $83 | 100,000/月 | 10 |
| **Growth** | $333 | 500,000/月 | 20 |
| **Scale** | $749 | 1,500,000/月 | 50 |

> **注意**: Enhanced Mode / JS レンダリング / Extract 機能は最大 9× クレジット消費
$md$,
  'https://docs.firecrawl.dev/',
  '2026-04-24',
  2
),

(
  'firecrawl',
  'api',
  'Firecrawl API 入門',
  $md$
## Firecrawl API の始め方

```python
# pip install firecrawl-py
from firecrawl import FirecrawlApp

app = FirecrawlApp(api_key="your-api-key")

# 単一 URL をスクレイプ → Markdown 出力
result = app.scrape_url(
    "https://docs.anthropic.com/claude/docs",
    params={"formats": ["markdown"]}
)
print(result["markdown"])  # LLM-ready な Markdown テキスト

# サイト全体をクロール
crawl_result = app.crawl_url(
    "https://example.com",
    params={
        "limit": 100,
        "scrapeOptions": {"formats": ["markdown"]}
    }
)

# 構造化データを LLM プロンプトで抽出
extract_result = app.extract(
    "https://example.com/product",
    schema={
        "type": "object",
        "properties": {
            "price": {"type": "number"},
            "name": {"type": "string"}
        }
    }
)
```

## LangChain との統合

```python
from langchain_community.document_loaders import FireCrawlLoader

loader = FireCrawlLoader(
    api_key="your-api-key",
    url="https://example.com",
    mode="crawl"  # "scrape" or "crawl"
)
documents = loader.load()  # LangChain Document オブジェクト
```

## 料金 (2026年4月時点)

| プラン | 料金 | クレジット | 超過料金 |
| :--- | :--- | :--- | :--- |
| **Free** | $0 | 500 (一回限り) | — |
| **Hobby** | $16/月 | 3,000/月 | $9/1k クレジット |
| **Standard** | $83/月 | 100,000/月 | $4.5/1k クレジット |

## クイックスタート

1. [firecrawl.dev](https://firecrawl.dev) でアカウント作成 → API キー取得
2. `pip install firecrawl-py` または `npm install @mendable/firecrawl-js`
3. `FirecrawlApp(api_key=...)` を初期化
4. `scrape_url()` または `crawl_url()` でデータ取得 → LLM に渡す
$md$,
  'https://docs.firecrawl.dev/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
