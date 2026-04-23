-- Session PS#3-S29: AI大学 152社化 — Vapi 追加
-- Nikhil Gupta (元 Cerebras) + Jordan Dearsley 創業 2022 年の音声 AI エージェント開発プラットフォーム。
-- プラットフォーム利用料 $0.05/分 + STT/LLM/TTS を自由に組み合わせ可能なモジュール型構成。
-- 1M 同時並列通話対応 / レイテンシ 500-800ms / 感情検知 / 割り込み検出機能搭載。
-- Deepgram (STT) + GPT-4 / Claude / Gemini (LLM) + ElevenLabs / Cartesia (TTS) を柔軟に選択可。
-- 既存 151 社に空白だった「リアルタイム音声 AI エージェント インフラ」軸を埋める。
-- Step 0: 8.5/9 (開発者 API 充実・エンタープライズ向け / 個人利用コスト高め)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'vapi',
  'overview',
  'Vapi — 開発者向けリアルタイム音声 AI エージェント インフラ',
  $md$
# Vapi — Voice AI Platform for Developers

2022 年創業。**Nikhil Gupta** (元 Cerebras エンジニア) と **Jordan Dearsley** が
「開発者が数時間で本番レベルの音声 AI エージェントを構築できる」インフラを目指して設立。

STT (音声認識) → LLM (言語理解・生成) → TTS (音声合成) のパイプラインを
モジュール単位で選択・組み合わせ可能な **フルスタック音声エージェント API** を提供。
電話・Web・モバイルに横断して展開でき、1M 同時通話のスケーラビリティを持つ。

## 主要機能
- **モジュール型パイプライン** — Deepgram / AssemblyAI (STT)、GPT-4 / Claude / Gemini (LLM)、
  ElevenLabs / Cartesia / PlayHT (TTS) を自由に組み合わせ
- **超低レイテンシ** — エンドツーエンド 500〜800ms、最適構成で 1.9s 以内
- **感情検知** — 話者の感情 (満足・苛立ち・緊急度) をリアルタイム分析し応答を調整
- **割り込み検出 & バックチャネル** — 自然な会話フローを維持する turn-taking エンジン
- **Phone Numbers API** — Twilio / Vonage 連携で即座に電話番号を取得・発着信管理
- **エンタープライズ対応** — HIPAA コンプライアンス ($1,000/月)、1M 同時通話対応

## 強み
- 数時間でプロトタイプ → 本番デプロイが可能な開発者体験
- LLM・STT・TTS を競合他社に縛られず最適組み合わせで選択できる柔軟性
- コールセンター自動化・採用面接 AI・医療問診 AI など多様なユースケースをカバー
$md$,
  'https://vapi.ai/',
  '2026-04-24',
  1
),

(
  'vapi',
  'models',
  'Vapi パイプライン構成オプション (2026)',
  $md$
## Vapi のモジュール型パイプライン

Vapi は「モデル」を提供するのではなく、各コンポーネントを選択して音声パイプラインを構成する。

## STT (音声認識) オプション

| プロバイダー | 特徴 | 推奨用途 |
| :--- | :--- | :--- |
| **Deepgram Nova-3** | 最高精度・最低レイテンシ | 標準推奨 |
| **AssemblyAI** | 話者分離・感情分析に強み | 多人数会話 |
| **Gladia** | 99 言語対応・多言語会話 | 多言語サポート |

## LLM (言語モデル) オプション

| モデル | コスト目安 | 特徴 |
| :--- | :--- | :--- |
| **GPT-4o** | ~$0.10/min | 高品質・安定 |
| **Claude 3.5 Sonnet** | ~$0.09/min | 長文理解・安全性 |
| **Gemini 1.5 Flash** | ~$0.02/min | コスト最適 |
| **Llama 3.3 70B** | ~$0.02/min | OSS・コスト効率 |

## TTS (音声合成) オプション

| プロバイダー | 特徴 | レイテンシ |
| :--- | :--- | :--- |
| **ElevenLabs** | 最高音質・感情表現豊か | ~200ms |
| **Cartesia** | 超低レイテンシ特化 | ~80ms |
| **PlayHT** | 多言語・クローン音声 | ~150ms |
| **Deepgram Aura** | シンプル・安価 | ~100ms |

## コスト最適化構成例

**低コスト構成**: Deepgram Nova-3 + Llama 3.3 70B + Deepgram Aura ≒ $0.05/min (Vapi 料金除く)
**バランス構成**: Deepgram + GPT-4o mini + Cartesia ≒ $0.10/min
**高品質構成**: Deepgram + GPT-4o + ElevenLabs ≒ $0.25-0.33/min
$md$,
  'https://docs.vapi.ai/',
  '2026-04-24',
  2
),

(
  'vapi',
  'api',
  'Vapi API 入門',
  $md$
## Vapi API の始め方

```python
# pip install vapi-python
from vapi import Vapi

client = Vapi(token="your-vapi-api-key")

# アシスタント作成
assistant = client.assistants.create(
    name="Customer Support Agent",
    model={
        "provider": "openai",
        "model": "gpt-4o",
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful customer support agent."
            }
        ]
    },
    voice={
        "provider": "11labs",
        "voiceId": "paula"
    },
    transcriber={
        "provider": "deepgram",
        "model": "nova-3"
    }
)

# 通話を開始 (Web SDK または電話)
call = client.calls.create(
    assistant_id=assistant.id,
    phone_number_id="your-phone-number-id",
    customer={"number": "+1234567890"}
)

print(f"Call started: {call.id}")
```

## 料金 (2026年4月時点)

| 項目 | 料金 |
| :--- | :--- |
| **Vapi プラットフォーム** | $0.05 / 分 |
| **同時通話追加枠** | $10 / 回線 / 月 |
| **HIPAA コンプライアンス** | $1,000 / 月 |

> **合計コスト目安**: プラットフォーム $0.05 + STT/LLM/TTS 実費 = **$0.10〜$0.33/分**

## クイックスタート

1. [vapi.ai](https://vapi.ai) でアカウント作成 → API キー取得
2. `pip install vapi-python` または `npm install @vapi-ai/web`
3. ダッシュボードでアシスタントを設定 (STT/LLM/TTS 選択)
4. Web SDK・電話番号・REST API のいずれかで通話開始

## JavaScript/TypeScript SDK

```typescript
import Vapi from "@vapi-ai/web";

const vapi = new Vapi("your-public-key");

vapi.start({
  assistantId: "your-assistant-id",
});
```
$md$,
  'https://docs.vapi.ai/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
