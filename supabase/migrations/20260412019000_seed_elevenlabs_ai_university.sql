-- ElevenLabs コンテンツシード
-- AI大学: ElevenLabs プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: 音声AI最大手 / テキスト→音声変換・音声クローン・リアルタイム音声 / 開発者向けAPI充実 / 日本語対応

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('elevenlabs', 'overview', 'ElevenLabs 概要',
$$ElevenLabs は2022年創業の**音声AI専門企業**。テキスト読み上げ (TTS)・音声クローン・リアルタイム音声変換を提供し、2024年時点で100万人以上の開発者が利用しています。Googleからの出資を受け、「最も自然な音声AI」として開発者・コンテンツクリエイター・エンタープライズに採用されています。

## 特徴

- **高品質TTS**: 32言語・数千の音声から選択可能。感情・抑揚・話速を細かく制御
- **音声クローン**: 1分未満の音声サンプルからパーソナライズドボイスを作成
- **リアルタイム変換**: 低レイテンシ (<300ms) でライブ音声変換・AIエージェント構築
- **Projects**: 長編コンテンツ (本・ポッドキャスト) を章単位で音声化するワークフロー
- **Sound Effects**: テキストから効果音・環境音を生成

## 主要ユースケース

| ユースケース | 内容 |
| :--- | :--- |
| **コンテンツ制作** | YouTube動画ナレーション・ポッドキャスト・有声本 |
| **AIエージェント** | 音声会話Bot・カスタマーサポート自動化 |
| **ゲーム・エンタメ** | キャラクターボイス生成・インタラクティブNPC |
| **学習コンテンツ** | eラーニング・外国語学習・読み上げ機能 |
| **アクセシビリティ** | 視覚障害者向けコンテンツ読み上げ |

## 強み

```text
テキスト → ElevenLabs TTS → 高品質音声 (mp3/wav/pcm)
              ↑
       感情・話速・安定性をパラメータで制御
       音声クローンで特定話者の声を再現
       リアルタイムAPIでAI音声エージェント構築
```

ElevenLabs は「どの AI からテキストを生成するかではなく、そのテキストをどう読み上げるか」を専門とする音声レイヤーとして機能します。Claude・GPT・Gemini などの出力を高品質音声に変換するミドルウェアとして広く採用されています。$$,
'https://elevenlabs.io/', '2026-04-12', 1),

('elevenlabs', 'models', 'ElevenLabs — 利用可能モデル (2026)',
$$ElevenLabs は用途に応じた複数の音声モデルを提供しています。

## テキスト読み上げ (TTS) モデル

| モデル | 特徴 | レイテンシ | 推奨用途 |
| :--- | :--- | :--- | :--- |
| **Eleven Multilingual v2** | 32言語対応・最高品質 | 普通 | ポッドキャスト・有声本・コンテンツ制作 |
| **Eleven Turbo v2.5** | 高速・低レイテンシ | 低 (<250ms) | リアルタイム会話・AIエージェント |
| **Eleven Flash v2.5** | 超高速・最低コスト | 最低 (<75ms) | バッチ処理・大量生成・コスト重視 |
| **Eleven English v1** | 英語特化・旧世代 | 普通 | 英語コンテンツのみ |

## 音声クローン

| 種類 | 必要サンプル | 精度 | 用途 |
| :--- | :--- | :--- | :--- |
| **Instant Voice Clone (IVC)** | 1分〜 | 高 | 個人向け・素早いクローン作成 |
| **Professional Voice Clone (PVC)** | 30分〜 (高品質) | 最高 | 商用・エンタープライズ向け |

## 音声ライブラリ

- **3,000+** のプリセット音声 (年齢・性別・アクセント・感情別)
- **Voice Design**: テキスト指示から新しい音声キャラクターを生成
- **Voice Sharing**: 作成した音声をマーケットプレイスで共有・収益化

## 言語サポート (Multilingual v2)

```text
日本語, 英語, スペイン語, フランス語, ドイツ語, イタリア語, ポルトガル語,
中国語, 韓国語, アラビア語, ヒンディー語, ロシア語 など32言語
```

## パラメータ制御

| パラメータ | 範囲 | 説明 |
| :--- | :--- | :--- |
| `stability` | 0〜1 | 0=変化に富む表現 / 1=安定した読み上げ |
| `similarity_boost` | 0〜1 | 元音声への類似度 (クローン時に重要) |
| `style` | 0〜1 | 感情表現の強さ (Multilingual v2) |
| `use_speaker_boost` | bool | 話者特性をブースト (Turbo v2.5以降) |$$,
'https://elevenlabs.io/docs/speech-synthesis/models', '2026-04-12', 2),

