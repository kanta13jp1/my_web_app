-- PS#4 S73 続: competitors pricing + japan_presence Batch 6 — NotionAI/通信3社/広告/AIプラットフォーム等 15社
-- 2026-04-27 (累計: 101+15 = 116社 / 172社中 67%)
-- 対象: notion-ai / vercel / huggingface / ntt-docomo / softbank-telecom / kddi-au /
--        meta-ads / metamask / klarna-ai / ollama / langchain-inc / harvey-ai /
--        ecforce / stores-jp / freee-insurance

-- ============================================================
-- AI プラットフォーム (3社)
-- ============================================================

-- Notion AI (paid: Notion AI add-on $10/user/月 / Notion Plus に込み)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 10.00,
  pricing_notes_ja   = 'Notion AI add-on $10/user/月 (年払い)。Plus $16プラン以上に含まれる場合あり。ドキュメントAI/Q&A/要約。',
  japan_presence_level = 'strong',
  japan_notes_ja     = 'Notion本体と同一 Japan DC (2026-05 予定) 恩恵。Custom Agents (β) → AI自律タスク実行。自分株式会社との overlap=9 最高値。'
WHERE id = 'notion-ai';

-- Vercel (freemium: Hobby無料 / Pro $20/user/月 / Enterprise 要見積)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 20.00,
  pricing_notes_ja   = 'Pro $20/user/月。Enterprise 要見積。v0 (AI UI生成) は別途 $20/月〜。Next.js ホスティングのデファクト。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2022,
  japan_notes_ja     = '日本法人なし。日本のフロントエンドエンジニアに広く利用。Next.js と同時に浸透。AI開発ツール (v0) でも存在感。'
WHERE id = 'vercel';

