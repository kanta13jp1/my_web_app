-- Perplexity AI コンテンツシード
-- AI大学: Perplexity AIプロバイダーの初期コンテンツ (overview / models / api)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('perplexity', 'overview', 'Perplexity AI 概要',
$$Perplexity AI は2022年に設立されたAI検索エンジン企業で、「答えを出す検索エンジン」として従来の検索体験を刷新しています。自然言語で質問を入力すると、ウェブ上の最新情報を収集・統合して根拠付きの回答を生成する点が特徴です。2026年現在、月間クエリ数は12〜15億件に達し、急速な成長を続けています。

同社は独自の **Sonar** モデルファミリー（Meta Llama 3.3 ベース）に加え、OpenAI・Anthropic・Google などの主要モデルも統合したプラットフォームを提供しています。2026年1月にはMicrosoft Azureと3年・7億5000万ドル規模のGPUリソース契約を締結し、エンタープライズ市場への本格展開を加速しています。

## 主要サービス

- **Perplexity Search** — リアルタイムWeb検索と引用付き回答生成（無料/Pro）
- **Perplexity Pro** — GPT-5・Claude・Geminiなど最新モデルへのアクセス（月額$20）
- **Perplexity Max** — Perplexity Computer・Model Councilなどの高度機能（月額$200）
- **Perplexity Computer** — 19種類以上のAIモデルを連携させるコンピューターエージェント
- **Model Council** — 複数の最前線モデルを同時に比較する機能
- **Sonar API** — 開発者向けリアルタイム検索グラウンディングAPI
- **Deep Research** — 自律型の深堀りリサーチ機能

## 強み

- リアルタイムWeb検索と回答生成を一体化した独自アーキテクチャ
- 引用（ソース）を必ず明示し、情報の透明性・信頼性を確保
- OpenAI・Anthropic・Meta・Googleなど多数のモデルを一プラットフォームで利用可能
- Sonar APIにより開発者がリアルタイム検索能力をアプリに組み込める
- 広告なしのサブスクリプションモデルで中立性を維持
$$,
'https://www.perplexity.ai/', '2026-04-12', 1),

('perplexity', 'models', 'Perplexity AI モデル一覧 (2026)',
$$## Sonar モデルファミリー（独自モデル）

Perplexity が開発・ホストする独自モデル群。リアルタイムWeb検索グラウンディングに最適化されています。

| モデル | コンテキスト | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **sonar** | 128K | 高速・低コスト、Llama 3.3ベース | 一般的なQ&A、チャット |
| **sonar-pro** | 200K | 高精度・大コンテキスト | 複雑なリサーチ、長文処理 |
| **sonar-reasoning** | 128K | 推論特化、思考チェーン付き | 複雑な論理タスク |
| **sonar-reasoning-pro** | 128K | 推論+高精度の組み合わせ | 高度な分析・判断 |
| **sonar-deep-research** | 128K | 自律型深堀りリサーチ | 包括的な調査レポート生成 |
| **r1-1776** | 128K | DeepSeek R1ベース、検閲なし版 | オープンな推論タスク |

## 統合済みサードパーティモデル（Proプラン以上）

Perplexity プラットフォームからアクセスできる外部モデル:

- **OpenAI**: GPT-5シリーズ（最新版含む）
- **Anthropic**: Claude 4系列（Opus・Sonnet）
- **Google**: Gemini 3.1 Pro
- **Moonshot AI**: Kimi K2.5（オープンソース推論モデル）

## 特徴的な機能

- **リアルタイムWeb検索グラウンディング** — 全モデルが最新情報を参照して回答
- **引用付き回答** — ソースURLを必ず明示（引用トークンは標準Sonarで課金なし）
- **Model Council** — 最大3モデルの出力を同時比較（Maxプランのみ）
- **Perplexity Computer** — 19種以上のモデルを連携させるエージェント型AIオペレーター
- **Deep Research** — 複数ラウンドの自律検索・統合によるリサーチレポート自動生成
$$,
'https://docs.perplexity.ai/docs/model-cards', '2026-04-12', 2),

('perplexity', 'api', 'Perplexity AI API 入門',
$$## Perplexity Sonar API の始め方

Perplexity の Sonar API は OpenAI互換のインターフェースで、リアルタイム検索グラウンディングをアプリに組み込めます。

```python
import openai

client = openai.OpenAI(
    api_key="YOUR_PERPLEXITY_API_KEY",
    base_url="https://api.perplexity.ai"
)

response = client.chat.completions.create(
    model="sonar-pro",
    messages=[
        {
            "role": "system",
            "content": "あなたは正確な情報を提供するAIアシスタントです。"
        },
        {
            "role": "user",
            "content": "2026年の最新AIモデルのトレンドを教えてください。"
        }
    ]
)

print(response.choices[0].message.content)
# citations (引用ソース) も含まれる
for citation in response.citations:
    print(f"出典: {citation}")
```

## 料金 (2026年4月時点)

### Sonar モデル（トークン料金）

| モデル | 入力 (1M tokens) | 出力 (1M tokens) | リクエスト料金 |
| :--- | :--- | :--- | :--- |
| **sonar** | $1.00 | $1.00 | $5〜$12 / 1,000 req |
| **sonar-pro** | $3.00 | $15.00 | $6〜$14 / 1,000 req |
| **sonar-reasoning** | $1.00 | $5.00 | $5 / 1,000 req |
| **sonar-reasoning-pro** | $2.00 | $8.00 | $6 / 1,000 req |
| **sonar-deep-research** | $2.00 | $8.00 | $5 / 1,000 req + 追加費用 |

※ 標準 Sonar・Sonar Pro では引用トークンは課金されません（2026年より）。

### Search API（検索のみ）

- **$5 / 1,000リクエスト** — 構造化された検索結果をランキング付きで返す

## APIキーの取得

1. [perplexity.ai/api-platform](https://www.perplexity.ai/api-platform) にアクセス
2. アカウント作成またはログイン
3. APIキーを発行し `Authorization: Bearer <KEY>` ヘッダーで使用
4. Pro ($20/月) サブスクリプションには月$5のAPIクレジットが付属
$$,
'https://docs.perplexity.ai/docs/getting-started/pricing', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Perplexity AI 追加',
  'Perplexity AI (perplexity) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、日本語コンテンツ、Sonar APIおよびリアルタイム検索グラウンディング情報を収録。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
