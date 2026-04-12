-- Writer コンテンツシード
-- AI大学: Writer プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: エンタープライズ向けビジネスAIに特化 / Palmyra LLMシリーズはビジネス文書生成に最適化 / RAG+KnowledgeGraph統合 / コンプライアンス対応

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('writer', 'overview', 'Writer 概要',
$$Writer は2020年創業のエンタープライズAI企業。**ビジネス文書生成・コンプライアンス管理・ブランドガイドライン準拠**に特化したAIプラットフォームです。独自の Palmyra LLM シリーズはビジネス用途向けに最適化されており、マーケティング・リーガル・HR・営業などの企業ユースケースで高い評価を得ています。

## 特徴

- **Palmyra LLM**: ビジネス文書・マーケティング・法務テキスト生成に特化した独自モデルシリーズ
- **Knowledge Graph**: 企業の内部ナレッジ・ブランドガイドラインをRAGで統合
- **コンプライアンス**: SOC2 Type II・HIPAA・GDPR準拠。企業データの安全な処理
- **ブランドボイス**: 企業のトーン・スタイルガイドをAIに学習させ、一貫したブランドコミュニケーションを実現
- **No-code ワークフロー**: プログラミング不要でAI文書自動化パイプラインを構築可能

## 強み

| 領域 | 内容 |
| :--- | :--- |
| **ビジネス特化** | マーケティング・法務・HR・営業文書の生成品質が汎用LLMより高い |
| **ブランド一貫性** | 企業固有の表現・スタイルをAIに記憶させ、全文書に適用 |
| **Knowledge Graph** | 社内ドキュメント・PDF・Webページを自動インデックス化してRAGに活用 |
| **コンプライアンス** | SOC2/HIPAA/GDPR準拠。エンタープライズセキュリティ要件を満たす |
| **チーム協働** | 複数ユーザーでAI生成コンテンツをレビュー・承認するワークフロー |

## 主要ユースケース

- **マーケティング**: ブログ記事・メールキャンペーン・SNS投稿の大量生成
- **リーガル**: 契約書ドラフト・コンプライアンスチェック・法務レポート
- **HR**: 求人票・社員ハンドブック・パフォーマンスレビュー文書
- **営業**: 提案書・RFPレスポンス・製品説明文$$,
'https://writer.com/', '2026-04-12', 1),

('writer', 'models', 'Writer Palmyra — 利用可能モデル (2026)',
$$Writer の Palmyra シリーズはビジネス文書生成に特化したモデルラインナップです。

## Palmyra モデルシリーズ

| モデル | コンテキスト | 特徴 |
| :--- | :--- | :--- |
| **palmyra-x-004** | 128K | 最大・最高精度。複雑なビジネス文書・長文分析 |
| **palmyra-x-003-instruct** | 32K | 高速指示追従型。マーケティングコピー・メール生成 |
| **palmyra-med** | 32K | 医療・ヘルスケア特化。医療記録・臨床文書 |
| **palmyra-fin** | 32K | 金融特化。財務レポート・投資家向け文書 |

## 特化モデルの優位性

```text
汎用 LLM vs Palmyra の比較 (ビジネスライティングベンチマーク):

┌─────────────────────────────┬──────────┬────────────┐
│ タスク                      │ GPT-4o   │ Palmyra X  │
├─────────────────────────────┼──────────┼────────────┤
│ マーケティングコピー品質    │ 82%      │ 91%        │
│ ブランドガイドライン準拠率  │ 67%      │ 95%        │
│ コンプライアンス用語精度    │ 74%      │ 93%        │
│ 法務文書ドラフト品質        │ 79%      │ 88%        │
└─────────────────────────────┴──────────┴────────────┘
```

## Knowledge Graph 統合

Writer の Knowledge Graph は以下を自動インデックス化:

- **PDF・Word 文書**: 社内マニュアル・規程・製品仕様書
- **Web ページ**: 公式サイト・競合サイト・業界情報
- **Notion/Confluence**: 既存のナレッジベース
- **Google Drive / SharePoint**: ファイルサーバー上のドキュメント群$$,
'https://dev.writer.com/docs/models', '2026-04-12', 2),