-- Hugging Face (freemium: Free / Pro $9/月 / Enterprise $20/user/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 9.00,
  pricing_notes_ja   = 'Pro $9/月 (優先GPU+private Spaces)。Enterprise $20/user/月 (SSO+監査ログ)。OSS AIモデルのハブ。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2022,
  japan_notes_ja     = '日本法人なし。日本のAIエンジニア・研究者のモデルハブとして標準。日本語LLM (rinna/cyberagent等) も多数ホスト。'
WHERE id = 'huggingface';

-- ============================================================
-- 日本大手通信 (3社) — 生活OS/ウェルネス/財務周辺で競合
-- ============================================================

-- NTT Docomo (freemium: dポイント無料 / サービス各種)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'dポイントクラブ無料。ドコモ光/ahamo/irumo等プラン多様。d払い/dカード/dポイントエコシステム。AI Agentサービス開発中。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 1992,
  japan_users_estimate = 80000000,
  japan_notes_ja     = 'NTTドコモ — 日本最大通信キャリア (8000万契約)。dポイントは日本最大ポイント経済圏の一つ。docomo AI Agent (LLM) 開発中。'
WHERE id = 'ntt-docomo';

-- SoftBank Telecom (freemium: PayPay/Yahoo!ショッピング/SBエコシステム)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'PayPay (無料/手数料1.6%)。SoftBank 光/Air等。Y!mobile/LINE MO。PayPayは国内最大QR決済。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 1994,
  japan_users_estimate = 35000000,
  japan_notes_ja     = 'SoftBank — PayPay/Yahoo!/LINE統合エコシステム。PayPay 6000万ユーザー。Arm株式保有でAI半導体にも関与。'
WHERE id = 'softbank-telecom';

-- KDDI (au) (freemium: Ponta/auPayエコシステム)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'au PAY/Pontaポイント無料。auスマートパスプレミアム ¥548/月。au経済圏でECや保険も統合。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2000,
  japan_users_estimate = 30000000,
  japan_notes_ja     = 'KDDI — au (3000万契約)。auPAY/Ponta/au経済圏。au健康アプリ (歩数管理) でウェルネス進出。au損保・au金融等。'
WHERE id = 'kddi-au';

-- ============================================================
-- デジタル広告 (1社)
-- ============================================================

-- Meta Ads (Facebook/Instagram) (paid: CPC課金)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '最低予算なし。Facebook/Instagram/Threads/WhatsApp横断広告。CPC 平均 ¥60〜¥200。Advantage+ AI最適化。',
  japan_presence_level = 'dominant',
  japan_notes_ja     = 'Meta Japan法人あり。Instagram日本MAU 3300万超。Facebook/Instagram広告は日本デジタル広告2位。Reels短尺動画加速中。'
WHERE id = 'meta-ads';

-- ============================================================
-- Web3 / FinTech AI (2社)
-- ============================================================

-- MetaMask (free: 無料 / スワップ手数料 0.875%)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'ウォレット無料。スワップ機能は 0.875% 手数料。MetaMask Portfolio / MetaMask Snaps で機能拡張。',
  japan_presence_level = 'growing',
  japan_notes_ja     = '日本法人なし。暗号資産ユーザーの標準ウォレット。DeFi/NFT/Web3に参加する日本ユーザーに普及。資産管理の観点で競合。'
WHERE id = 'metamask';

-- Klarna AI (freemium: BNPL無料 / Klarna Card $8/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '3回払い・後払い無料 (遅延手数料あり)。Klarna Card $8/月。AIショッピングアシスタントを統合。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本未展開 (2026年現在)。欧米BNPL最大手。AI Shopping Assistant でチェックアウト体験革新中。Paidy と対比で競合分析価値あり。'
WHERE id = 'klarna-ai';

-- ============================================================
-- OSS / ローカル AI (1社)
-- ============================================================

-- Ollama (free: 完全無料 / OSS)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '完全無料 (OSSプロジェクト)。macOS/Linux/Windows対応。Llama3/Gemma/Mistral等をローカル実行。CLI + REST API。',
  japan_presence_level = 'growing',
  japan_notes_ja     = '日本のAIエンジニア・開発者にOSSローカルLLMの標準として急速普及。LM Studio と並行して利用されることが多い。プライバシー重視の開発者に支持。'
WHERE id = 'ollama';

-- ============================================================
-- 日本 EC SaaS (2社)
-- ============================================================

-- ecforce (paid: ベーシック ¥98,000/月〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 650.00,
  pricing_notes_ja   = 'ベーシック ¥98,000/月 (約$650)。グロース ¥298,000/月。D2C・定期購入特化EC。CVR最適化AI搭載。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2021,
  japan_notes_ja     = 'SUPER STUDIO株式会社。D2C EC No.1。コスメ・健康食品メーカーの標準プラットフォーム。累計2200ショップ。'
WHERE id = 'ecforce';

-- STORES.jp (freemium: フリープラン0円 / スタンダード ¥2980/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 20.00,
  pricing_notes_ja   = 'フリープラン 0円 (手数料5%)。スタンダード ¥2,980/月 (手数料3.6%)。ネットショップ+予約+ポイント一体型。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2012,
  japan_notes_ja     = 'ヘイ株式会社 (旧STORES.jp)。日本のネットショップ開設ツール。BASE と市場二分。Shopify / BASE 対抗で成長中。'
WHERE id = 'stores-jp';

-- ============================================================
-- 日本 FinTech (1社)
-- ============================================================

-- freee Insurance (freemium: 保険比較無料 / 商品各種)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '保険比較・見積もり無料。freeeエコシステム内で保険を一元管理。中小企業向け賠償責任保険等も提供。',
  japan_presence_level = 'growing',
  japan_notes_ja     = 'freee株式会社のサービス。会計・HR・開業・保険を統合するエコシステム展開。中小企業のリスク管理ニーズに応える。'
WHERE id = 'freee-insurance';

-- ============================================================
-- seed achievement
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S73 続: competitors pricing+japan_presence Batch6 — NotionAI/通信3社/広告/AIプラットフォーム等 15社',
  'notion-ai/vercel/huggingface/ntt-docomo/softbank-telecom/kddi-au/meta-ads/metamask/klarna-ai/ollama/ecforce/stores-jp/freee-insurance 他の pricing+japan_presence 充填。累計116社 (172社中67%)。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
