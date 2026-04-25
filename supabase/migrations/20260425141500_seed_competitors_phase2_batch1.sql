-- PS#4 S43: competitors Phase 2 Batch 1 — 21→36社 (2026-04-25)
-- 追加15社: AI Coding 7 + Productivity 4 + Fintech JP 2 + Chat 2
-- docs/COMPETITOR_EXPANSION_PLAN.md Phase 2 計画に基づく

INSERT INTO public.competitors
  (id, display_name, category, website, description, market_cap, user_count,
   founded_year, hq_location, jp_strength, jp_weakness, sort_order)
VALUES

-- ============================================================
-- AI Coding (7社) — PS#4 S38-S42 モニタリング済み
-- ============================================================
(
  'cursor',
  'Cursor',
  'ai-coding',
  'https://cursor.com/',
  'AI-native コードエディタ (Anysphere / $9.9B / VS Code fork)',
  9900000000, NULL, 2022, 'San Francisco, CA',
  'VS Code 互換で乗り換え容易・日本語UI対応進行中',
  'エンタープライズ向け管理機能が限定的',
  25
),
(
  'windsurf',
  'Windsurf (Codeium)',
  'ai-coding',
  'https://windsurf.com/',
  'AI IDE by Codeium — Cascade エージェント・コンテキスト認識',
  1250000000, NULL, 2021, 'Mountain View, CA',
  'Cursor 対抗で無料プランが充実',
  '日本語サポートが Cursor より薄い',
  26
),
(
  'replit',
  'Replit',
  'ai-coding',
  'https://replit.com/',
  'ブラウザ完結型 AI コーディング環境・教育〜プロ向け',
  1160000000, 35000000, 2016, 'San Francisco, CA',
  '教育市場で強い・ゼロ環境構築が魅力',
  'ローカル IDE と比べてパフォーマンスで劣る',
  27
),
(
  'lovable',
  'Lovable',
  'ai-coding',
  'https://lovable.dev/',
  'フルスタック AI アプリビルダー (React + Supabase) — 月$10M ARR突破',
  NULL, NULL, 2023, 'Stockholm, Sweden',
  'デザイン品質が高くノーコード寄りのユーザーに人気',
  'カスタマイズ深度が Bolt.new に劣る場面あり',
  28
),
(
  'bolt-new',
  'Bolt.new (StackBlitz)',
  'ai-coding',
  'https://bolt.new/',
  'ブラウザ内フルスタック AI アプリビルダー (WebContainer)',
  NULL, NULL, 2023, 'San Francisco, CA',
  'WebContainer でバックエンドもブラウザで完結',
  '大規模プロジェクトは Cursor より適性が低い',
  29
),
(
  'v0',
  'v0 (Vercel)',
  'ai-coding',
  'https://v0.dev/',
  'Vercel の AI UI コンポーネントジェネレーター (shadcn/ui 特化)',
  NULL, NULL, 2023, 'San Francisco, CA',
  'Next.js + Vercel スタックで即デプロイが可能',
  '独立 IDE でなく Vercel エコシステム前提',
  30
),
(
  'devin',
  'Devin (Cognition AI)',
  'ai-coding',
  'https://devin.ai/',
  '世界初の完全自律 AI ソフトウェアエンジニア ($2B)',
  2000000000, NULL, 2023, 'San Francisco, CA',
  '完全自律タスク実行で上流工程を代替',
  '$500/月〜と高価・日本語対応は初期段階',
  31
),

