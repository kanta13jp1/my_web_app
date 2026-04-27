-- PS#4 S71 続: competitors pricing + japan_presence Batch 3 — 日本 SaaS + Zoom/Teams/bolt-new
-- 2026-04-27 (Batch2 AI/SaaS 18社に続く第3弾)
-- 対象: freee / smarthr / yayoi / sansan / cybozu-kintone / base / carely / digi-smac /
--        zoom / typeform / bolt-new / factory-ai / descript

-- ============================================================
-- 日本ローカル SaaS (8社)
-- ============================================================

-- freee (freemium: スタータープラン ¥1980/月 / スタンダード ¥3980)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 13.00,
  pricing_notes_ja   = 'スタータープラン ¥1,980/月 (約$13)。スタンダード ¥3,980/月。30日無料トライアルあり。',
  japan_presence_level = 'dominant',
  japan_notes_ja     = '日本法人・東証グロース上場。中小企業会計No.1。270万以上の事業者が利用。freee会計/人事労務/開業。'
WHERE id = 'freee';

-- SmartHR (freemium: ライトプラン / 要見積エンタープライズ)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '従業員数・機能によるカスタム見積。小規模向けライトプランあり。HR基盤+ピープルアナリティクス。',
  japan_presence_level = 'dominant',
  japan_notes_ja     = '日本法人 (SmartHR株式会社)。シリーズD $140M調達。国内HR SaaSシェアNo.1。6万社以上導入。'
WHERE id = 'smarthr';

-- 弥生 (Yayoi) (paid: 弥生会計 ¥2090/月〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 14.00,
  pricing_notes_ja   = '弥生会計 セルフプラン ¥2,090/月 (約$14)。ベーシック ¥3,030/月。クラウド版 / インストール版あり。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 1987,
  japan_notes_ja     = '日本の中小企業会計シェアNo.1 (38年の歴史)。200万事業者利用。freeeと市場二分。KKRグループ。'
WHERE id = 'yayoi';

-- Sansan (paid: 名刺管理 要見積 / Eight無料)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '法人向け名刺管理は要見積 (従業員規模連動)。個人向け Eight は無料。Bill One / Contract One 別料金。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2009,
  japan_notes_ja     = '東証プライム上場 (Sansan株式会社)。国内大手企業の名刺管理でシェアNo.1。インド・シンガポール展開中。'
WHERE id = 'sansan';

-- Cybozu Kintone (paid: ライト ¥780/user/月 / スタンダード ¥1500/user)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 5.20,
  pricing_notes_ja   = 'ライトプラン ¥780/user/月 (約$5.2)。スタンダード ¥1,500/user/月。5ユーザー〜契約可。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2011,
  japan_notes_ja     = 'サイボウズ株式会社 (東証プライム)。kintone は国内ノーコード業務改善No.1。中小企業〜大企業まで30万社超導入。'
WHERE id = 'cybozu-kintone';

-- BASE (EC: スタータープラン 0円 / グロース ¥16580/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'スタータープラン0円 (売上手数料6.6%+¥30)。グロース ¥16,580/月 (売上手数料2.9%+¥30)。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2012,
  japan_notes_ja     = 'BASE株式会社 (東証グロース)。国内ネットショップ開設No.1 (220万ショップ)。個人・小規模事業者に強い。'
WHERE id = 'base';

-- Carely (健康管理クラウド: 要見積)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '従業員健康管理クラウド。従業員数・機能による要見積。産業医連携・ストレスチェック含む。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2018,
  japan_notes_ja     = 'iCARE株式会社。日本の健康経営支援SaaS。大手企業向け産業保健管理。ウェルネス管理領域で競合。'
WHERE id = 'carely';

-- DigiSMAC (デジタル変革SaaS: 要見積)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'クラウド型電子稟議・ワークフロー。中堅〜大手企業向け要見積。DX推進パッケージ提供。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2019,
  japan_notes_ja     = '日本のDX SaaS。電子稟議・申請・承認のデジタル化。Garoon/kintone連携あり。'
WHERE id = 'digi-smac';

-- ============================================================
-- グローバル SaaS (2社)
-- ============================================================

-- Zoom (freemium: Basic無料 / Pro $15.99/user/月 / Business $21.99)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 15.99,
  pricing_notes_ja   = 'Pro $15.99/user/月 (年払い)。Business $21.99/user/月。AI Companion (Copilot) 全プランで利用可に。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2018,
  japan_notes_ja     = '日本法人あり (Zoom Video Communications)。コロナ禍で急速普及、日本語完全対応。企業・教育機関で標準化。'
WHERE id = 'zoom';

-- Typeform (freemium: Free / Basic $29/月 / Plus $59/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 25.00,
  pricing_notes_ja   = 'Basic $25/月 (年払い)。Plus $50/月。AIによるフォーム自動生成機能追加。',
  japan_presence_level = 'limited',
  japan_launch_year  = NULL,
  japan_notes_ja     = '日本法人なし。デザイン重視フォームとして日本でもマーケター・スタートアップに人気。日本語対応あり。'
WHERE id = 'typeform';

-- ============================================================
-- AI 開発ツール (3社)
-- ============================================================

-- bolt.new by StackBlitz (freemium: Free / Pro $20/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 20.00,
  pricing_notes_ja   = 'Pro $20/月。無料プランはメッセージ上限あり。FullStack Web App をAIが自律生成。',
  japan_presence_level = 'limited',
  japan_launch_year  = NULL,
  japan_notes_ja     = '日本法人なし。2024年ノーコードAI開発として急成長。Supabase統合で日本のFlutter開発者にも注目。'
WHERE id = 'bolt-new';

-- Factory AI (AI ソフトウェアエンジニア: paid)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'エンタープライズ要見積。GitHub連携で自律的にPR作成・Issue解決。コードベース全体の理解AI。',
  japan_presence_level = 'limited',
  japan_launch_year  = NULL,
  japan_notes_ja     = '日本法人なし。2024年AI SWE競合として台頭。Devin対抗として一部日本企業も検討。'
WHERE id = 'factory-ai';

-- Descript (freemium: Free / Creator $24/月 / Business $40/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 24.00,
  pricing_notes_ja   = 'Creator $24/月。Business $40/月。動画・ポッドキャスト編集AI + 文字起こし + Overdub音声クローン。',
  japan_presence_level = 'limited',
  japan_launch_year  = NULL,
  japan_notes_ja     = '日本法人なし。英語コンテンツ制作者に人気。日本語文字起こし対応追加中。Podcaster/YouTuber に注目。'
WHERE id = 'descript';

-- ============================================================
-- seed achievement
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S71 続: competitors pricing+japan_presence Batch3 — 日本SaaS+Zoom+bolt-new等13社',
  'freee/smarthr/yayoi/sansan/cybozu-kintone/base/carely/digi-smac/zoom/typeform/bolt-new/factory-ai/descript の pricing_tier・pricing_start_usd・pricing_notes_ja・japan_presence_level・japan_notes_ja を充填。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
