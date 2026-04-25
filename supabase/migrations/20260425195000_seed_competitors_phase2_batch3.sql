-- PS#4 S45: competitors Phase 2 Batch 3 — 51→66社 (2026-04-25)
-- 追加15社: AI/LLM 5 + JP Productivity 3 + PM/Collaboration 4 + Creator/Dev 3
-- 衝突回避: 195000 (Batch 1=142000 / Batch 2=175000 からの十分な間隔)

INSERT INTO public.competitors
  (id, display_name, category, website, description, market_cap, user_count,
   founded_year, hq_location, jp_strength, jp_weakness, sort_order)
VALUES

-- ============================================================
-- AI / LLM Providers (5社) — PS#4 競合監視対象
-- ============================================================
(
  'cohere',
  'Cohere',
  'ai-coding',
  'https://cohere.com/',
  'エンタープライズ特化 LLM API (Command R+ / $2.2B / RAG 最適化)',
  2200000000, NULL, 2019, 'Toronto, Canada',
  'エンタープライズ RAG・セキュリティに強い。日本語対応あり',
  'OpenAI/Anthropic と比べブランド認知で劣る',
  37
),
(
  'mistral',
  'Mistral AI',
  'ai-coding',
  'https://mistral.ai/',
  'フランス発 OSS LLM (Mistral Large 2 / $1.03B / Apache 2.0)',
  1030000000, NULL, 2023, 'Paris, France',
  'OSS 公開で自社ホスト可 / EU GDPR 準拠が強み',
  '日本語能力で GPT-4o / Claude に劣る',
  38
),
(
  'together-ai',
  'Together AI',
  'ai-coding',
  'https://www.together.ai/',
  'OSS LLM ホスティング & ファインチューニング基盤 ($228M / $1B+ 評価)',
  1000000000, NULL, 2022, 'San Francisco, CA',
  'Llama/Mistral 等 OSS モデルを低コストで API 提供',
  '独自モデルがなくコモディティ化リスク',
  39
),
(
  'hugging-face',
  'Hugging Face',
  'ai-coding',
  'https://huggingface.co/',
  'AI モデルハブ & OSS コミュニティ (1M+ モデル / $4.5B / "AI の GitHub")',
  4500000000, NULL, 2016, 'New York, NY',
  'AI大学教材の参照先として最重要。Spaces でデモ公開も容易',
  '商用利用ライセンスが複雑な場合あり',
  40
),
(
  'replicate',
  'Replicate',
  'ai-coding',
  'https://replicate.com/',
  'OSS AI モデルを API で即利用 (Flux / Whisper 等 / $40M)',
  NULL, NULL, 2019, 'San Francisco, CA',
  '画像・動画・音声 AI を 1 API で利用できる手軽さ',
  '推論コスト最適化で Fireworks/Together に劣ることも',
  41
),

-- ============================================================
-- JP Productivity / Work (3社) — 国内特化競合
-- ============================================================
(
  'cybozu-kintone',
  'kintone (Cybozu)',
  'productivity',
  'https://kintone.cybozu.co.jp/',
  'サイボウズ発ローコード業務アプリ (JP No.1 / 30,000社 / 海外展開中)',
  1800000000, NULL, 2011, 'Tokyo, Japan',
  '日本企業の業務フロー自動化で圧倒的シェア。中小〜大企業まで幅広い',
  '海外展開は初期段階 / UI の洗練度が Notion に劣る',
  27
),
(
  'sansan',
  'Sansan',
  'productivity',
  'https://jp.sansan.com/',
  'B2B 名刺管理→営業 DX SaaS (東証プライム / 9,000社 / Eight)',
  1200000000, NULL, 2007, 'Tokyo, Japan',
  '日本企業の名刺文化を完全デジタル化 / Eight 個人版で個人市場も',
  '名刺特化で汎用 PKM には対応不可',
  28
),
(
  'money-tree',
  'マネーツリー (Moneytree)',
  'fintech',
  'https://moneytree.jp/',
  '日本向け個人資産管理アプリ (MoneyForward 対抗 / Goldman Sachs 出資)',
  NULL, NULL, 2012, 'Tokyo, Japan',
  'プライバシー重視・金融機関 API 連携数が多い',
  'UI が MoneyForward より地味で認知度が低い',
  57
),

