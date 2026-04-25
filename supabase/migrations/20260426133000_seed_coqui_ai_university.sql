-- PS#3 S55: AI大学 202→203社化 — Coqui 追加
-- Coqui: OSS 音声クローン TTS / XTTS-v2 / Apache 2.0 / 多言語 3秒クローン

INSERT INTO ai_university_content (provider_id, section, content_md, display_order)
VALUES
(
  'coqui_ai',
  'overview',
  $md$## Coqui — OSS 音声クローン TTS

**カテゴリ**: Open-Source Text-to-Speech / Voice Cloning
**設立**: 2021年 / 本社: ダブリン (アイルランド)
**ライセンス**: Apache 2.0 (XTTS-v2) / Mozilla Public License (TTS 旧版)
**コミュニティ**: Hugging Face 最多ダウンロード TTS モデル群 / GitHub 35k+ Stars
**評価**: ★8/9

### 概要
Coqui は元 Mozilla TTS チームが創業した OSS 音声合成企業。旗艦モデル **XTTS-v2** は 3 秒の音声サンプルから話者の声を複製し、16 ヶ国語でナチュラルな音声を生成する。商用利用可能な Apache 2.0 ライセンスで、Hugging Face 経由で無料利用できる。

### 主な特長
- **XTTS-v2**: 3 秒サンプルでゼロショット声クローン / 16 言語対応 / 商用 OK
- **OSS 完全公開**: Apache 2.0 / Hugging Face モデルハブで無料利用
- **多言語対応**: 英語・日本語・スペイン語・フランス語・ドイツ語など 16 言語
- **感情制御**: テキスト内の [laughter] / [emphasis] タグで感情・強調を指定
- **ローカル実行**: GPU なしでも動作 (CPU モード対応 / RTX 3090 で最速)
- **Coqui Studio** (旧 SaaS): 2024 年に閉鎖 → OSS コミュニティが継続開発

### 競合との差別化
| ツール | 特徴 |
|--------|------|
| **ElevenLabs** | 最高品質・感情豊か / 有料 SaaS |
| **Murf** | Canva 統合・ビジネス向け / 有料 SaaS |
| **OpenVoice** | My Shell OSS / スタイル転送特化 |
| **Bark** | Suno AI OSS / 笑い声・歌声対応 |

Coqui の強みは **Apache 2.0 × ローカル実行 × 3 秒クローン × 無料**。プライバシー重視・オンプレミス展開に最適。

### 導入コスト
- **OSS (XTTS-v2)**: 完全無料 (Hugging Face Hub / ローカル実行)
- **GPU**: VRAM 4GB 以上推奨 (NVIDIA RTX シリーズ)
- **CPU フォールバック**: 低速だが動作可能
$md$,
  1
),
(
  'coqui_ai',
  'api',
  $md$## Coqui API / 統合

### Python ライブラリ (TTS)

```python
from TTS.api import TTS

# XTTS-v2 モデルでゼロショット声クローン
tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2")

# 3秒サンプルから日本語音声生成
tts.tts_to_file(
    text="自分株式会社のAI大学へようこそ。",
    speaker_wav="sample_voice.wav",   # 3秒以上の参照音声
    language="ja",
    file_path="output.wav"
)
```

### Hugging Face Transformers 経由

```python
from transformers import pipeline

tts = pipeline("text-to-speech", model="coqui/XTTS-v2")
audio = tts("Hello from Coqui!", speaker_embeddings=speaker_emb)
```

### FastAPI サーバー化 (Self-host)

```python
from fastapi import FastAPI
from TTS.api import TTS

app = FastAPI()
tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2")

@app.post("/synthesize")
async def synthesize(text: str, language: str = "ja"):
    tts.tts_to_file(text=text, language=language, file_path="/tmp/out.wav")
    return FileResponse("/tmp/out.wav")
```

### インストール

```bash
pip install TTS  # PyPI 公式パッケージ
# または
pip install git+https://github.com/coqui-ai/TTS
```

### 制限事項
- XTTS-v2 は Coqui Public Model License (商用は別途確認)
- 旧来の TTS モデルは Apache 2.0
- リアルタイムストリーミングは非公式実装のみ
$md$,
  2
),
(
  'coqui_ai',
  'models',
  $md$## Coqui の AI モデル

| モデル | 用途 | ライセンス |
|--------|------|-----------|
| **XTTS-v2** | 多言語ゼロショット声クローン | Coqui Public Model License |
| **YourTTS** | 多言語ゼロショット (旧世代) | Apache 2.0 |
| **Tacotron2** | 英語 TTS (シンプル・高速) | Apache 2.0 |
| **FastSpeech2** | 英語 TTS (制御性高い) | Apache 2.0 |
| **VITS** | end-to-end 高品質 | Apache 2.0 |

### XTTS-v2 対応言語 (16 言語)
英語 / スペイン語 / フランス語 / ドイツ語 / イタリア語 / ポルトガル語 /
ポーランド語 / トルコ語 / ロシア語 / オランダ語 / チェコ語 / アラビア語 /
**日本語** / 中国語 / ハンガリー語 / 韓国語

### 自分株式会社での活用可能性
- AI 大学コンテンツの日本語音声ナレーション (完全ローカル / コスト $0)
- 自社キャラクター音声の声クローン → ブランドボイス確立
- プライバシー重視の音声アシスタント (オンプレミス展開)
- 競合比較レポートの Podcast 音声版生成 (API コスト不要)

### 日本語対応状況
- XTTS-v2 で日本語対応 ★7/9 (自然さは ElevenLabs の ★9 より劣る)
- 文字量が多いと発音が乱れる場合あり → 500文字以下に分割推奨
$md$,
  3
)
ON CONFLICT (provider_id, section) DO UPDATE
  SET content_md = EXCLUDED.content_md,
      display_order = EXCLUDED.display_order,
      updated_at = NOW();

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 202→203社化: Coqui 追加',
  'PS#3 S55。Coqui (OSS 音声クローン TTS / XTTS-v2 / 3秒ゼロショット声クローン / 16言語 / Apache 2.0 / Hugging Face 35k+ Stars / ローカル実行 / 完全無料 / ★8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
