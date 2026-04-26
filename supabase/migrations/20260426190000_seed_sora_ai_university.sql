-- Win版#132 part 24: AI大学 214→215社化 — OpenAI Sora 追加
-- Sora: OpenAI 動画生成 AI / Sora 2 / 60秒長尺 / DiT (Diffusion Transformer) / 2026 GA / 物理シミュレーション

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'sora',
  'overview',
  'Sora — OpenAI の動画生成 AI (Sora 2 / 60秒長尺 / 物理シミュレーション / 2026 GA)',
  $$## Sora — OpenAI の動画生成 AI

**カテゴリ**: AI Video Generation / Diffusion Transformer / Multimodal
**提供元**: OpenAI / 本社: San Francisco, CA
**初公開**: 2024年2月 (Sora 1) / GA: 2026年 (Sora 2)
**特徴**: 最大 60 秒の高解像度動画生成 / 物理法則の再現 / Multi-shot シーン構成
**ユーザー**: 映像クリエイター / 広告制作 / ゲーム開発者 / プロトタイピング
**評価**: 9/9

### 概要
Sora は OpenAI が開発した text-to-video / image-to-video / video-to-video 生成 AI。**Diffusion Transformer (DiT)** アーキテクチャを採用し、テキストプロンプトから最大 60 秒・1080p の高品質動画を生成できる。Sora 2 では複数ショットの一貫した世界モデル (World Simulator) として進化し、登場人物・物理オブジェクト・カメラワークの連続性を保ったまま長尺生成が可能。2024 年 2 月にデモ公開され大きな話題を呼び、2026 年に ChatGPT Pro / Team / Enterprise + API として正式 GA。

### 主な特長
- **長尺生成**: 最大 60 秒 (Sora 1 = 60s / Sora 2 はさらに延長可能)
- **物理シミュレーション**: 流体・布・光の屈折・重力など物理法則を内包学習
- **Multi-shot**: 1 プロンプトで複数カット (close-up → wide shot 等) を一貫して生成
- **World Simulator**: 登場人物の同一性 / 背景の連続性を保持 (Sora 2 強化)
- **Image-to-Video**: 静止画をアニメーション化 (キーフレーム指定可)
- **Video-to-Video**: 既存動画のスタイル変換 / 編集
- **Storyboard**: ChatGPT 内で複数シーンをタイムライン編集
- **Remix / Re-cut / Loop / Blend**: 生成動画の派生編集機能
- **ウォーターマーク**: 生成動画に C2PA メタデータ + 視認可能なウォーターマーク (誤情報対策)

### 競合との差別化

| サービス | 最大長 | 解像度 | 物理再現 | 公開度 |
|---------|--------|--------|---------|--------|
| **Sora 2 (OpenAI)** | 60s+ | 1080p | ★★★★★ | API GA (2026) |
| Veo 3 (Google) | 60s | 4K | ★★★★ | Vertex AI |
| Runway Gen-4 | 16s | 1080p | ★★★★ | API/Web |
| Pika 2.0 | 10s | 1080p | ★★★ | Web/API |
| Kling 2.0 (快手) | 10-120s | 1080p | ★★★★ | Web (中国) |
| HunyuanVideo (Tencent) | 5s | 720p | ★★★ | OSS |

### 利用シーン
- **広告クリエイティブ**: 15s/30s 商品動画を数分でプロトタイプ
- **ストーリーボード**: 映画/TV 企画段階のビジュアライゼーション
- **ゲーム開発**: シネマティック / カットシーンのドラフト
- **教育コンテンツ**: 歴史/科学の動的説明動画
- **SNS マーケティング**: TikTok/Reels/Shorts 用短尺動画

### 注意点 / 制限
- 人間の手指・複雑な動作はまだ崩れる場合あり
- 著作権キャラクター / 実在人物の生成は制限 (OpenAI ポリシー)
- 1 動画あたり生成時間: Sora 2 は約 1-3 分 (60s 動画)
- API レート: ChatGPT Pro = 月 50 動画 / Team・Enterprise はカスタム
- 商用利用: 有料プラン (Plus/Pro/Team/Enterprise) は OK

### 料金 (2026年4月時点)
- **ChatGPT Plus** ($20/月): 月 50 動画 (最大 5 秒 / 720p)
- **ChatGPT Pro** ($200/月): 月 500 動画 (最大 20 秒 / 1080p)
- **ChatGPT Team / Enterprise**: カスタム
- **API** (Sora 2 GA): $0.10〜0.50 / 動画秒 (解像度別)

### API 例 (OpenAI SDK)
```python
from openai import OpenAI
client = OpenAI()

video = client.videos.create(
    model="sora-2",
    prompt="A golden retriever puppy running through a field of sunflowers at sunset, cinematic camera following from behind, 4K, slow motion",
    duration_seconds=10,
    resolution="1080p",
    aspect_ratio="16:9",
)
print(video.url)  # download URL
```

### 公式リソース
- **公式サイト**: https://openai.com/sora
- **API ドキュメント**: https://platform.openai.com/docs/guides/video-generation
- **Sora System Card**: https://openai.com/index/sora-system-card/
- **C2PA ウォーターマーク仕様**: https://c2pa.org/

OpenAI Sora は動画生成 AI の最先端であり、長尺・高品質・物理シミュレーションの 3 軸で 2026 年現在の SOTA。広告・映像・ゲーム業界の制作プロセスに大きな変革をもたらす存在。$$,
  'https://openai.com/sora',
  '2026-04-26',
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 214→215社化: Sora 追加',
  'Win版#132 part 24。OpenAI Sora (動画生成 / Sora 2 / 60秒長尺 / DiT / 物理シミュレーション / 2026 GA / 9/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
