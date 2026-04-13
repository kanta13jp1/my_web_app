-- Windows版#62: AI大学44社目 — Adobe Firefly
-- Adobeが開発するクリエイター向け生成AI。商業利用安全な学習データで差別化

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'adobe_firefly',
  'overview',
  'Adobe Firefly とは',
  E'## Adobe Firefly とは\n\nAdobe Firefly は**Adobe**が開発するクリエイター向け生成AIプラットフォーム。\n2023年3月にベータ公開、同年9月に正式リリース。\nPhotoshop・Illustrator・Premiere Pro等のAdobe製品に深く統合されている。\n\n### 最大の特徴: 商業利用安全なAI\n\n他社の画像生成AIと異なり、**Adobeが著作権をクリアしたデータのみで学習**。\nAdobe Stockのライセンス取得コンテンツ、パブリックドメイン、著作権切れ素材を使用。\nプロのクリエイターや企業が安心して商業プロジェクトに使える点が最大の差別化要因。\n\n### 主要サービス\n- **Firefly Image 3**: テキストから高品質画像を生成\n- **Generative Fill**: Photoshopの選択範囲を自動補完・拡張\n- **Generative Expand**: 画像の余白をAIで自然に拡張\n- **Text Effects**: テキストに素材感・質感を適用\n- **Generative Recolor**: ベクターイラストの配色を一括変換 (Illustrator)\n- **Firefly Video**: 動画生成・編集AI (2024年〜)\n\n### 強み\n- Photoshop/Illustratorと直接統合 — ワークフロー断絶なし\n- 商業利用OK (Adobe Content Credentials 付き)\n- Adobe Firefly API でSaaS製品に組み込み可能\n- Creative Cloud契約者は追加料金なしで一定数使用可能\n\n> 公式サイト: https://firefly.adobe.com/',
  'https://firefly.adobe.com/',
  '2026-04-13',
  1,
  true
),
(
  'adobe_firefly',
  'models',
  'Adobe Firefly モデル一覧',
  E'## Adobe Firefly モデル一覧\n\n### 画像生成モデル\n\n| モデル | 特徴 | 対応機能 |\n| --- | --- | --- |\n| **Firefly Image 3** | 最新フラッグシップ。フォトリアル・詳細品質向上 | テキスト→画像、Generative Fill |\n| **Firefly Image 2** | 前世代モデル (互換維持) | — |\n| **Firefly Vector** | テキストから SVG ベクター生成 | Illustrator連携 |\n| **Firefly Design** | テンプレート自動生成 | Adobe Express |\n\n### 動画・音声モデル\n\n| モデル | 特徴 |\n| --- | --- |\n| **Firefly Video** | テキスト/画像から動画生成 (2024年リリース) |\n| **Project Music GenAI Control** | 音楽生成・編集 (ベータ) |\n\n### 主要パラメータ (Firefly Image 3)\n```\nプロンプト: テキスト説明 (英語推奨)\nアスペクト比: 正方形 / 横長 / 縦長 / ワイドスクリーン\nコンテンツタイプ: 写真 / グラフィック / アート\nスタイル: フォトリアル / ベクター / ピクセルアート等\nカラーパレット: カスタム指定可\n照明: ゴールデンアワー / スタジオ / 自然光等\n```\n\n### Adobe Express / Photoshop 統合機能\n- **Generative Fill**: ブラシで塗った領域をプロンプトで置換\n- **Generative Expand**: 画像の外側を自動的に補完\n- **Remove Background**: ワンクリック背景除去 (Firefly駆動)\n- **Generative Recolor**: Illustratorでベクターの配色自動変換\n\n### クレジット消費 (Creative Cloud)\n| 操作 | 消費クレジット |\n| --- | --- |\n| 画像生成 (標準) | 1クレジット |\n| 画像生成 (高品質) | 2クレジット |\n| 動画生成 | 10〜20クレジット |\n| Creative Cloud全プラン | 月25〜1,000クレジット付き |',
  'https://helpx.adobe.com/firefly/using/firefly-image-3.html',
  '2026-04-13',
  2,
  true
),
(
  'adobe_firefly',
  'api',
  'Adobe Firefly API 利用方法',
  E'## Adobe Firefly API 利用方法\n\n### 概要\nAdobe Firefly Services API はエンタープライズ・開発者向けのREST API。\nコンテンツ制作の自動化・SaaS製品への生成AI組み込みに利用できる。\n\n### 認証 (OAuth 2.0)\n```bash\n# Step 1: Adobe Developer Console でプロジェクト作成\n# https://developer.adobe.com/console\n\n# Step 2: アクセストークン取得\ncurl -X POST https://ims-na1.adobelogin.com/ims/token/v3 \\\n  -d "grant_type=client_credentials" \\\n  -d "client_id=YOUR_CLIENT_ID" \\\n  -d "client_secret=YOUR_CLIENT_SECRET" \\\n  -d "scope=openid,AdobeID,firefly_api"\n```\n\n### 画像生成 API\n```bash\n# テキストから画像生成\ncurl -X POST https://firefly-api.adobe.io/v3/images/generate \\\n  -H "Authorization: Bearer $ACCESS_TOKEN" \\\n  -H "x-api-key: $CLIENT_ID" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "numVariations": 1,\n    "prompt": "A serene Japanese garden with cherry blossoms",\n    "size": { "width": 1024, "height": 1024 },\n    "contentClass": "photo"\n  }''\n```\n\n### Generative Fill API\n```bash\ncurl -X POST https://firefly-api.adobe.io/v3/images/fill \\\n  -H "Authorization: Bearer $ACCESS_TOKEN" \\\n  -H "x-api-key: $CLIENT_ID" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "prompt": "modern kitchen with marble countertops",\n    "image": { "source": { "url": "https://example.com/room.jpg" } },\n    "mask": { "source": { "url": "https://example.com/mask.png" } }\n  }''\n```\n\n### 料金 (API プラン)\n| プラン | 月額 | 画像生成数 |\n| --- | --- | --- |\n| Firefly API Free Tier | 無料 | 100リクエスト/月 |\n| Standard | $49.99 | 2,000リクエスト/月 |\n| Enterprise | 要見積り | カスタム |\n\n### リソース\n- 開発者ポータル: https://developer.adobe.com/firefly-api/\n- APIリファレンス: https://developer.adobe.com/firefly-api/docs/\n- Adobe Developer Console: https://developer.adobe.com/console',
  'https://developer.adobe.com/firefly-api/',
  '2026-04-13',
  3,
  true
),
(
  'adobe_firefly',
  'news',
  'Adobe Firefly 最新情報',
  E'## Adobe Firefly 最新情報 (2026-04-13)\n\n### 注目トピック\n- **Firefly Image 3**: 2024年にリリース。写実性・テキスト描画・スタイル一貫性で大幅向上\n- **Firefly Video**: テキスト/画像から動画生成機能が正式リリース。Premiere Proに統合\n- **Content Credentials**: AI生成コンテンツの透明性を証明するメタデータ標準 (CAI準拠)\n- **Firefly Custom Models**: 企業独自のブランドスタイルでファインチューニング可能なモデル\n- **Adobe GenStudio**: Firefly APIを使ったエンタープライズコンテンツ制作プラットフォーム\n- **Project Turntable**: 2D画像から3Dモデルを生成する新機能 (実験的)\n\n### 業界位置づけ\nMidjourney/DALL-E/Stable Diffusionと比較して「商業利用の安全性」で差別化。\n広告代理店・出版社・ECサイトなど著作権リスクを避けたいプロユースに支持される。\nAdobe Creative Cloudの1億人超のユーザーベースがベースとなっている。\n\n> 公式: https://firefly.adobe.com/ | API: https://developer.adobe.com/firefly-api/',
  'https://firefly.adobe.com/',
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
