-- PS#3 S71: AI大学 236→237社化 — Langfuse 追加
-- Langfuse: OSS LLMオブザーバビリティ / トレーシング / 評価 / プロンプト管理 / Sequoia €4M / Berlin

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'langfuse',
  'overview',
  'Langfuse — OSS LLMオブザーバビリティ (トレーシング+評価+プロンプト管理 / Sequoia €4M / Berlin / GitHub 8k+)',
  $$## Langfuse — LLMアプリケーション オブザーバビリティ プラットフォーム

**カテゴリ**: LLM Observability / Monitoring / Evaluation / Prompt Management
**開発元**: Langfuse GmbH / 本社: Berlin, Germany
**設立**: 2023年 / 創業者: Clemens Rawert / Marc Klingen / Max Deichmann
**資金調達**: €4M Seed (2023年) + Series A準備中 / 投資家: Sequoia (Surge) / Y Combinator W23
**GitHub**: 8,000+ stars / MIT ライセンス (OSS)
**提供形態**: Cloud (langfuse.com) / Self-hosted (Docker)
**評価**: 9/9

### 概要
Langfuse は **「LLMアプリの本番トラフィックを可視化・評価・改善するためのオブザーバビリティプラットフォーム」**。従来のアプリと異なり、LLMアプリは同じ入力でも出力が不定期に変化し、コスト・品質・レイテンシのトレードオフが複雑。Langfuse はこれらを一元管理する。

2023年 Y Combinator 出身。Dify / LangChain / LlamaIndex / OpenAI SDK など主要フレームワークと公式インテグレーション済みで、**「LLMアプリを本番運用するなら Langfuse は必須」** と評される。

### 主な機能

**トレーシング (Tracing)**
- LLMコールごとに入力・出力・レイテンシ・コストを自動記録
- ネストしたスパン (Span): 複数LLMコールの親子関係を可視化
- セッション追跡: マルチターン会話を1セッションとして集約
- メタデータ: ユーザーID / バージョン / 環境 (prod/staging) を付与

**評価 (Evaluation)**
- LLM-as-a-Judge: 自動品質スコアリング (GPT-4 / Claude で出力の品質を評価)
- ヒューマンアノテーション: UI上でエンジニアがグッド/バッドを付ける
- データセット: 良い例/悪い例を蓄積 → 回帰テストに使用
- カスタムスコア: 独自評価基準を関数で定義

**プロンプト管理**
- バージョン管理: プロンプトの変更履歴 + ロールバック
- A/Bテスト: 複数プロンプトバリアントのパフォーマンス比較
- 本番デプロイ: コードを再デプロイせずプロンプトを更新

**コスト・使用量モニタリング**
- トークン数・API コストをリアルタイム集計
- モデル別・機能別・ユーザー別のコスト内訳
- コスト異常検知アラート

### フレームワークインテグレーション
| フレームワーク | 統合方法 |
|--------------|---------|
| OpenAI SDK | `openai` ライブラリをラップする `langfuse.openai` で差し替え |
| Anthropic SDK | `langfuse.anthropic` でラップ |
| LangChain | `CallbackHandler` を1行追加 |
| LlamaIndex | `LlamaIndexInstrumentor` |
| Dify | Dify の設定画面から Langfuse エンドポイントを入力 |
| OpenTelemetry | OTEL エクスポーターとして使用可 |

### 導入コスト
- **Hobby (無料)**: 50,000イベント/月 / 1ユーザー / 60日保持
- **Pro**: 月$59 / 100万イベント / チームメンバー複数 / 90日保持
- **Team**: 月$499 / 無制限 / SSO / SLA
- **Self-hosted**: 無料 (MIT) / Enterprise版は有償

### 自分株式会社での活用可能性
- **AI大学コンテンツ更新WF監視**: `ai-university-update.yml` の各LLMコールをトレース → コスト最適化
- **CS自動返信品質評価**: `reply-support-request` EFの返信品質を LLM-as-a-Judge で自動スコアリング
- **プロンプト管理**: `daily-judgment` / `ai-assistant` EF のプロンプトをコードから外出し → コード再デプロイなしで改善$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'langfuse',
  'api',
  'Langfuse SDK — トレーシング実装 (Python/TypeScript / OpenAI+Anthropic統合 / Supabase EF統合)',
  $$## Langfuse SDK / 統合

