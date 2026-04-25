-- Session PS#3-S47: AI大学 191→192社化 — Amazon Bedrock 追加
-- AWS が提供するマネージド LLM サービス。Claude・Titan・Llama・Mistral 等を
-- 単一 API で呼び出し可能。Guardrails・Agents・Knowledge Bases・Model Evaluation を提供。
-- エンタープライズグレードのセキュリティ (VPC / IAM / PrivateLink)。
-- Step 0: 8.5/9 (AWS エコシステム / Claude API代替 / エンタープライズ必須 / VPC統合)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'amazon_bedrock',
  'overview',
  'Amazon Bedrock — AWS で Claude・Llama・Titan を単一 API で使うマネージド LLM サービス',
  $md$
# Amazon Bedrock — Managed Foundation Models on AWS

**AWS で複数の LLM プロバイダーのモデルを単一 API で利用**できるマネージドサービス。

Anthropic Claude・Meta Llama・Amazon Titan・Mistral・Cohere など主要モデルを、
AWS の IAM・VPC・CloudWatch と統合した状態で安全に利用できる。
エンタープライズのセキュリティ・コンプライアンス要件を満たす設計。

## 提供モデル (2026年時点)

| プロバイダー | モデル |
| :--- | :--- |
| **Anthropic** | Claude 3.5 Sonnet / Claude 3 Haiku / Claude 3 Opus |
| **Amazon** | Titan Text G1 / Titan Embeddings G1 / Nova Micro/Lite/Pro |
| **Meta** | Llama 3.2 / Llama 3.1 (8B / 70B / 405B) |
| **Mistral** | Mistral Large / Mistral Small |
| **Cohere** | Command R+ / Command R / Embed |
| **AI21** | Jamba 1.5 Large / Jamba 1.5 Mini |
| **Stability AI** | Stable Diffusion XL / Stable Image Core |

## 主要機能

### Agents (エージェント)
- LLM + ツール + 知識ベースを統合したエージェントを NoCode で構築
- Action Groups でカスタムアクションを定義 (Lambda 関数を呼び出し)
- Human-in-the-Loop に対応

### Knowledge Bases (RAG)
- S3 のドキュメントを自動的に Vector Store に変換
- 対応 Vector Store: OpenSearch / Aurora / Redis / MongoDB / Pinecone
- 完全マネージドの RAG パイプライン

### Guardrails (安全フィルタ)
- コンテンツフィルタリング (有害コンテンツ / 個人情報 / 差別的表現)
- 特定トピックの拒否ルール
- PII (個人識別情報) の自動マスキング

### Model Evaluation
- 複数モデルの品質・コスト・レイテンシを比較評価
- カスタムデータセットでの評価

## エンタープライズセキュリティ

```
VPC ──── PrivateLink ──── Bedrock (パブリックインターネット不使用)
IAM ──── Role-Based Access Control
KMS ──── 保存データの暗号化
CloudWatch ──── ログ・監視・アラート
CloudTrail ──── 全 API 呼び出しの監査ログ
```

## Claude API vs Amazon Bedrock の使い分け

| 観点 | Anthropic Claude API | Amazon Bedrock |
| :--- | :--- | :--- |
| **設定の簡単さ** | ✅ API キーのみ | AWS アカウント + IAM 設定 |
| **AWS 統合** | — | ✅ S3/Lambda/CloudWatch 直結 |
| **VPC 分離** | — | ✅ PrivateLink |
| **マルチモデル** | Claude のみ | ✅ 8社 30+ モデル |
| **コンプライアンス** | — | ✅ HIPAA/SOC2/ISO27001 |
| **日本リージョン** | — | ✅ ap-northeast-1 (東京) |
$md$,
  'https://aws.amazon.com/bedrock/',
  '2026-04-25',
  1
),

