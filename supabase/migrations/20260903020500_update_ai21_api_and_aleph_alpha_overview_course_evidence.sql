-- Issues #5144 & #5253: AI21 Labs API 入門 & Aleph Alpha 概要コースのエビデンス契約・検証ラボ・更新日付の強化
UPDATE ai_university_contents
SET
  description = $md$
# AI21 Labs API 入門 — Jamba-Large / Mini 実践ラボ (2026)

AI21 Labs の最新 SDK (`ai21>=3.0.0`) を使用し、SSM+Transformer ハイブリッド MoE モデル（`jamba-large`, `jamba-mini`）を呼び出すハンズオンチュートリアルです。

## 対象学習者 & 到達目標
- **対象者**: Python での LLM API 呼び出し経験があり、長文コンテキスト処理やトークン課金計算を実装したいエンジニア
- **到達目標**: `AI21Client` を用いて 256K コンテキストのチャット補完を実行し、`response.usage` から入力・出力トークン費用を正確に算出できる

## 環境セットアップ (Pinned Environment)

```bash
# Python 3.11+ 推奨
pip install "ai21>=3.0.0" openai
export AI21_API_KEY="your_api_key"
```

## 実践 60 分ラボ: Jamba API 呼び出し & トークンコスト算出

```python
import os
from ai21 import AI21Client
from ai21.models.chat import ChatMessage

client = AI21Client(api_key=os.environ["AI21_API_KEY"])

# 1. Chat Completion 呼び出し
response = client.chat.completions.create(
    model="jamba-mini",  # 高速・低コスト MoE モデル
    messages=[
        ChatMessage(role="system", content="あなたは法務・コンプライアンスの専門家です。"),
        ChatMessage(role="user", content="秘密保持契約書 (NDA) の主要リスク条項を3点要約してください。"),
    ],
    temperature=0.4,
    max_tokens=500,
)

print("=== 回答 ===")
print(response.choices[0].message.content)

# 2. トークン使用量とコストの自動計算 (jamba-mini: 入力 $0.20/1M, 出力 $0.40/1M)
usage = response.usage
prompt_tokens = usage.prompt_tokens
completion_tokens = usage.completion_tokens

cost = (prompt_tokens * 0.20 / 1_000_000) + (completion_tokens * 0.40 / 1_000_000)
print(f"\n消費トークン: 入力={prompt_tokens}, 出力={completion_tokens}")
print(f"推定API費用: ${cost:.6f} USD")
```
$md$,
  source_url = 'https://docs.ai21.com/reference/overview',
  published_at = '2026-09-02'
WHERE provider_id = 'ai21' AND (title LIKE '%API 入門%' OR id = '363d108c-37e3-4bb5-a4a2-a34f65416938' OR sort_order = 3);

UPDATE ai_university_contents
SET
  description = $md$
# Aleph Alpha 概要 — 欧州 AI 主権・Pharia & 説明可能 AI (AtMan)

**Aleph Alpha** はドイツ・ハイデルベルク発のエンタープライズ AI 企業。
EU AI 法 (AI Act) や GDPR に完全準拠した **データ主権 (Data Sovereignty)** と、モデルの判断根拠を可視化する **AtMan (Attention Manipulation)** 説明可能性技術を中核としています。

## 対象学習者 & 到達目標
- **対象者**: 金融・官公庁・ヘルスケアなど厳格な規制環境下で AI 導入を検討するアーキテクト
- **到達目標**: 一般モデル（OpenAI / Anthropic 等）と欧州主権特化モデル（Aleph Alpha Pharia / Luminous）のデータ主権・説明性・監査トレース要件を比較し、導入可否判定メモ（Go/No-Go Memo）を策定できる

## Aleph Alpha のコアコンポーネント (2026)

| コンポーネント | 特徴 | 推奨ユースケース |
| :--- | :--- | :--- |
| **Pharia-1-LLM** | 欧州データ主権・バイリンガル特化 (英/独/仏/西) | 官公庁文書処理・EU 域内完結業務 |
| **AtMan (説明可能性)** | トークン単位で回答の根拠となった入力箇所をスコア可視化 | 融資審査・医療診断補助・法務判断 |
| **On-Premises / Sovereign Cloud** | 顧客専用データセンター・ドイツ国内インフラ展開 | 軍事・防衛・機密行政データ |

## 導入判定ラボ: 30分 Go/No-Go Decision
1. **データ所在地要件**: EU 域外へのデータ移転禁止 ➔ **Aleph Alpha (Go)**
2. **監査説明性**: 根拠条文の明示・監査ログ提出義務 ➔ **AtMan 搭載モデル (Go)**
3. **汎用クリエイティブ**: 多言語・エンタメ ➔ 一般グローバル LLM を推奨 (No-Go)
$md$,
  source_url = 'https://aleph-alpha.com/',
  published_at = '2026-09-02'
WHERE provider_id = 'aleph_alpha' AND (title LIKE '%Aleph Alpha 概要%' OR id = '183e7514-c5ac-487f-a78a-ddbbcbbd1088' OR sort_order = 1);
