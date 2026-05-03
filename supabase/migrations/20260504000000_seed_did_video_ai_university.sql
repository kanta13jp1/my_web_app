-- PS#3 S152: AI大学 D-ID 動画AI追加 (Issue #1735)
-- Source: NotebookLM da2a95d1 D-ID: Comprehensive Guide to AI Video Creation

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'did', 'ai_video_avatar',
  'D-ID — AIアバター・デジタルヒューマン・リアルタイム対話動画生成完全ガイド (10/10)',
  $$## D-ID とは

**D-ID** は 2017 年設立のイスラエル発 AI 動画スタートアップ。
1 枚の写真とテキスト・音声から**本物そっくりのAIアバター動画**を生成する技術で知られ、
デジタルヒューマン / プレゼン動画 / リアルタイム AI エージェント分野のパイオニア。

**起源**: 顔認識からプライバシーを「防御 (Defense)」する技術からスタートし、
その顔操作の専門知識を逆転させてAI生成 (Generation) プラットフォームに進化した。

## 主要API

```
[Videos API — 非同期動画生成]
  V4 Expressive Avatars:
    → 1枚の写真から話すアバター動画を生成
    → 感情パラメータ (happiness/serious/surprised/sad) でリップシンク
    → Canvas Layout: 横長/正方形/縦長など配信メディア対応

  Video Translate:
    → 既存動画を 100+ 言語に自動翻訳 (リップシンク + 音声クローン)
    → YouTubeコンテンツの多言語展開に最適

[Realtime API — WebRTC リアルタイム対話]
  Agents & Agent Sessions:
    → 独自知識ベース (RAG) + LLM と連携
    → WebRTC で低遅延リアルタイム動画ストリーミング
    → AIアバターと生の会話ができる

  Agents Embed SDK:
    → バックエンドコード不要でフロントエンドに直接埋め込み
    → Flutter Web の WebView または iframe で統合可能
```

## D-ID API コード例

```python
import requests

# 動画生成 (Videos API)
response = requests.post(
    "https://api.d-id.com/talks",
    headers={"Authorization": "Basic YOUR_API_KEY"},
    json={
        "source_url": "https://your-storage/avatar.jpg",
        "script": {
            "type": "text",
            "subtitles": False,
            "provider": {
                "type": "microsoft",
                "voice_id": "ja-JP-NanamiNeural"  # 日本語音声
            },
            "input": "こんにちは、自分株式会社のAI大学へようこそ！"
        },
        "config": {
            "fluent": True,
            "pad_audio": 0.0
        }
    }
)

talk_id = response.json()["id"]

# 動画取得 (polling)
result = requests.get(
    f"https://api.d-id.com/talks/{talk_id}",
    headers={"Authorization": "Basic YOUR_API_KEY"}
)
video_url = result.json()["result_url"]
```

## D-ID vs 競合比較

| 特性 | D-ID | HeyGen | Synthesia | Hedra |
|------|------|--------|-----------|-------|
| **リアルタイム対話** | ✅ WebRTC | △ | ✗ | ✗ |
| **1枚写真から生成** | ✅ | ✅ | △ | ✅ |
| **感情制御** | ✅ V4 Expressive | ✅ | ✅ | ✅ |
| **Video Translate** | ✅ 100+言語 | ✅ | ✅ | ✗ |
| **Embed SDK** | ✅ | △ | ✗ | ✗ |
| **月額** | $7〜 | $29〜 | $22〜 | API課金 |
| **無料枠** | 5 credits | 1 video/月 | なし | あり |

## AI倫理とウォーターマーキング

```
D-IDの合成メディア倫理ポリシー:
  ✅ 電子透かし (Digital Watermarking) — AI生成動画に不可視マーキング
  ✅ C2PA 標準対応 — コンテンツの真正性証明
  ✅ AI Speech Classifier — 合成音声の検出ツール
  ✅ TOS: 本人同意なしのディープフェイク禁止

自分株式会社での倫理適用:
  → AI大学講義動画: "この動画はAIで生成されました" ラベル必須
  → ユーザーアバター: 本人写真 + 同意確認 UI を必須化
  → AI_CHARACTER_PRINCIPLES.md の合成メディア倫理条項に追記
```

## 自分株式会社での活用シナリオ

```
1. AI大学 音声講義動画 (AI大学 × 動画AI):
   → ai_university_content のテキストコンテンツを
   → D-ID Videos API でアバター動画化
   → Supabase Storage 保存 → AI大学ページで視聴可能
   → 費用: 月 50 動画 ≒ $7 (Lite プラン)

2. AI アバター カスタマーサポート:
   → reply-support-request EF が回答文生成
   → D-ID Realtime API で応答動画をストリーミング
   → Flutter Web: WebRTC + video element で表示
   → CS体験の差別化 (テキスト → 動画AI対応)

3. WBS コーチングアバター (Issue #917 関連):
   → WBS タスク完了時に AIアバター が「よくできました！」と音声+動画で褒める
   → Flutter の AnimatedContainer と連携してモチベーション向上
   → D-ID V4 Expressive: happiness 感情で生成

4. Replit LP 動画デモ:
   → プロダクト説明動画を D-ID で自動生成
   → 複数言語版を Video Translate で展開 (英語/日本語/中国語)
```

## 自分株式会社 AI 大学での位置づけ

- **学部**: 動画・メディアAI学部 (video_ai)
- **学科**: AIアバター・デジタルヒューマン学科 (ai_video_avatar)
- **関連プロバイダー**: Hedra / HeyGen / Synthesia / Runway ML / ElevenLabs
- **実用的示唆**: Realtime API + WebRTC は Flutter Web の WebView 経由で統合可能。
  D-ID Lite ($7/月) で AI大学講義動画の自動生成パイプラインが実現可能。
$$,
  'https://www.d-id.com',
  '2026-01-01',
  102
)
ON CONFLICT (provider, category) DO NOTHING;
