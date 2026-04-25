-- PS#3 S59: AI大学 210→211社化 — Lalal.ai 追加
-- Lalal.ai: AI 音声・ステム分離 / ボーカル/楽器/ドラム/ベースを個別抽出 / Phoenix Neural Net

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lalal_ai',
  'overview',
  'Lalal.ai — AI 音声・ステム分離 (ボーカル/楽器 10音源分離 / Phoenix Neural Net / API)',
  $$## Lalal.ai — AI 音声・ステム分離

**カテゴリ**: AI Stem Separation / Audio Source Separation / Music Production
**設立**: 2019年 / 本社: キプロス
**特許技術**: Phoenix Neural Net (フェニックスニューラルネット)
**ユーザー数**: 数百万人のミュージシャン・映像制作者
**評価**: 8/9

### 概要
Lalal.ai は**楽曲を個別音源 (ステム) に分離する AI プラットフォーム**。ボーカル・ギター・ドラム・ベース・ピアノ・エレクトリックギターなど最大 10 音源を高精度で分離できる。カラオケトラック作成・リミックス制作・映像の BGM 入れ替え・楽器練習用伴奏生成など幅広いユースケースを持つ。

### 主な特長
- **10 音源分離**: ボーカル / ドラム / ベース / ギター / ピアノ / シンセ / ストリングス など
- **Phoenix Neural Net**: 独自 AI モデルで業界最高水準の分離精度
- **ノイズ除去**: 背景音・風切り音・マイクノイズの除去機能
- **API**: REST API で音源分離をプログラムから実行
- **全フォーマット対応**: MP3 / WAV / FLAC / AIFF / AAC / OGG
- **バッチ処理**: 複数ファイルの一括処理 (API + Pro プラン)

### 競合との差別化
Spleeter (Deezer OSS): 高速だが精度低 / iZotope RX: DAW プラグイン / 高価 / Moises: モバイル向け / バンドスコア連動 / Demucs (Meta OSS): ローカル実行 / GPU 必要

Lalal.ai の強みは **クラウド API × 10音源分離 × ノイズ除去統合 × コスパ**。ブラウザだけで完結し、API 経由で自動化パイプラインに組み込める。

### 導入コスト
- **Free**: 90 秒プレビュー (フル版は有料)
- **Light**: 90 分 (8.33 USD)
- **Personal**: 300 分 (22 USD / 月)
- **Business**: 2000 分 (39 USD / 月) + API アクセス
- **Enterprise**: 問い合わせ (大容量 / SLA / カスタム統合)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lalal_ai',
  'api',
  'Lalal.ai API — ステム分離 REST API + ポーリング + バッチ処理 (Python)',
  $$## Lalal.ai API / 統合

### ステム分離 API (Python)

```python
import requests

# Step 1: ファイルアップロード
upload_url = "https://www.lalal.ai/api/upload/"
headers = {"Authorization": "license YOUR_API_KEY"}

with open("song.mp3", "rb") as f:
    response = requests.post(
        upload_url,
        headers=headers,
        files={"file": ("song.mp3", f, "audio/mpeg")}
    )
file_id = response.json()["id"]
```

### 分離処理開始

```python
# Step 2: 分離リクエスト
process_url = "https://www.lalal.ai/api/process/"
payload = {
    "id": file_id,
    "stem": "vocals",         # vocals / drums / bass / piano / guitar / etc.
    "splitter": "phoenix",    # phoenix (最高品質) / cassiopeia (高速)
    "filter": 0               # 0=balanced / 1=mild / 2=aggressive
}
response = requests.post(process_url, json=payload, headers=headers)
task_id = response.json()["task_id"]
```

### 結果取得 (ポーリング)

```python
# Step 3: 完了確認
check_url = f"https://www.lalal.ai/api/check/?id={file_id}"
import time

while True:
    status = requests.get(check_url, headers=headers).json()
    if status["task"]["status"] == "success":
        stem_url = status["task"]["stem_track"]      # 分離音源 (ボーカルなど)
        background_url = status["task"]["back_track"] # 残り音源
        break
    time.sleep(5)

# Step 4: ダウンロード
stem_data = requests.get(stem_url).content
with open("vocals.mp3", "wb") as f:
    f.write(stem_data)
```

### 対応ステム (stem パラメータ)
vocals / drums / bass / piano / guitar / acoustic_guitar / electric_guitar /
synthesizer / strings / wind_instruments

### 制限事項
- API は Business プラン以上
- 最大ファイルサイズ: 300MB
- 処理時間: 1分の音楽 = 約 30秒〜3分$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lalal_ai',
  'models',
  'Lalal.ai モデル — Phoenix Neural Net + Cassiopeia + ノイズ除去 AI',
  $$## Lalal.ai の AI モデル

| モデル | 特徴 | 用途 |
|--------|------|------|
| **Phoenix** | 最高品質 / 低ブリード (漏れ) | プロ制作・配信 |
| **Cassiopeia** | 高速 / 軽量 | 大量処理・リアルタイム近似 |
| **Noise Cleaner** | 背景ノイズ / 風切り音除去 | ポッドキャスト・インタビュー |

### 分離精度指標
- ボーカル分離 SDR (Signal-to-Distortion Ratio): 業界トップ水準
- ブリード (漏れ) 率: 競合比 60% 低減 (Phoenix)
- 処理速度: 3分楽曲 = 約 45秒 (クラウド)

### 自分株式会社での活用可能性
- 動画 BGM のボーカル除去 → カラオケトラック生成 (著作権未解決のため自社コンテンツのみ)
- ポッドキャスト音声のノイズ除去自動化 (Noise Cleaner API)
- AI 大学コンテンツの音声クリーニング → 高品質 e-ラーニング音声
- リミックス制作ワークフローの自動化 (ドラムトラック単独抽出 → 差し替え)

### 倫理・著作権
- 分離機能自体は合法 (ツール提供のみ)
- 分離した音源の二次利用は原著作権者の許諾が必要
- 自社制作音楽 / ロイヤリティフリー音楽 / カバー楽曲には制限なし$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 210→211社化: Lalal.ai 追加',
  'PS#3 S59。Lalal.ai (AI 音声・ステム分離 / Phoenix Neural Net / ボーカル/ドラム/ベース/ギターなど 10音源分離 / ノイズ除去 / REST API / Business プランで自動化可 / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
