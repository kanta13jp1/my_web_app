-- Windowsアプリ版#本セッション: Snowflake AI大学コンテンツ seed
-- Snowflake Cortex AI + Arctic model — エンタープライズデータAI

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

('snowflake', 'overview',
'Snowflake AI: エンタープライズデータAIの全貌',
$$# Snowflake AI

Snowflakeは、クラウドデータプラットフォームにAIを深く統合した**エンタープライズデータAI**のリーダー。
SQL・Python・データウェアハウスと密接に連携し、ガバナンスを保ちながらAIを活用できる点が最大の特徴。

## 主要製品

| 製品 | 説明 |
|------|------|
| **Cortex AI** | Snowflake内でLLMを安全実行。外部にデータを送らずAI活用可能 |
| **Arctic** | Apache 2.0ライセンスのオープンソースLLM。SQL・コード生成特化 |
| **Snowflake Intelligence** | 自然言語でデータを問い合わせるAIエージェント (2025年11月GA) |
| **Cortex Analyst** | BI・データ分析をチャットインターフェースで操作 |
| **Document AI** | 非構造化ドキュメントからデータ抽出 |

## 強みと用途

- **データガバナンス**: データがSnowflakeの境界外に出ない安全なAI
- **SQL生成**: ArcticはSQL・コード生成でGPT-4に匹敵
- **エンタープライズ統合**: 既存データウェアハウスに即時AI追加
- **マルチモデル対応**: Cortex経由でMistral/Llama/Arcticなどを使い分け

## 競合との比較

```
Snowflake Cortex → データ内でAI実行 (セキュリティ最強)
OpenAI API       → 外部API呼び出し (柔軟性最高)
Databricks       → MLOps + Fine-tuning (カスタマイズ最強)
```

**このプロジェクトとの関連**: PostgreSQL (Supabase) + Edge FunctionパターンにSnowflakeのアプローチは参考になる。
$$,
'https://www.snowflake.com/en/product/features/cortex/',
'2026-04-16', 1),

('snowflake', 'models',
'Arctic + Cortex: Snowflakeのモデル体系',
$$# Snowflake AIモデル体系

## Arctic (オープンソースLLM)

| 項目 | 詳細 |
|------|------|
| **ライセンス** | Apache 2.0 (商用利用無料) |
| **特化** | SQL生成・コード生成・エンタープライズタスク |
| **アーキテクチャ** | MoE (Mixture of Experts) — 128エキスパート |
| **パラメータ** | 480B (アクティブ: 17B) |
| **ベンチマーク** | HumanEval / SQL benchでDRBX超え |

## Cortex AI で使えるモデル

Snowflake Cortex経由で以下のモデルをAPI呼び出し可能:

- `snowflake-arctic` — SQL/コード特化
- `mistral-large` / `mistral-7b` — 汎用
- `llama3.1-70b` / `llama3.1-8b` — Meta製
- `llama3.2-1b` / `llama3.2-3b` — 軽量
- `reka-flash` — Reka製
- `jamba-instruct` — AI21 Jamba製

## Cortex Search + Cortex Analyst

- **Cortex Search**: ベクター + キーワードのハイブリッド検索
- **Cortex Analyst**: 自然言語でデータ分析指示 (Text-to-SQL)
$$,
'https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions',
'2026-04-16', 2),

('snowflake', 'api',
'Snowflake Cortex AI: API・開発者ガイド',
$$# Snowflake Cortex AI API

## 基本的な使い方 (SQL)

```sql
-- LLM呼び出し (SQL内で直接使用)
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'snowflake-arctic',
  'このSQLクエリを最適化してください: SELECT * FROM orders WHERE ...'
) AS result;

-- 感情分析
SELECT SNOWFLAKE.CORTEX.SENTIMENT(review_text) AS sentiment
FROM customer_reviews;

-- 要約
SELECT SNOWFLAKE.CORTEX.SUMMARIZE(document_text) AS summary
FROM documents;

-- 翻訳
SELECT SNOWFLAKE.CORTEX.TRANSLATE(text, 'en', 'ja') AS japanese_text
FROM articles;
```

## Python API (Snowpark)

```python
from snowflake.cortex import Complete, Summarize, Translate

# LLM呼び出し
response = Complete("snowflake-arctic", "SQLを最適化して: ...")

# バッチ処理
df.withColumn("summary", Summarize(col("content")))
```

## REST API

```bash
curl -X POST https://<account>.snowflakecomputing.com/api/v2/cortex/inference \
  -H "Authorization: Bearer <token>" \
  -d '{"model": "snowflake-arctic", "messages": [{"role": "user", "content": "..."}]}'
```

## 料金

- Cortex LLM Functions: **Snowflake Credit**で課金 (約$0.0002〜$0.01 / 1K tokens)
- Arctic: オープンソース版は**無料**でローカル実行可
$$,
'https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions',
'2026-04-16', 3),

('snowflake', 'news',
'Snowflake AI 最新ニュース (2026-04-16)',
$$# Snowflake AI 最新動向 (2026-04-16)

## 主要アップデート

### Snowflake Intelligence GA (2025年11月)
自然言語でデータを問い合わせるAIエージェント機能が一般提供開始。
ビジネスユーザーがSQLを書かずにデータ分析できる革新的機能。

### Arctic + Azure AI Model Catalog
SnowflakeのArcticモデルがMicrosoft Azure AI Model Catalogに収録。
エンタープライズ顧客がAzure経由でもArcticを利用可能に。

### Devin (Cognition AI) との統合
Devin AIがSnowflakeとのMCP統合を発表。
自律AIエンジニアがSnowflakeデータに直接アクセスしてSQL/コード生成可能に。

### Cortex Agents (2026年 強化)
Cortex Agentsが複数ツール統合をサポート。
Snowflakeデータ + 外部API + LLM推論を組み合わせた自律エージェント構築が可能。

## 競合との位置づけ (2026年)

```
データ主権重視のエンタープライズ → Snowflake Cortex (データ外部送信なし)
フレキシブルなAPI利用 → OpenAI / Anthropic
ML/モデル訓練 → Databricks
```

## このプロジェクトへの示唆

- Supabaseでの `pg_vector` + 全文検索 → SnowflakeのCortex Searchパターンが参考に
- Edge FunctionでのLLM呼び出し → Cortexの「データ内AI」アーキテクチャをDockerパターンで応用可能
$$,
'https://www.snowflake.com/en/blog/data-ai-predictions-2026/',
'2026-04-16', 4)

ON CONFLICT (provider, category, title) DO UPDATE
  SET content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
