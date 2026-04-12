-- Oracle AI コンテンツシード
-- AI大学: Oracle プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: エンタープライズDB最大手がAI統合基盤を提供 / OCI Generative AI で Llama/Cohere/Mistral をAPI提供 / 企業向けRAG・ベクトルDB特化

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('oracle', 'overview', 'Oracle AI (OCI Generative AI) 概要',
$$Oracle は1977年創業の世界最大のエンタープライズデータベース企業であり、**Oracle Cloud Infrastructure (OCI)** を通じて Generative AI サービスを提供しています。「自律型データベース」「AI統合DB」「エンタープライズRAG」が強みで、既存のOracle Databaseユーザーが最も恩恵を受けられるAIプラットフォームです。

## 特徴

- **OCI Generative AI**: Meta Llama・Cohere・Mistral など複数のモデルをフルマネージドで提供
- **Oracle Database 23ai**: データベースにベクトル検索 (AI Vector Search) を内蔵。SQLでEmbeddingを生成・検索できる
- **Oracle AI Services**: Vision・Language・Speech・Document Understanding などの専門AIサービス群
- **Select AI**: NL2SQL機能 — 自然言語でDBクエリを自動生成

## 強み

| 領域 | 内容 |
| :--- | :--- |
| **エンタープライズ特化** | 既存Oracleユーザーがゼロ移行コストでAI統合 |
| **ベクトルDB内蔵** | 外部ベクトルDBなしでRAGを構築 (Oracle DB 23ai) |
| **複数モデル選択** | Llama/Cohere/Mistral など用途に応じて切り替え |
| **プライベートデプロイ** | 専有クラスタで完全データ分離 |
| **コスト優位性** | 他クラウドより大幅に安いGPUインスタンス |

## 主要ユーザー

世界の Fortune 500 企業の 98% が Oracle を利用。金融・医療・小売・製造業でのAI導入に最適。$$,
'https://www.oracle.com/artificial-intelligence/', '2026-04-12', 1),

('oracle', 'models', 'Oracle OCI Generative AI — 利用可能モデル (2026)',
$$OCI Generative AI では複数のモデルプロバイダーのモデルを一つのAPIで利用できます。

## テキスト生成モデル

| モデル | プロバイダー | コンテキスト | 特徴 |
| :--- | :--- | :--- | :--- |
| **meta.llama-3.3-70b-instruct** | Meta | 128K | 汎用・高精度・オープンソース |
| **meta.llama-3.1-405b-instruct** | Meta | 128K | 最大規模・最高精度 |
| **meta.llama-3.1-8b-instruct** | Meta | 128K | 高速・低コスト |
| **cohere.command-r-plus** | Cohere | 128K | RAG特化・ツール呼び出し対応 |
| **cohere.command-r** | Cohere | 128K | 高速・コスト効率重視 |
| **mistral.mistral-large** | Mistral | 128K | 欧州規制対応・多言語 |
| **mistral.mistral-7b** | Mistral | 32K | 軽量・高速 |
| **xai.grok-2** | xAI | 131K | リアルタイム情報・推論 |

## Embedding モデル

| モデル | 次元 | 用途 |
| :--- | :--- | :--- |
| **cohere.embed-multilingual-v3.0** | 1024 | 多言語RAG・意味検索 |
| **cohere.embed-english-v3.0** | 1024 | 英語特化高精度 |

## Oracle Database 23ai AI Vector Search

```sql
-- テーブルに vector 型カラムを追加
ALTER TABLE documents ADD COLUMN embedding VECTOR(1024, FLOAT32);

-- Oracle の DBMS_VECTOR_CHAIN でEmbedding生成
UPDATE documents SET embedding =
  dbms_vector_chain.utl_to_embedding(content,
    json('{"provider":"ocigenai","credential_name":"OCI_CRED","url":"...","model":"cohere.embed-multilingual-v3.0"}'));

-- コサイン類似度検索 (SQL で完結)
SELECT title, VECTOR_DISTANCE(embedding, :query_vector, COSINE) AS score
FROM documents ORDER BY score FETCH FIRST 5 ROWS ONLY;
```$$,
'https://docs.oracle.com/en-us/iaas/Content/generative-ai/overview.htm', '2026-04-12', 2),