('elevenlabs', 'api', 'ElevenLabs API 入門',
$$## セットアップ

```bash
pip install elevenlabs
```

## Python SDK でテキスト読み上げ

```python
from elevenlabs.client import ElevenLabs
from elevenlabs import save

client = ElevenLabs(api_key="<ELEVENLABS_API_KEY>")

# テキストを音声に変換
audio = client.generate(
    text="こんにちは。ElevenLabsのテキスト読み上げAPIのデモです。",
    voice="Aria",           # プリセット音声名 or voice_id
    model="eleven_multilingual_v2",
)

save(audio, "output.mp3")
print("音声ファイルを保存しました: output.mp3")
```

## 音声IDの取得と使用

```python
from elevenlabs.client import ElevenLabs

client = ElevenLabs(api_key="<ELEVENLABS_API_KEY>")

# 利用可能な音声一覧を取得
voices = client.voices.get_all()
for voice in voices.voices:
    print(f"名前: {voice.name}, ID: {voice.voice_id}, カテゴリ: {voice.category}")

# voice_id を直接指定して読み上げ
audio = client.generate(
    text="特定の音声IDを使用した読み上げテスト。",
    voice="21m00Tcm4TlvDq8ikWAM",  # Rachel の voice_id
    model="eleven_multilingual_v2",
)
```

## リアルタイムストリーミング (AIエージェント向け)

```python
from elevenlabs.client import ElevenLabs
from elevenlabs import stream

client = ElevenLabs(api_key="<ELEVENLABS_API_KEY>")

# ストリーミングで低レイテンシ再生 (AIエージェント・チャットBot向け)
audio_stream = client.generate(
    text="この文章はストリーミングで生成・再生されます。",
    voice="Aria",
    model="eleven_turbo_v2_5",  # 低レイテンシモデルを使用
    stream=True,
)

stream(audio_stream)  # リアルタイム再生
```

## 音声クローンの作成 (Instant Voice Clone)

```python
from elevenlabs.client import ElevenLabs

client = ElevenLabs(api_key="<ELEVENLABS_API_KEY>")

# 音声サンプルからカスタム音声を作成
with open("my_voice_sample.mp3", "rb") as f:
    voice = client.clone(
        name="マイカスタムボイス",
        description="自分の音声のクローン",
        files=[f],
    )

print(f"音声クローン作成完了: {voice.voice_id}")

# クローンした音声で読み上げ
audio = client.generate(
    text="これはクローンした音声での読み上げです。",
    voice=voice.voice_id,
    model="eleven_multilingual_v2",
)
```

## Claude + ElevenLabs の組み合わせ (音声AIエージェント)

```python
import anthropic
from elevenlabs.client import ElevenLabs
from elevenlabs import stream

anthropic_client = anthropic.Anthropic(api_key="<ANTHROPIC_API_KEY>")
elevenlabs_client = ElevenLabs(api_key="<ELEVENLABS_API_KEY>")

def voice_ai_response(user_input: str) -> None:
    """ユーザーの質問にClaudeが回答し、ElevenLabsで読み上げ"""
    # Step 1: Claude でテキスト生成
    message = anthropic_client.messages.create(
        model="claude-opus-4-6",
        max_tokens=500,
        messages=[{"role": "user", "content": user_input}],
    )
    response_text = message.content[0].text
    print(f"Claude回答: {response_text}\n")

    # Step 2: ElevenLabs で音声変換・再生
    audio_stream = elevenlabs_client.generate(
        text=response_text,
        voice="Aria",
        model="eleven_turbo_v2_5",
        stream=True,
    )
    stream(audio_stream)

# 使用例
voice_ai_response("Flutterでのアニメーション実装のベストプラクティスを教えてください")
```

## Supabase Edge Function から呼び出し (Deno)

```typescript
// ElevenLabs TTS を Supabase Edge Function から利用
const ELEVENLABS_API_KEY = Deno.env.get("ELEVENLABS_API_KEY")!;

async function textToSpeech(text: string, voiceId = "21m00Tcm4TlvDq8ikWAM") {
  const response = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
    {
      method: "POST",
      headers: {
        "xi-api-key": ELEVENLABS_API_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        text,
        model_id: "eleven_multilingual_v2",
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.75,
          style: 0.3,
        },
      }),
    }
  );

  if (!response.ok) throw new Error(`ElevenLabs API error: ${response.status}`);
  return await response.arrayBuffer(); // MP3 バイナリデータ
}
```

## 料金 (2026年4月時点, USD)

| プラン | 月額 | クレジット | 特徴 |
| :--- | :--- | :--- | :--- |
| **Free** | $0 | 10,000文字/月 | 個人・評価用 |
| **Starter** | $5 | 30,000文字/月 | 個人プロジェクト |
| **Creator** | $22 | 100,000文字/月 | コンテンツクリエイター |
| **Pro** | $99 | 500,000文字/月 | プロ・商用利用 |
| **Scale** | $330 | 2,000,000文字/月 | 大量生成・API重視 |
| **Business** | $1,320 | 10,000,000文字/月 | エンタープライズ |

- **1文字 ≈ 0.001〜0.002秒の音声** (英語基準)
- **API アクセス**: Starter プラン以上$$,
'https://elevenlabs.io/docs/quickstart', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 ElevenLabs 追加 (28社目)',
  'ElevenLabs を AI大学プロバイダーとして追加。音声AI最大手・TTS/音声クローン/リアルタイム音声変換・Eleven Multilingual v2 (32言語)・Turbo/Flash低レイテンシモデル・Claude+ElevenLabs音声AIエージェント統合例を収録。AI大学プロバイダー数 27社→28社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
