-- Windows版#57: Kling AI (kling) — AI大学36社目
-- シネマティック動画生成 (discovery mode 8/9評価)

INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('kling', 'overview',
   'Kling AI — シネマティック品質の動画生成AI',
   E'## Kling AI とは\n\nKling AI は中国の**快手 (Kuaishou Technology)** が開発した\n次世代動画生成AIプラットフォーム。\n2024年6月リリース、2025年に国際展開。\n\n## 特徴\n\n**「映画品質」**の動画生成が最大の売り。\nプロの映像制作者からも「Runway Gen-3 に匹敵する品質」と評価される。\n\n### 主な強み\n\n- **高品質な動きの表現**: 人物・動物の自然な動作再現が特に優秀\n- **長尺動画**: 最大3分の動画を1回のプロンプトで生成\n- **物理ベースのモーション**: 重力・慣性を正確にシミュレート\n- **顔の一貫性**: 同一人物を複数シーンで安定して描写\n- **音声同期**: 口パクと音声の精度が高い\n\n## 用途\n\n| 用途 | 実績 |\n|------|------|\n| 映画・CM制作 | グローバルブランドの広告で採用実績 |\n| インフルエンサー | ショートドラマ・ミュージックビデオ |\n| ゲーム開発 | キャラクターアニメーション生成 |\n| 教育コンテンツ | 説明動画の低コスト制作 |\n\n## 評価 (2026年4月)\n\n- **Artificial Analysis 動画ベンチマーク**: 1位タイ (Runway Gen-3と並ぶ)\n- **X (旧Twitter) 人気**: #KlingAI がトレンド入り多数\n- **Google Play / App Store**: 平均 4.5/5.0',
   '2026-04-12'),

  ('kling', 'models',
   'Kling AI モデル一覧 (2026年4月現在)',
   E'## Kling 1.6 Pro (最新フラッグシップ)\n\nKling の最高品質モデル。プロ向け映像制作に使用される。\n\n| スペック | 値 |\n|---------|----|\n| 最大解像度 | 1920×1080 (1080p) |\n| 最大長さ | 3分 (180秒) |\n| フレームレート | 30fps |\n| 生成速度 | 〜3分/5秒クリップ |\n\n## Kling 1.6 Standard\n\nコストパフォーマンス重視のモデル。個人・中小ビジネス向け。\n品質は Pro の約80%だが、生成速度は2倍、コストは1/3。\n\n## Kling 1.5 (安定版)\n\n2025年リリースの安定版。エンタープライズでの大量生成に適する。\n\n## Kling Video-to-Video\n\n既存動画のスタイル変換・編集に特化したモデル。\nリアル映像→アニメ、現代→時代劇などのスタイル転換が得意。\n\n## 競合比較\n\n| 指標 | Kling 1.6 Pro | Runway Gen-3 | Luma Dream Machine |\n|------|--------------|--------------|--------------------|\n| 品質スコア | 9.1/10 | 9.0/10 | 8.8/10 |\n| 最大長さ | 3分 | 30秒 | 2分 |\n| コスト (5秒) | $0.35 | $0.50 | $0.40 |\n| 日本語対応 | ○ | △ | △ |',
   '2026-04-12'),

  ('kling', 'api',
   'Kling AI API ガイド',
   E'## API アクセス\n\nKling AI は **Kling Open Platform** として API を公開中。\n\n```\nベースURL: https://api.klingai.com/v1\n認証: Bearer トークン + HMAC-SHA256 署名\n```\n\n## 主要エンドポイント\n\n### テキスト→動画生成\n```http\nPOST /videos/text2video\nAuthorization: Bearer {ACCESS_TOKEN}\nContent-Type: application/json\n\n{\n  "model_name": "kling-v1-6",\n  "prompt": "A samurai walks through cherry blossom petals, cinematic",\n  "negative_prompt": "blurry, low quality",\n  "cfg_scale": 0.5,\n  "mode": "pro",\n  "aspect_ratio": "16:9",\n  "duration": "5"\n}\n```\n\n### 画像→動画\n```http\nPOST /videos/image2video\n{\n  "model_name": "kling-v1-6",\n  "image_url": "https://example.com/image.jpg",\n  "prompt": "The character begins to move",\n  "duration": "5",\n  "mode": "pro"\n}\n```\n\n### タスクステータス確認\n```http\nGET /videos/text2video/{task_id}\n```\n\n## 料金 (API)\n\n| モード | 1クリップあたり (5秒) | 備考 |\n|--------|----------------------|------|\n| Standard | $0.14 | 個人・スタートアップ向け |\n| Pro | $0.35 | 高品質・商用向け |\n\n## 代替アクセス方法\n\n- **Replicate**: `klingai/kling-1.6-pro` モデルとして利用可\n- **fal.ai**: `/fal-ai/kling-video` として統合\n- **AIMLAPI**: 400+ モデル統合APIから利用可\n\n## 注意事項\n\n- 一部地域で API 利用制限あり (VPN 必要な場合がある)\n- 商用利用はエンタープライズプランの申請が必要\n- 日本からのアクセスは現在 Web UI は可能、API は審査制',
   '2026-04-12')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
