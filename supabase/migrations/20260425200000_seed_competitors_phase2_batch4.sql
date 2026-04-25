-- PS#4 S46: competitors Phase 2 Batch 4 — 66→80社 (2026-04-25)
-- 追加14社: AI Video 3 + Developer/API 2 + Health/Wellness 3 + JP HR 1 + E-Commerce 1 + CRM 2 + Design 1 + CMS 1
-- Phase 2 完了: 目標 75-80社に到達
-- 衝突回避: 200000 (Batch3=195000 / 以降インスタンスとの十分な間隔)

INSERT INTO public.competitors
  (id, display_name, category, website, description, market_cap, user_count,
   founded_year, hq_location, jp_strength, jp_weakness, sort_order)
VALUES

-- ============================================================
-- AI Video Generation (3社) — 動画生成 AI 競合
-- ============================================================
(
  'runway',
  'Runway',
  'ai-coding',
  'https://runwayml.com/',
  'AI 動画生成ツール — Gen-3 Alpha / ハリウッド採用 / $1.5B 評価 / Adobe と競合',
  1500000000, NULL, 2018, 'New York, NY',
  'Gen-3 で高品質動画生成 / Adobe Premiere との連携も / 日本クリエイターに浸透中',
  '月額$35〜 / 長尺動画は高コスト / 日本語インターフェースなし',
  43
),
(
  'heygen',
  'HeyGen',
  'ai-coding',
  'https://www.heygen.com/',
  'AI アバター動画生成 — リアルタイム翻訳+口パク合成 / $75M Series A / 日本語対応',
  500000000, NULL, 2020, 'Los Angeles, CA',
  'AI 動画翻訳で日本語対応が競合最高水準 / 企業研修・マーケ動画に特化',
  'テンプレ依存でクリエイティブ自由度はRunwayに劣る',
  44
),
(
  'pika',
  'Pika',
  'ai-coding',
  'https://pika.art/',
  'テキスト→動画 AI ($80M / Pika 1.0〜2.0 / Sora 対抗 / iOS・Web)',
  500000000, NULL, 2023, 'Palo Alto, CA',
  '直感的 UI で非専門家も即動画生成 / アニメ調スタイルが日本市場に人気',
  '商用利用は有料プランのみ / 1分超動画は未対応',
  45
),

-- ============================================================
-- Developer / API Platform (2社) — 開発者向け API
-- ============================================================
(
  'stripe',
  'Stripe',
  'fintech',
  'https://stripe.com/',
  '決済 API のデファクトスタンダード — $65B 評価 / 100+ 通貨 / Stripe AI 搭載',
  65000000000, NULL, 2010, 'San Francisco, CA',
  '日本向け Stripe Connect + 円決済に完全対応 / 日本語ドキュメント充実',
  'SaaS 型サブスクは競合の Square/PAY.JP より手数料やや高め',
  46
),
(
  'twilio',
  'Twilio',
  'cloud-office',
  'https://www.twilio.com/',
  'コミュニケーション API — SMS/Voice/Video / $9B / Twilio AI 統合済',
  9000000000, NULL, 2008, 'San Francisco, CA',
  'SendGrid 統合で Email+SMS 一括 / Segment CDP 連携でデータ活用',
  '日本のキャリア SMS 配信は別途設定が複雑 / 認証コスト高め',
  47
),

-- ============================================================
-- Health / Wellness (3社) — 健康・ウェルネス
-- ============================================================
(
  'headspace',
  'Headspace',
  'health',
  'https://www.headspace.com/',
  'マインドフルネス・瞑想アプリ — 月$12.99 / Ginger 統合 / $320M 評価',
  320000000, NULL, 2010, 'Los Angeles, CA',
  '日本語コンテンツ追加中 / 企業向け EAP (Employee Assistance) 展開',
  '日本語コンテンツ量は Calm に劣る / 競合 meditopia に負ける場面も',
  48
),
(
  'calm',
  'Calm',
  'health',
  'https://www.calm.com/',
  '瞑想・睡眠アプリ No.1 — $2B ユニコーン / 100M+ DL / Sleep Stories が差別化',
  2000000000, 100000000, 2012, 'San Francisco, CA',
  'Sleep Stories 日本語版あり / アプリストア長年 No.1 / ウェルビーイング市場牽引',
  '日本語コンテンツはHeadspaceと同水準で選別余地あり',
  49
),
(
  'oura',
  'Oura Ring',
  'health',
  'https://ouraring.com/',
  'スマートリング 睡眠/健康トラッキング — $5B 評価 / NBA 公式採用 / Gen4 発売',
  5000000000, NULL, 2013, 'Oulu, Finland',
  '指輪型で充電2日 / 睡眠スコア精度が世界最高水準 / 日本でも公式販売中',
  'デバイス $349〜 + 月額サブスク $5.99 と二重課金モデルへの批判あり',
  50
),

