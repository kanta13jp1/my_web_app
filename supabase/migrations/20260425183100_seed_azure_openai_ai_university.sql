-- Session PS#3-S49: AI大学 194→195社化 — Azure OpenAI 追加
-- Microsoft Azure 上のマネージド OpenAI サービス。GPT-4o/o1/DALL-E/Whisper を
-- プライベートエンドポイント + RBAC + コンテンツフィルタで企業安全に利用可能。
-- Fortune 100 の 90%+ が採用。HIPAA・SOC2・FedRAMP 準拠。
-- Step 0: 8.5/9 (GPT-4o Enterprise / プライベートEP / コンプライアンス / Fortune100 90%+ / Azure統合)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'azure_openai',
  'overview',
  'Azure OpenAI — Microsoft Azure 上のマネージド OpenAI サービス (Fortune 100 の 90%+ 採用)',
  $md$
# Azure OpenAI Service — Enterprise Grade OpenAI on Microsoft Azure

**Microsoft Azure 上でホストされるマネージド OpenAI サービス**。
OpenAI の最新モデルを**プライベートエンドポイント・RBAC・コンテンツフィルタ**付きで
企業向けに安全に提供する。

**Fortune 100 企業の 90%+ が採用**。HIPAA・SOC2・FedRAMP・ISO 27001 準拠。

## 利用可能なモデル

| モデル | 用途 | 備考 |
| :--- | :--- | :--- |
| **GPT-4o** | マルチモーダル LLM (テキスト+画像) | 最高性能 |
| **GPT-4o mini** | コスト最適 LLM | GPT-3.5 比 高精度 |
| **o1 / o3** | 推論特化モデル (STEM/コーディング) | Chain of Thought 内部実行 |
| **GPT-4 Turbo** | 128K コンテキスト | 長文対応 |
| **DALL-E 3** | 画像生成 | 高品質 |
| **Whisper** | 音声→テキスト変換 | 57言語対応 |
| **text-embedding-3** | Embedding ベクトル生成 | RAG 用途 |

## OpenAI API との違い

| 機能 | Azure OpenAI | OpenAI API |
| :--- | :--- | :--- |
| **プライベートエンドポイント** | ✅ VNet 統合 | — |
| **RBAC** | ✅ Azure AD / Entra ID | API Key のみ |
| **コンプライアンス** | HIPAA / SOC2 / FedRAMP / ISO | SOC2 のみ |
| **コンテンツフィルタ** | ✅ カスタム設定可 | 標準のみ |
| **データ残存** | ✅ ゼロ (学習に使用しない) | オプト アウト必要 |
| **SLA** | 99.9% | 99.9% |
| **リージョン** | 世界 30+ Azure リージョン | 米国中心 |

## 主要機能

### プライベートエンドポイント
- Azure Virtual Network 内で API を完全プライベート化
- インターネット公開なしでオンプレミス/Azure リソースから安全接続

### マネージド ID と RBAC
- Azure AD / Entra ID でアクセス制御
- `Cognitive Services OpenAI User` ロールで細粒度権限管理
- API Key 不要での認証が可能

### コンテンツフィルタ
- 有害コンテンツ (暴力/ヘイト/性的) をリアルタイムフィルタリング
- カスタム分類器の追加設定も可
- フィルタ設定はエンドポイントごとに調整可能

### Azure AI Studio との統合
- ファインチューニング (GPT-3.5/GPT-4 mini)
- Prompt Flow でLLMOps パイプラインを構築
- 評価・デプロイ・モニタリングを一元管理
$md$,
  'https://azure.microsoft.com/ja-jp/products/ai-services/openai-service',
  '2026-04-25',
  1
),

