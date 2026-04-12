-- Windows版#58: Pika Labs (pika) — AI大学37社目
-- Consumer向け動画生成API $0.03/generation (discovery mode 7/9評価)

INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('pika', 'overview',
   'Pika Labs — 誰でも使える動画生成AI',
   E'## Pika Labs とは\n\nPika Labs は**消費者・クリエイター向け**に特化した動画生成AIスタートアップ。\nスタンフォード大学の学生が2023年に創業、1年で急成長。\n\n## 特徴\n\n「プロでなくても映画品質の動画を作れる」をミッションに掲げ、\n**使いやすさと低コスト**を最大の差別化ポイントとする。\n\n### 主な強み\n\n- **低コスト**: $0.03/生成〜 (Runway/Kling の1/10)\n- **高速生成**: 〜30秒で5秒クリップを生成\n- **直感的UI**: 初心者でも5分でスタート可能\n- **エフェクト特化**: スロー・逆再生・ズームなどを1クリックで適用\n- **キャラクター一貫性**: Pikaffect で人物の見た目を維持\n\n## 主な用途\n\n| 用途 | 実績 |\n|------|------|\n| SNSショート動画 | TikTok・Reels・YouTube Shorts で人気 |\n| マーケティング | 低予算での動画広告制作 |\n| 教育コンテンツ | 説明動画の自動生成 |\n| ゲームシネマティック | インディーゲームのトレーラー制作 |\n\n## 資金調達\n\n- シリーズB: $8000万ドル (2024年)\n- 評価額: $5億ドル超\n- 投資家: Lightspeed Venture Partners など',
   '2026-04-12'),

  ('pika', 'models',
   'Pika モデル一覧 (2026年4月現在)',
   E'## Pika 2.2 (最新)\n\n2026年Q1にリリースされた最新バージョン。\n品質・速度ともに大幅改善、Runway Gen-3 に近い品質を実現。\n\n| スペック | 値 |\n|---------|----|\n| 最大解像度 | 1920×1080 (1080p) |\n| 最大長さ | 10秒 |\n| フレームレート | 24fps |\n| 生成速度 | 〜30秒/5秒クリップ |\n\n## Pika 2.1\n\n安定版。長期プロジェクト・バッチ処理に適する。\n\n## Pika 1.5\n\n旧バージョン。無料プランでも利用可能。\n\n## Pikaffect (エフェクト特化)\n\nキャラクター外観を保ったまま動きを生成する特殊モデル。\nインフルエンサー・バーチャルアバター制作に人気。\n\n## 競合比較\n\n| 指標 | Pika 2.2 | Kling 1.6 | Luma DM | Runway G3 |\n|------|----------|-----------|---------|----------|\n| 品質スコア | 8.0/10 | 9.1/10 | 8.8/10 | 9.0/10 |\n| コスト (5秒) | $0.03 | $0.35 | $0.40 | $0.50 |\n| 生成速度 | 30秒 | 3分 | 2分 | 2分 |\n| 最大長さ | 10秒 | 3分 | 2分 | 30秒 |',
   '2026-04-12'),

  ('pika', 'api',
   'Pika Labs API ガイド',
   E'## API アクセス\n\n**Pika API** はベータ公開中。開発者向けに早期アクセスを提供。\n\n```\nベースURL: https://api.pika.art/v1\n認証: Bearer トークン\n```\n\n## 主要エンドポイント\n\n### テキスト→動画\n```http\nPOST /generate\nAuthorization: Bearer {API_KEY}\nContent-Type: application/json\n\n{\n  "prompt": "A cat playing piano in jazz club, cinematic",\n  "options": {\n    "aspectRatio": "16:9",\n    "frameRate": 24,\n    "duration": 5,\n    "resolution": "1080p"\n  }\n}\n```\n\n### ジョブステータス確認\n```http\nGET /jobs/{job_id}\n```\n\n### 画像→動画\n```http\nPOST /generate/image-to-video\n{\n  "imageUrl": "https://example.com/image.jpg",\n  "prompt": "The character starts walking",\n  "duration": 5\n}\n```\n\n## 料金\n\n| プラン | 月額 | 生成数/月 | API |\n|--------|------|-----------|-----|\n| Free | $0 | 20本 | ✗ |\n| Standard | $8 | 150本 | ✓ |\n| Pro | $20 | 700本 | ✓ |\n| Unlimited | $70 | 無制限 | ✓ |\n\n**API 従量課金**: $0.03/生成 (5秒クリップ)\n\n## 代替アクセス\n\n- **Replicate**: `pika-labs/pika-2.2` として利用可\n- **fal.ai**: `/fal-ai/pika` として統合\n- **AIMLAPI**: 統合APIから利用可\n\n## 日本コミュニティ\n\n- X: `@PikaLabsAI`\n- Discord: Pika Community (日本語チャンネルあり)',
   '2026-04-12')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
