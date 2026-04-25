-- PS#4 S50: 競合 Phase 3 Batch 3 — 110→125社化 (2026-04-26)
-- AI Writing / Video / Voice / Automation / Security / HR Tech
-- 累計 125社 (目標190社の 66%)

INSERT INTO public.competitors (
  id, name, display_name, category, website_url,
  description, funding_or_valuation, employee_count_range,
  key_features, our_overlap_score, threat_level,
  founded_year, headquarters, is_active, created_at, updated_at
) VALUES

-- ============================================================
-- AI Writing / Content (3社)
-- ============================================================
(
  'notion-ai',
  'Notion AI',
  'Notion AI',
  'productivity',
  'https://www.notion.so/product/ai',
  'NotionのAI機能拡張。文章生成・要約・翻訳・Q&Aをワークスペース内で直接利用。$10/メンバー/月の追加サービス。',
  '(Notion: $10B valuation)',
  '500+',
  ARRAY['AI文章生成','要約','翻訳','Q&A','データベース自動化'],
  9, 'critical',
  2023, 'San Francisco, USA', true, now(), now()
),
(
  'grammarly',
  'Grammarly',
  'Grammarly',
  'productivity',
  'https://www.grammarly.com',
  'AI英文校正・ライティングアシスタント。3,000万日次ユーザー。GrammarlyGO (生成AI) でコンテンツ生成も対応。',
  '$13B valuation (Series C $200M)',
  '1000+',
  ARRAY['英文校正','トーン調整','AI文章生成','盗作検出','Chrome拡張'],
  5, 'low',
  2009, 'San Francisco, USA', true, now(), now()
),
(
  'jasper-ai',
  'Jasper',
  'Jasper AI',
  'ai-platform',
  'https://www.jasper.ai',
  'マーケター向けAIコンテンツ生成プラットフォーム。ブログ・SNS・広告コピーを一元管理。売上$70M超。',
  '$1.5B valuation (Series A $125M)',
  '200+',
  ARRAY['AIコピーライティング','ブランドボイス管理','SNS投稿','SEO最適化','チームコラボ'],
  7, 'high',
  2021, 'Austin, USA', true, now(), now()
),

-- ============================================================
-- AI Video / Voice (3社)
-- ============================================================
(
  'elevenlabs',
  'ElevenLabs',
  'ElevenLabs',
  'ai-platform',
  'https://elevenlabs.io',
  'AIリアルタイム音声合成・クローニング。29言語対応。ポッドキャスト・オーディオブック・ゲームキャラクターで急成長。',
  '$3.3B valuation (Series C $180M)',
  '200+',
  ARRAY['音声合成','音声クローニング','多言語TTS','リアルタイム音声','SDK'],
  5, 'medium',
  2022, 'London, UK', true, now(), now()
),
(
  'synthesia',
  'Synthesia',
  'Synthesia',
  'ai-platform',
  'https://www.synthesia.io',
  'AIアバター動画生成。テキスト→動画化。130言語・225アバター。企業トレーニング動画制作で世界50,000社利用。',
  '$1B valuation (Series C $90M)',
  '300+',
  ARRAY['AIアバター動画','テキスト→動画','多言語対応','ブランドカスタマイズ','LMS連携'],
  4, 'medium',
  2017, 'London, UK', true, now(), now()
),
(
  'descript',
  'Descript',
  'Descript',
  'ai-platform',
  'https://www.descript.com',
  '動画・ポッドキャスト編集のAIプラットフォーム。テキスト編集感覚で動画編集。Overdub音声クローン機能。',
  '$550M valuation (Series C $50M)',
  '200+',
  ARRAY['テキストベース動画編集','音声クローン','文字起こし','スクリーンレコーダー','コラボ編集'],
  4, 'medium',
  2017, 'San Francisco, USA', true, now(), now()
),

-- ============================================================
-- Automation / Integration (3社)
-- ============================================================
(
  'make-integromat',
  'Make',
  'Make (Integromat)',
  'productivity',
  'https://www.make.com',
  'ノーコードワークフロー自動化プラットフォーム。1,500+アプリ連携。Zapier対抗。ビジュアルシナリオビルダー。',
  '$2B valuation (Series B $100M)',
  '1000+',
  ARRAY['ワークフロー自動化','1500+連携','ビジュアルビルダー','AI処理','カスタムAPI'],
  7, 'high',
  2012, 'Prague, Czech Republic', true, now(), now()
),
(
  'pipedream',
  'Pipedream',
  'Pipedream',
  'developer-tools',
  'https://pipedream.com',
  '開発者向けイベントドリブン自動化プラットフォーム。コード+ノーコードのハイブリッド。APIトリガーで即実行。',
  '$50M funding (Series A)',
  '50+',
  ARRAY['イベントドリブン自動化','コード対応','1000+トリガー','AI Agent','無料Tier充実'],
  6, 'medium',
  2018, 'San Francisco, USA', true, now(), now()
),
(
  'airtable',
  'Airtable',
  'Airtable',
  'productivity',
  'https://www.airtable.com',
  'スプレッドシート×データベースのノーコードプラットフォーム。Notionとの直接競合。$11.7B評価。',
  '$11.7B valuation (Series F $735M)',
  '1000+',
  ARRAY['スプレッドシートDB','ビュー切替','自動化','API','AI機能'],
  8, 'high',
  2012, 'San Francisco, USA', true, now(), now()
),

