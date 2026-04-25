-- PS#4 S50: 競合 Phase 3 Batch 6 — 155→170社化 (2026-04-26)
-- Telecom JP / Logistics JP / Cloud Gaming / AI Chip / Healthcare AI / CRM
-- 累計 170社 (目標190社の 89%)

INSERT INTO public.competitors (
  id, name, display_name, category, website_url,
  description, funding_or_valuation, employee_count_range,
  key_features, our_overlap_score, threat_level,
  founded_year, headquarters, is_active, created_at, updated_at
) VALUES

-- ============================================================
-- Telecom JP (3社)
-- ============================================================
(
  'ntt-docomo',
  'NTTドコモ',
  'NTTドコモ',
  'telecom',
  'https://www.docomo.ne.jp',
  'NTTグループの携帯電話最大手。dポイント・dカード・d払い・ドコモ口座など金融・決済サービスも展開。',
  '(NTT TSE:9432 傘下)',
  '30000+',
  ARRAY['携帯通信','dポイント','d払い','dカード','ドコモ光'],
  4, 'medium',
  1992, '東京都千代田区', true, now(), now()
),
(
  'softbank-telecom',
  'SoftBank',
  'ソフトバンク',
  'telecom',
  'https://www.softbank.jp',
  '国内3大キャリアの一角。PayPay・LINEMOなど金融・MVNO事業も展開。AI投資(ARM等)も注力。',
  '(ソフトバンクG TSE:9984)',
  '20000+',
  ARRAY['携帯通信','PayPay','Yahoo!ショッピング','LINEMO','SoftBank光'],
  5, 'medium',
  1981, '東京都港区', true, now(), now()
),
(
  'kddi-au',
  'KDDI (au)',
  'KDDI (au)',
  'telecom',
  'https://www.au.com',
  'au携帯・UQモバイル・auPAY・auじぶん銀行など生活インフラを統合。ポイント経済圏を構築。',
  '(KDDI TSE:9433)',
  '50000+',
  ARRAY['携帯通信','auPAY','auじぶん銀行','auポイント','UQモバイル'],
  4, 'medium',
  2000, '東京都千代田区', true, now(), now()
),

-- ============================================================
-- Logistics JP (2社)
-- ============================================================
(
  'yamato-transport',
  'ヤマト運輸',
  'ヤマト運輸',
  'logistics',
  'https://www.kuronekoyamato.co.jp',
  '宅急便の国内最大手。EC物流・法人向け配送・ヤマトフィナンシャル(決済)・DX事業も展開。',
  '(ヤマトHD TSE:9064)',
  '200000+',
  ARRAY['宅急便','EC配送','法人物流','クロネコメンバーズ','冷蔵配送'],
  3, 'low',
  1919, '東京都中央区', true, now(), now()
),
(
  'sagawa-express',
  '佐川急便',
  '佐川急便',
  'logistics',
  'https://www.sagawa-exp.co.jp',
  '法人向け配送に強みを持つ宅配大手2位。SGHグループ。フィリピン・東南アジアにも進出。',
  '(SGH TSE:9143)',
  '100000+',
  ARRAY['宅配便','法人物流','国際物流','3PL','デリバリー最適化'],
  3, 'low',
  1957, '大阪府大阪市', true, now(), now()
),

-- ============================================================
-- Cloud Gaming / Entertainment Tech (2社)
-- ============================================================
(
  'nvidia-geforce-now',
  'NVIDIA GeForce NOW',
  'GeForce NOW',
  'entertainment',
  'https://www.nvidia.com/geforce-now',
  'クラウドゲーミングサービス。GPUクラウドで高性能ゲームをどのデバイスでも。NVIDIA傘下。',
  '(NVIDIA NASDAQ:NVDA $2T+)',
  '30000+',
  ARRAY['クラウドゲーミング','RTX ON','PC/Mac/スマホ対応','1600+ゲーム','月額サブスク'],
  3, 'low',
  2015, 'Santa Clara, USA', true, now(), now()
),
(
  'xbox-cloud-gaming',
  'Xbox Cloud Gaming',
  'Xbox Cloud Gaming',
  'entertainment',
  'https://www.xbox.com/cloud-gaming',
  'Microsoftのクラウドゲーミング。Game Pass Ultimateに含まれる。スマホ・ブラウザでXboxゲームをプレイ。',
  '(Microsoft NASDAQ:MSFT $3T+)',
  '220000+',
  ARRAY['クラウドゲーミング','Game Pass連携','Android/iOS/ブラウザ対応','Forza/HaloなどXbox独占タイトル'],
  3, 'low',
  2020, 'Redmond, USA', true, now(), now()
),

