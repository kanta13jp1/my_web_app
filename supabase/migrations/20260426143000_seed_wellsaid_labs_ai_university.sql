-- PS#3 S56 fix: 20260426143000 — WellSaid Labs AI大学 seed (provider/category/content schema)
-- WellSaid Labs: エンタープライズ向け AI 音声クローン / 同意ベース / スタジオ品質 / 10M+ USD 調達

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'wellsaid_labs',
  'overview',
  'WellSaid Labs — エンタープライズ AI 音声クローン (同意ベース / スタジオ品質 / 10M+ USD)',
  $$## WellSaid Labs — エンタープライズ AI 音声クローン

**カテゴリ**: Enterprise AI Voice Cloning / Text-to-Speech
**設立**: 2018年 / 本社: シアトル (ワシントン州)
**調達**: 10M+ USD (シリーズ A / FUSE / Harmony Partners)
**特許技術**: 同意ベース (Consent-Based) 声クローン
**評価**: 8/9

### 概要
WellSaid Labs はエンタープライズ向けスタジオ品質 AI 音声に特化した TTS プラットフォーム。最大の特徴は「同意ベース声クローン」—— 実際の声優から明示的な許可を得た上でデジタル声クローンを作成し、企業が権利を守りながら音声コンテンツを制作できる倫理的なアプローチ。e-ラーニング・企業研修動画・マーケティング動画など B2B コンテンツ制作に強い。

### 主な特長
- **同意ベース声クローン**: 実声優から許諾取得済みのプロ品質 AI 音声 50+ 種
- **スタジオ品質**: 専門録音スタジオと遜色ない音質
- **WellSaid Studio**: ブラウザ上でテキスト→音声→動画編集を完結
- **API**: REST API でプログラムから音声生成
- **チームコラボ**: 複数メンバーがプロジェクトを共有・編集
- **コンプライアンス重視**: 声優の権利保護 / 使用許諾管理

### 競合との差別化
ElevenLabs: 最高品質 / 一般消費者向け / 声クローン規制なし / Murf: Canva 統合 / コンシューマー向け / Speechify: 読み上げ特化 / 著名人ボイス / Resemble AI: リアルタイム 50ms / ゲーム向け

WellSaid の強みは **倫理的声クローン × エンタープライズ品質 × B2B e-ラーニング特化**。コンテンツチームが安心して使える唯一のプラットフォーム。

### 導入コスト
- **Creator**: 月 49 USD (個人 / Studio UI / 50 AI 音声)
- **Teams**: 月 89 USD/席 (チームコラボ / API アクセス)
- **Enterprise**: 問い合わせ (カスタム声クローン / SSO / SLA)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'wellsaid_labs',
  'api',
  'WellSaid Labs API — REST TTS + 声優 ID + Webhook非同期生成 (Python)',
  $$## WellSaid Labs API / 統合

### REST API

```python
import requests

url = "https://api.wellsaidlabs.com/v1/tts/stream"
headers = {
    "X-Api-Key": "YOUR_API_KEY",
    "Accept": "audio/mpeg",
    "Content-Type": "application/json"
}
payload = {
    "text": "AI大学へようこそ。WellSaid Labsが生成する音声です。",
    "speaker_id": 3
}
response = requests.post(url, json=payload, headers=headers, stream=True)
with open("output.mp3", "wb") as f:
    for chunk in response.iter_content(chunk_size=4096):
        f.write(chunk)
```

### 声優 ID 一覧取得

```python
speakers_url = "https://api.wellsaidlabs.com/v1/speakers"
response = requests.get(speakers_url, headers={"X-Api-Key": "YOUR_API_KEY"})
speakers = response.json()
# 例: [{"id": 1, "name": "Alana B.", "type": "neural", "gender": "F"}, ...]
```

### Webhook 統合 (非同期生成)

```python
payload = {
    "text": "長文コンテンツ...",
    "speaker_id": 5,
    "webhook_url": "https://your-server.com/webhook"
}
response = requests.post(
    "https://api.wellsaidlabs.com/v1/tts/async",
    json=payload, headers=headers
)
job_id = response.json()["job_id"]
```

### Zapier / Make 連携
- Notion ページ → WellSaid API → MP3 → Google Drive
- Google Docs コンテンツ → 音声ナレーション自動生成

### 制限事項
- カスタム声クローンは Enterprise プランのみ
- API は Teams プラン以上
- 最大 3000 文字/リクエスト
- 日本語は beta 対応 (一部 AI 音声のみ)$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'wellsaid_labs',
  'models',
  'WellSaid Labs モデル — 同意ベース声クローン技術 + エンタープライズ品質 Neural TTS',
  $$## WellSaid Labs の AI モデル

| 機能 | 技術 |
|------|------|
| Text-to-Speech | 独自 Neural TTS (スタジオ録音品質) |
| Voice Cloning | 同意ベース声クローン (声優許諾取得) |
| 発音制御 | 発音記号 (IPA) 指定 / SSML サポート |
| 感情制御 | ポーズ・速度・強調コントロール |

### 同意ベース声クローンの仕組み
1. **声優リクルート**: WellSaid が声優と正式契約 (報酬・使用許諾)
2. **録音**: 高品質スタジオ収録 (5〜10 時間のデータセット)
3. **モデル学習**: 専用 Neural TTS モデルを訓練
4. **ライセンス販売**: ユーザーは月額で声を利用 (声優は継続ロイヤリティ)

これにより AI 声クローンの倫理問題 (声優の仕事奪取・無断使用) を回避。

### 自分株式会社での活用可能性
- AI 大学 e-ラーニングコンテンツへのプロ品質ナレーション付与
- 企業研修動画・操作マニュアル動画の音声自動化
- 競合分析レポートの Podcast 音声版 (B2B 品質)
- LP 動画のナレーション自動生成 → 多言語 LP 展開

### 日本語対応状況
- 日本語: beta (2024年時点 / 一部 AI 音声のみ)
- 英語コンテンツ: 9/9 (エンタープライズ最高品質)$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 205→206社化: WellSaid Labs 追加',
  'PS#3 S56。WellSaid Labs (エンタープライズ AI 音声クローン / 同意ベース声クローン / スタジオ品質 / 50+ AI 音声 / API 提供 / 10M+ USD 調達 / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
