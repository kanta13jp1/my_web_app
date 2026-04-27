-- PS#4 S73: competitors pricing + japan_presence Batch 5 — EC/FinTech/エンタメ/AI インフラ 15社
-- 2026-04-27 (累計: 40+18+13+15+15 = 101社 / 172社中 59%)
-- 対象: rakuten / coincheck / paidy / nintendo / netflix / spotify / paypal / wise /
--        telegram / magic-ai / cerebras-systems / google-ads / progate / together-ai / drata

-- ============================================================
-- 日本 EC / FinTech (5社)
-- ============================================================

-- Rakuten (freemium: 楽天市場出店 月4万円〜 / 個人サービス多数無料)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '楽天市場出店 月約4万円〜 (手数料別途)。楽天証券/銀行/保険等は無料〜要見積。楽天エコシステム全体でロイヤルティ強化。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 1997,
  japan_users_estimate = 130000000,
  japan_notes_ja     = '日本最大EC・ポイントエコシステム。楽天証券1000万口座超。楽天モバイル・保険・銀行・旅行統合。東証プライム上場。'
WHERE id = 'rakuten';

-- Coincheck (freemium: 取引無料 / スプレッド収益モデル)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '口座開設・維持費無料。取引所手数料 Maker/Taker 0%。販売所スプレッドで収益。NFT・レンディング・積立サービスあり。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2012,
  japan_users_estimate = 2300000,
  japan_notes_ja     = '日本最大級仮想通貨取引所 (口座数 230万)。マネックスグループ傘下。ビットコイン積立の先駆者。金融庁登録済。'
WHERE id = 'coincheck';

-- Paidy (BNPL: ユーザー無料 / 翌月まとめ払い)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'ユーザー利用無料。3回/6回払いは手数料 年率6%(最大)。加盟店手数料は別途。PayPal Group傘下。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2014,
  japan_users_estimate = 10000000,
  japan_notes_ja     = '日本最大 BNPL (後払い決済) — 1000万ユーザー超。2021年 PayPal に $2.7B で売却。Amazon Japan で利用可。'
WHERE id = 'paidy';

-- PayPal (freemium: 送金無料 / 商取引 2.9%+固定費)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '個人間送金無料 (国内)。EC 決済 3.6%+40円 (標準)。PayPal Checkout で EC 導入簡単。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2004,
  japan_notes_ja     = 'PayPal Pte. Ltd. 日本法人あり。国際送金・海外EC決済で利用多い。国内EC ではPayPayに押され気味。'
WHERE id = 'paypal';

-- Wise (freemium: 受取無料 / 送金 0.3〜2%)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '口座開設無料。送金手数料 0.3〜2% (金融機関比80%安い傾向)。Wise Business は月3USD。日本円↔外貨に強い。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2018,
  japan_notes_ja     = '日本資金移動業者登録済。フリーランス・越境EC・海外在住者の主要送金手段。日本語サポート充実。'
WHERE id = 'wise';

-- ============================================================
-- エンタメ / コンテンツ (3社)
-- ============================================================

-- Nintendo (paid: Switch ゲーム $70 / NSO $20/年)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 4.00,
  pricing_notes_ja   = 'Nintendo Switch Online ¥2400/年 (個人)。ゲーム本体 ¥7000〜¥8000。ウェルビーイング系 Switch Sports 連携。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 1889,
  japan_users_estimate = 30000000,
  japan_notes_ja     = '京都本社・東証プライム上場。Switch 140M台出荷。Nintendo Museum 開館 (2024)。健康・ウェルネスに Switch Sports で参入。'
WHERE id = 'nintendo';

-- Netflix (paid: 広告あり $6.99/月 / スタンダード $15.49/月 / プレミアム $22.99)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 7.00,
  pricing_notes_ja   = '広告あり ¥790/月。スタンダード ¥1590/月。プレミアム ¥1980/月。日本語コンテンツ充実 (オリジナル多数)。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2015,
  japan_users_estimate = 10000000,
  japan_notes_ja     = '日本法人あり。日本向けオリジナルコンテンツ多数 (深夜特急・First Love 等)。アニメ配信強化中。視聴時間競合。'
WHERE id = 'netflix';

