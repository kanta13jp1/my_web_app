-- Windows版#57: Luma AI (luma) — AI大学35社目
-- 3D-aware動画生成 Dream Machine API (discovery mode 9/9評価)

INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('luma', 'overview',
   'Luma AI — 3D-aware動画生成のパイオニア',
   E'## Luma AI とは\n\nLuma AI は**3D空間理解を持つ動画生成AI**のパイオニア企業。\nサンフランシスコ拠点、2021年創業。\n\n## Dream Machine\n\n旗艦プロダクト **Dream Machine** はテキスト・画像から高品質な動画を生成。\n従来の2D動画生成AIと異なり、**3D空間の奥行き・カメラモーション・物理挙動**を\nリアルに表現できる点が最大の差別化ポイント。\n\n## 主な特徴\n\n- **3D-aware生成**: 空間理解により自然な奥行き・影・反射を表現\n- **カメラコントロール**: パン・ズーム・軌道など映画的カメラワーク\n- **物理シミュレーション**: 流体・煙・布の自然な動きを再現\n- **高解像度**: 最大1080p、5秒〜最大120秒の動画生成\n- **マルチモーダル**: テキスト→動画、画像→動画、動画→動画の3モード\n\n## 用途\n\n| 用途 | 内容 |\n|------|------|\n| 広告・マーケティング | 製品プロモーション動画の高速制作 |\n| 映画・VFX | シーンプリビズ・コンセプトビジュアル |\n| ゲーム開発 | アセット生成・シネマティック制作 |\n| SNSコンテンツ | ショート動画の自動生成 |\n| Eコマース | 商品3Dビジュアライゼーション |',
   '2026-04-12'),

  ('luma', 'models',
   'Luma AI モデル一覧 (2026年4月現在)',
   E'## Dream Machine 1.6 (最新)\n\n**Dream Machine** の最新バージョン。テキスト・画像から最大120秒の動画を生成。\n\n| スペック | 値 |\n|---------|----|\n| 最大解像度 | 1920×1080 (1080p) |\n| 最大長さ | 120秒 |\n| フレームレート | 24fps |\n| 生成速度 | 〜2分/5秒クリップ |\n\n## Luma Image\n\n静止画から動画への変換に特化したモデル。\nE コマース向け製品ビジュアライゼーションで高評価。\n\n## Luma Interpolate\n\n2枚の画像間をシームレスにモーフィングする専用モデル。\nキーフレームアニメーション制作に活用。\n\n## Ray2 (最新3Dレンダリングモデル)\n\nLuma の基盤技術である**NeRF (Neural Radiance Field)** を活用した\n3Dシーン再構築モデル。スマートフォン動画から3Dモデルを自動生成。\n\n## 競合比較\n\n| モデル | 強み | 弱み |\n|--------|------|------|\n| Luma Dream Machine | 3D理解・カメラコントロール | 生成速度やや遅め |\n| Runway Gen-3 | 高品質・プロ向け | 高コスト |\n| Kling AI | シネマティック品質 | API制限あり |\n| Pika 2.0 | 高速・低コスト | 品質はLuma以下 |',
   '2026-04-12'),

  ('luma', 'api',
   'Luma AI API ガイド',
   E'## API アクセス\n\n**Luma AI Dream Machine API** は公式に提供されており、\nエンタープライズ向けの本格的な統合が可能。\n\n```\nベースURL: https://api.lumalabs.ai/dream-machine/v1\n認証: Bearer トークン (APIキー)\n```\n\n## 主要エンドポイント\n\n### 動画生成\n```http\nPOST /generations\nAuthorization: Bearer {API_KEY}\nContent-Type: application/json\n\n{\n  "prompt": "A serene mountain lake at golden hour, cinematic camera sweep",\n  "aspect_ratio": "16:9",\n  "loop": false\n}\n```\n\n### ステータス確認\n```http\nGET /generations/{id}\n```\n\n### 画像→動画\n```http\nPOST /generations/image\n{\n  "prompt": "The scene comes to life",\n  "keyframes": {\n    "frame0": {\n      "type": "image",\n      "url": "https://example.com/image.jpg"\n    }\n  }\n}\n```\n\n## 料金\n\n| プラン | 価格 | 生成数 |\n|--------|------|--------|\n| Free | $0 | 30生成/月 |\n| Standard | $29.99/月 | 120生成/月 |\n| Pro | $99.99/月 | 400生成/月 |\n| Premier | $499.99/月 | 2000生成/月 |\n\n## AIMLAPI.com 経由のアクセス\n\n`https://api.aimlapi.com/v1` から Luma モデルにアクセス可能。\n400+ AIモデルを1つのAPIキーで統合管理できる。\n\n## 日本語コミュニティ\n\n- 公式Discord: `Luma AI Community`\n- X: `@LumaLabsAI`\n- 日本語ユーザーグループあり (AI動画制作コミュニティ)',
   '2026-04-12')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
