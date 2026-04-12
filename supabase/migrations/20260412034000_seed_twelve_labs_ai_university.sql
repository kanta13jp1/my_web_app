-- Windows版#59: Twelve Labs (twelve_labs) — AI大学39社目
-- 動画理解・検索・マルチモーダルAI特化 API

INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('twelve_labs', 'overview',
   'Twelve Labs — 動画を「理解する」AI',
   E'## Twelve Labs とは\n\nTwelve Labs は**動画理解・検索・分析**に特化したAI APIプロバイダー。\nサンフランシスコ拠点、2021年創業。\n\n「動画をテキストと同じように検索・分析できる世界を作る」をビジョンとする。\n\n## 特徴\n\n従来のAIが「動画を見る」のに対し、Twelve Labs は**動画の文脈・感情・行動を理解**する。\n\n### 主な機能\n\n| 機能 | 説明 |\n|------|------|\n| **セマンティック検索** | 自然言語で動画内のシーンを検索 |\n| **動画Q&A** | 「この動画で何が起きているか？」に回答 |\n| **シーン分析** | 感情・行動・オブジェクト・テキストを自動検出 |\n| **動画要約** | 長尺動画を短い要約に変換 |\n| **分類・タグ付け** | コンテンツを自動カテゴリ分類 |\n\n## 主な用途\n\n- スポーツ動画のハイライト自動生成\n- 監視カメラの異常検出\n- eラーニングのコンテンツ検索\n- ソーシャルメディアのコンテンツモデレーション\n- 映像アーカイブのデジタル化・検索\n\n## 評価・実績\n\n- シリーズB: $5000万ドル調達 (2024年)\n- Andreessen Horowitz (a16z) が主要投資家\n- NFL・Nasdaq などが採用',
   '2026-04-12'),

  ('twelve_labs', 'models',
   'Twelve Labs モデル一覧 (2026年4月現在)',
   E'## Marengo 2.7 (埋め込みモデル・最新)\n\n動画からマルチモーダル埋め込みを生成するモデル。\nテキスト・画像・音声・映像を統一的なベクトル空間で表現。\n\n| スペック | 値 |\n|---------|----|\n| 対応モダリティ | 映像・音声・テキスト・画像 |\n| 最大動画長 | 2時間 |\n| 検索精度 (mAP) | 0.78 |\n| 処理速度 | 1時間動画を約3分で解析 |\n\n## Pegasus-1 (生成モデル)\n\n動画を入力としてテキストを生成するマルチモーダルLLM。\n動画Q&A・要約・チャプター生成に使用。\n\n| 機能 | 詳細 |\n|------|------|\n| 動画Q&A | 動画の内容に関する質問に回答 |\n| 要約生成 | 最大3000字の要約を生成 |\n| チャプター | 動画をトピック別に自動分割 |\n| ハイライト | 重要シーンを自動抽出 |\n\n## 競合比較\n\n| 指標 | Twelve Labs | Google Video AI | AWS Rekognition |\n|------|-------------|-----------------|------------------|\n| セマンティック検索 | ✓ (最高精度) | △ | ✗ |\n| 動画Q&A | ✓ | ✓ | ✗ |\n| 日本語対応 | ✓ | ✓ | ✓ |\n| 価格 | 中 | 高 | 中 |',
   '2026-04-12'),

  ('twelve_labs', 'api',
   'Twelve Labs API ガイド',
   E'## API アクセス\n\n**Twelve Labs API** は公式に公開中。Python/JavaScript SDK 提供。\n\n```\nベースURL: https://api.twelvelabs.io/v1.3\n認証: x-api-key ヘッダー\n```\n\n## 主要エンドポイント\n\n### インデックス作成\n```http\nPOST /indexes\nx-api-key: {API_KEY}\nContent-Type: application/json\n\n{\n  "engine_id": "marengo2.7",\n  "index_options": ["visual", "conversation", "text_in_video", "logo"],\n  "index_name": "my-video-index"\n}\n```\n\n### 動画アップロード\n```http\nPOST /tasks\n{\n  "index_id": "{index_id}",\n  "video_url": "https://example.com/video.mp4",\n  "language": "ja"\n}\n```\n\n### セマンティック検索\n```http\nPOST /search\n{\n  "index_id": "{index_id}",\n  "query": "サッカーのゴールシーン",\n  "options": ["visual", "conversation"],\n  "threshold": "high"\n}\n```\n\n### 動画Q&A (Pegasus)\n```http\nPOST /generate/gist\n{\n  "video_id": "{video_id}",\n  "types": ["topic", "hashtag", "title"]\n}\n\nPOST /generate/summarize\n{\n  "video_id": "{video_id}",\n  "type": "summary"\n}\n```\n\n## 料金\n\n| プラン | 月額 | 動画時間 | API |\n|--------|------|----------|-----|\n| Free | $0 | 600分/月 | ✓ |\n| Starter | $20 | 2400分/月 | ✓ |\n| Growth | $100 | 14400分/月 | ✓ |\n\n**従量課金**: $0.014/分 (Marengo) / $0.034/分 (Pegasus)',
   '2026-04-12')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