('writer', 'api', 'Writer API 入門',
$$## セットアップ

```bash
pip install writer-sdk
# または OpenAI 互換エンドポイント経由で既存コードを流用可能
pip install openai
```

## Python SDK でテキスト生成

```python
import writerai

# Writer SDK 初期化
client = writerai.Writer(api_key="<WRITER_API_KEY>")

# Palmyra X でビジネス文書生成
response = client.chat.chat(
    model="palmyra-x-004",
    messages=[
        {
            "role": "system",
            "content": "あなたはプロのビジネスライターです。"
                       "明確・簡潔・説得力のある日本語でビジネス文書を作成してください。"
        },
        {
            "role": "user",
            "content": "新機能リリースのプレスリリースを作成してください。"
                       "製品名: 自分株式会社アプリ、新機能: AI大学 (24社のAIプロバイダーを学べる教育機能)"
        }
    ],
    max_tokens=1000,
    temperature=0.5,
)

print(response.choices[0].message.content)
```

## OpenAI 互換エンドポイント

```python
from openai import OpenAI

# Writer は OpenAI 互換 API を提供
client = OpenAI(
    api_key="<WRITER_API_KEY>",
    base_url="https://api.writer.com/v1"
)

response = client.chat.completions.create(
    model="palmyra-x-003-instruct",
    messages=[
        {"role": "user", "content": "SaaSプロダクトのオンボーディングメールを3種類作成してください。"}
    ],
    max_tokens=800,
)
print(response.choices[0].message.content)
```

## Knowledge Graph でRAGを構築

```python
import writerai

client = writerai.Writer(api_key="<WRITER_API_KEY>")

# Step 1: Knowledge Graph にファイルをアップロード
with open("company_guidelines.pdf", "rb") as f:
    file = client.files.upload(
        content=f.read(),
        content_type="application/pdf",
    )

# Step 2: Graph を作成してファイルを追加
graph = client.graphs.create(name="Company Knowledge Base")
client.graphs.file.add(graph_id=graph.id, file_id=file.id)

# Step 3: Graph を参照して質問に回答
response = client.graphs.question(
    graph_ids=[graph.id],
    question="社内の有給休暇ポリシーはどうなっていますか？",
    stream=False,
)

print(response.answer)
print(f"参照ソース: {[s.snippet for s in response.sources]}")
```

## ストリーミング生成

```python
import writerai

client = writerai.Writer(api_key="<WRITER_API_KEY>")

# ストリーミングで長文を高速表示
stream = client.chat.chat(
    model="palmyra-x-004",
    messages=[{
        "role": "user",
        "content": "2026年のAI業界トレンドを詳しく分析してください。"
    }],
    max_tokens=2000,
    stream=True,
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
```

## 料金 (2026年4月時点, USD)

| モデル | 入力 (1M tokens) | 出力 (1M tokens) |
| :--- | :--- | :--- |
| **Palmyra X 004** | $10.00 | $30.00 |
| **Palmyra X 003 Instruct** | $5.00 | $15.00 |
| **Palmyra Med** | $10.00 | $30.00 |
| **Palmyra Fin** | $10.00 | $30.00 |

- **Enterprise プラン**: カスタム価格・専有インスタンス・SLA保証
- **無料トライアル**: 14日間フル機能を無料利用可能$$,
'https://dev.writer.com/docs/quickstart', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Writer 追加 (25社目)',
  'Writer を AI大学プロバイダーとして追加。エンタープライズビジネスAI特化・Palmyra LLMシリーズ (X004/X003/Med/Fin)・Knowledge Graph RAG・ブランドガイドライン準拠機能を収録。OpenAI互換API・Knowledge Graph構築・ストリーミングの実装例を掲載。AI大学プロバイダー数 24社→25社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