-- ============================================================
-- Project Management / Collaboration (4社)
-- ============================================================
(
  'clickup',
  'ClickUp',
  'productivity',
  'https://clickup.com/',
  'オールインワン PM ツール — タスク/Docs/Goals/Chat ($4B / 800,000チーム)',
  4000000000, NULL, 2017, 'San Diego, CA',
  'Notion + Jira + Slack を 1 ツールで代替できると主張 / 無料プランが充実',
  '機能過多で学習コストが高い / 日本語サポートは基本的',
  29
),
(
  'airtable',
  'Airtable',
  'productivity',
  'https://www.airtable.com/',
  'スプレッドシート × DB ハイブリッド ($11B / 450,000組織)',
  11000000000, NULL, 2012, 'San Francisco, CA',
  'ノーコードで複雑なデータ管理が可能 / API 自動化が強力',
  '大規模データでは PostgreSQL 等に劣る / 個人利用はコスト高',
  30
),
(
  'coda',
  'Coda',
  'productivity',
  'https://coda.io/',
  'Doc + DB + Automation 一体型 ($700M / "All-in-one doc")',
  700000000, NULL, 2014, 'Mountain View, CA',
  'ドキュメントとデータベースの境界をなくすコンセプトが先進的',
  'Notion に比べ知名度・日本語対応で劣る',
  31
),
(
  'miro',
  'Miro',
  'productivity',
  'https://miro.com/',
  'ビジュアルコラボレーション ホワイトボード ($17.5B / 70M users)',
  17500000000, 70000000, 2011, 'San Francisco, CA',
  'リモートチームのブレスト・設計でデファクト / 日本語対応良好',
  '個人 PKM ではなくチームコラボ特化',
  32
),

-- ============================================================
-- Creator / Developer Tools (3社)
-- ============================================================
(
  'vercel',
  'Vercel',
  'cloud-office',
  'https://vercel.com/',
  'Next.js / フロントエンド クラウド ($3.25B / 300M+ deploys/月)',
  3250000000, NULL, 2015, 'San Francisco, CA',
  'Next.js × Edge Functions で日本の開発者に人気 / v0 との連携',
  '開発者向け専門ツールで非エンジニアには無縁',
  168
),
(
  'zoom',
  'Zoom',
  'chat',
  'https://zoom.us/',
  'ビデオ会議 → AI コミュニケーション Hub ($20B / 300M MAU)',
  20000000000, 300000000, 2011, 'San Jose, CA',
  'コロナ禍で日本市場にも完全浸透 / AI Companion 搭載で Slack 競合',
  'Slack/Teams との差別化が曖昧になりつつある',
  81
),
(
  'figma',
  'Figma',
  'ai-coding',
  'https://www.figma.com/',
  'ブラウザベース UI デザインツール ($20B / Adobe 買収不成立 → 独立継続)',
  20000000000, NULL, 2012, 'San Francisco, CA',
  'デザイン〜開発者ハンドオフのデファクト / 日本のデザイナー利用率最高',
  'コードエディタではないので実装は別途必要',
  42
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

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競合 51→66 社化 Phase 2 Batch 3 (PS#4 S45)',
  'AI/LLM 5社(cohere/mistral/together-ai/hugging-face/replicate) + ' ||
  'JP Productivity 3社(kintone/sansan/money-tree) + ' ||
  'PM/Collaboration 4社(clickup/airtable/coda/miro) + ' ||
  'Creator/Dev 3社(vercel/zoom/figma) = 計15社追加 → 累計66社',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
