-- PS#4 S50: 競合 Phase 3 Batch 4 — 125→140社化 (2026-04-26)
-- E-commerce Platform / EdTech / Real Estate JP / Travel JP / Food JP
-- 累計 140社 (目標190社の 74%)

INSERT INTO public.competitors (
  id, name, display_name, category, website_url,
  description, funding_or_valuation, employee_count_range,
  key_features, our_overlap_score, threat_level,
  founded_year, headquarters, is_active, created_at, updated_at
) VALUES

-- ============================================================
-- E-commerce Platform (3社)
-- ============================================================
(
  'ecforce',
  'ecforce',
  'ecforce',
  'e-commerce',
  'https://ec-force.com',
  '国内D2C・EC特化のSaaSプラットフォーム。定期購入・シリアル管理・マーケ自動化。TSE:4844。',
  '¥60億売上 (TSE:4844)',
  '300+',
  ARRAY['定期購入管理','D2C最適化','顧客分析','マーケ自動化','決済一元管理'],
  5, 'low',
  2012, '東京都渋谷区', true, now(), now()
),
(
  'stores-jp',
  'STORES',
  'STORES.jp',
  'e-commerce',
  'https://stores.jp',
  'ヘイ社が運営するネットショップ作成サービス。無料〜有料プラン。実店舗POSとの統合も。国内EC開設数50万超。',
  '非公開 (hey: シリーズC $45M)',
  '500+',
  ARRAY['ネットショップ開設','POSレジ連携','デジタルコンテンツ販売','予約管理','決済'],
  6, 'medium',
  2012, '東京都渋谷区', true, now(), now()
),
(
  'wix',
  'Wix',
  'Wix',
  'productivity',
  'https://www.wix.com',
  'ノーコードWebサイト作成プラットフォーム。240M+サイト。AI Wixでデザイン自動生成。NASDAQ:WIX。',
  '$7B valuation (NASDAQ: WIX)',
  '5000+',
  ARRAY['ノーコードWebサイト','EC機能','AI生成','ブログ','予約管理'],
  6, 'medium',
  2006, 'Tel Aviv, Israel', true, now(), now()
),

-- ============================================================
-- EdTech (3社)
-- ============================================================
(
  'udemy',
  'Udemy',
  'Udemy',
  'education',
  'https://www.udemy.com',
  'オンライン学習マーケットプレイス最大手。21万コース・6,200万学習者。法人向けUdemy Businessも展開。NASDAQ:UDMY。',
  '$3B valuation (NASDAQ: UDMY)',
  '1000+',
  ARRAY['オンラインコース','講師マーケット','法人研修','証明書','モバイルアプリ'],
  5, 'low',
  2010, 'San Francisco, USA', true, now(), now()
),
(
  'progate',
  'Progate',
  'Progate',
  'education',
  'https://prog-8.com',
  '初心者向けプログラミング学習サービス。日本発・世界100万人。スライドとコーディング環境一体型。',
  '非公開 (2017年Draper Nexus他から調達)',
  '100+',
  ARRAY['プログラミング学習','スライド型UI','ブラウザ内コーディング','パス機能','英語対応'],
  4, 'low',
  2014, '東京都渋谷区', true, now(), now()
),
(
  'schoo',
  'Schoo',
  'Schoo',
  'education',
  'https://schoo.jp',
  'ビジネスパーソン向けオンライン動画学習サービス。7,000コース超・法人向け研修プラットフォームも展開。',
  '非公開 (シリーズD+)',
  '200+',
  ARRAY['ビジネス動画学習','ライブ授業','法人研修','スキル診断','習熟度管理'],
  5, 'medium',
  2011, '東京都千代田区', true, now(), now()
),

-- ============================================================
-- Real Estate JP (2社)
-- ============================================================
(
  'suumo',
  'SUUMO',
  'SUUMO',
  'real-estate',
  'https://suumo.jp',
  'リクルート運営の日本最大級の不動産ポータル。賃貸・売買・新築・中古をカバー。月間5,000万PV超。',
  '(リクルート TSE:6098)',
  '500+',
  ARRAY['賃貸物件検索','売買物件','内見予約','ローン計算','引越しサービス'],
  4, 'low',
  2009, '東京都千代田区', true, now(), now()
),
(
  'itandi',
  'ITANDI BB',
  'ITANDI BB',
  'real-estate',
  'https://bb.itandi.co.jp',
  '不動産業者向けDXプラットフォーム。空室確認・申込・審査・契約をオンライン化。野村不動産グループ。',
  '非公開 (野村不動産グループ)',
  '300+',
  ARRAY['空室確認API','オンライン申込','電子契約','審査自動化','内見予約'],
  5, 'low',
  2012, '東京都渋谷区', true, now(), now()
),