### セットアップ
```bash
pip install langfuse
# または
npm install langfuse
```

```bash
export LANGFUSE_PUBLIC_KEY="pk-lf-..."
export LANGFUSE_SECRET_KEY="sk-lf-..."
export LANGFUSE_HOST="https://cloud.langfuse.com"  # Self-hostedなら自ドメイン
```

### OpenAI SDK ドロップイン統合 (Python)
```python
# 既存コード: import openai
# 変更後: from langfuse.openai import openai  ← これだけ!

from langfuse.openai import openai
import os

client = openai.OpenAI()

def ask_ai(question: str, user_id: str = "anonymous") -> str:
    """Langfuse トレーシング付き OpenAI 呼び出し"""
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": question}],
        # Langfuse メタデータ (オプション)
        metadata={
            "user_id": user_id,
            "feature": "ai-university-qa",
        }
    )
    return response.choices[0].message.content

# → Langfuse ダッシュボードに自動でトレースが記録される
answer = ask_ai("Difyとは何ですか？", user_id="user_123")
```

### Anthropic SDK 統合 (Python)
```python
from langfuse.anthropic import anthropic

client = anthropic.Anthropic()

def claude_complete(prompt: str, session_id: str = "") -> str:
    """Langfuse トレーシング付き Claude 呼び出し"""
    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
        metadata={"session_id": session_id},
    )
    return message.content[0].text

response = claude_complete("Cursor AIの特徴を3点で説明して")
```

### 手動トレーシング (複雑なフロー向け)
```python
from langfuse import Langfuse

lf = Langfuse()

def rag_pipeline(query: str, user_id: str) -> str:
    """RAGパイプライン全体をトレース"""
    # トレース開始
    trace = lf.trace(
        name="rag-pipeline",
        user_id=user_id,
        input={"query": query},
        session_id=f"session-{user_id}",
    )

    # Step 1: ベクター検索
    retrieval_span = trace.span(
        name="vector-retrieval",
        input={"query": query},
    )
    docs = vector_db.search(query, top_k=5)
    retrieval_span.end(output={"doc_count": len(docs)})

    # Step 2: LLM 生成
    generation = trace.generation(
        name="llm-generation",
        model="claude-sonnet-4-6",
        input=[{"role": "user", "content": f"Context: {docs}\n\nQ: {query}"}],
    )
    answer = call_claude(docs, query)
    generation.end(output=answer)

    # トレース終了
    trace.update(output={"answer": answer})
    lf.flush()
    return answer
```

### Deno Edge Function 統合 (TypeScript)
```typescript
// supabase/functions/ai-assistant/index.ts (Langfuse統合版)
import Anthropic from "npm:@anthropic-ai/sdk";
import { Langfuse } from "npm:langfuse";

const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });
const langfuse = new Langfuse({
  publicKey: Deno.env.get("LANGFUSE_PUBLIC_KEY")!,
  secretKey: Deno.env.get("LANGFUSE_SECRET_KEY")!,
  baseUrl: Deno.env.get("LANGFUSE_HOST") ?? "https://cloud.langfuse.com",
});

Deno.serve(async (req: Request) => {
  const { message, userId = "anonymous" } = await req.json();

  const trace = langfuse.trace({
    name: "ai-assistant",
    userId,
    input: { message },
  });

  const generation = trace.generation({
    name: "claude-response",
    model: "claude-sonnet-4-6",
    input: [{ role: "user", content: message }],
  });

  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    messages: [{ role: "user", content: message }],
  });

  const answer = response.content[0].type === "text" ? response.content[0].text : "";

  generation.end({ output: answer });
  trace.update({ output: { answer } });
  await langfuse.flushAsync();

  return new Response(JSON.stringify({ answer }), {
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
  'langfuse',
  'models',
  'Langfuse 技術詳細 — OpenTelemetry準拠 / LLMオブザーバビリティ比較 / コスト可視化アーキテクチャ',
  $$## Langfuse 技術詳細

### OpenTelemetry (OTEL) 準拠アーキテクチャ

Langfuse は v2.x から **OpenTelemetry (OTEL)** プロトコルに準拠しており、既存のオブザーバビリティインフラと統合できる。

```
[Langfuse のデータフロー]