('oracle', 'api', 'Oracle OCI Generative AI API 入門',
$$## セットアップ

OCI アカウント作成後、API キーを設定して利用できます。

```bash
pip install oci
```

OCI SDK の設定ファイル (`~/.oci/config`):

```ini
[DEFAULT]
user=ocid1.user.oc1..xxxx
fingerprint=xx:xx:xx:xx
tenancy=ocid1.tenancy.oc1..xxxx
region=us-chicago-1
key_file=~/.oci/oci_api_key.pem
```

## Python SDK でテキスト生成

```python
import oci

# OCIクライアント初期化
config = oci.config.from_file()
generative_ai_client = oci.generative_ai_inference.GenerativeAiInferenceClient(
    config=config,
    service_endpoint="https://inference.generativeai.us-chicago-1.oci.oraclecloud.com"
)

COMPARTMENT_ID = "ocid1.compartment.oc1..xxxx"

# Llama 3.3 70B でテキスト生成
response = generative_ai_client.chat(
    oci.generative_ai_inference.models.ChatDetails(
        compartment_id=COMPARTMENT_ID,
        serving_mode=oci.generative_ai_inference.models.OnDemandServingMode(
            model_id="meta.llama-3.3-70b-instruct"
        ),
        chat_request=oci.generative_ai_inference.models.GenericChatRequest(
            messages=[
                oci.generative_ai_inference.models.UserMessage(
                    content=[oci.generative_ai_inference.models.TextContent(
                        text="OracleデータベースとAIの組み合わせメリットを教えてください。"
                    )]
                )
            ],
            max_tokens=1024,
            temperature=0.7
        )
    )
)

print(response.data.chat_response.choices[0].message.content[0].text)
```

## OpenAI互換API (LangChain対応)

```python
from langchain_openai import ChatOpenAI

# OCI Generative AI は OpenAI互換エンドポイントを提供
llm = ChatOpenAI(
    model="meta.llama-3.3-70b-instruct",
    openai_api_base="https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/chat",
    openai_api_key="<OCI_API_KEY>"
)

response = llm.invoke("RAGシステムの設計ベストプラクティスを教えてください。")
print(response.content)
```

## Oracle Database 23ai で RAG を構築

```python
import oracledb  # pip install oracledb
import oci

# Oracle DB 接続
conn = oracledb.connect(user="hr", password="xxx", dsn="localhost/FREEPDB1")

# 質問をEmbeddingに変換
embedding_client = oci.generative_ai_inference.GenerativeAiInferenceClient(config=config)
query_embedding = embedding_client.embed_text(...)  # 略

# ベクトル類似度検索 (SQL)
cursor = conn.cursor()
cursor.execute("""
    SELECT title, content
    FROM documents
    ORDER BY VECTOR_DISTANCE(embedding, :1, COSINE)
    FETCH FIRST 3 ROWS ONLY
""", [query_embedding])

context = "\n".join([row[1] for row in cursor.fetchall()])
# context を Llama 3.3 に渡してRAG回答生成
```

## 料金 (2026年4月時点, USD)

| モデル | 入力 (1M tokens) | 出力 (1M tokens) |
| :--- | :--- | :--- |
| **Llama 3.3 70B** | $0.60 | $0.60 |
| **Llama 3.1 405B** | $3.00 | $3.00 |
| **Cohere Command R+** | $2.50 | $10.00 |
| **Cohere Command R** | $0.50 | $1.50 |
| **Mistral Large** | $2.00 | $6.00 |

- **無料枠**: 毎月 1M tokens まで無料 (新規アカウント)
- **専有クラスタ**: 固定料金でデータ完全分離 (HIPAA/金融規制対応)$$,
'https://docs.oracle.com/en-us/iaas/Content/generative-ai/use-playground-chat.htm', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Oracle AI 追加 (19社目)',
  'Oracle (OCI Generative AI) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、Llama/Cohere/Mistral マルチモデル、Oracle DB 23ai AI Vector Search でのRAG構築、OpenAI互換APIでのLangChain対応を収録。AI大学プロバイダー数 18社→19社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