-- ============================================================
-- Travel JP / 予約 (2社)
-- ============================================================
(
  'jalan',
  'じゃらん',
  'じゃらんnet',
  'travel',
  'https://www.jalan.net',
  'リクルート運営の旅行予約サービス。ホテル・旅館・ツアー。口コミ・ポイント制度が特徴。月間4,000万PV。',
  '(リクルート TSE:6098)',
  '300+',
  ARRAY['ホテル予約','旅館予約','ポイント制度','口コミ','クーポン'],
  4, 'low',
  2000, '東京都千代田区', true, now(), now()
),
(
  'ikyu',
  '一休.com',
  '一休.com',
  'travel',
  'https://www.ikyu.com',
  'ヤフー傘下の高級ホテル・旅館・レストラン予約サービス。富裕層向け厳選掲載が特徴。',
  '(LINEヤフー TSE:4689)',
  '300+',
  ARRAY['高級ホテル予約','高級レストラン','一休プレミア会員','ポイント','ギフト'],
  4, 'low',
  1999, '東京都港区', true, now(), now()
),

-- ============================================================
-- Food / Delivery JP (2社)
-- ============================================================
(
  'ubereats-japan',
  'Uber Eats',
  'Uber Eats',
  'food-delivery',
  'https://www.ubereats.com/jp',
  '日本でもトップのフードデリバリーサービス。全国300都市以上展開。店舗・ユーザー・配達員の3面プラットフォーム。',
  '(Uber NYSE:UBER $100B+)',
  '1000+',
  ARRAY['フードデリバリー','店舗管理ツール','配達員管理','サブスク Eats Pass','リアルタイム追跡'],
  4, 'low',
  2016, '東京都渋谷区', true, now(), now()
),
(
  'tabelog',
  '食べログ',
  '食べログ',
  'food-delivery',
  'https://tabelog.com',
  'カカクコム運営の日本最大グルメサービス。1億件超の口コミ・予約機能。レストランDXも展開。',
  '(カカクコム TSE:2371)',
  '500+',
  ARRAY['レストラン口コミ','予約','テイクアウト','食べログ予約管理','分析ツール'],
  4, 'low',
  2005, '東京都渋谷区', true, now(), now()
),

-- ============================================================
-- AI Assistant / Productivity (3社)
-- ============================================================
(
  'perplexity-ai',
  'Perplexity AI',
  'Perplexity',
  'ai-platform',
  'https://www.perplexity.ai',
  'AI検索エンジン。リアルタイムWeb検索+LLM回答生成。引用付き回答が特徴。月間1億クエリ超。',
  '$9B valuation (Series D $500M)',
  '100+',
  ARRAY['AI検索','リアルタイムWeb検索','引用付き回答','Proモード','API'],
  6, 'high',
  2022, 'San Francisco, USA', true, now(), now()
),
(
  'typeform',
  'Typeform',
  'Typeform',
  'productivity',
  'https://www.typeform.com',
  'インタラクティブなフォーム・アンケート作成ツール。1問1答UI。AI機能でアンケート自動生成。',
  '$2B valuation (Series C $135M)',
  '500+',
  ARRAY['インタラクティブフォーム','アンケート','AI生成','Zapier連携','ロジック分岐'],
  6, 'medium',
  2012, 'Barcelona, Spain', true, now(), now()
),
(
  'calendly',
  'Calendly',
  'Calendly',
  'productivity',
  'https://calendly.com',
  'スケジュール調整自動化ツール。「会議したい→URLを送る」だけで予約完結。1,000万人以上が利用。',
  '$3B valuation (Series B $350M)',
  '500+',
  ARRAY['スケジュール自動調整','カレンダー連携','グループ会議','AI提案','Zoom連携'],
  7, 'high',
  2013, 'Atlanta, USA', true, now(), now()
)

ON CONFLICT (id) DO UPDATE SET
  display_name        = EXCLUDED.display_name,
  description         = EXCLUDED.description,
  funding_or_valuation= EXCLUDED.funding_or_valuation,
  key_features        = EXCLUDED.key_features,
  our_overlap_score   = EXCLUDED.our_overlap_score,
  threat_level        = EXCLUDED.threat_level,
  updated_at          = now();

-- ============================================================
-- 実績記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競合 125→140社化 Phase 3 Batch 4 (PS#4 S50)',
  'EC Platform (ecforce/STORES/Wix) + EdTech JP (Udemy/Progate/Schoo) + ' ||
  'Real Estate JP (SUUMO/ITANDI) + Travel JP (じゃらん/一休) + ' ||
  'Food JP (Uber Eats/食べログ) + AI/Productivity (Perplexity/Typeform/Calendly) = 15社追加。' ||
  '累計 140社 / 目標190社の 74%。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
