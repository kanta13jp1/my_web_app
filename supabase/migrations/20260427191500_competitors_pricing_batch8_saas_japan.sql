-- PS#4 S74: competitors pricing + japan_presence Batch 8 — SaaS/コラボ/日本モビリティ等 15社
-- 2026-04-27 (累計: 131+15 = 146社 / 172社中 85%)
-- 対象: stripe / salesforce / miro / signal / whatsapp / threads / teams /
--        langchain-inc / you-com / make-integromat / freee-hr / schoo /
--        mercari / go-taxi / wordpress

-- ============================================================
-- 決済インフラ (1社)
-- ============================================================

-- Stripe (paid: 決済 2.9%+$0.30/件)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'オンライン決済 2.9%+$0.30/件。サブスク管理+0.5〜0.8%。日本円決済対応。Billing/Connect/Radar等多数のプロダクト。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2016,
  japan_notes_ja     = '日本法人あり。日本語ドキュメント完備。国内スタートアップ・SaaSの決済インフラとして標準。楽天・SoftBank等と競合。EC・SaaS課金で広く採用。'
WHERE id = 'stripe';

-- ============================================================
-- CRM / エンタープライズ (1社)
-- ============================================================

-- Salesforce (enterprise: Starter Suite $25/user/月)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = 25.00,
  pricing_notes_ja   = 'Starter Suite $25/user/月。Professional $80。Enterprise $165。Einstein AI add-on $50。Agentforce 2.0 (AI Agent)。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2000,
  japan_notes_ja     = '日本法人あり (Salesforce Japan)。国内CRM/SFA市場No.1。三菱電機・NTT・ソニー等導入。Agentforce 2.0でAI自律エージェント本格展開。'
WHERE id = 'salesforce';

-- ============================================================
-- コラボレーション (1社)
-- ============================================================

