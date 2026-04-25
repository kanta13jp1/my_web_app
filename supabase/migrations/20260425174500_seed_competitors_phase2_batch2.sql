-- PS#4 S44: competitors Phase 2 Batch 2 — 36→51社 (2026-04-25)
-- 追加15社: Chat 4 + HR JP 3 + Cloud Office 3 + AI Search 2 + Productivity 3
-- docs/COMPETITOR_EXPANSION_PLAN.md Phase 2 継続

INSERT INTO public.competitors
  (id, display_name, category, website, description, market_cap, user_count,
   founded_year, hq_location, jp_strength, jp_weakness, sort_order)
VALUES

-- ============================================================
-- Chat / SNS (4社) — X/Discord/Slack 対抗追加
-- ============================================================
(
  'whatsapp',
  'WhatsApp (Meta)',
  'chat',
  'https://www.whatsapp.com/',
  'Meta 傘下メッセージング (2B users / E2E暗号化)',
  NULL, 2000000000, 2009, 'Menlo Park, CA',
  '国際コミュニティ向け・ビジネス API が充実',
  '日本国内普及率は LINE に大きく劣る',
  77
),
(
  'signal',
  'Signal',
  'chat',
  'https://signal.org/',
  'プライバシー最優先メッセージング (非営利 / OSS / E2E全通信)',
  NULL, 40000000, 2014, 'Mountain View, CA',
  'プライバシー意識の高いユーザーから絶大な信頼',
  '機能の少なさとブランド認知がビジネス利用を阻む',
  78
),
(
  'threads',
  'Threads (Meta)',
  'chat',
  'https://www.threads.net/',
  'Instagram 連携テキスト SNS — X 対抗 (350M MAU)',
  NULL, 350000000, 2023, 'Menlo Park, CA',
  'Instagram ユーザー基盤で急成長 / 日本でも著名人利用が増加',
  'アルゴリズム依存でコミュニティ形成が X に劣る',
  79
),
(
  'bluesky',
  'Bluesky',
  'chat',
  'https://bsky.app/',
  '分散型 SNS (AT Protocol / 元 Twitter CTO Jack Dorsey / 36M users)',
  NULL, 36000000, 2019, 'Seattle, WA',
  'プライバシー × 検閲耐性 / 日本の X 移住組が流入',
  'ビジネス機能が未整備・広告収益モデル不在',
  80
),

-- ============================================================
-- HR / Attendance JP (3社) — Jobcan 対抗
-- ============================================================
(
  'smarthr',
  'SmartHR',
  'hr-attendance',
  'https://smarthr.jp/',
  'クラウド人事労務 SaaS — 日本 No.1 (東証グロース / 導入 70,000社+)',
  1500000000, NULL, 2013, 'Tokyo, Japan',
  '雇用契約〜給与計算〜人事評価まで一気通貫 / 大手企業導入実績豊富',
  '個人ユーザー向け機能はなし (B2B 専業)',
  85
),
(
  'kingoftime',
  'KING OF TIME (Humax Systems)',
  'hr-attendance',
  'https://www.kingofzeit.jp/',
  '国内シェア No.1 クラウド勤怠管理 (20,000社 / 220万ID)',
  NULL, NULL, 2004, 'Tokyo, Japan',
  '顔認証打刻・IC カード・スマホ打刻など多様な打刻手段',
  '単体機能特化で総合人事機能は SmartHR に劣る',
  86
),
(
  'freee-hr',
  'freee 人事労務',
  'hr-attendance',
  'https://www.freee.co.jp/hr/',
  'freee の人事労務モジュール — 会計との一体運用',
  NULL, NULL, 2015, 'Tokyo, Japan',
  'freee 会計と同一プラットフォームで中小企業の事務コストを削減',
  '大企業向け複雑なカスタマイズは SmartHR/Jobcan に劣る',
  87
),

