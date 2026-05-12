-- PS#3 S108: AI大学 311→312社化 — LocalAI (OpenAI互換マルチバックエンド/セルフホスト)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'local-ai', 'overview',
  'LocalAI — OpenAI互換マルチバックエンドAI API・GPU不要・Docker完結 (GitHub 24k+ / 9/9)',
  $$## LocalAI とは

**LocalAI** は **OpenAI API の完全互換ドロップイン代替をセルフホストで実現するフレームワーク**。GitHub 24,000+ スター。**GPU 不要、クラウド不要** — CPU だけで LLM / 画像生成 / 音声認識 / TTS / 埋め込みを全て同一 API エンドポイントから提供する。

既存の OpenAI クライアントを `api_key` と `base_url` の変更だけで LocalAI に向け直せる。**1つの Docker コマンド** で全サービスを起動し、`http://localhost:8080/v1` が OpenAI 互換 API として機能する。

## LocalAI がカバーする AI 機能

```
テキスト生成 (LLM):
  ・llama.cpp バックエンド (GGUF モデル)
  ・whisper.cpp / stable-diffusion.cpp 内蔵
  ・GPT4All / exllama2 など複数バックエンド

マルチモーダル:
  ・画像生成: Stable Diffusion / DALL-E 互換 (/v1/images/generations)
  ・音声認識: Whisper 互換 (/v1/audio/transcriptions)
  ・TTS: Coqui TTS / piper 互換 (/v1/audio/speech)
  ・ビジョン: LLaVA 互換 (画像 + テキスト入力)

埋め込み:
  ・テキスト埋め込み (/v1/embeddings)
  ・LocalAI 独自の BERT ベースモデル対応

OpenAI 互換エンドポイント:
  ・/v1/chat/completions  ← ChatGPT 互換
  ・/v1/completions       ← GPT-3 互換
  ・/v1/embeddings        ← Ada 互換
  ・/v1/images/generations ← DALL-E 互換
  ・/v1/audio/transcriptions ← Whisper 互換
  ・/v1/audio/speech      ← TTS 互換
  ・/v1/models            ← モデル一覧
```

## 設計思想: モデル設定ファイル (YAML)

```yaml
# models/horse-racing-ai.yaml
name: horse-racing-ai          # API で指定するモデル名
context_size: 4096
parameters:
  model: llama-3.1-8B-Q4_K_M.gguf
  temperature: 0.7
  top_p: 0.9

# システムプロンプト固定
system_prompt: |
  あなたは日本競馬の専門AIです。
  JRAレースの予想・分析を行います。

# テンプレート (モデル固有のフォーマット)
template:
  chat: |
    <|begin_of_text|><|start_header_id|>system<|end_header_id|>
    {{.System}}<|eot_id|>
    <|start_header_id|>user<|end_header_id|>
    {{.Input}}<|eot_id|>
    <|start_header_id|>assistant<|end_header_id|>
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **オールインワン AI** | LLM + 画像生成 + Whisper を1つの API で提供 | インフラ単純化 |
| **プライベートAI** | 競馬データをクラウドに送らずローカル処理 | GDPR/データ流出ゼロ |
| **コスト削減** | OpenAI API を LocalAI で置き換えテスト | 開発コスト 90%削減 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'local-ai', 'api',
  'LocalAI 実践 — Docker起動/モデル設定YAML/OpenAI互換API/画像生成/Whisper/TTS/Python SDK',
  $$## Docker で起動 (ワンコマンド)

```bash
# CPU のみ (全機能利用可)
docker run -p 8080:8080 \
  -v $PWD/models:/build/models \
  --name local-ai \
  localai/localai:latest-aio-cpu

# GPU (CUDA) 付き
docker run --gpus all \
  -p 8080:8080 \
  -v $PWD/models:/build/models \
  localai/localai:latest-aio-gpu-nvidia-cuda-12

# → http://localhost:8080/v1 が OpenAI 互換 API として起動
# → http://localhost:8080 Web UI でモデル管理
```

## Docker Compose (本番構成)

```yaml
# docker-compose.yml
version: "3.9"
services:
  localai:
    image: localai/localai:latest-aio-cpu
    ports:
      - "8080:80"
    volumes:
      - ./models:/build/models
    environment:
      - THREADS=4           # CPU スレッド数
      - CONTEXT_SIZE=4096
      - DEBUG=false
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/readyz"]
      interval: 30s
      retries: 5