(
  'azure_openai',
  'api',
  'Azure OpenAI API — Python/TypeScript SDK セットアップ・Chat Completion・Embedding・RAG 実装',
  $md$
## セットアップ

```bash
# Python SDK
pip install openai  # openai パッケージ v1+ が Azure OpenAI 対応

# Node.js / TypeScript
npm install openai
```

---

## 認証設定

```python
import os
from openai import AzureOpenAI

# API Key 認証 (最も簡単)
client = AzureOpenAI(
    azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],  # https://<resource>.openai.azure.com/
    api_key=os.environ["AZURE_OPENAI_API_KEY"],
    api_version="2024-02-01"
)

# マネージド ID 認証 (推奨 / API Key 不要)
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

token_provider = get_bearer_token_provider(
    DefaultAzureCredential(), "https://cognitiveservices.azure.com/.default"
)

client = AzureOpenAI(
    azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
    azure_ad_token_provider=token_provider,
    api_version="2024-02-01"
)
```

---

## Chat Completion

```python
# テキスト生成
response = client.chat.completions.create(
    model="gpt-4o",  # デプロイ名 (Azure ではモデル名ではなくデプロイ名を指定)
    messages=[
        {"role": "system", "content": "あなたは自分株式会社のAIアシスタントです。"},
        {"role": "user", "content": "Azure OpenAI の利点を教えてください。"}
    ],
    temperature=0.7,
    max_tokens=1000
)
print(response.choices[0].message.content)

# ストリーミング
stream = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "長い文章を生成して"}],
    stream=True
)
for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

---

## マルチモーダル (画像入力)

```python
import base64

# 画像をBase64エンコード
with open("screenshot.png", "rb") as f:
    image_data = base64.b64encode(f.read()).decode("utf-8")

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "このスクリーンショットのUIを分析してください"},
            {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{image_data}"}}
        ]
    }]
)
```

---

## Embedding (RAG 用)

```python
# テキストをベクトル化
response = client.embeddings.create(
    model="text-embedding-3-small",  # デプロイ名
    input="このプロジェクトのアーキテクチャは Flutter Web + Supabase です"
)
embedding_vector = response.data[0].embedding  # 1536次元のリスト

# Supabase pgvector で保存 (Dart 側)
# await supabase.rpc('match_documents', params: {'query_embedding': embeddingVector})
```

---

## TypeScript / Deno (Edge Function)

```typescript
// Supabase Edge Function での使用例
import { AzureOpenAI } from "npm:openai@^4";

const client = new AzureOpenAI({
  endpoint: Deno.env.get("AZURE_OPENAI_ENDPOINT")!,
  apiKey: Deno.env.get("AZURE_OPENAI_API_KEY")!,
  apiVersion: "2024-02-01",
});

const response = await client.chat.completions.create({
  model: "gpt-4o",  // Azure デプロイ名
  messages: [{ role: "user", content: "Hello from Edge Function!" }],
});
console.log(response.choices[0].message.content);
```

---

## Terraform でリソース作成

```hcl
resource "azurerm_cognitive_account" "openai" {
  name                = "my-openai-resource"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.main.name
  kind                = "OpenAI"
  sku_name            = "S0"
}

resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-05-13"
  }
  scale { type = "Standard" }
}
```
$md$,
  'https://learn.microsoft.com/ja-jp/azure/ai-services/openai/',
  '2026-04-25',
  2
),

(
  'azure_openai',
  'models',
  'Azure OpenAI 本番運用 — コンプライアンス設計・コスト最適化・このプロジェクトへの統合',
  $md$
## エンタープライズ コンプライアンス設計

### データ ガバナンス
```
Azure OpenAI の保証:
- ✅ ユーザーデータを OpenAI モデルのトレーニングに使用しない
- ✅ プロンプト/レスポンスはログ保持なし (デフォルト)
- ✅ Azure リージョン内でデータ処理 (データ越境なし)
- ✅ Customer-Managed Keys (CMK) でデータ暗号化可能
```

### ネットワーク分離
```
VNet 統合パターン:
[アプリケーション] → [Azure VNet] → [プライベートエンドポイント] → [Azure OpenAI]
                                      ↑ インターネットを経由しない