-- Miro (freemium: Starter $10/user/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 10.00,
  pricing_notes_ja   = 'Starter $10/user/月 (年払い)。Business $20/user/月。無料は3ボード制限。AI生成機能・付箋・マインドマップ。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2021,
  japan_notes_ja     = '日本法人なし。日本語UI対応。アジャイル開発チームや Design Thinking でのワークショップに人気。FigJam/Lucidchart と競合。'
WHERE id = 'miro';

-- ============================================================
-- メッセージング (3社)
-- ============================================================

-- Signal (free: OSS/非営利)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '完全無料。シグナル財団 (非営利) 運営。E2E暗号化メッセージ・音声/ビデオ通話・グループ。オープンソース。',
  japan_presence_level = 'growing',
  japan_notes_ja     = '日本法人なし。プライバシー意識高まりで利用増。LINE代替として海外在住者・セキュリティ重視層に支持。WhatsApp比で日本普及率は低い。'
WHERE id = 'signal';

-- WhatsApp (free: 個人無料 / API課金)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '個人利用無料。Business API $0.005/会話〜。Meta傘下。世界200カ国超で30億ユーザー。',
  japan_presence_level = 'limited',
  japan_notes_ja     = 'Meta Japan法人あり。日本ではLINEが支配的で WhatsApp 普及率は低い。海外取引・旅行者向けに利用。モバイルコミュニケーション競合として分析価値あり。'
WHERE id = 'whatsapp';

-- Threads (free: Meta/Instagram連携SNS)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '完全無料。Instagramアカウント連携必須。ActivityPub対応でFediverse互換。2023年7月ローンチ・5日で1億ユーザー。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2023,
  japan_notes_ja     = 'Meta Japan法人あり。日本でも急速ユーザー増。X (旧Twitter) 代替としての認知拡大。クリエイター・ブランド公式発信の場に。'
WHERE id = 'threads';

-- ============================================================
-- ビジネスチャット (1社)
-- ============================================================

-- Microsoft Teams (freemium: Essentials $4/user/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 4.00,
  pricing_notes_ja   = 'Essentials $4/user/月。M365 Business Basic $6/user/月に含む。無料プランは会議60分制限。Copilot Chat $30/user/月別途。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2017,
  japan_users_estimate = 320000000,
  japan_notes_ja     = 'Microsoft Japan法人あり。国内企業でのビジネスチャット利用率No.1 (Office365普及によるデフォルト化)。Copilot統合でAIアシスタント展開中。'
WHERE id = 'teams';

-- ============================================================
-- AI フレームワーク / 開発ツール (2社)
-- ============================================================

-- LangChain Inc (freemium: LangSmith Developer $39/seat/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 39.00,
  pricing_notes_ja   = 'LangChain OSS 無料。LangSmith Developer $39/seat/月。Plus $299/月 (3席)。エンタープライズ要見積。LangGraph Studio同梱。',
  japan_presence_level = 'growing',
  japan_notes_ja     = '日本法人なし。日本のAIエンジニアのLLMアプリ開発フレームワーク標準。LangGraph・LangSmith・LangServeのエコシステム。Sequoia $25M調達。'
WHERE id = 'langchain-inc';

-- You.com (freemium: You Pro $15/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 15.00,
  pricing_notes_ja   = 'You Pro $15/月 (Claude 3.5/GPT-4o/Gemini選択)。無料はスタンダードAIのみ。Research/Code/Writeモード。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。AIプライバシーサーチとして注目。Perplexity対抗。日本語対応あり。$45M Series B調達。AIアシスタント+プライバシー検索で差別化。'
WHERE id = 'you-com';

-- ============================================================
-- ワークフロー自動化 (1社)
-- ============================================================

-- Make (旧Integromat) (freemium: Core $9/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 9.00,
  pricing_notes_ja   = 'Coreプラン $9/月 (10,000op/月)。Pro $16/月。Business $29/月。無料は1,000op/月。Zapier の半額以下で機能豊富。',
  japan_presence_level = 'growing',
  japan_notes_ja     = '日本法人なし。日本語UI対応。Zapier代替として国内スタートアップ・マーケターに浸透。1,500+アプリ連携。n8n/Zapierと三つ巴で競合。'
WHERE id = 'make-integromat';

-- ============================================================
-- CMS (1社)
-- ============================================================

-- WordPress (freemium: Starter $4/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 4.00,
  pricing_notes_ja   = 'WordPress.com Starter $4/月 (年払い)。Business $25/月。WordPress.org OSSは無料 (ホスティング別途)。',
  japan_presence_level = 'dominant',
  japan_notes_ja     = 'Automattic日本語サポートあり。日本語ブログ・企業サイトのCMS市場シェア最大。テーマ/プラグインエコシステム強大。WP-MIXなど日本コミュニティ活発。'
WHERE id = 'wordpress';

-- ============================================================
-- 日本 HR SaaS (1社)
-- ============================================================

-- freee HR (paid: ¥500/人/月〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 3.40,
  pricing_notes_ja   = '¥500/人/月〜 (勤怠管理)。給与計算・社会保険手続きをone-stop。freee会計との連携強み。中小企業向け。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2015,
  japan_notes_ja     = 'freee株式会社。東証グロース上場。中小企業のバックオフィスDX推進。freee会計・開業・保険・HR を統合エコシステムで提供。HR Tech競合として高脅威。'
WHERE id = 'freee-hr';

-- ============================================================
-- 日本 教育 / C2C / モビリティ (3社)
-- ============================================================

-- Schoo (freemium: プレミアム ¥1,480/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 10.00,
  pricing_notes_ja   = '個人プレミアム ¥1,480/月 (約$10)。法人スクー 3名〜 ¥1,500/人/月。無料はライブ授業のみ視聴可。IT・ビジネス講座5,000本+。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2011,
  japan_users_estimate = 880000,
  japan_notes_ja     = '東証グロース上場。日本最大のオンライン動画学習サービス (88万ユーザー)。AI大学のコンテンツ競合。生涯学習・リスキリング需要で成長中。'
WHERE id = 'schoo';

-- Mercari (free: 手数料型)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'ユーザー無料。販売手数料10%+振込手数料200円。メルカリShops手数料6.5%〜。メルペイ統合。月間ユーザー2000万超。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2013,
  japan_users_estimate = 22000000,
  japan_notes_ja     = '東証プライム上場。日本最大のフリマアプリ (月間2200万人)。メルカリUS展開。メルペイ・メルコインでFinTech進出。CtoCコマース領域で高脅威。'
WHERE id = 'mercari';

-- GO タクシーアプリ (free: アプリ無料)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'アプリ無料。タクシー料金は通常メーター。GOクーポンで割引。法人GO Business 月額別途。AI配車最適化・電子領収書。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2020,
  japan_users_estimate = 13000000,
  japan_notes_ja     = 'モビリティテクノロジーズ (DeNA+日本交通)。国内タクシー配車アプリNo.1 (1300万ダウンロード)。AI自動配車・キャッシュレス化推進。ライドシェア解禁議論と連動。'
WHERE id = 'go-taxi';

-- ============================================================
-- seed achievement
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S74: competitors pricing+japan_presence Batch8 — SaaS/コラボ/日本モビリティ等 15社',
  'stripe/salesforce/miro/signal/whatsapp/threads/teams/langchain-inc/you-com/make-integromat/freee-hr/schoo/mercari/go-taxi/wordpress の pricing+japan_presence 充填。累計146社 (172社中85%)。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
