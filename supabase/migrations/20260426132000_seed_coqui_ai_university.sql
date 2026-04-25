-- PS#3 S55 fix (PS#1 S46): 20260426133000 — Coqui AI大学 seed (provider/category/content schema)
-- Coqui: OSS TTS / XTTS-v2 / 3秒声クローン / 16言語 / Apache 2.0

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'coqui_ai',
  'overview',
  'Coqui — OSS 音声クローン TTS (XTTS-v2 / 3秒声クローン / 16言語 / Apache 2.0)',
  $$## Coqui — OSS 音声クローン TTS

**カテゴリ**: Open-Source Text-to-Speech / Voice Cloning
**設立**: 2021年 / 本社: ダブリン (アイルランド)
**ライセンス**: Apache 2.0 (XTTS-v2) / Mozilla Public License (TTS 旧版)
**コミュニティ**: Hugging Face 最多ダウンロード TTS モデル群 / GitHub 35k+ Stars
**評価**: 8/9

### 概要
Coqui は元 Mozilla TTS チームが創業した OSS 音声合成企業。旗艦モデル XTTS-v2 は 3 秒の音声サンプルから話者の声を複製し、16 ヶ国語でナチュラルな音声を生成する。商用利用可能な Apache 2.0 ライセンスで、Hugging Face 経由で無料利用できる。

### 主な特長
- **XTTS-v2**: 3 秒サンプルでゼロショット声クローン / 16 言語対応 / 商用 OK
- **OSS 完全公開**: Apache 2.0 / Hugging Face モデルハブで無料利用
- **多言語対応**: 英語・日本語・スペイン語・フランス語・ドイツ語など 16 言語
- **感情制御**: テキスト内の [laughter] / [emphasis] タグで感情・強調を指定
- **ローカル実行**: GPU なしでも動作 (CPU モード対応 / RTX 3090 で最速)
- **Coqui Studio** (旧 SaaS): 2024 年に閉鎖 → OSS コミュニティが継続開発

### 競合との差別化
ElevenLabs: 最高品質・感情豊か / 有料 SaaS / Murf: Canva 統合・ビジネス向け / 有料 SaaS / OpenVoice: My Shell OSS / スタイル転送特化 / Bark: Suno AI OSS / 笑い声・歌声対応

Coqui の強みは **Apache 2.0 × ローカル実行 × 3 秒クローン × 無料**。プライバシー重視・オンプレミス展開に最適。

### 導入コスト
- **OSS (XTTS-v2)**: 完全無料 (Hugging Face Hub / ローカル実行)
- **GPU**: VRAM 4GB 以上推奨 (NVIDIA RTX シリーズ)
- **CPU フォールバック**: 低速だが動作可能$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'coqui_ai',
  'api',
  'Coqui — Python SDK・統合 (TTS ライブラリ / XTTS-v2 / FastAPI サーバー化 / pip install)',
  $$## Coqui API / 統合

### Python ライブラリ (TTS)
pip でインストール: pip install TTS (PyPI 公式)

主要 API: TTS("tts_models/multilingual/multi-dataset/xtts_v2") でモデル初期化 → tts_to_file(text, speaker_wav, language, file_path) で音声生成。speaker_wav に 3 秒以上の参照音声を指定するとゼロショット声クローン。

### Hugging Face Transformers 経由
pipeline("text-to-speech", model="coqui/XTTS-v2") でロード → テキストと speaker_embeddings を渡して音声生成。

### FastAPI サーバー化 (Self-host)
FastAPI + TTS ライブラリで REST エンドポイントを構築してセルフホスト可能。POST /synthesize で text と language を受け取り WAV を返す構成が一般的。

### インストール
pip install TTS (PyPI) または pip install git+https://github.com/coqui-ai/TTS (最新版)

### 制限事項
- XTTS-v2 は Coqui Public Model License (商用は別途確認)
- 旧来の TTS モデルは Apache 2.0
- リアルタイムストリーミングは非公式実装のみ$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'coqui_ai',
  'models',
  'Coqui — AIモデル (XTTS-v2 / YourTTS / Tacotron2 / VITS / 16言語 / 日本語対応)',
  $$## Coqui の AI モデル

XTTS-v2: 多言語ゼロショット声クローン (Coqui Public Model License) / YourTTS: 多言語ゼロショット 旧世代 (Apache 2.0) / Tacotron2: 英語 TTS シンプル高速 (Apache 2.0) / FastSpeech2: 英語 TTS 制御性高い (Apache 2.0) / VITS: end-to-end 高品質 (Apache 2.0)

### XTTS-v2 対応言語 (16 言語)
英語 / スペイン語 / フランス語 / ドイツ語 / イタリア語 / ポルトガル語 / ポーランド語 / トルコ語 / ロシア語 / オランダ語 / チェコ語 / アラビア語 / 日本語 / 中国語 / ハンガリー語 / 韓国語

### 自分株式会社での活用可能性
- AI 大学コンテンツの日本語音声ナレーション (完全ローカル / コスト 0 円)
- 自社キャラクター音声の声クローン → ブランドボイス確立
- プライバシー重視の音声アシスタント (オンプレミス展開)
- 競合比較レポートの Podcast 音声版生成 (API コスト不要)

### 日本語対応状況
- XTTS-v2 で日本語対応 7/9 (自然さは ElevenLabs の 9 より劣る)
- 文字量が多いと発音が乱れる場合あり → 500文字以下に分割推奨$$,
  NULL,
  NULL,
  203
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 202→203社化: Coqui 追加',
  'PS#3 S55 (PS#1 S46 fix)。Coqui (OSS 音声クローン TTS / XTTS-v2 / 3秒ゼロショット声クローン / 16言語 / Apache 2.0 / Hugging Face 35k+ Stars / ローカル実行 / 完全無料 / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