-- ============================================================
-- Cloud Office / SaaS (3社) — Google/Microsoft 対抗
-- ============================================================
(
  'zoho',
  'Zoho',
  'cloud-office',
  'https://www.zoho.com/',
  'インド発オールインワン SaaS (45+ アプリ / 100M users / 非上場)',
  NULL, 100000000, 1996, 'Chennai, India',
  '低価格で CRM・会計・HR・プロジェクト管理を一体提供 / 日本語対応',
  '個々の機能深度では専業 SaaS に劣る',
  165
),
(
  'dropbox',
  'Dropbox',
  'cloud-office',
  'https://www.dropbox.com/',
  'クラウドファイルストレージ (700M users / $2.4B ARR / Dash AI搭載)',
  8000000000, 700000000, 2007, 'San Francisco, CA',
  '馴染みのあるフォルダ UI / Dropbox Dash AI 検索でナレッジ活用',
  'OneDrive/Google Drive に価格・容量で競合',
  166
),
(
  'atlassian',
  'Atlassian (Jira/Confluence)',
  'cloud-office',
  'https://www.atlassian.com/',
  'Jira + Confluence + Trello — エンタープライズ開発 PM ツール ($42B)',
  42000000000, 300000, 2002, 'Sydney, Australia',
  '日本の開発現場での Jira 普及率は高い / Atlassian Intelligence 搭載',
  '個人・スタートアップには高機能すぎ価格も高い',
  167
),

-- ============================================================
-- AI Search / Assistant (2社) — Google/ChatGPT 対抗
-- ============================================================
(
  'perplexity',
  'Perplexity AI',
  'ai-coding',
  'https://www.perplexity.ai/',
  'AI 検索エンジン — リアルタイム Web 参照 + 引用付き回答 ($9B)',
  9000000000, 100000000, 2022, 'San Francisco, CA',
  '引用付き最新情報が信頼性高い / 日本語検索品質が向上',
  '生成 AI との協調作業より「検索置換」特化で用途が限定',
  35
),
(
  'you-com',
  'You.com',
  'ai-coding',
  'https://you.com/',
  'AI 検索 + コーディングアシスタント (YouCode / $25M)',
  NULL, NULL, 2020, 'Palo Alto, CA',
  'プライバシー重視の AI 検索 + エージェント機能',
  '知名度・日本語対応で Perplexity に大きく劣る',
  36
),

-- ============================================================
-- Productivity (3社) — Notion/Obsidian 対抗
-- ============================================================
(
  'logseq',
  'Logseq',
  'productivity',
  'https://logseq.com/',
  'ローカルファースト アウトライナー PKM (OSS / Clojure / 30k GitHub stars)',
  NULL, 500000, 2020, 'Remote',
  '完全 OSS・ローカル保存でプライバシー最強クラス',
  'UI の学習コストが高く日本語入力に課題あり',
  24
),
(
  'bear-app',
  'Bear',
  'productivity',
  'https://bear.app/',
  'Apple デバイス向けシンプル Markdown ノートアプリ (Shiny Frog)',
  NULL, 3000000, 2016, 'Milan, Italy',
  'iPhone/Mac での日本語入力が最もスムーズなノートアプリの一つ',
  'Windows/Android 非対応 / チーム共有機能なし',
  25
),
(
  'linear',
  'Linear',
  'productivity',
  'https://linear.app/',
  'モダン開発チーム向け Issue トラッカー ($400M / Jira 対抗)',
  400000000, NULL, 2019, 'San Francisco, CA',
  'UX 品質が高く開発チームに熱狂的なファンが多い',
  '個人利用ユースケースよりチーム開発専用',
  26
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
  '競合 36→51 社化 Phase 2 Batch 2 (PS#4 S44)',
  'Chat 4社(whatsapp/signal/threads/bluesky) + HR JP 3社(smarthr/kingoftime/freee-hr) + ' ||
  'Cloud Office 3社(zoho/dropbox/atlassian) + AI Search 2社(perplexity/you.com) + ' ||
  'Productivity 3社(logseq/bear/linear) = 計15社追加 → 累計51社',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