-- Spotify (freemium: Free (広告あり) / Individual $10.99/月 / Family $16.99)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 10.99,
  pricing_notes_ja   = 'Individual $10.99/月。Family $16.99/月。Student $5.99/月。AI DJ・AI Playlist等AI機能充実。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2016,
  japan_users_estimate = 10000000,
  japan_notes_ja     = '日本法人あり (Spotify Japan)。音楽・Podcast 合わせ日本で急成長。Voicyとの競合でPodcast市場争奪中。'
WHERE id = 'spotify';

-- ============================================================
-- コミュニケーション (1社)
-- ============================================================

-- Telegram (free: 完全無料 / Premium $5/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 5.00,
  pricing_notes_ja   = 'Premium $5/月 (追加容量・高速DL・ステッカー等)。本体は完全無料。暗号通貨統合 (TON) あり。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2021,
  japan_notes_ja     = '日本語対応あり。2021年プライバシー意識高まりで日本ユーザー急増。コミュニティ機能が強い。LINE代替として関心増。'
WHERE id = 'telegram';

-- ============================================================
-- AI インフラ / 推論 (3社)
-- ============================================================

-- Magic AI (magic.dev) (paid: エンタープライズ要見積)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'エンタープライズ要見積。Long Term Memory (LTM) アーキテクチャで100M トークンコンテキスト。AI SWEエージェント。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。2024年 AI SWE エージェント競合として台頭。Devin/Factory 対抗。日本企業採用はまだ初期段階。'
WHERE id = 'magic-ai';

-- Cerebras Systems (enterprise: Cloud API $0.60/1M tokens〜)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'Cerebras Cloud API $0.60/1M tokens〜 (Llama3)。超高速推論 (18x faster than GPU)。WSE-3 チップ独自開発。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。2024年 IPO申請。AI推論高速化技術で研究機関・大企業から注目。日本法人設立準備中との報道。'
WHERE id = 'cerebras-systems';

-- Together AI (paid: API従量課金 $0.20/1M tokens〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'API $0.20/1M tokens〜 (Llama/Mistral等)。Open Source AIの推論プラットフォーム。Fine-tuning API あり。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。OpenソースLLM推論基盤として研究者・スタートアップに人気。日本のAI研究者も利用。'
WHERE id = 'together-ai';

-- ============================================================
-- 広告 / デジタルマーケ / コンプライアンス (3社)
-- ============================================================

-- Google Ads (paid: 最低予算なし / クリック課金)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '最低予算なし。クリック課金 (業種平均 ¥50〜¥1000/クリック)。Google広告 = 検索/YouTube/ディスプレイ統合。',
  japan_presence_level = 'dominant',
  japan_notes_ja     = 'Google Japan法人。日本のデジタル広告市場シェア No.1 (約35%)。Yahoo!広告と二分。生活OS側面として競合。'
WHERE id = 'google-ads';

-- Progate (freemium: 無料体験 / Pro月¥1078/年¥10780)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 7.50,
  pricing_notes_ja   = 'Pro ¥1,078/月 (約$7.5)。年払い ¥10,780。HTML/CSS/Python/Ruby/JavaScript等21コース。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2014,
  japan_users_estimate = 2000000,
  japan_notes_ja     = '日本発のコーディング学習サービス。200万ユーザー超。英語・インド版も展開。AI大学と直接競合するコンテンツ領域。'
WHERE id = 'progate';

-- Drata (enterprise: SOC2/ISO/HIPAA自動化 $25k/年〜)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'スタートアップ向け $25k/年〜。エンタープライズ要見積。SOC2・ISO27001・HIPAA・GDPR自動化SaaS。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。ISO27001/ISMS 取得支援SaaS として日本でも徐々に採用増。Vanta と直接競合する。'
WHERE id = 'drata';

-- ============================================================
-- seed achievement
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S73: competitors pricing+japan_presence Batch5 — EC/FinTech/エンタメ/AIインフラ 15社',
  'rakuten/coincheck/paidy/paypal/wise/nintendo/netflix/spotify/telegram/magic-ai/cerebras-systems/together-ai/google-ads/progate/drata の pricing_tier・pricing_start_usd・pricing_notes_ja・japan_presence_level・japan_notes_ja 充填。累計101社 (172社中59%)。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
