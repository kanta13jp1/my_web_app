-- Windows版#61: AI大学42社目 — Midjourney
-- 画像生成AIの代名詞。Discordベースの独自UIで1億人超のユーザーを誇る

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'midjourney',
  'overview',
  'Midjourney とは',
  E'## Midjourney とは\n\nMidjourney は 2022年にDavid Holz率いるMidjourney Inc.が公開した**テキストから画像を生成するAIサービス**。\nDiscordボット経由で利用するという独自UXが話題を呼び、画像生成AIの代名詞となった。\n\n### 特徴\n- **芸術性の高さ**: リアル・イラスト・アート全般で業界最高水準の品質\n- **Discord統合**: Discordサーバー上で `/imagine` コマンドで即生成\n- **Web版 (alpha)**: ブラウザからも利用可能 (2024年〜)\n- **ビジョン機能**: V6以降は画像参照・スタイル転送に対応\n- **商用利用**: 有料プランで商用ライセンス付き\n\n### 主なバージョン\n| バージョン | 特徴 |\n| --- | --- |\n| V6 | 最高品質・テキスト描画強化 (2024) |\n| V6.1 | 構図精度・一貫性向上 |\n| Niji 6 | アニメ・マンガ特化モデル |\n| Omni Reference | 特定キャラクターを一貫描画 |\n\n> 公式サイト: https://www.midjourney.com/',
  'https://www.midjourney.com/',
  '2026-04-13',
  1,
  true
),
(
  'midjourney',
  'models',
  'Midjourney モデル一覧',
  E'## Midjourney モデル一覧\n\n### 最新モデル (2025-2026)\n\n| モデル | 特徴 | 用途 |\n| --- | --- | --- |\n| **V7** | 次世代フラッグシップ (2025年) | フォトリアル・アート全般 |\n| **V6.1** | 安定版・商用利用推奨 | プロ制作 |\n| **Niji 6** | アニメ・マンガ特化 | イラスト・キャラクター |\n| **Raw mode** | 写実寄り・AI感を抑制 | フォトグラフィー |\n\n### 主要パラメータ\n```\n/imagine prompt [説明文] --ar 16:9 --v 6.1 --style raw\n--ar: アスペクト比 (1:1 / 16:9 / 9:16 など)\n--v:  モデルバージョン\n--style: raw (写実) / cute / expressive\n--q:  品質 0.25〜2 (デフォルト1)\n--s:  スタイル強度 0〜1000\n--c:  混沌度 0〜100 (多様性)\n```\n\n### Omni Reference (新機能)\nキャラクター・スタイル・物体を参照画像から一貫描画。\n複数シーンで同一キャラクターを維持できる。\n\n### 価格プラン\n| プラン | 月額 | 月間生成数 |\n| --- | --- | --- |\n| Basic | $10 | 200枚 |\n| Standard | $30 | 900枚 |\n| Pro | $60 | 1,800枚 |\n| Mega | $120 | 3,600枚 |',
  'https://docs.midjourney.com/',
  '2026-04-13',
  2,
  true
),
(
  'midjourney',
  'api',
  'Midjourney API 利用方法',
  E'## Midjourney API 利用方法\n\n### 注意: 公式APIは限定提供\nMidjourney は 2024年現在、**公式APIをエンタープライズ向けに限定提供**している。\n一般ユーザーはDiscordボットまたはWeb版を利用する。\n\n### 利用方法\n\n#### 1. Discord経由 (一般ユーザー)\n```\n1. https://discord.gg/midjourney でサーバー参加\n2. #newbies チャンネルで /imagine コマンド実行\n3. または Midjourney Bot をDMで使用\n```\n\n#### 2. Web版 (alpha)\n```\nhttps://www.midjourney.com/ にサインインして\nブラウザ上で直接プロンプト入力・生成\n```\n\n#### 3. サードパーティAPI (非公式)\n```\nGoAPI / replicate.com 経由で\nプログラム的にアクセス可能 (規約要確認)\n```\n\n### 公式APIエンドポイント (エンタープライズ)\n```http\nPOST https://api.midjourney.com/v1/imagine\nAuthorization: Bearer <API_KEY>\nContent-Type: application/json\n{\n  "prompt": "a futuristic city at sunset",\n  "aspect_ratio": "16:9",\n  "model": "v6.1"\n}\n```\n\n### リソース\n- 公式ドキュメント: https://docs.midjourney.com/\n- Discord: https://discord.gg/midjourney\n- Web版: https://www.midjourney.com/',
  'https://docs.midjourney.com/',
  '2026-04-13',
  3,
  true
),
(
  'midjourney',
  'news',
  'Midjourney 最新情報',
  E'## Midjourney 最新情報 (2026-04-13)\n\n### 注目トピック\n- **V7リリース**: 2025年に次世代モデル公開。テキスト生成精度・フォトリアリズムで大幅向上\n- **Omni Reference**: 同一キャラクター・オブジェクトを異なるシーンで一貫描画する機能\n- **Niji 7**: アニメ特化モデルの最新版。日本のマンガスタイルの精度が向上\n- **Web版正式公開**: Discordに依存しないブラウザUI。コレクション管理・共有機能を強化\n- **動画生成 (Video)**: 静止画から動画を生成するMotion機能のテスト中\n- **ユーザー数**: 1,600万人超の有料サブスクライバー (2025年推定)\n\n### 業界への影響\n画像生成AIの普及をリードし、クリエイターエコノミーの再構築に貢献。\nAdobe、Getty Imagesなど従来のストック画像業者と競合しつつ、\n新たなクリエイティブワークフローの標準となっている。\n\n> 公式ブログ: https://www.midjourney.com/updates',
  'https://www.midjourney.com/updates',
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
