-- Amazon AI (Bedrock / Nova) コンテンツシード
-- AI大学: Amazon プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: AWS Bedrock でエンタープライズ最大規模 / Nova モデル公開済み / マルチモデルプラットフォーム

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('amazon', 'overview', 'Amazon AI (Bedrock) 概要',
$$Amazon (AWS) は世界最大のクラウドプロバイダーとして、AI推論インフラ・独自モデル・マルチモデルプラットフォームを提供しています。2024年末に発表した **Amazon Nova** シリーズは AWS 初の独自大規模言語モデルで、速度・コスト・精度のバランスに優れています。

**Amazon Bedrock** は複数の AI プロバイダーのモデルを単一 API で利用できるマネージドサービスで、Anthropic (Claude)・Meta (Llama)・Mistral・Cohere・AI21 Labs など多数のモデルに対応しています。エンタープライズ向けのセキュリティ・コンプライアンス・プライベートデプロイを AWS インフラで実現できる点が最大の強みです。

## 主要サービス
- **Amazon Bedrock** — マルチモデル AI プラットフォーム (50+ モデル)
- **Amazon Nova** — AWS 独自モデルシリーズ (テキスト・マルチモーダル・動画)
- **Amazon Titan** — 埋め込み・テキスト生成の旧世代モデル
- **Amazon SageMaker** — MLOps・カスタムモデルトレーニング統合基盤
- **Amazon Q** — エンタープライズ AI アシスタント (コード生成・ビジネス分析)

## 強み
- AWS の既存インフラ (VPC・IAM・CloudTrail) と完全統合 — セキュリティ・監査が容易
- 50以上のモデルを単一 API で切り替え可能 (Claude 3 / Llama / Mistral / Nova 等)
- プライベートモデルのファインチューニング・カスタマイズが可能
- エンタープライズ向け SLA・コンプライアンス (HIPAA / SOC2 / GDPR)
- S3 / DynamoDB / Lambda との Native 統合でデータパイプライン構築が容易$$,
'https://aws.amazon.com/bedrock/', '2026-04-12', 1),

('amazon', 'models', 'Amazon Nova / Bedrock モデル一覧 (2026)',
$$## Amazon Nova シリーズ (AWS 独自モデル)

| モデル | コンテキスト | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Nova Micro** | 128K | テキストのみ、超低コスト・超高速 | 分類・要約・簡単な QA |
| **Nova Lite** | 300K | マルチモーダル (テキスト+画像+動画)、低コスト | 汎用・コスト重視 |
| **Nova Pro** | 300K | 高精度マルチモーダル、バランス型 | 複雑なタスク全般 |
| **Nova Premier** | 1M | 最高精度、長文コンテキスト | 複雑な推論・長文分析 |
| **Nova Canvas** | — | テキスト→画像生成 (スタジオ品質) | 広告・コンテンツ生成 |
| **Nova Reel** | — | テキスト→動画生成 (最大2分) | 動画広告・プレゼン |

## Bedrock 経由で利用可能な主要モデル

| モデル | プロバイダー | 特徴 |
| :--- | :--- | :--- |
| **Claude 3.5 / 3.7 Sonnet** | Anthropic | 最高精度・コーディング |
| **Claude 3 Haiku** | Anthropic | 高速・低コスト |
| **Llama 3.3 70B** | Meta | OSS・汎用 |
| **Mistral Large 3** | Mistral | EU準拠・多言語 |
| **Command R+** | Cohere | RAG特化 |

## 特化機能
- **Bedrock Agents**: ツール呼び出し・RAG・アクション実行を組み合わせたエージェント構築
- **Knowledge Bases**: S3 文書を自動でベクトル化 → RAG 即時構築
- **Guardrails**: 有害コンテンツ・PII 漏洩を自動フィルタリング
- **Model Evaluation**: A/B テストで最適モデルを自動選定$$,
'https://aws.amazon.com/bedrock/nova/', '2026-04-12', 2),

('amazon', 'api', 'Amazon Bedrock API 入門',
$$## Amazon Bedrock API の始め方

AWS CLI の設定後、Python SDK (boto3) で即利用できます。

```python
import boto3
import json

# Bedrock クライアント作成
bedrock = boto3.client(
    service_name="bedrock-runtime",
    region_name="us-east-1"
)

# Amazon Nova Pro でテキスト生成
response = bedrock.invoke_model(
    modelId="amazon.nova-pro-v1:0",
    body=json.dumps({
        "messages": [
            {
                "role": "user",
                "content": [{"text": "Amazon Bedrockの強みを教えてください。"}]
            }
        ]
    })
)

result = json.loads(response["body"].read())
print(result["output"]["message"]["content"][0]["text"])
```

## Converse API (全モデル統一インターフェース)

```python
import boto3

bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")

# Claude / Nova / Llama など同一コードで切り替え可能
response = bedrock.converse(
    modelId="anthropic.claude-3-5-sonnet-20241022-v2:0",
    messages=[{"role": "user", "content": [{"text": "Hello!"}]}]
)
print(response["output"]["message"]["content"][0]["text"])
```

## Knowledge Bases (RAG 即時構築)

```python
# S3 文書から RAG を構築 (コンソール or CDK で設定後)
bedrock_agent = boto3.client("bedrock-agent-runtime", region_name="us-east-1")

response = bedrock_agent.retrieve_and_generate(
    input={"text": "会社の休暇ポリシーは？"},
    retrieveAndGenerateConfiguration={
        "type": "KNOWLEDGE_BASE",
        "knowledgeBaseConfiguration": {
            "knowledgeBaseId": "YOUR_KB_ID",
            "modelArn": "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-pro-v1:0"
        }
    }
)
print(response["output"]["text"])
```

## 料金 (2026年4月時点, us-east-1)

| モデル | 入力 (100万トークン) | 出力 (100万トークン) |
| :--- | :--- | :--- |
| **Nova Micro** | $0.035 | $0.14 |
| **Nova Lite** | $0.06 | $0.24 |
| **Nova Pro** | $0.80 | $3.20 |
| **Claude 3 Haiku** | $0.25 | $1.25 |
| **Claude 3.5 Sonnet** | $3.00 | $15.00 |

- AWS Free Tier: 新規アカウントは一定量無料
- API アクセス: [AWS Console](https://console.aws.amazon.com/bedrock/) でモデルアクセスを有効化後に利用可能
- SDK: `pip install boto3` / npm: `npm install @aws-sdk/client-bedrock-runtime`$$,
'https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started.html', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Amazon (Bedrock/Nova) 追加 (12社目)',
  'Amazon (AWS Bedrock / Nova シリーズ) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、日本語コンテンツ、Nova Pro/Lite/Micro・Converse API・Knowledge Bases RAG構築を収録。AI大学プロバイダー数 11社→12社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