```

## モデルのダウンロードとセットアップ

```bash
# LocalAI ギャラリーからモデルを取得
curl http://localhost:8080/models/apply \
  -H "Content-Type: application/json" \
  -d '{"id": "huggingface@TheBloke/Llama-2-7B-Chat-GGUF/llama-2-7b-chat.Q4_K_M.gguf"}'

# または models/ ディレクトリに直接 GGUF + YAML を配置
# models/
#   llama-3.1-8b-Q4_K_M.gguf
#   horse-racing-ai.yaml      ← モデル設定
```

## OpenAI SDK からアクセス

```python
from openai import OpenAI

# LocalAI への接続 (base_url だけ変更)
client = OpenAI(
    base_url="http://localhost:8080/v1",
    api_key="local-ai",  # 任意
)

# Chat Completions
response = client.chat.completions.create(
    model="horse-racing-ai",   # YAML で定義したモデル名
    messages=[
        {"role": "user", "content": "今週の中山記念の見どころを教えて"},
    ],
    temperature=0.7,
    max_tokens=300,
)
print(response.choices[0].message.content)

# 利用可能モデル一覧
models = client.models.list()
for model in models.data:
    print(f"  - {model.id}")
```

## 画像生成 (Stable Diffusion / DALL-E 互換)

```bash
# Stable Diffusion モデルを設定ファイルで登録
# models/stablediffusion.yaml
# name: stablediffusion
# backend: diffusers
# parameters:
#   model: runwayml/stable-diffusion-v1-5
```

```python
from openai import OpenAI
import base64, io
from PIL import Image

client = OpenAI(base_url="http://localhost:8080/v1", api_key="local-ai")

# DALL-E 互換 API で画像生成
response = client.images.generate(
    model="stablediffusion",
    prompt="Japanese horse racing, jockey on horse, realistic photo",
    n=1,
    size="512x512",
    response_format="b64_json",
)

# 画像を保存
image_data = base64.b64decode(response.data[0].b64_json)
image = Image.open(io.BytesIO(image_data))
image.save("horse_racing.png")
print("Image saved!")
```

## 音声認識 (Whisper 互換)

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8080/v1", api_key="local-ai")

# 音声ファイルを文字起こし (Whisper 互換)
with open("./race_commentary.mp3", "rb") as audio_file:
    transcript = client.audio.transcriptions.create(
        model="whisper-1",  # LocalAI の Whisper モデル名
        file=audio_file,
        language="ja",
    )
print(transcript.text)
# → "シャフリヤールが先頭に立ち、第4コーナーを回りました..."
```

## TTS (テキスト→音声)

```python
from openai import OpenAI
from pathlib import Path

client = OpenAI(base_url="http://localhost:8080/v1", api_key="local-ai")

# テキストを音声合成
response = client.audio.speech.create(
    model="tts-1",
    voice="alloy",
    input="今日のレース結果をお知らせします。第1レース、1着はシャフリヤール。",
)

speech_file_path = Path("./race_result.mp3")
response.stream_to_file(speech_file_path)
print(f"Audio saved: {speech_file_path}")
```

## 埋め込み (Embeddings)

```python
from openai import OpenAI
import numpy as np

client = OpenAI(base_url="http://localhost:8080/v1", api_key="local-ai")

# テキスト埋め込みベクター生成
response = client.embeddings.create(
    model="text-embedding-ada-002",  # LocalAI が対応するモデル名
    input=[
        "競馬 G1 天皇賞 春 長距離",
        "競馬 G1 有馬記念 中山 中距離",
    ],
)

embeddings = [item.embedding for item in response.data]
print(f"Embedding dimensions: {len(embeddings[0])}")

# 類似度計算
sim = np.dot(embeddings[0], embeddings[1]) / (
    np.linalg.norm(embeddings[0]) * np.linalg.norm(embeddings[1])
)
print(f"Similarity: {sim:.4f}")
```

## Supabase Edge Function + LocalAI 連携

```typescript
// supabase/functions/ai-assistant/index.ts
// LocalAI セルフホストを使うパターン

const LOCAL_AI_URL = Deno.env.get("LOCAL_AI_URL") || "http://localai:8080";

async function callLocalAI(prompt: string) {
  const res = await fetch(`${LOCAL_AI_URL}/v1/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "horse-racing-ai",
      messages: [{ role: "user", content: prompt }],
      max_tokens: 400,
    }),
  });
  const data = await res.json();
  return data.choices[0].message.content;
}
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 311→312社化: LocalAI 追加',
  'PS#3 S108。LocalAI (OpenAI互換マルチバックエンド/LLM+画像生成+Whisper+TTS+Embeddings/GPU不要CPU対応/Docker完結/YAML設定/Stable Diffusion互換/GitHub 24k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
