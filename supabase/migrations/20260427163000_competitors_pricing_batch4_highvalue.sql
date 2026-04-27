-- PS#4 S72: competitors pricing + japan_presence Batch 4 — 高脅威/EC/DevOps/ウェルネス 15社
-- 2026-04-27 (累計: 40+18+13+15 = 86社)
-- 対象: jasper-ai / grammarly / shopify / heygen / synthesia / udemy / coursera /
--        headspace / jules-google / tiktok-shop / postman / vanta / datadog / sentry / wix

-- ============================================================
-- AI ライティング / コンテンツ (2社)
-- ============================================================

-- Jasper AI (paid: Creator $49/月 / Pro $69/月 / Business 要見積)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 49.00,
  pricing_notes_ja   = 'Creator $49/月。Pro $69/月 (3ユーザー, SEO+プロジェクト)。Business 要見積。年払い20%OFF。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。英語マーケター向けが主。日本語対応は基本水準。AIコンテンツ規制強化で一部企業が導入見直し。'
WHERE id = 'jasper-ai';

-- Grammarly (freemium: Free / Premium $12/月 / Business $15/user)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 12.00,
  pricing_notes_ja   = 'Premium $12/月 (年払い)。Business $15/user/月。GrammarlyGO (GenAI) 全プランで利用可。',
  japan_presence_level = 'growing',
  japan_notes_ja     = '日本法人なし。英語学習・英文メール作成で日本企業でも利用増。Google Docs / Outlook 統合で普及。'
WHERE id = 'grammarly';

-- ============================================================
-- EC / コマース (2社)
-- ============================================================

-- Shopify (paid: Basic $29/月 / Shopify $79/月 / Advanced $299/月)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 29.00,
  pricing_notes_ja   = 'Basic $29/月 (年払い)。Shopify $79/月。Advanced $299/月。決済手数料 2%〜。日本円/日本決済対応。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2017,
  japan_notes_ja     = '日本法人あり (Shopify Japan)。国内ECプラットフォームシェア2位。BASE/STORESと競合。マーチャント5万以上。'
WHERE id = 'shopify';

-- TikTok Shop (free: 出店無料 / 販売手数料 6%)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '出店・利用無料。販売手数料6%。TikTokライブコマースとの統合でエンゲージメント高い。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2023,
  japan_notes_ja     = '2023年日本サービス開始。Z世代への購買浸透率急上昇。ByteDance規制リスクあり。日本で月間2300万MAU。'
WHERE id = 'tiktok-shop';

-- ============================================================
-- ビデオ AI (2社)
-- ============================================================

