-- Windows版#64: AI大学49社目 — Samsung Galaxy AI
-- Samsungが開発するオンデバイスAI。Galaxy S24以降に搭載

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'samsung',
  'overview',
  'Samsung Galaxy AI とは',
  E'## Samsung Galaxy AI とは\n\n**Galaxy AI** は Samsung が Galaxy S24 シリーズ (2024年1月) から搭載した**オンデバイスAI機能群**。\nGoogleとの提携によりGemini Nanoをオンデバイスで動作させ、通訳・要約・画像編集等を実現する。\n\n### 主要機能\n- **Live Translate (通話翻訳)**: 電話中にリアルタイムで音声翻訳 (13言語対応)\n- **Chat Assist**: メッセージの文体変換・翻訳・要約\n- **Note Assist**: 手書きメモの自動整形・要約・翻訳\n- **Browsing Assist**: Webページの要約・翻訳\n- **Circle to Search**: 画面上の任意のオブジェクトを丸で囲んで検索\n- **Generative Edit**: AI写真編集 (物体除去・背景拡張・角度補正)\n- **Sketch to Image**: 落書きから高品質画像を生成\n- **Transcript Assist**: 録音の文字起こし・要約\n\n### 技術基盤\n- **Gemini Nano**: Googleのオンデバイスモデル (Samsung独占搭載)\n- **Samsung Gauss**: Samsung Research開発の独自モデル\n- **Snapdragon NPU**: Qualcommの専用AIチップで高速推論\n- **One UI 6.1+**: Galaxy AIのソフトウェアフレームワーク\n\n> 公式: https://www.samsung.com/galaxy-ai/',
  'https://www.samsung.com/galaxy-ai/',
  '2026-04-13',
  1,
  true
),
(
  'samsung',
  'models',
  'Samsung AI モデル・技術一覧',
  E'## Samsung AI モデル・技術\n\n### オンデバイスモデル\n| モデル | 開発元 | 用途 |\n| --- | --- | --- |\n| **Gemini Nano** | Google (Samsung独占) | テキスト要約・翻訳・チャットアシスト |\n| **Samsung Gauss** | Samsung Research | テキスト生成・コード生成・画像生成 |\n| **Samsung Gauss 2** | Samsung Research | マルチモーダル対応・性能向上 |\n\n### クラウドモデル (サーバーサイド)\n| モデル | 用途 |\n| --- | --- |\n| **Gemini Pro** | 高度な推論・翻訳 |\n| **Samsung自社サーバーモデル** | Live Translate・Generative Edit |\n\n### Gauss モデルファミリー\n```\nSamsung Gauss Language: テキスト生成・要約・翻訳\nSamsung Gauss Code: コード生成・補完 (社内開発支援)\nSamsung Gauss Image: テキストから画像生成・編集\n```\n\n### 対応デバイス\n| デバイス | チップ | Galaxy AI |\n| --- | --- | --- |\n| Galaxy S24 Ultra | Snapdragon 8 Gen 3 | ✅ フル対応 |\n| Galaxy S24 / S24+ | Exynos 2400 | ✅ フル対応 |\n| Galaxy Z Fold 6 / Flip 6 | Snapdragon 8 Gen 3 | ✅ フル対応 |\n| Galaxy S23 シリーズ | OTA更新 | ✅ 一部機能 |\n| Galaxy Tab S9 | OTA更新 | ✅ 一部機能 |\n\n### NPU (Neural Processing Unit)\n```\nSnapdragon 8 Gen 3 NPU: 45 TOPS\n→ Gemini Nanoをデバイス上で約5ms/tokenで推論\n→ バッテリー消費を最小化しながら常時AI処理\n```',
  'https://semiconductor.samsung.com/us/processor/',
  '2026-04-13',
  2,
  true
),
(
  'samsung',
  'api',
  'Samsung Galaxy AI 開発者ガイド',
  E'## Samsung Galaxy AI 開発者ガイド\n\n### 注意: 公開APIは限定的\nGalaxy AI はエンドユーザー向け機能であり、汎用REST APIは提供されていない。\n開発者はSamsung独自のSDK・フレームワーク経由でAI機能にアクセスする。\n\n### Samsung AI SDK\n```kotlin\n// On-Device AI (Galaxy AI SDK)\nimport com.samsung.android.sdk.ai\n\nval aiEngine = SamsungAI.getEngine(context)\nval result = aiEngine.summarize(\n    text = "長文テキスト...",\n    language = "ja"\n)\nprintln(result.summary)\n```\n\n### One UI Integration\n```xml\n<!-- AndroidManifest.xml -->\n<uses-feature android:name=\"com.samsung.android.galaxyai\" />\n```\n\n### Samsung AI Platform (Tizen)\n```javascript\n// Tizen AIデバイス向け\nvar ai = tizen.ml.pipeline;\nai.construct("model_path", function(pipeline) {\n    pipeline.invoke(inputData, function(result) {\n        console.log("AI result:", result);\n    });\n});\n```\n\n### Bixby Developer Studio\n```\nBixby Capsules:\n- 音声コマンドでアプリ機能を呼び出し\n- NLU (自然言語理解) カスタマイズ\n- Samsung デバイスエコシステム統合\nhttps://bixbydevelopers.com/\n```\n\n### リソース\n- Samsung Developers: https://developer.samsung.com/\n- Galaxy AI: https://www.samsung.com/galaxy-ai/\n- Samsung Research: https://research.samsung.com/\n- Bixby Developer: https://bixbydevelopers.com/',
  'https://developer.samsung.com/',
  '2026-04-13',
  3,
  true
),
(
  'samsung',
  'news',
  'Samsung Galaxy AI 最新情報',
  E'## Samsung Galaxy AI 最新情報 (2026-04-13)\n\n### 注目トピック\n- **Galaxy S24で世界初のオンデバイスAI**: 2024年1月発売。電話翻訳・写真編集等のAI機能が話題に\n- **Galaxy AI 2億台展開**: 2024年末までにGalaxy AIを2億台以上のデバイスに展開\n- **Gauss 2**: 2025年発表。マルチモーダル対応・オンデバイス性能が大幅向上\n- **Circle to Search**: Googleと共同開発。画面のどこでも丸で囲んで検索\n- **Generative Edit 進化**: AI写真編集が動画にも拡張 (Galaxy S25+)\n- **Galaxy Ring + AI**: ウェアラブルデバイスとAIの統合 (健康モニタリング)\n- **Knox AI**: エンタープライズ向けオンデバイスAIセキュリティ\n\n### 業界位置づけ\nApple Intelligence と並ぶ「オンデバイスAI」の二大巨頭。\nGoogleとの深い提携 (Gemini Nano独占搭載) でAndroid AIを牽引。\n年間2億台以上のスマートフォン出荷でAIの普及を加速。\n\n### 競合比較\n| 項目 | Galaxy AI | Apple Intelligence | Google Pixel AI |\n| --- | --- | --- | --- |\n| オンデバイスモデル | Gemini Nano + Gauss | AFM (Apple独自) | Gemini Nano |\n| 翻訳機能 | Live Translate (13言語) | Translation (全システム) | Pixel Interpreter |\n| 画像編集 | Generative Edit | Clean Up | Magic Eraser |\n| 対応機種 | S24以降 + Z6以降 | iPhone 15 Pro以降 | Pixel 8以降 |\n\n> 公式: https://www.samsung.com/galaxy-ai/',
  'https://www.samsung.com/galaxy-ai/',
  '2026-04-13',
  1,
  true
)
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
