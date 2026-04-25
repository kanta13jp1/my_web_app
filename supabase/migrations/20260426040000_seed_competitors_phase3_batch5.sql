-- PS#4 S50: 競合 Phase 3 Batch 5 — 140→155社化 (2026-04-26)
-- Crypto/Web3 / Insurance Tech JP / Media JP / Social Commerce / AI Agent Platform
-- 累計 155社 (目標190社の 82%)

INSERT INTO public.competitors (
  id, name, display_name, category, website_url,
  description, funding_or_valuation, employee_count_range,
  key_features, our_overlap_score, threat_level,
  founded_year, headquarters, is_active, created_at, updated_at
) VALUES

-- ============================================================
-- Crypto / Web3 (2社)
-- ============================================================
(
  'coincheck',
  'Coincheck',
  'Coincheck',
  'fintech',
  'https://coincheck.com',
  '国内最大級の暗号資産取引所。マネックスグループ傘下。NFT・IEO・つみたて機能も提供。',
  '(マネックスG TSE:8698)',
  '500+',
  ARRAY['暗号資産取引','NFTマーケット','IEO','つみたて','Coincheckでんき'],
  3, 'low',
  2012, '東京都渋谷区', true, now(), now()
),
(
  'metamask',
  'MetaMask',
  'MetaMask',
  'fintech',
  'https://metamask.io',
  'イーサリアム/EVM対応ウォレット&Web3ゲートウェイ。月間3,000万アクティブユーザー。ConsenSys運営。',
  '$7B valuation (ConsenSys Series D)',
  '500+',
  ARRAY['暗号資産ウォレット','dApp連携','NFT管理','スワップ','Bridge機能'],
  2, 'low',
  2016, 'San Francisco, USA', true, now(), now()
),

-- ============================================================
-- Insurance Tech JP (2社)
-- ============================================================
(
  'lifenet-insurance',
  'ライフネット生命',
  'ライフネット生命',
  'fintech',
  'https://www.lifenet-seimei.co.jp',
  '日本初のネット生命保険。シンプルな保険設計+AI査定。スマホ完結で申込〜請求まで対応。',
  '¥130億売上 (TSE:7157)',
  '300+',
  ARRAY['ネット完結生命保険','AI保険料試算','スマホ申込','シンプル設計','オンライン請求'],
  3, 'low',
  2006, '東京都千代田区', true, now(), now()
),
(
  'freee-insurance',
  'insurtech (代表例: justInCase)',
  'justInCase',
  'fintech',
  'https://justincase.jp',
  '少額短期保険のInsurTechスタートアップ。アプリで完結する「わりかん保険」「スマホ保険」を展開。',
  '非公開 (シリーズB)',
  '100+',
  ARRAY['わりかん保険','スマホ保険','アプリ完結申込','少額短期','AI審査'],
  3, 'low',
  2016, '東京都港区', true, now(), now()
),

-- ============================================================
-- Media JP / コンテンツ (3社)
-- ============================================================
(
  'niconico',
  'ニコニコ動画',
  'ニコニコ動画',
  'media',
  'https://www.nicovideo.jp',
  'ドワンゴ運営の動画コメント文化特化SNS。弾幕コメント・ニコ生・超会議・ボカロ文化発祥地。',
  '(KADOKAWAグループ TSE:9468)',
  '1000+',
  ARRAY['動画投稿','弾幕コメント','ニコニコ生放送','ニコニコチャンネル','超会議'],
  3, 'low',
  2006, '東京都文京区', true, now(), now()
),
(
  'ameba',
  'Ameba',
  'Ameba (サイバーエージェント)',
  'media',
  'https://ameba.jp',
  'サイバーエージェント運営のブログ・SNSプラットフォーム。芸能人ブログ・アメブロで国内最大級。',
  '(サイバーエージェント TSE:4751)',
  '500+',
  ARRAY['ブログ','アメブロ','インフルエンサー','フォロー機能','アメコイン'],
  4, 'low',
  2004, '東京都渋谷区', true, now(), now()
),
(
  'hatena',
  'はてな',
  'はてなブログ',
  'media',
  'https://hatenablog.com',
  'ブログ・ブックマーク・Mackerelを運営するテックカルチャー系メディア企業。TSE:3930。',
  '¥35億売上 (TSE:3930)',
  '200+',
  ARRAY['ブログ','はてなブックマーク','Mackerel(監視)','読書記録','ポイント'],
  5, 'medium',
  2001, '京都府京都市', true, now(), now()
),