-- HeyGen (freemium: Free 1動画/月 / Creator $29/月 / Team $89/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 29.00,
  pricing_notes_ja   = 'Creator $29/月。Team $89/月。AIアバター動画・口パク合成・多言語吹替。日本語アバターあり。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2023,
  japan_notes_ja     = '日本法人なし。2023年日本語対応開始。マーケター・教育業界でAI動画制作ツールとして急速普及。'
WHERE id = 'heygen';

-- Synthesia (paid: Starter $29/月 / Creator $89/月 / Enterprise 要見積)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 29.00,
  pricing_notes_ja   = 'Starter $29/月 (10動画/月)。Creator $89/月。Enterprise 要見積。AIアバター+多言語ナレーション。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。英語圏企業での研修・プレゼン動画制作に主に採用。日本語アバターは限定的。'
WHERE id = 'synthesia';

-- ============================================================
-- 教育 (2社)
-- ============================================================

-- Udemy (freemium: コース $10〜200 / Personal Pro $30/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 15.00,
  pricing_notes_ja   = 'コース買い切り $10〜$200 (セール時$10〜)。Personal Plan $30/月。Business $360/user/年。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2015,
  japan_notes_ja     = '日本法人あり (ベネッセコーポレーションと提携)。国内最大のオンライン学習市場。AIコース急増中。日本語コース1万本超。'
WHERE id = 'udemy';

-- Coursera (freemium: 無料聴講 / Plus $59/月 / Degrees 別料金)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 59.00,
  pricing_notes_ja   = 'Plus $59/月 (7000+コース)。Coursera for Business $400/user/年。大学学位プログラムは別途。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2019,
  japan_notes_ja     = '日本法人なし。東大・京大コンテンツあり。エンジニア・データサイエンティスト向けに日本でも利用増。'
WHERE id = 'coursera';

-- ============================================================
-- ウェルネス / メンタルヘルス (1社)
-- ============================================================

-- Headspace (freemium: Free体験 / $12.99/月 / $99.99/年)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 8.33,
  pricing_notes_ja   = '$99.99/年 (月割$8.33)。月払い$12.99。Headspace for Work 要見積。瞑想・マインドフルネス専門。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。日本語コンテンツ少ない。Calm と同ジャンルで日本では認知度低め。ウェルビーイング市場で潜在競合。'
WHERE id = 'headspace';

-- ============================================================
-- Google AI / 新 AI ツール (1社)
-- ============================================================

-- Jules by Google (beta: 無料 / 将来GA後有料化予定)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '2026年現在 Waitlist + 無料ベータ。GA後は Google One AI Premium に統合予定。GitHub Issue 自律解決AI。',
  japan_presence_level = 'growing',
  japan_notes_ja     = 'Google プロダクトとして日本語対応予定。Devin/GitHub Copilot Workspaces 対抗。GA後の価格次第で日本企業採用加速。'
WHERE id = 'jules-google';

-- ============================================================
-- DevOps / SaaS インフラ (4社)
-- ============================================================

-- Postman (freemium: Free / Basic $14/user/月 / Professional $29)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 14.00,
  pricing_notes_ja   = 'Basic $14/user/月。Professional $29/user/月。API開発の業界標準。PostbotがAI機能として統合。',
  japan_presence_level = 'growing',
  japan_notes_ja     = '日本法人なし。日本のAPI開発者なら必須ツール。REST/GraphQL/gRPCデバッグの標準。日本語ドキュメントが充実。'
WHERE id = 'postman';

-- Vanta (enterprise: SOC2/ISO27001 自動化 要見積)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'Starter $7,500/年〜。Enterprise 要見積。SOC 2 Type II / ISO 27001 / HIPAA 自動化SaaS。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。欧米スタートアップがSOC2取得に多用。日本では ISMS (ISO27001) の Vanta採用が増加傾向。'
WHERE id = 'vanta';

-- Datadog (paid: $15/host/月〜 / $23 Pro / $31 Enterprise)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 15.00,
  pricing_notes_ja   = 'インフラ監視 $15/host/月。APM $31/host/月。Logs $2.55/GB〜。日本円請求対応。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2019,
  japan_notes_ja     = '日本法人あり (Datadog Japan)。大手日本企業のSRE/DevOpsチームに浸透。Mackerel (Hatena) と競合。'
WHERE id = 'datadog';

-- Sentry (freemium: Free / Team $26/月 / Business $80/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 26.00,
  pricing_notes_ja   = 'Team $26/月。Business $80/月。エラートラッキングのデファクトスタンダード。AI Autofixで自動修正提案。',
  japan_presence_level = 'growing',
  japan_notes_ja     = '日本法人なし。日本のスタートアップ〜大企業まで幅広く使用。Sentry Japan User Group が活発。'
WHERE id = 'sentry';

-- ============================================================
-- Web サイトビルダー (1社)
-- ============================================================

-- Wix (freemium: Free / Core $17/月 / Business $36/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 17.00,
  pricing_notes_ja   = 'Core $17/月 (年払い)。Business $36/月。Wix ADI (AI自動生成) + Wix Studio でプロ向け強化。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2014,
  japan_notes_ja     = '日本語UI完全対応。日本語テンプレート豊富。個人・中小企業サイト作成ツールとして国内で高認知。'
WHERE id = 'wix';

-- ============================================================
-- seed achievement
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S72: competitors pricing+japan_presence Batch4 — 高脅威/EC/DevOps 15社',
  'jasper-ai/grammarly/shopify/tiktok-shop/heygen/synthesia/udemy/coursera/headspace/jules-google/postman/vanta/datadog/sentry/wix の pricing_tier・pricing_start_usd・pricing_notes_ja・japan_presence_level・japan_notes_ja 充填。累計86社。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