LLMアプリ (Python / TypeScript / Deno)
  ↓ SDK または OTEL エクスポーター
Langfuse Ingestion API (HTTPS)
  ↓ キューイング (非同期・ノンブロッキング)
Langfuse Worker
  ├── イベント正規化
  ├── トークン数計算 (tiktoken)
  ├── コスト計算 (モデル別単価テーブル)
  └── 集計 (セッション / ユーザー / プロジェクト別)
  ↓
PostgreSQL (トレース・スパン・スコア保存)
ClickHouse (分析クエリ用カラムナーDB、大規模向け)
  ↓
Langfuse UI (Next.js)
  ├── トレースビューア (ウォーターフォール表示)
  ├── ダッシュボード (コスト・品質トレンド)
  ├── データセット管理 (評価用サンプル)
  └── プロンプト管理 (バージョン管理付き)
```

### LLMオブザーバビリティ競合比較

| 項目 | **Langfuse** | **Helicone** | **LangSmith** | **Arize AI** |
|------|-------------|-------------|--------------|-------------|
| OSS | ✅ MIT | ✅ MIT | ❌ (商用) | ❌ (商用) |
| セルフホスト | ✅ Docker | ✅ | ❌ | ❌ |
| LLM評価 | ✅ LLM-judge | △ | ✅ | ✅ |
| プロンプト管理 | ✅ | △ | ✅ LangHub | △ |
| OTEL準拠 | ✅ v2+ | △ | △ | ✅ |
| 月額最安 | 無料 (50k ev) | 無料 (10k req) | 無料 (100k) | 無料 (制限) |
| データ保管場所 | 選択可 (EU/US/Self) | US | US | US |
| **日本企業推奨度** | ◎ (EU準拠/Self-host) | ○ | △ | △ |

### コスト可視化の仕組み

```python
# Langfuse 内部のコスト計算 (概念コード)

MODEL_COSTS = {
    "claude-sonnet-4-6": {
        "input": 3.00 / 1_000_000,   # $3.00 per 1M input tokens
        "output": 15.00 / 1_000_000, # $15.00 per 1M output tokens
        "cache_read": 0.30 / 1_000_000,
        "cache_write": 3.75 / 1_000_000,
    },
    "gpt-4o": {
        "input": 2.50 / 1_000_000,
        "output": 10.00 / 1_000_000,
    },
    # 200+ モデルの単価テーブルを内蔵
}

def calculate_cost(model: str, usage: dict) -> float:
    costs = MODEL_COSTS.get(model, {})
    return (
        usage.get("input_tokens", 0) * costs.get("input", 0)
        + usage.get("output_tokens", 0) * costs.get("output", 0)
        + usage.get("cache_read_input_tokens", 0) * costs.get("cache_read", 0)
    )
```

### 自分株式会社でのコスト最適化事例 (想定)

```
現状 (推定):
  ai-university-update.yml: 60プロバイダー × 2時間毎 × ~500トークン = ~720,000トークン/日
  cs-check.yml: 10チケット × 4時間毎 = ~50,000トークン/日
  daily-report: 1回 × ~10,000トークン/日
  合計: ~780,000トークン/日 ≈ 月$35 (Claude Sonnet換算)

Langfuse 導入後の改善:
  ① トレースで「無駄なLLMコール」特定 → キャッシュ導入
  ② コスト高い機能を特定 → モデルをHaikuに切替可能か判断
  ③ 評価スコアが低いプロンプトを特定 → 改善優先度付け
  期待効果: Claude API コスト 30〜50% 削減
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 236→237社化: Langfuse 追加',
  'PS#3 S71。Langfuse (OSS LLMオブザーバビリティ/トレーシング+評価+プロンプト管理/OpenTelemetry準拠/Sequoia YC W23/€4M/Berlin/MIT/GitHub 8k+/9/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
