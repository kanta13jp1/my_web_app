---
title: "AIで動画を自動生成するパイプライン — NotebookLM + ElevenLabs + GitHub Actions"
tags: AI,自動化,個人開発,youtube
published: false
---

# AIで動画を自動生成するパイプライン — NotebookLM + ElevenLabs + GitHub Actions

「動画コンテンツを作りたいが、編集に時間をかけたくない」という課題を、AI自動化パイプラインで解決した話をします。

## パイプラインの全体像

```
YouTube動画 → ElevenLabs Scribe (文字起こし) → SRT生成
          → タイトルカード生成 (PIL)
          → Philosophy.dart に動画埋め込み
          → GitHub Actions が自動 commit/push
          → Slack 通知
```

1本の動画を処理するのに、人間の作業は「YouTube URLを渡す」だけです。

## Step 1: ElevenLabs Scribe で文字起こし

ElevenLabs の Scribe API は日本語を含む多言語に対応しており、話者識別 (speaker diarization) も実装されています。

```python
# scripts/video/transcribe.py
import requests

def transcribe(audio_path: str) -> dict:
    with open(audio_path, 'rb') as f:
        response = requests.post(
            'https://api.elevenlabs.io/v1/speech-to-text',
            headers={'xi-api-key': API_KEY},
            files={'audio': f},
            data={'model_id': 'scribe_v1', 'diarize': True}
        )
    return response.json()
```

複数話者が検出された場合のみ `「話者A:」「話者B:」` プレフィックスを付与します。単一話者の場合は挙動を変えません。

## Step 2: SRT ファイル生成

Scribe の出力を SRT 形式に変換します。ポイントは「適切な cue 境界」の検出です：

```python
# 4段階の境界検出ロジック
# 1. 終止符・疑問符・感嘆符で分割
# 2. 長すぎる cue (15秒超) を強制分割
# 3. 無音区間 (0.5秒超) で分割
# 4. 最大単語数 (20語) で分割
```

ASR の誤認識を修正する補正辞書も環境変数で設定できます。

## Step 3: タイトルカード生成

動画のサムネイルとタイトルカードを PIL で自動生成します。

```python
# scripts/video/make_cards.py
from PIL import Image, ImageDraw, ImageFont

# 自分株式会社デザイントークン: Orange + Indigo
BACKGROUND = '#1e1b4b'  # Indigo 950
ACCENT = '#f97316'       # Orange 500

def make_title_card(title: str, series: str) -> Image:
    img = Image.new('RGB', (1280, 720), BACKGROUND)
    # テキスト自動折り返し + Noto Sans CJK JP
    ...
```

## Step 4: GitHub Actions での自動化

```yaml
# .github/workflows/notebooklm-video-pipeline.yml
name: NotebookLM Video Pipeline

on:
  workflow_dispatch:
    inputs:
      youtube_url:
        required: true

jobs:
  pipeline:
    steps:
      - name: Step 0 - YouTube quota pre-flight
        # 24h以内に6本以上処理済みなら abort
      
      - name: Step 1 - Download audio
        run: yt-dlp -x --audio-format mp3 "${{ inputs.youtube_url }}"
      
      - name: Step 2 - Transcribe
        run: python scripts/video/transcribe.py
      
      - name: Step 3 - Build SRT
        run: python scripts/video/build_srt.py
      
      - name: Step 4 - Make title cards
        run: python scripts/video/make_cards.py
      
      - name: Step 8 - Embed in Flutter
        run: python scripts/embed_video_in_philosophy.py
      
      - name: Notify Slack
        if: always()
        # Block Kit 形式で成功/失敗を通知
```

## Slack 通知

成功時は動画URL、処理時間、SRTのサマリーを送信。失敗時は GitHub Actions のリンクを貼ります。

```json
{
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "✅ 動画処理完了\n*タイトル:* {title}\n*時間:* {duration}\n*URL:* {url}"
      }
    }
  ]
}
```

## 実際の処理例

Nomic AEC の解説動画 (18MB / 8分17秒) を処理した結果：
- 文字起こし精度: 技術用語の誤認識 17件を補正辞書で修正
- SRT: 42 cue
- 処理時間: 約4分 (GitHub Actions 上)

## まとめ

このパイプラインにより：
- 動画1本あたりの人間作業: **5分以下** (URL入力 + Slack確認)
- YouTube quota を超えない設計 (6本/日上限チェック)
- 重複処理防止 (slug dedup window 1h)

AI 動画コンテンツの量産に使えるテンプレートとして公開しています。