```

### コンテンツ フィルタ カスタマイズ
```python
# フィルタレベル: low / medium / high / none
# カテゴリ: hate / sexual / violence / self_harm
# ※ none は Microsoft の承認が必要

# Azure AI Studio → Deployments → Content Filter で設定
```

---

## コスト最適化

### PTU (Provisioned Throughput Units) vs Pay-as-you-go

| 方式 | コスト | 適用場面 |
| :--- | :--- | :--- |
| **Pay-as-you-go** | トークン課金 | 開発・テスト・変動トラフィック |
| **PTU (予約)** | 固定月額 | 予測可能トラフィック・コスト削減 |
| **PTU 割引** | ~50% 削減 | 大規模本番環境 |

### モデル選択戦略
```python
# コスト階層
COST_TIERS = {
    "gpt-4o": 1.0,        # 基準
    "gpt-4o-mini": 0.05,  # 95% 安い
    "o1-mini": 0.3,       # 推論タスクで高コスパ
}

# ルーティング例: タスク複雑度でモデル選択
def choose_model(task_complexity: str) -> str:
    if task_complexity == "simple":
        return "gpt-4o-mini"  # FAQ, 分類
    elif task_complexity == "reasoning":
        return "o1-mini"      # コード生成, 数学
    else:
        return "gpt-4o"       # 複雑なマルチステップ
```

---

## このプロジェクト (自分株式会社) での活用

### ai-assistant EF の Azure フォールバック

```typescript
// supabase/functions/ai-assistant/index.ts
// 既存の Claude → Azure OpenAI フォールバック

async function callAzureOpenAI(prompt: string): Promise<string> {
  const client = new AzureOpenAI({
    endpoint: Deno.env.get("AZURE_OPENAI_ENDPOINT")!,
    apiKey: Deno.env.get("AZURE_OPENAI_API_KEY")!,
    apiVersion: "2024-02-01",
  });

  const response = await client.chat.completions.create({
    model: "gpt-4o",
    messages: [
      { role: "system", content: "あなたは自分株式会社のAIアシスタントです。" },
      { role: "user", content: prompt }
    ],
  });
  return response.choices[0].message.content ?? "";
}

// ai_circuit_breaker テーブルで状態管理
// Claude → Azure OpenAI → Gemini の順でフォールバック
```

### 画像生成 (DALL-E 3) の活用

```typescript
// OGP 画像の自動生成
const imageResponse = await client.images.generate({
  model: "dall-e-3",
  prompt: "自分株式会社 AI ライフマネジメントアプリの OGP 画像。モダンでプロフェッショナルなデザイン。",
  size: "1792x1024",  // OGP 推奨サイズ
  quality: "hd",
  style: "vivid",
});
const imageUrl = imageResponse.data[0].url;
```

### RAG パイプライン (Embedding + pgvector)

```python
# 1. コンテンツを Embedding に変換
def embed_ai_university_content(content: str) -> list[float]:
    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=content
    )
    return response.data[0].embedding

# 2. Supabase に保存
# supabase.table("ai_university_content")
#     .update({"embedding": embedding_vector})
#     .eq("id", content_id)
#     .execute()

# 3. 類似検索
# supabase.rpc("match_ai_university",
#     {"query_embedding": query_vector, "match_threshold": 0.8})
```

---

## セットアップ クイックスタート (3 ステップ)

1. **Azure ポータル** → リソースグループ → Azure OpenAI → リソース作成 → モデルをデプロイ
2. **エンドポイント + API Key** をコピー → `.env` に設定
   ```
   AZURE_OPENAI_ENDPOINT=https://<resource>.openai.azure.com/
   AZURE_OPENAI_API_KEY=<your-key>
   ```
3. `pip install openai` → Python SDK でテスト呼び出し
$md$,
  'https://learn.microsoft.com/ja-jp/azure/ai-services/openai/how-to/create-resource',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