-- ============================================================
-- AI Chip / Infrastructure (2社)
-- ============================================================
(
  'groq-ai',
  'Groq',
  'Groq',
  'ai-infrastructure',
  'https://groq.com',
  'LPU (Language Processing Unit) によりLLM推論を超高速化。Llama3-70Bを秒間800トークンで処理。',
  '$2.8B valuation (Series D $640M)',
  '500+',
  ARRAY['LPU推論チップ','超高速LLM推論','GroqCloud API','低レイテンシ','Llama/Mistral対応'],
  4, 'medium',
  2016, 'Mountain View, USA', true, now(), now()
),
(
  'cerebras-systems',
  'Cerebras',
  'Cerebras Systems',
  'ai-infrastructure',
  'https://www.cerebras.net',
  'ウエハースケールエンジン(WSE)でLLM学習を超高速化。GPT-3相当を3分で学習。IPO準備中。',
  '$4B valuation (Series F $250M)',
  '300+',
  ARRAY['ウエハースケールAI','超高速LLM学習','Cerebras Cloud','モデルトレーニング','低コスト推論'],
  3, 'medium',
  2016, 'Sunnyvale, USA', true, now(), now()
),

-- ============================================================
-- Healthcare AI (2社)
-- ============================================================
(
  'google-health',
  'Google Health',
  'Google Health',
  'health',
  'https://health.google',
  'Googleの医療AI部門。Med-PaLM 2 (医療LLM)・Fitbit・健康データ分析を展開。FDA認可製品も。',
  '(Alphabet NASDAQ:GOOGL $2T)',
  '1000+',
  ARRAY['Med-PaLM 2','医療画像AI診断','Fitbit','健康記録API','EMR統合'],
  4, 'low',
  2019, 'Mountain View, USA', true, now(), now()
),
(
  'viz-ai',
  'Viz.ai',
  'Viz.ai',
  'health',
  'https://www.viz.ai',
  '医療画像AIによる脳卒中・心臓病の早期発見自動化。FDA認可済。病院1,000施設以上が導入。',
  '$1B valuation (Series D $100M)',
  '500+',
  ARRAY['脳卒中AI早期発見','CT/MRI解析','医師アラート','EHR連携','FDA認可'],
  2, 'low',
  2016, 'San Francisco, USA', true, now(), now()
),

-- ============================================================
-- CRM / Sales Tech (2社)
-- ============================================================
(
  'hubspot-crm',
  'HubSpot CRM',
  'HubSpot',
  'productivity',
  'https://www.hubspot.com',
  'マーケ・セールス・CS統合CRMプラットフォーム。中小企業向け無料CRMで普及。NYSE:HUBS $15B。',
  '$15B valuation (NYSE: HUBS)',
  '8000+',
  ARRAY['無料CRM','マーケ自動化','セールスパイプライン','CS管理','AI機能'],
  7, 'high',
  2006, 'Cambridge, USA', true, now(), now()
),
(
  'zoho-crm',
  'Zoho CRM',
  'Zoho',
  'productivity',
  'https://www.zoho.com',
  'インド発の統合ビジネスSuiteブランド。CRM・会計・HR・ProjectなどSaaS60+を一体提供。非上場。',
  '$5B+ valuation (非上場)',
  '15000+',
  ARRAY['CRM','会計','HRシステム','プロジェクト管理','AI Zia'],
  8, 'high',
  1996, 'Chennai, India', true, now(), now()
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
  '競合 155→170社化 Phase 3 Batch 6 (PS#4 S50)',
  'Telecom JP (ドコモ/SoftBank/KDDI) + Logistics JP (ヤマト/佐川) + ' ||
  'Cloud Gaming (GeForce NOW/Xbox Cloud) + AI Chip (Groq/Cerebras) + ' ||
  'Healthcare AI (Google Health/Viz.ai) + CRM (HubSpot/Zoho) = 15社追加。' ||
  '累計 170社 / 目標190社の 89%。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
