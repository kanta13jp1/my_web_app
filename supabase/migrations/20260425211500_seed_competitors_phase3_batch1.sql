-- PS#4 S47: competitors Phase 3 Batch 1 — 80→95社 (2026-04-25)
-- 追加15社: Gaming/Entertainment 4 + Content/Media 2 + FinTech 3 + EC JP 3 + Learning 2 + AI JP 1
-- Phase 3: 80→120社 (PS#4 月次拡張継続)
-- 衝突回避: 211500 (Batch4=200000 / Win版WBS=210000 からの十分な間隔)

INSERT INTO public.competitors
  (id, display_name, category, website, description, market_cap, user_count,
   founded_year, hq_location, jp_strength, jp_weakness, sort_order)
VALUES

-- ============================================================
-- Gaming / Entertainment (4社) — エンタメ・ゲーム競合
-- ============================================================
(
  'nintendo',
  'Nintendo',
  'entertainment',
  'https://www.nintendo.com/',
  '世界的ゲームメーカー — Switch 140M台 / $50B / マリオ・ゼルダ IP 最強',
  50000000000, NULL, 1889, 'Kyoto, Japan',
  '日本発 / Switch はウェルビーイングゲーム強化中 / Switch Sports = 健康管理連携',
  'モバイルアプリ・SaaS 型生活管理ツールとの直接競合は限定的',
  88
),
(
  'sony-playstation',
  'Sony PlayStation',
  'entertainment',
  'https://www.playstation.com/',
  'PlayStation 5 / PS Network 1億MAU / PSPlus / $100B ソニーグループ子会社',
  100000000000, 100000000, 1994, 'Tokyo, Japan',
  'PlayStation Studios JP 強大 / PS App で生活・ゲーム連携 / Insomniac 傑作群',
  '生活管理 SaaS との統合は PlayStation Network 経由でのみ',
  89
),
(
  'roblox',
  'Roblox',
  'entertainment',
  'https://www.roblox.com/',
  'UGC メタバースゲームプラットフォーム — $22B / 60M+ DAU / 10代に圧倒的',
  22000000000, 60000000, 2006, 'San Mateo, CA',
  '教育コンテンツとの融合 / デジタルウェルビーイング機能強化中',
  '日本語コンテンツは英語より少ない / 10代以上では減退傾向',
  90
),
(
  'epic-games',
  'Epic Games',
  'entertainment',
  'https://www.epicgames.com/',
  'Fortnite / Unreal Engine 5 / Epic Games Store — $32B / 10億+ 登録',
  32000000000, 1000000000, 1991, 'Cary, NC',
  'Fortnite で Z世代の「生活の場」化 / Unreal でメタバース社会変革',
  '生活管理アプリとの接点は仮想空間コンセプトのみ',
  91
),

-- ============================================================
-- Content / Media (2社) — コンテンツ・メディア
-- ============================================================
(
  'netflix',
  'Netflix',
  'entertainment',
  'https://www.netflix.com/',
  'ストリーミング No.1 — $290B / 260M+ 会員 / Netflix Games + AI推薦',
  290000000000, 260000000, 1997, 'Los Gatos, CA',
  '日本語コンテンツ最多級 / 映画・アニメ・ドラマ全カバー / 生活時間の競合',
  'ゲーム・生産性管理との統合は限定的',
  92
),
(
  'spotify',
  'Spotify',
  'entertainment',
  'https://www.spotify.com/',
  '音楽 / Podcast / audiobook No.1 — $90B / 600M+ MAU / AI DJ搭載',
  90000000000, 600000000, 2006, 'Stockholm, Sweden',
  '日本語 Podcast 市場急拡大 / メンタルウェルネス系プレイリスト人気',
  'Apple Music / Line Music が日本ではそれなりの強さ',
  93
),

-- ============================================================
-- FinTech / Payments (3社)
-- ============================================================
(
  'paypal',
  'PayPal',
  'fintech',
  'https://www.paypal.com/',
  '決済・ウォレットの世界標準 — $65B / 426M アカウント / Venmo + PayPal AI',
  65000000000, 426000000, 1998, 'San Jose, CA',
  '越境 EC・フリーランス報酬受取の定番 / 日本も対応拡大中',
  '日本国内 B2B は Stripe / PAYJP に劣る / 手数料が高め',
  94
),
(
  'wise',
  'Wise (TransferWise)',
  'fintech',
  'https://wise.com/',
  '国際送金 × マルチ通貨ウォレット — $10B / 1600万顧客 / 旧 TransferWise',
  10000000000, 16000000, 2011, 'London, UK',
  '日本円→外貨の送金手数料が銀行比 最大8倍安い / 海外在住日本人に必須',
  '国内送金は PayPay 等に劣る / 法人向けは Airwallex に追い上げられている',
  95
),
(
  'paidy',
  'Paidy (AKA Paidy)',
  'fintech',
  'https://paidy.com/',
  'JP後払い(BNPL)最大手 — PayPal 3,000億円買収 / 700万+ ユーザー / 分割払い',
  NULL, 7000000, 2008, 'Tokyo, Japan',
  '日本初の後払い SaaS / PayPal 傘下で信用力 UP / 若年層・EC 購入で激増',
  '海外展開ゼロ / 競合 NP 後払い / atone / GMO 後払いに囲まれる',
  96
),

-- ============================================================
-- E-Commerce JP (3社) — 国内 EC
-- ============================================================
(
  'rakuten',
  '楽天 (Rakuten)',
  'e-commerce',
  'https://www.rakuten.co.jp/',
  '日本最大 EC+金融+モバイル スーパーアプリ — 時価総額 $10B / 楽天市場 5万店',
  10000000000, NULL, 1997, 'Tokyo, Japan',
  'ポイント経済圏で日本 No.1 / 金融・EC・旅行・モバイル全統合 / スーパーアプリ最強',
  '楽天モバイル赤字 / ポイント設計が複雑で若年層離れ / UI が古い',
  97
),
(
  'mercari',
  'メルカリ (Mercari)',
  'e-commerce',
  'https://www.mercari.com/',
  'フリマアプリ JP No.1 — 東証プライム / 2200万MAU / 米国展開中 / merpay',
  3000000000, 22000000, 2013, 'Tokyo, Japan',
  '日本スマホ世代に圧倒的浸透 / merpay で FinTech 展開 / メルカリ Shop B2C',
  '米国事業は赤字継続 / CtoCの不正商品対策コスト増大',
  98
),
(
  'base',
  'BASE',
  'e-commerce',
  'https://thebase.com/',
  '個人・小規模 EC 開設 No.1 JP — 東証グロース / 170万ショップ / BASE AI',
  300000000, NULL, 2012, 'Tokyo, Japan',
  '無料でECショップ即開設 / クリエイター・個人事業主向け最適解',
  '大規模 EC は Shopify / 楽天に劣る / 手数料 3%+決済 3.6%',
  99
),

-- ============================================================
-- Learning / Self-improvement (2社) — 学習・自己成長
-- ============================================================
(
  'duolingo',
  'Duolingo',
  'health',
  'https://www.duolingo.com/',
  '語学学習アプリ No.1 — $6.5B / 500M+ DL / Duolingo Max (GPT-4) / ゲーミフィケーション',
  6500000000, 500000000, 2011, 'Pittsburgh, PA',
  '日本語学習者への英語教材最多 / AI Max で習熟度判定 / Streak が習慣形成に直結',
  '有料 Duolingo Max $13.99/月 が普及率阻害 / 話す練習は弱い',
  100
),
(
  'coursera',
  'Coursera',
  'health',
  'https://www.coursera.org/',
  'MOOC 最大プラットフォーム — $2.5B / 148M 登録 / Google/IBM/Stanford 認定証',
  2500000000, 148000000, 2012, 'Mountain View, CA',
  '日本語字幕付きコース拡大 / LinkedIn と資格連携 / AI/データサイエンス需要急増',
  '完走率 5-10% / 日本語ネイティブコースは Udemy-JP に大幅に劣る',
  101
),

-- ============================================================
-- AI / Cloud JP (1社) — 国産 AI インフラ
-- ============================================================
(
  'sakura-internet',
  'さくらインターネット',
  'ai-coding',
  'https://www.sakura.ad.jp/',
  'JP 国産クラウド+AI — 東証プライム / 政府 GPU 整備事業 / H100 5,000枚 確保',
  300000000, NULL, 1999, 'Osaka, Japan',
  '国産クラウドで GDPR/個人情報保護法完全準拠 / 政府案件に強い / 低レイテンシ',
  'AWS/Azure/GCP に比べグローバルリーチは限定的 / AI サービス層はまだ薄い',
  102
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
  '競合 80→95 社化 Phase 3 Batch 1 (PS#4 S47)',
  'Gaming/Entertainment 4社(nintendo/sony-playstation/roblox/epic-games) + ' ||
  'Content 2社(netflix/spotify) + FinTech 3社(paypal/wise/paidy) + ' ||
  'EC JP 3社(rakuten/mercari/base) + Learning 2社(duolingo/coursera) + ' ||
  'AI JP 1社(sakura-internet) = 計15社追加 → 累計95社',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