(
  'amazon_bedrock',
  'api',
  'Amazon Bedrock 入門 — Converse API・Claude 呼び出し・Agents・Knowledge Bases',
  $md$
## セットアップ

```bash
# AWS CLI と boto3 のインストール
pip install boto3 awscli

# AWS 認証設定
aws configure
# AWS Access Key ID: AKIA...
# AWS Secret Access Key: xxx...
# Default region name: ap-northeast-1  (東京)
# Default output format: json

# Bedrock へのアクセス許可を確認
aws bedrock list-foundation-models --region ap-northeast-1 | head -20
```

---

## 1. Converse API (統一 API)

```python
import boto3
import json

# Bedrock Runtime クライアント
bedrock = boto3.client("bedrock-runtime", region_name="ap-northeast-1")

# Converse API: 全モデル共通のインターフェース
response = bedrock.converse(
    modelId="anthropic.claude-3-5-sonnet-20241022-v2:0",
    messages=[
        {
            "role": "user",
            "content": [{"text": "日本の AI 規制について教えてください"}]
        }
    ],
    inferenceConfig={
        "maxTokens": 1024,
        "temperature": 0.7,
    }
)

print(response["output"]["message"]["content"][0]["text"])
print(f"入力トークン: {response['usage']['inputTokens']}")
print(f"出力トークン: {response['usage']['outputTokens']}")
```

---

## 2. ストリーミング

```python
response = bedrock.converse_stream(
    modelId="anthropic.claude-3-5-sonnet-20241022-v2:0",
    messages=[{
        "role": "user",
        "content": [{"text": "量子コンピュータの原理を説明してください"}]
    }]
)

# ストリームからチャンクを受け取る
for event in response["stream"]:
    if "contentBlockDelta" in event:
        delta = event["contentBlockDelta"]["delta"]
        if "text" in delta:
            print(delta["text"], end="", flush=True)
```

---

## 3. マルチモーダル (画像入力)

```python
import base64
from pathlib import Path

# 画像を base64 エンコード
image_data = base64.b64encode(Path("chart.png").read_bytes()).decode()

response = bedrock.converse(
    modelId="anthropic.claude-3-5-sonnet-20241022-v2:0",
    messages=[{
        "role": "user",
        "content": [
            {
                "image": {
                    "format": "png",
                    "source": {"bytes": base64.b64decode(image_data)}
                }
            },
            {"text": "このグラフからどのような傾向が読み取れますか？"}
        ]
    }]
)
```

---

## 4. Bedrock Agents (エージェント)

```python
bedrock_agent = boto3.client("bedrock-agent-runtime", region_name="ap-northeast-1")

# エージェントを呼び出す
response = bedrock_agent.invoke_agent(
    agentId="AGENT_ID",
    agentAliasId="ALIAS_ID",
    sessionId="session-123",
    inputText="先月の売上レポートをまとめて Slack に送信してください",
)

for event in response["completion"]:
    if "chunk" in event:
        print(event["chunk"]["bytes"].decode())
```

---

## 5. Knowledge Bases (RAG)

```python
bedrock_kb = boto3.client("bedrock-agent-runtime", region_name="ap-northeast-1")

# Knowledge Base を検索して回答生成
response = bedrock_kb.retrieve_and_generate(
    input={"text": "返品ポリシーはどうなっていますか？"},
    retrieveAndGenerateConfiguration={
        "type": "KNOWLEDGE_BASE",
        "knowledgeBaseConfiguration": {
            "knowledgeBaseId": "KB_ID",
            "modelArn": "arn:aws:bedrock:ap-northeast-1::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
            "retrievalConfiguration": {
                "vectorSearchConfiguration": {"numberOfResults": 5}
            }
        }
    }
)

print(response["output"]["text"])
# 引用ソースも確認
for citation in response["citations"]:
    print(f"ソース: {citation['retrievedReferences'][0]['location']}")
```

---

## 6. Guardrails (コンテンツフィルタ)

```python
response = bedrock.converse(
    modelId="anthropic.claude-3-5-sonnet-20241022-v2:0",
    messages=[{"role": "user", "content": [{"text": user_input}]}],
    guardrailConfig={
        "guardrailIdentifier": "GUARDRAIL_ID",
        "guardrailVersion": "DRAFT",
        "trace": "enabled"
    }
)

# フィルタされた場合
if response.get("stopReason") == "guardrail_intervened":
    print("コンテンツポリシー違反のため回答できません")
```
$md$,
  'https://docs.aws.amazon.com/bedrock/latest/userguide/',
  '2026-04-25',
  2
),