-- ============================================================
-- Social Commerce / ライブコマース (2社)
-- ============================================================
(
  'poshmark',
  'Poshmark',
  'Poshmark',
  'e-commerce',
  'https://poshmark.com',
  'ファッション特化のソーシャルコマースプラットフォーム。米国最大級C2C古着マーケット。NASDAQ上場後Naver買収。',
  '(Naver $1.2B買収済)',
  '500+',
  ARRAY['古着売買','ライブショッピング','スタイリスト機能','Offers','シッピング自動化'],
  4, 'low',
  2011, 'Redwood City, USA', true, now(), now()
),
(
  'tiktok-shop',
  'TikTok Shop',
  'TikTok Shop',
  'e-commerce',
  'https://www.tiktok.com/business/tiktok-shop',
  'TikTok内のソーシャルコマース機能。ライブ配信×EC。東南アジアで急成長中。日本展開も2024年開始。',
  '(ByteDance $240B+)',
  '10000+',
  ARRAY['ライブコマース','動画EC','アフィリエイト','フルフィルメント','ショップ内広告'],
  5, 'high',
  2021, 'Singapore', true, now(), now()
),

-- ============================================================
-- AI Agent Platform (4社)
-- ============================================================
(
  'devin-cognition',
  'Devin (Cognition)',
  'Devin AI',
  'ai-platform',
  'https://cognition.ai',
  '世界初の完全自律AIソフトウェアエンジニア。PR作成・デバッグ・テスト・デプロイまで自律実行。',
  '$2B valuation (Series A $175M)',
  '50+',
  ARRAY['自律コーディング','PR自動作成','デバッグ','テスト自動化','GitHub連携'],
  6, 'high',
  2023, 'San Francisco, USA', true, now(), now()
),
(
  'jules-google',
  'Jules (Google)',
  'Jules by Google',
  'ai-platform',
  'https://jules.google',
  'Google DeepMindのAI開発エージェント。GitHubイシューを自動修正するコーディングエージェント。2025年GA。',
  '(Google/Alphabet NASDAQ:GOOGL)',
  '100000+',
  ARRAY['Issue自動修正','PR作成','コードレビュー','テスト実行','GitHub App'],
  6, 'high',
  2025, 'Mountain View, USA', true, now(), now()
),
(
  'factory-ai',
  'Factory AI',
  'Factory',
  'ai-platform',
  'https://www.factory.ai',
  'AIドローン(エージェント)による企業向けソフトウェア開発自動化。コードレビュー・ドキュメント・テストを自律化。',
  '$200M valuation (Series A $20M)',
  '50+',
  ARRAY['AI開発エージェント','コードレビュー自動化','ドキュメント生成','テスト自動化','Slack連携'],
  5, 'high',
  2023, 'San Francisco, USA', true, now(), now()
),
(
  'magic-ai',
  'Magic.dev',
  'Magic',
  'ai-platform',
  'https://magic.dev',
  'LTM-2 (Long Term Memory) モデルを持つAIコーディングエージェント。100万トークンコンテキスト対応。',
  '$1.5B valuation (Series A $145M)',
  '50+',
  ARRAY['長期記憶AIコーディング','コードベース全理解','ペアプロ','自律エージェント','100Mコンテキスト'],
  5, 'high',
  2023, 'San Francisco, USA', true, now(), now()
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
  '競合 140→155社化 Phase 3 Batch 5 (PS#4 S50)',
  'Crypto/Web3 (Coincheck/MetaMask) + Insurance JP (ライフネット/justInCase) + ' ||
  'Media JP (ニコニコ/Ameba/はてな) + Social Commerce (Poshmark/TikTok Shop) + ' ||
  'AI Agent Platform (Devin/Jules/Factory/Magic) = 15社追加。' ||
  '累計 155社 / 目標190社の 82%。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
