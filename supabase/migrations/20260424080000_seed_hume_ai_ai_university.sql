-- Session PS#3-S28: AI大学 149社化 — Hume AI 追加
-- Alan Cowen (元 Google Brain) が創業した「感情知能 (EI)」特化 Voice AI スタートアップ。
-- 2021 年 NYC 創業 → EVI (2024-01) → EVI 2 (2024-09) → EVI 3 (2025) → EVI 4-mini (2026)。
-- 2024-03 Series B $50M @ $219M valuation / 累計 $80.7M (Nat Friedman / Daniel Gross など)。
-- 2026-01: 創業者 Alan Cowen が Google DeepMind に "Reverse Acqui-Hire" (ライセンス契約経由)。
-- 現 CEO: Andrew Ettinger。2026 年 revenue 目標 $100M。
-- 既存 148 社に空白だった「感情 AI × リアルタイム音声 × 共感 UX」軸を埋める。
-- Step 0: 8/9 (Philosophy 3「優しいmentor」軸に完全一致 / Google DeepMind 採用で技術力実証)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'hume_ai',
  'overview',
  'Hume AI — 感情知能 (Emotional Intelligence) 搭載 Voice AI の先駆者',
  $md$
# Hume AI — 感情知能 × 共感 Voice AI

2021 年 New York 創業。創業者 **Dr. Alan Cowen** (元 Google Brain / UCLA 感情研究 PhD) が
「AI が人間の感情を理解・表現できるべき」という信念で設立。音声・表情・テキストから
27 種類の感情を分類する独自モデルを核に、**EVI (Empathic Voice Interface)** を開発した。

2026 年 1 月、Alan Cowen は Google DeepMind との大型ライセンス契約を通じて
**"Reverse Acqui-Hire"** という形で DeepMind に合流 (同社の Voice AI 強化を担当)。
Hume AI は **Andrew Ettinger** が新 CEO となり独立運営を継続、2026 年 $100M 収益を目指す。

## 主要プロダクト
- **EVI 3** (2025 — 最新安定版) — 超低遅延・高度な personality カスタマイズ / WebSocket 接続
- **EVI 4-mini** (2026 preview) — コスト最適化版 / 軽量デプロイ向け
- **Octave 2** (preview) — TTS (Text-to-Speech) エンジン / 声質・感情トーン細調整
- **Expression Measurement API** — 表情・音声・言語から 27 感情を数値化

## 強み
- **感情認識 × 音声合成の同時処理**: 人間のトーン (怒り・悲しみ・喜び) を検出し、それに
  応じた感情トーンで即座に返答する end-to-end パイプライン
- **Personality カスタマイズ**: system prompt + voice modulation で企業ブランドに合わせた
  独自 AI キャラクター構築 (gender / pitch / speaking rate 調整可)
- **Philosophy 「優しいmentor」軸**: EVI は「評価・批判ゼロ」の共感的対話 — mental health /
  カスタマーサポート / 教育コーチング分野でリードユーザーが続出
- **マルチ SDK**: Python / TypeScript / React / .NET / Swift の公式 SDK 完備

## 資金調達・バリュエーション
| ラウンド | 時期 | 金額 | バリュエーション |
|----------|------|------|------------------|
| Seed     | 2021 | $5M  | —                |
| Series A | 2023 | $12.7M | —              |
| Series B | 2024-03 | $50M | $219M        |
| 累計     | 2024 | $80.7M | $219M         |
| 2026 目標 revenue | — | $100M ARR | 未公開 |

## 2026 年の転換点: Google DeepMind "Reverse Acqui-Hire"
2026-01-22、Google DeepMind が Hume AI と大規模ライセンス契約を締結。
この契約の一環として **Alan Cowen (創業者/前 CEO) と上級エンジニア数名が DeepMind に合流**。
新 CEO の **Andrew Ettinger** の下、Hume AI は独立企業として EVI プラットフォームを継続発展させる。
この事例は「スタートアップが大手に「感情 AI 技術」を供与しながら独自ブランドを維持する」
新しい M&A パターンとして業界から注目されている。

## 自分株式会社での活用
- **AI大学 優しいmentor 軸**: EVI を「評価ゼロの学習アドバイザー」として AI大学 UI に統合候補
- **ユーザー感情分析**: ユーザーの音声/テキストトーンから engagement 低下を早期検知
- **カスタマーサポート**: 感情認識で「フラストレーション状態のユーザー」を自動検出 → エスカレーション
$md$,
  'https://www.hume.ai/',
  '2026-04-24',
  1
),

