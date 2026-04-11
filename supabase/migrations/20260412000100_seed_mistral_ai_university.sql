-- Mistral AI コンテンツシード
-- AI大学: Mistral AIプロバイダーの初期コンテンツ (overview / models / api)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('mistral', 'overview', 'Mistral AI 概要',
$$Mistral AI は2023年にパリで創業されたフランス発の AI スタートアップです。元 Meta・Google DeepMind のエンジニアが共同設立し、欧州で最も注目される AI 企業の一つとして急成長しました。「オープンで効率的なAIを世界に」をミッションに掲げ、商用モデルとオープンウェイトモデルを並行して開発・提供しています。

Mistral のモデルは高性能でありながら軽量・省エネであることが特徴で、Mixture-of-Experts (MoE) アーキテクチャを積極的に採用しています。GDPR 準拠の EU ホスティングにより、欧州企業からの信頼も厚く、エンタープライズ向け API サービス「la Plateforme」も提供しています。

## 主要サービス
- **la Plateforme** — 商用 API サービス（テキスト生成・埋め込み・画像理解）
- **Le Chat** — Mistral 製の AI チャットアシスタント（無料プランあり）
- **Mistral オープンウェイトモデル** — Apache 2.0 ライセンスで自由に利用・改変可能
- **オンプレミス / クラウドデプロイ** — Azure・AWS・GCP 経由での利用も可能

## 強み
- 欧州最大の独立系 AI 企業、GDPR 準拠の EU ホスティング
- Mixture-of-Experts (MoE) による高効率アーキテクチャ
- オープンウェイトモデル（商用利用可）と商用モデルを両輪で展開
- 推論・マルチモーダル・コーディング・音声など幅広いモダリティをカバー
- 競合比でコストパフォーマンスが高く、Small〜Large で用途別に選択可能$$,
'https://mistral.ai/', '2026-04-12', 1),

('mistral', 'models', 'Mistral AI モデル一覧 (2026)',
$$## Mistral Small / Medium / Large シリーズ

| モデル | コンテキスト | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Mistral Small 4** | 256K | 推論・ビジョン・コーディングを1モデルに統合、MoE 119B (有効6B) | 汎用・コスト重視 |
| **Mistral Medium 3** | 128K | Small と Large の中間、バランス型 | バランス重視のタスク |
| **Mistral Large 3** | 128K | 最高精度、MoE 675B (有効41B)、LMArena OSS 2位 | 高精度タスク全般 |
| **Ministral 3B / 8B / 14B** | 32K | エッジ・オンデバイス向け超軽量シリーズ | モバイル・省メモリ環境 |

## 特化モデル

| モデル | 特徴 | 用途 |
| :--- | :--- | :--- |
| **Magistral Small / Medium** | 連鎖思考 (CoT) 推論、o3 / o4-mini に対抗 | 数学・論理・複雑推論 |
| **Devstral 2** | コーディングエージェント特化、24B で Qwen 3 Coder 30B を超える性能 | コード生成・エージェント |
| **Pixtral** | ビジョン・OCR 特化のマルチモーダルモデル | 画像理解・文書解析 |
| **Voxtral TTS** | 4B パラメータ、9言語対応の音声合成モデル | テキスト読み上げ・音声生成 |

## 特徴的な機能
- **configurable reasoning_effort** — Small 4 で推論深度をリクエストごとに調整可能
- **オープンウェイト** — Magistral Small・Devstral Small 2 など主要モデルが Apache 2.0 で公開
- **ローカル実行** — Devstral は OpenHands / SWE-Agent で完全ローカル動作可能
- **多言語音声** — Voxtral TTS は英・仏・独・西・蘭・葡・伊・ヒンディー・アラビア語に対応$$,
'https://docs.mistral.ai/getting-started/models', '2026-04-12', 2),

('mistral', 'api', 'Mistral AI API 入門',
$$## Mistral AI API の始め方

```python
import os
from mistralai import Mistral

client = Mistral(api_key=os.environ["MISTRAL_API_KEY"])

response = client.chat.complete(
    model="mistral-small-latest",
    messages=[
        {"role": "user", "content": "Mistral AI の強みを教えてください。"}
    ]
)

print(response.choices[0].message.content)
```

## ストリーミング対応

```python
stream = client.chat.stream(
    model="mistral-large-latest",
    messages=[{"role": "user", "content": "詳しく説明してください。"}]
)

for chunk in stream:
    print(chunk.data.choices[0].delta.content, end="")
```

## 料金 (2026年4月時点)

| モデル | 入力 (100万トークン) | 出力 (100万トークン) |
| :--- | :--- | :--- |
| **Mistral Small 4** | $0.20 | $0.60 |
| **Mistral Medium 3** | $0.40 | $2.00 |
| **Mistral Large 3** | $2.00 | $6.00 |
| **Mistral Embed** | $0.10 | — |

- 無料枠あり（GDPR 準拠 EU ホスティング）
- API キーは [la Plateforme](https://console.mistral.ai/) で発行
- SDK: `pip install mistralai` / npm: `npm install @mistralai/mistralai`$$,
'https://docs.mistral.ai/getting-started/quickstart', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Mistral AI 追加',
  'Mistral AI (mistral) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、日本語コンテンツ、La Platformeおよびオープンウェイトモデル情報を収録。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