-- ============================================================
-- Productivity (4社) — Notion 対抗軸
-- ============================================================
(
  'obsidian',
  'Obsidian',
  'productivity',
  'https://obsidian.md/',
  'ローカルファースト PKM・Markdown + グラフビュー',
  NULL, 1500000, 2020, 'Somewhere, CA',
  'ローカル保存でプライバシー重視のユーザーに強い',
  'チーム共有機能が Notion より弱い',
  20
),
(
  'mem-ai',
  'Mem.ai',
  'productivity',
  'https://mem.ai/',
  'AI パーソナル知識管理 — 自動整理・GPT-4 ベース検索 ($23.5M)',
  NULL, NULL, 2020, 'San Francisco, CA',
  '自動タグ付け・AI 検索で情報整理コストが低い',
  '日本語フル対応は未達',
  21
),
(
  'anytype',
  'Anytype',
  'productivity',
  'https://anytype.io/',
  'ローカルファースト Notion 代替・E2E 暗号化・OSS',
  NULL, 500000, 2019, 'Berlin, Germany',
  'プライバシー × データ所有権で差別化',
  'UI 成熟度が Notion より低い',
  22
),
(
  'craft-docs',
  'Craft',
  'productivity',
  'https://www.craft.do/',
  'Apple デザイン美麗ドキュメントアプリ (Swift native)',
  NULL, 2000000, 2020, 'Budapest, Hungary',
  'macOS/iOS で最高の編集体験・日本語入力も安定',
  'Windows/Web 版は機能限定・チーム機能は Notion に劣る',
  23
),

-- ============================================================
-- Fintech JP (2社) — MoneyForward 対抗
-- ============================================================
(
  'freee',
  'freee',
  'fintech',
  'https://www.freee.co.jp/',
  '中小企業向けクラウド会計・勤怠 SaaS (東証プライム / 時価総額約1,500億円)',
  1500000000, 3500000, 2012, 'Tokyo, Japan',
  '国内中小企業 No.1 シェア・会計士連携が密',
  '個人向け機能は MoneyForward に比べ簡素',
  55
),
(
  'yayoi',
  '弥生',
  'fintech',
  'https://www.yayoi-kk.co.jp/',
  '国内会計ソフト老舗 (ORIX グループ / 200万事業者)',
  NULL, 2000000, 1978, 'Tokyo, Japan',
  '税理士・会計士との連携率が業界最高・老舗ブランド信頼',
  'クラウド移行が遅く UI が古い',
  56
),

-- ============================================================
-- Chat / SNS (2社) — Slack/Discord 対抗
-- ============================================================
(
  'telegram',
  'Telegram',
  'chat',
  'https://telegram.org/',
  'プライバシー重視メッセージング (950M users / BOT API)',
  NULL, 950000000, 2013, 'Dubai, UAE',
  'BOT API が強力・暗号化 × 大規模グループで人気',
  'ビジネス向け管理機能が Slack に大きく劣る',
  75
),
(
  'teams',
  'Microsoft Teams',
  'chat',
  'https://www.microsoft.com/microsoft-teams/',
  'Microsoft 365 統合ビジネスチャット (320M MAU / Copilot 搭載)',
  NULL, 320000000, 2017, 'Redmond, WA',
  '日本企業の Microsoft 365 導入率が高く Teams もセットで普及',
  '無料プランは Slack/Discord に劣る・重い',
  76
)

ON CONFLICT (id) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  category      = EXCLUDED.category,
  website       = EXCLUDED.website,
  description   = EXCLUDED.description,
  market_cap    = COALESCE(EXCLUDED.market_cap, competitors.market_cap),
  user_count    = COALESCE(EXCLUDED.user_count, competitors.user_count),
  founded_year  = COALESCE(EXCLUDED.founded_year, competitors.founded_year),
  hq_location   = COALESCE(EXCLUDED.hq_location, competitors.hq_location),
  jp_strength   = COALESCE(EXCLUDED.jp_strength, competitors.jp_strength),
  jp_weakness   = COALESCE(EXCLUDED.jp_weakness, competitors.jp_weakness),
  sort_order    = EXCLUDED.sort_order,
  updated_at    = now();

-- development_achievements 記録
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競合 21→36 社化 Phase 2 Batch 1 (PS#4 S43)',
  'AI Coding 7社(cursor/windsurf/replit/lovable/bolt-new/v0/devin) + ' ||
  'Productivity 4社(obsidian/mem.ai/anytype/craft) + ' ||
  'Fintech JP 2社(freee/弥生) + Chat 2社(telegram/Teams) = 計15社追加',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
