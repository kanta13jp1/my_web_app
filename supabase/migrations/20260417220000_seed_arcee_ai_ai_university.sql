-- Arcee AI 初期コンテンツシード (2026-04-17)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('arcee_ai', 'overview', 'Arcee AI 概要',
$$Arcee AI は 2023 年に米国フロリダ州マイアミで設立された **米国発のオープンソース・ファンデーションモデル企業**。中国発 (DeepSeek / Qwen / Zhipu) や大手クローズド (OpenAI / Anthropic) に対抗する、**米国生まれの真に開いた weights を持つ LLM** を掲げて開発を続けている。

2026 年 4 月、旗艦モデル **Trinity-Large-Thinking** (399B パラメータ・13B active sparse MoE) を Apache 2.0 で公開し、TechCrunch や VentureBeat で「**非中国企業が公開した最強のオープンウェイトモデル**」と評価された。Nano (6B) / Mini (26B MoE) / Large (400B MoE) の 3 サイズ構成で、エッジからクラウドまでをカバーする。

## 主要サービス

- **Trinity シリーズ** — 3 サイズのオープンウェイト LLM (Nano / Mini / Large)
- **Trinity-Large-Thinking** — 399B 推論特化モデル (Apache 2.0)
- **Arcee Cloud** — OpenAI 互換 API エンドポイント (Mini / Large ホスティング)
- **OpenRouter 統合** — Trinity Mini は OpenRouter の無料枠でも利用可能
- **MergeKit** — モデルマージ OSS ツール (50k+ GitHub stars)

## 強み

- **Apache 2.0 ライセンス**: 商用利用・改変・再配布すべて自由
- **米国生まれ**: 政府機関・金融・医療など米国規制下での採用が容易
- **OpenAI API 互換**: 既存アプリから数行で移植可能
- Mini は **$0.045 / 1M input tokens** と超低コスト
- **MergeKit** による独自モデルブレンドを公式サポート$$,
'https://www.arcee.ai/', '2026-04-17', 1),

('arcee_ai', 'models', 'Arcee AI モデル一覧 (2026)',
$$## Trinity ファミリー

| モデル | パラメータ | コンテキスト | 特徴 | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| **Trinity Nano** | 6B (A1B MoE) | 128K | エッジ / オフライン最適化 | モバイル・組込み・低レイテンシ |
| **Trinity Mini** | 26B (A3B MoE) | 128K | エージェント・ツール呼び出し特化 | バックエンド SaaS |
| **Trinity Large** | 400B (A13B MoE) | 256K | スパース MoE 大規模モデル | 高精度推論 |
| **Trinity-Large-Thinking** | 399B | 256K | Chain-of-Thought 推論強化 | 研究・数学・コーディング |

## 特徴的な機能

- **マルチターン対話** 最適化 (システム指示への追従性)
- **ツール呼び出し** (Function Calling) + 構造化 JSON 出力
- **OpenAI Chat Completions API 互換**
- **HuggingFace 公式配布** (`arcee-ai/trinity-*`)
- **OpenRouter ホスティング** (Mini は無料枠あり)
- **MergeKit 統合**: 独自モデルとのマージも公式サポート$$,
'https://www.arcee.ai/trinity', '2026-04-17', 2),

('arcee_ai', 'api', 'Arcee AI API 入門',
$$## Arcee Cloud API の始め方

```python
# OpenAI SDK で Arcee Cloud に接続 (OpenAI 互換 API)
import openai

client = openai.OpenAI(
    api_key="YOUR_ARCEE_API_KEY",
    base_url="https://api.arcee.ai/v1",
)

response = client.chat.completions.create(
    model="trinity-mini",
    messages=[
        {"role": "system", "content": "あなたは親切なアシスタントです。"},
        {"role": "user", "content": "ベクトル DB と RAG の違いを説明して"},
    ],
    temperature=0.7,
    max_tokens=1024,
)

print(response.choices[0].message.content)
```

## 料金 (2026年4月時点)

- **Trinity Mini**: $0.045 / 1M input · $0.15 / 1M output
- **Trinity Large**: 従量課金 (Contact Sales で詳細提示)
- **OpenRouter 無料枠**: Trinity Mini は OpenRouter 経由で無料 (レート制限あり)
- **Free Tier**: 月間 $5 クレジット (Nano / Mini 利用可)
- **Enterprise**: オンプレミス提供あり (専用 SLA / コンプライアンス対応)

## 参考リンク

- 公式サイト: <https://www.arcee.ai/>
- Trinity モデル: <https://www.arcee.ai/trinity>
- Open Source Catalog: <https://www.arcee.ai/open-source-catalog>
- HuggingFace: <https://huggingface.co/arcee-ai>
- OpenRouter (Mini 無料): <https://openrouter.ai/arcee-ai/trinity-mini:free>
- MergeKit OSS: <https://github.com/arcee-ai/mergekit>$$,
'https://www.arcee.ai/open-source-catalog', '2026-04-17', 3)

ON CONFLICT DO NOTHING;