(
  'amazon_bedrock',
  'models',
  'Amazon Bedrock 本番実装 — コスト最適化・LangChain 統合・Lambda 連携・東京リージョン',
  $md$
## LangChain / LangGraph との統合

```python
from langchain_aws import ChatBedrock
from langchain_core.messages import HumanMessage

# LangChain の ChatBedrock (langchain-aws パッケージ)
llm = ChatBedrock(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    region_name="ap-northeast-1",
    model_kwargs={
        "max_tokens": 2048,
        "temperature": 0.7,
    }
)

response = llm.invoke([HumanMessage(content="日本の GDP を教えてください")])
print(response.content)

# LangGraph との統合 (通常の LangChain LLM として使用可)
from langgraph.prebuilt import create_react_agent
from langchain_core.tools import tool

@tool
def get_weather(city: str) -> str:
    """天気情報を取得します"""
    return f"{city}の天気: 晴れ / 25°C"

agent = create_react_agent(llm, tools=[get_weather])
result = agent.invoke({"messages": [HumanMessage("東京の天気を教えて")]})
```

---

## Lambda 連携 (サーバーレス)

```python
# Lambda 関数内で Bedrock を呼び出す
import boto3
import json

bedrock = boto3.client("bedrock-runtime")

def lambda_handler(event, context):
    user_message = event.get("message", "")

    response = bedrock.converse(
        modelId="anthropic.claude-3-haiku-20240307-v1:0",  # 安価なモデルで高速
        messages=[{
            "role": "user",
            "content": [{"text": user_message}]
        }],
        inferenceConfig={"maxTokens": 512}
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "answer": response["output"]["message"]["content"][0]["text"],
            "tokens": response["usage"]["totalTokens"]
        }, ensure_ascii=False)
    }
```

必要な IAM ポリシー:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Converse",
      "bedrock:ConverseStream"
    ],
    "Resource": "arn:aws:bedrock:ap-northeast-1::foundation-model/*"
  }]
}
```

---

## コスト最適化

| 戦略 | 効果 |
| :--- | :--- |
| **Claude 3 Haiku 優先** | Sonnet 比 約1/10 のコスト、十分な品質 |
| **Prompt Caching** | 同一プレフィックスの 2 回目以降 90% 削減 |
| **Provisioned Throughput** | 大量処理時はオンデマンドより安価 |
| **Cross-Region Inference** | リージョン間で負荷分散・コスト最適化 |
| **Model Distillation** | 大モデルで生成したデータで小モデルを Fine-tuning |

---

## Bedrock vs Direct Claude API (このプロジェクト向け判断基準)

```
AWS 既存インフラあり? → YES → Bedrock (IAM/VPC統合が楽)
              ↓ NO
HIPAA/SOC2 等コンプライアンス必須? → YES → Bedrock
              ↓ NO
複数 LLM を切り替えたい? → YES → Bedrock (マルチモデル)
              ↓ NO
シンプルに始めたい? → YES → Anthropic Claude API (API キーのみ)
```

## クイックスタート (3 ステップ)

1. `aws configure` で AWS 認証設定 + ap-northeast-1 選択
2. `pip install boto3 langchain-aws` でインストール
3. `bedrock.converse(modelId="anthropic.claude-3-5-sonnet-...", messages=[...])` で呼び出し
$md$,
  'https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started.html',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