(
  'hume_ai',
  'models',
  'Hume AI モデル一覧 (2026) — EVI 3 / EVI 4-mini / Octave 2',
  $md$
# Hume AI モデル・プロダクト一覧 (2026年4月時点)

## EVI (Empathic Voice Interface) シリーズ

| バージョン | リリース | 特徴 | 主な用途 |
|-----------|---------|------|---------|
| **EVI 3** | 2025 | 最新安定版 / 超低レイテンシ / 高度 personality 設定 | 本番デプロイ / カスタマーサポート |
| **EVI 4-mini** | 2026 preview | コスト最適化 / 軽量デプロイ | 高スループット用途 / モバイル |
| EVI 2 | 2024-09 | 初の商用版 / EVI 1 比 40% 低レイテンシ・30% 低コスト | — (旧バージョン) |
| EVI 1 | 2024-01 | 初公開 EVI / WebSocket 接続確立 | — (旧バージョン) |

### EVI 3 の主要機能
- **感情トーン検出**: ユーザーの音声から 27 感情を 200ms 以内にリアルタイム分類
- **感情応答生成**: 検出した感情に対応したトーンで音声合成 (平静 → 共感的 / 怒り → 落ち着かせる)
- **Personality 設定**: system prompt で性格・口調・専門分野を定義 (例: 「優しい数学教師」)
- **Voice Modulation**: gender / pitch / speaking_rate / expressiveness の API パラメータ制御
- **WebSocket 接続**: リアルタイム双方向ストリーミング (サブセカンドレイテンシ)
- **ツール統合**: EVI 会話中に外部 API を呼び出す Tool Use (Function Calling 相当)

## Octave 2 (TTS)

| 項目 | 内容 |
|------|------|
| タイプ | Text-to-Speech エンジン |
| 特徴 | 感情表現・声質の細粒度コントロール / SSML 非依存でプロンプトで制御 |
| 活用例 | EVI に組み込んだカスタムボイス / 音声コンテンツ生成 |

## Expression Measurement API

| 項目 | 内容 |
|------|------|
| 入力 | 音声・動画 (表情) ・テキスト |
| 出力 | 27 感情カテゴリのスコア (0〜1) |
| レイテンシ | 非リアルタイムバッチ処理 |
| 用途 | 会話分析 / コンテンツ感情タグ付け / UX リサーチ |

## 料金プラン (2026年4月時点)

| プラン | 月額 | EVI 分数 | 用途 |
|--------|------|---------|------|
| Free | $0 | $20 クレジット | 個人・PoC |
| Starter | $3 | 小規模 | 軽量アプリ |
| Business | $500 | 12,500 min/月 | 商用 SaaS |
| Enterprise | 要相談 | 無制限 | 大規模 |

> EVI 使用料金は接続時間 (分) 課金。無料枠は新規アカウントに $20 クレジット付与。
$md$,
  'https://www.hume.ai/pricing',
  '2026-04-24',
  2
),

(
  'hume_ai',
  'api',
  'Hume AI API 入門 — EVI WebSocket 接続・Python/TypeScript SDK',
  $md$
# Hume AI API の始め方

Hume AI の主力 API は **EVI (Speech-to-Speech)** と **Expression Measurement** の 2 系統。
EVI は REST ではなく **WebSocket** で接続するリアルタイム音声 API。

## 前提: API キー取得
1. https://platform.hume.ai でアカウント作成
2. Dashboard → API Keys → 新規キー生成
3. 環境変数 `HUME_API_KEY` に設定

## Python SDK — EVI 接続 (最小サンプル)

```python
import asyncio
from hume import AsyncHumeClient
from hume.empathic_voice.types import UserInput

async def main():
    client = AsyncHumeClient(api_key="YOUR_HUME_API_KEY")

    async with client.empathic_voice.chat.connect(
        config_id="YOUR_CONFIG_ID"  # Dashboard で事前作成
    ) as socket:
        # テキストメッセージを送信
        await socket.send_user_input(
            UserInput(text="こんにちは！今日は元気ですか？")
        )

        # 音声レスポンスを受信
        async for message in socket:
            if message.type == "audio_output":
                # message.data が base64 エンコードされた音声バイト
                print(f"音声受信: {len(message.data)} bytes")

asyncio.run(main())
```

## TypeScript (React) SDK — EVI Hook

```typescript
import { useVoice } from "@humeai/voice-react";

function EviChat() {
  const { connect, disconnect, messages, status } = useVoice();

  return (
    <div>
      <button onClick={() => connect({ apiKey: process.env.HUME_API_KEY! })}>
        会話開始
      </button>
      <button onClick={disconnect}>終了</button>
      <p>状態: {status}</p>
      {messages.map((msg, i) => (
        <p key={i}>{msg.type}: {msg.message?.content}</p>
      ))}
    </div>
  );
}
```

## EVI Configuration API — カスタム Personality 設定

```python
from hume import HumeClient

client = HumeClient(api_key="YOUR_HUME_API_KEY")

# カスタム AI キャラクターを作成
config = client.empathic_voice.configs.create(
    name="学習メンター",
    prompt={
        "text": "あなたは優しく共感的な学習コーチです。"
                "学習者の感情を理解し、挫折しても励まし続けてください。"
                "評価・批判はせず、常に前向きなフィードバックをしてください。"
    },
    voice={"name": "ITO"},  # 日本語対応ボイス
)
print(f"Config ID: {config.id}")
```

## 料金 (2026年4月時点)
- **EVI**: 接続時間 (分) ベース課金
  - Free: $20 クレジット付与
  - Business: $500/月 (12,500 EVI 分込み)
- **Expression Measurement**: 処理ファイル数ベース

## 関連リンク
- APIドキュメント: https://dev.hume.ai/intro
- Python SDK: `pip install hume`
- React/TypeScript SDK: `npm install @humeai/voice-react`
- GitHub: https://github.com/HumeAI
$md$,
  'https://dev.hume.ai/intro',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
