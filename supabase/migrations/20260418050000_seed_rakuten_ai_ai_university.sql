-- Rakuten AI 3.0 初期コンテンツシード (2026-04-18)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('rakuten_ai', 'overview', 'Rakuten AI 3.0 概要',
$$**Rakuten AI 3.0** は楽天グループが経済産業省 (METI) と新エネルギー・産業技術総合開発機構 (NEDO) による **GENIAC (Generative AI Accelerator Challenge)** プロジェクトの一環として開発した、日本国内最大級のファウンデーションモデル。2025 年 12 月 18 日に発表、2026 年 3 月 17 日に **Apache 2.0** ライセンスで公開された。

**約 700 億パラメータ** の Mixture of Experts (MoE) モデルで、日本語処理に特化しながらも英語・中国語も高水準に扱える。楽天グループ全サービスが活用する **Rakuten AI Gateway** 経由で GenAI API 群を提供し、エンタープライズ・個人開発者の両方にアクセス可能。

## 主要サービス

- **Rakuten AI 3.0 (Base)** — 700B MoE / 日本語最適化
- **Rakuten AI Gateway** — 内部統合 GenAI API プラットフォーム
- **HuggingFace 公開ウェイト** — Apache 2.0 で完全オープン
- **楽天市場・楽天トラベル統合** — 商品検索・旅行プラン生成への組込

## 強み

- **日本最大級** の国産 MoE モデル (700B)
- **GENIAC 選定** (経産省 + NEDO) による信頼性
- **Apache 2.0** ライセンスで **商用無制限**
- **日本語特化**: 敬語・ビジネス文書・関西弁まで網羅
- 楽天 1.5億ユーザー基盤での実戦投入済み$$,
'https://global.rakuten.com/corp/news/press/2026/0317_01.html', '2026-04-18', 1),

('rakuten_ai', 'models', 'Rakuten AI モデル一覧 (2026)',
$$## Rakuten AI 系列

| モデル | パラメータ | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Rakuten AI 3.0** | 700B MoE | 日本最大級・GENIAC最新版 | 高精度日本語タスク全般 |
| **Rakuten AI 2.0** | 8x7B MoE | 前世代 (2024年12月) | コスト重視タスク |
| **Rakuten AI 7B** | 7B | 軽量オープン版 | エッジ・ローカル実行 |
| **Rakuten AI 7B-Instruct** | 7B | SFT版 | Instruction Following |

## 特徴的な機能

- **日本語特化 MoE**: エキスパート層が日本語/英語で分岐
- **楽天独自データ**: 1.5億ユーザーの購買・旅行データで学習 (匿名化済み)
- **関西弁対応**: 方言ベンチマークでも高スコア
- **ビジネス文書生成**: 敬語・社内メール・営業資料に特化
- **HuggingFace 公開**: `Rakuten/RakutenAI-3.0-Instruct` 等$$,
'https://huggingface.co/Rakuten', '2026-04-18', 2),

('rakuten_ai', 'api', 'Rakuten AI API 入門',
$$## Rakuten AI Gateway API の始め方

```python
# Rakuten AI Gateway (OpenAI SDK 互換想定)
import openai

client = openai.OpenAI(
    api_key="YOUR_RAKUTEN_AI_KEY",
    base_url="https://api.rakuten.ai/v1",  # Rakuten AI Gateway
)

response = client.chat.completions.create(
    model="rakuten-ai-3.0",
    messages=[
        {"role": "system", "content": "日本語で丁寧に応答するアシスタントです。"},
        {"role": "user", "content": "楽天市場で買い物する際のコツを3つ教えてください。"},
    ],
    temperature=0.7,
    max_tokens=2048,
)

print(response.choices[0].message.content)
```

## HuggingFace ローカル実行

```python
from transformers import AutoModelForCausalLM, AutoTokenizer

model = AutoModelForCausalLM.from_pretrained("Rakuten/RakutenAI-3.0-Instruct")
tokenizer = AutoTokenizer.from_pretrained("Rakuten/RakutenAI-3.0-Instruct")

inputs = tokenizer("おすすめの日本旅行先を3つ教えて", return_tensors="pt")
outputs = model.generate(**inputs, max_new_tokens=512)
print(tokenizer.decode(outputs[0]))
```

## 料金・ライセンス (2026年4月時点)

- **HuggingFace (OSS)**: **完全無料** (Apache 2.0)
- **Rakuten AI Gateway API**: 未公開 (エンタープライズ商談ベース)
- **楽天会員特典**: 今後楽天会員向けに優遇プラン提供予定
- **研究利用**: GENIAC 経由で無料クレジット申請可能

## 参考リンク

- プレスリリース: <https://global.rakuten.com/corp/news/press/2026/0317_01.html>
- HuggingFace: <https://huggingface.co/Rakuten>
- GENIAC: <https://www.meti.go.jp/policy/mono_info_service/geniac/>
- 技術ブログ: <https://rakuten.today/>$$,
'https://huggingface.co/Rakuten', '2026-04-18', 3)

ON CONFLICT DO NOTHING;