-- ============================================================
-- JP HR / Attendance (1社) — 国内 HR テック
-- ============================================================
(
  'kincone',
  'KINCONE (Techtouch)',
  'hr-attendance',
  'https://kincone.com/',
  'Suica で打刻できる交通費精算連携勤怠アプリ (JP / 中小企業特化 / SaaS)',
  NULL, NULL, 2013, 'Tokyo, Japan',
  '交通系 IC カードタッチで打刻→経費精算一体化 / 中小企業導入コスト最安水準',
  '大企業向けの複雑なシフト管理は King of Time/SmartHR に劣る',
  34
),

-- ============================================================
-- E-Commerce (1社)
-- ============================================================
(
  'shopify',
  'Shopify',
  'e-commerce',
  'https://www.shopify.com/',
  'EC プラットフォーム No.1 — $80B / 176か国 / Shopify AI (Sidekick) 搭載',
  80000000000, NULL, 2006, 'Ottawa, Canada',
  '日本語対応 + 国内決済(PAY.JP/SBペイメント) / Shopify Japan 拡大中',
  'BASE/カラーミーショップ等国産 EC に価格・日本語サポートで劣る面も',
  83
),

-- ============================================================
-- CRM / Marketing (2社)
-- ============================================================
(
  'hubspot',
  'HubSpot',
  'productivity',
  'https://www.hubspot.com/',
  'インバウンドマーケ + CRM All-in-One — $15B / 216,000社 / Breeze AI 搭載',
  15000000000, 216000, 2006, 'Cambridge, MA',
  '無料 CRM が強力で日本中小 SaaS 企業の標準 / 日本語サポートあり',
  'Salesforce に対して大企業カスタマイズで劣る / 価格が上位プランで高騰',
  84
),
(
  'salesforce',
  'Salesforce',
  'productivity',
  'https://www.salesforce.com/',
  'エンタープライズ CRM 世界 No.1 — $200B / Einstein AI / Agentforce 2.0',
  200000000000, NULL, 1999, 'San Francisco, CA',
  '日本 Salesforce が東証一部上場 / 大手日本企業のほぼ全てが利用',
  '中小企業には複雑過ぎ・高コスト / Slack 統合後も操作性に課題',
  85
),

-- ============================================================
-- Design (1社)
-- ============================================================
(
  'canva',
  'Canva',
  'ai-coding',
  'https://www.canva.com/',
  'ノーコード デザインプラットフォーム — $26B / 170M users / Magic Studio AI',
  26000000000, 170000000, 2013, 'Sydney, Australia',
  '日本語 UI 完備 + 日本語フォント豊富 / 教育・中小企業でデファクト',
  'プロデザイナーには機能不足 / Figma との棲み分けが課題',
  86
),

-- ============================================================
-- CMS / Blogging (1社)
-- ============================================================
(
  'wordpress',
  'WordPress (Automattic)',
  'productivity',
  'https://wordpress.com/',
  'Web の 43% を動かす CMS — Automattic $7.5B / Jetpack AI / ブログ→ヘッドレス進化',
  7500000000, NULL, 2003, 'San Francisco, CA',
  '日本語プラグイン豊富 / はてなブログ等と競合 / 個人〜中小企業で圧倒的シェア',
  'Ghost/Substack 等モダン CMS に UX で劣る / セキュリティ管理が煩雑',
  87
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
  '競合 66→80 社化 Phase 2 Batch 4 完了 (PS#4 S46)',
  'AI Video 3社(runway/heygen/pika) + Developer/API 2社(stripe/twilio) + ' ||
  'Health 3社(headspace/calm/oura) + JP HR 1社(kincone) + E-Commerce 1社(shopify) + ' ||
  'CRM 2社(hubspot/salesforce) + Design 1社(canva) + CMS 1社(wordpress) = 計14社追加 → 累計80社 / Phase 2完了',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
