-- Session PS#3-S31: AI大学 156社化 — LiveKit 追加
-- Russ d'Sa (CEO / 元 Twilio VP) + David Zhao (CTO) が 2020 年に創業したリアルタイム AI 通信インフラ。
-- OpenAI ChatGPT Voice Mode のバックエンドとして採用された実績を持つ。
-- 2026-01 Series C $100M (Index Ventures 主導) @ $1B valuation / 累計 $183M 調達。
-- OSS Agents フレームワーク (Python/Node.js) は月 100 万回ダウンロード。
-- Build (無料・1,000 エージェント分/月) → Ship $50/月 → Scale $500/月 / $0.01/エージェント分。
-- 既存 155 社に空白だった「リアルタイム音声・映像・物理 AI エージェント通信インフラ」軸を埋める。
-- Step 0: 9/9 (OSS・公開 API・OpenAI 公式パートナー・$1B unicorn)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'livekit',
  'overview',
  'LiveKit — 音声・映像・物理 AI エージェントのリアルタイム通信インフラ',
  $md$
# LiveKit — Realtime AI Infrastructure

2020 年創業。**Russ d'Sa** (CEO / 元 Twilio VP) と **David Zhao** (CTO) が
「あらゆる AI エージェントにリアルタイム音声・映像能力を付与するインフラ」として構築。

**OpenAI ChatGPT Voice Mode** のバックエンドとして採用されたことで一躍注目を集め、
2026 年 1 月に Series C $100M (Index Ventures 主導) を調達し評価額 **$1B (ユニコーン)** に到達。
累計調達額は $183M。

OSS の **LiveKit Agents フレームワーク** (Python / Node.js) は毎月 **100 万回以上ダウンロード** され、
音声 AI エージェント開発のデファクトスタンダードになりつつある。

## 主要プロダクト
- **LiveKit Agents** — 音声・映像 AI エージェント構築用 Python/Node.js フレームワーク (OSS)
- **LiveKit Cloud** — マネージドリアルタイム通信インフラ (WebRTC / SIP / TURN)
- **LiveKit Inference** — エージェント内で STT/LLM/TTS を直接呼び出す統合推論 API
- **Agent Builder** — コード不要でエージェントをプロトタイプ・デプロイできる GUI
- **LiveKit SIP** — 電話網 (PSTN/SIP) と LiveKit エージェントを接続するゲートウェイ

## 強み
- **OpenAI 公式パートナー** — ChatGPT Voice Mode + Realtime API の基盤として採用
- **完全 OSS** — エージェントフレームワーク & メディアサーバーともに Apache 2.0 / MIT
- **マルチモーダル対応** — 音声だけでなく映像・画面共有・物理ロボット制御にも対応
- テスラ (営業/サポート/ロードサイド)・Salesforce Agentforce など大規模本番採用実績
$md$,
  'https://livekit.io/',
  '2026-04-24',
  1
),

(
  'livekit',
  'models',
  'LiveKit エージェントパイプライン・統合一覧 (2026)',
  $md$
## LiveKit Agents パイプライン

LiveKit はエージェントパイプラインを STT → LLM → TTS の順で処理する。
各コンポーネントは差し替え可能。

## STT (音声認識) 統合

| プロバイダー | プラグイン | 特徴 |
| :--- | :--- | :--- |
| **Deepgram** | `livekit-plugins-deepgram` | 超低レイテンシ・推奨 |
| **OpenAI Whisper** | `livekit-plugins-openai` | 高精度・多言語 |
| **AssemblyAI** | `livekit-plugins-assemblyai` | 感情分析・話者分離 |
| **Google STT** | `livekit-plugins-google` | 100+ 言語 |

## LLM 統合

| プロバイダー | プラグイン | 特徴 |
| :--- | :--- | :--- |
| **OpenAI** | `livekit-plugins-openai` | GPT-4o / Realtime API |
| **Anthropic** | `livekit-plugins-anthropic` | Claude 3.5 Sonnet |
| **Google** | `livekit-plugins-google` | Gemini 1.5 Pro |
| **Groq** | `livekit-plugins-groq` | 超高速推論 |

## TTS (音声合成) 統合

| プロバイダー | プラグイン | 特徴 |
| :--- | :--- | :--- |
| **ElevenLabs** | `livekit-plugins-elevenlabs` | 最高音質 |
| **Cartesia** | `livekit-plugins-cartesia` | 超低レイテンシ |
| **OpenAI TTS** | `livekit-plugins-openai` | シンプル・安定 |

## プラン比較

| プラン | 月額 | エージェント分 | WebRTC 分 |
| :--- | :--- | :--- | :--- |
| **Build** | 無料 | 1,000 分/月 | 5,000 分/月 |
| **Ship** | $50 | 5,000 分/月 | 25,000 分/月 |
| **Scale** | $500 | 50,000 分/月 | 250,000 分/月 |
| **Enterprise** | 要相談 | 無制限 | 無制限 |

超過分: エージェント分 $0.01/分・WebRTC $0.0004/分
$md$,
  'https://docs.livekit.io/agents/',
  '2026-04-24',
  2
),

(
  'livekit',
  'api',
  'LiveKit Agents API 入門',
  $md$
## LiveKit Agents の始め方

```python
# pip install livekit-agents livekit-plugins-deepgram livekit-plugins-openai livekit-plugins-cartesia

import asyncio
from livekit.agents import AutoSubscribe, JobContext, WorkerOptions, cli, llm
from livekit.agents.voice_assistant import VoiceAssistant
from livekit.plugins import cartesia, deepgram, openai

async def entrypoint(ctx: JobContext):
    initial_ctx = llm.ChatContext().append(
        role="system",
        text=(
            "あなたは自分株式会社の AI アシスタントです。"
            "丁寧で親切な会話スタイルで対応してください。"
        ),
    )

    await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)

    assistant = VoiceAssistant(
        vad=silero.VAD.load(),
        stt=deepgram.STT(),
        llm=openai.LLM(model="gpt-4o"),
        tts=cartesia.TTS(),
        chat_ctx=initial_ctx,
    )
    assistant.start(ctx.room)

    # 最初の挨拶
    await assistant.say("こんにちは！ご用件をお聞かせください。", allow_interruptions=True)
    await asyncio.sleep(300)  # 5分間待機

if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))
```

## 環境変数

```bash
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your-api-key
LIVEKIT_API_SECRET=your-api-secret
OPENAI_API_KEY=your-openai-key
DEEPGRAM_API_KEY=your-deepgram-key
```

## 料金 (2026年4月時点)

| 項目 | 料金 |
| :--- | :--- |
| **エージェントセッション分** | $0.01 / 分 |
| **WebRTC 通話分** | $0.0004〜0.0005 / 分 |
| **Inference (STT/TTS)** | モデルにより異なる |

## クイックスタート

1. [cloud.livekit.io](https://cloud.livekit.io) でプロジェクト作成 → API キー取得
2. `pip install livekit-agents` + 必要なプラグインをインストール
3. エージェントスクリプトを作成して `python agent.py dev` で起動
4. LiveKit Playground でブラウザからテスト
$md$,
  'https://docs.livekit.io/agents/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