-- ============================================================
-- Security / Compliance (2社)
-- ============================================================
(
  'vanta',
  'Vanta',
  'Vanta',
  'developer-tools',
  'https://www.vanta.com',
  'セキュリティコンプライアンス自動化。SOC2/ISO27001/HIPAA対応を自動化。IPO準備中スタートアップの必需品。',
  '$2.45B valuation (Series C $150M)',
  '600+',
  ARRAY['SOC2自動化','コンプライアンス監視','セキュリティアセスメント','ベンダーリスク管理','証拠収集自動化'],
  5, 'medium',
  2017, 'San Francisco, USA', true, now(), now()
),
(
  'drata',
  'Drata',
  'Drata',
  'developer-tools',
  'https://drata.com',
  'セキュリティコンプライアンス自動化プラットフォーム。SOC2/ISO/GDPR対応。Vantaとの直接競合。$2B評価。',
  '$2B valuation (Series C $200M)',
  '600+',
  ARRAY['SOC2自動化','GDPR対応','AI証拠収集','サプライヤー管理','リスクスコアリング'],
  5, 'medium',
  2019, 'San Diego, USA', true, now(), now()
),

-- ============================================================
-- HR Tech JP (2社)
-- ============================================================
(
  'smarthr',
  'SmartHR',
  'SmartHR',
  'hr-tech',
  'https://smarthr.jp',
  '日本最大のクラウド人事労務SaaS。入退社手続き・給与・雇用契約・組織図・人材育成まで統合。TSE上場準備中。',
  '未公開 ($200M+ 累計調達)',
  '1000+',
  ARRAY['労務手続き自動化','電子契約','給与明細配布','マイナンバー管理','タレントマネジメント'],
  7, 'high',
  2013, '東京都港区', true, now(), now()
),
(
  'hrmos',
  'HRMOS',
  'HRMOS採用',
  'hr-tech',
  'https://irecruit-doc.hrmos.co',
  'ビズリーチ社のHRクラウドシリーズ。採用管理・タレントマネジメント・勤怠管理を統合。',
  '(ビジョナル TSE:4194)',
  '1000+',
  ARRAY['採用管理ATS','タレントプール','評価管理','勤怠管理','ビズリーチ連携'],
  6, 'medium',
  2016, '東京都渋谷区', true, now(), now()
),

-- ============================================================
-- Legal Tech / 電子契約 (2社)
-- ============================================================
(
  'cloudsign',
  'CloudSign',
  'クラウドサイン',
  'legal-tech',
  'https://www.cloudsign.jp',
  '弁護士ドットコム運営の電子契約サービス。国内シェアNo.1。200万件超の契約締結実績。行政機関でも採用。',
  '(弁護士ドットコム TSE:6027)',
  '300+',
  ARRAY['電子署名','契約管理','テンプレート','GMO・DocuSign連携','API'],
  8, 'critical',
  2015, '東京都港区', true, now(), now()
),
(
  'docusign',
  'DocuSign',
  'DocuSign',
  'legal-tech',
  'https://www.docusign.com',
  '電子署名・契約ライフサイクル管理の世界最大手。NASDAQ:DOCU。1M+顧客・$2.4B売上。AIによる契約分析も。',
  '$17B valuation (NASDAQ: DOCU)',
  '7000+',
  ARRAY['電子署名','CLM契約管理','AI契約分析','Salesforce連携','コンプライアンス管理'],
  7, 'high',
  2003, 'San Francisco, USA', true, now(), now()
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
  '競合 110→125社化 Phase 3 Batch 3 (PS#4 S50)',
  'AI Writing (Notion AI/Grammarly/Jasper) + AI Video/Voice (ElevenLabs/Synthesia/Descript) + ' ||
  'Automation (Make/Pipedream/Airtable) + Security (Vanta/Drata) + HR JP (SmartHR/HRMOS) + ' ||
  'Legal Tech (クラウドサイン/DocuSign) = 15社追加。累計 125社 / 目標190社の 66%。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
