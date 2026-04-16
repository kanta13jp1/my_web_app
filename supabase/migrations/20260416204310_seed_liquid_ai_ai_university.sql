-- Liquid AI 初期コンテンツシード (2026-04-16)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('liquid_ai', 'overview', 'Liquid AI 概要',
$$## Liquid AI とは

Liquid AI は MIT の研究室から生まれたボストン発のスタートアップです（2023年設立）。従来の Transformer アーキテクチャに依存しない、まったく新しい基盤モデルのアーキテクチャ「LFM（Liquid Foundation Models）」を開発しています。

LFM は液体状態機械（Liquid State Machine）と呼ばれる理論に基づき、長い文脈・時系列データの処理において Transformer よりも計算効率が高い特性を持ちます。2024年に $250M の資金調達を完了し、2025年〜2026年にかけてシリーズ B でさらなる資金を獲得しました。

## 主要サービス

- **LFM-40B**: 40B パラメータのフラッグシップモデル
- **LFM-7B / LFM-3B / LFM-1B**: 軽量・エッジ向けモデル群
- **liquid.ai API**: クラウド推論 API（ベータ公開中）
- **オンデバイス展開**: エッジデバイス・IoT 向け最適化モデル

## 強み

- **Transformer 非依存**: 理論的に長い系列データでメモリ効率が O(1) に近い
- **エッジ展開に強い**: スマートフォン・組み込みデバイスへの展開が容易
- **時系列・センサーデータ処理**: 医療・産業 IoT 向けの特化能力
- **高い推論効率**: 同パラメータ数の Transformer モデルより約 2〜4 倍高速$$,
'https://www.liquid.ai', '2026-04-16', 1),

('liquid_ai', 'models', 'Liquid AI モデル一覧 (2026)',
$$## LFM (Liquid Foundation Models) シリーズ

| モデル | パラメータ数 | コンテキスト長 | 特徴 | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| **LFM-40B** | 40B | 32K | 最高性能・マルチモーダル対応 | エンタープライズ・研究 |
| **LFM-7B** | 7B | 32K | バランス型・高効率 | 一般アプリケーション |
| **LFM-3B** | 3B | 16K | 軽量・高速 | モバイル・エッジ |
| **LFM-1B** | 1B | 8K | 超軽量 | IoT・組み込み |

## 特徴的な機能

- **液体時間定数 (LTC)**: ニューラル回路の動的な適応学習
- **長文脈処理**: 100K トークン以上の処理でも線形メモリ消費
- **構造化状態空間**: Mamba / SSM との組み合わせで更なる効率化
- **継続学習**: 新しいデータへの継続的な適応が容易
- **時系列データ特化**: 医療・金融・センサーデータの処理に強い

## ベンチマーク比較

- MMLU: LFM-40B が GPT-4o-mini 相当のスコアを達成
- HumanEval: Llama-3 70B に匹敵するコーディング能力
- 推論速度: 同等 Transformer より約 2〜3 倍高速$$,
'https://www.liquid.ai/liquid-foundation-models', '2026-04-16', 2),

('liquid_ai', 'api', 'Liquid AI API 入門',
$$## Liquid AI API の始め方

Liquid AI の API は OpenAI 互換インターフェースを提供しており、既存のコードをほぼ変更なく移行できます。

```python
from openai import OpenAI

client = OpenAI(
    api_key="your-liquid-api-key",
    base_url="https://api.liquid.ai/v1"
)

response = client.chat.completions.create(
    model="lfm-40b",
    messages=[
        {"role": "system", "content": "あなたは優秀なアシスタントです。"},
        {"role": "user", "content": "液体基盤モデルの利点を説明してください"}
    ],
    max_tokens=1024,
    temperature=0.7
)

print(response.choices[0].message.content)
```

## 料金 (2026年4月時点)

- **LFM-40B**: $0.60 / 100万入力トークン、$1.20 / 100万出力トークン
- **LFM-7B**: $0.15 / 100万入力トークン、$0.30 / 100万出力トークン
- **LFM-3B**: $0.05 / 100万入力トークン、$0.10 / 100万出力トークン

## アクセス方法

1. [liquid.ai](https://www.liquid.ai) でアカウント作成
2. API キーを発行
3. `base_url` を `https://api.liquid.ai/v1` に設定

## 主なユースケース

- **長文書処理**: 法務・医療記録など長い文書の分析
- **リアルタイム推論**: エッジデバイスでの低レイテンシ推論
- **IoT・センサー分析**: 時系列センサーデータの異常検知$$,
'https://www.liquid.ai', '2026-04-16', 3)

ON CONFLICT DO NOTHING;
