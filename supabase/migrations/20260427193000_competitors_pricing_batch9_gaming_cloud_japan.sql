-- PS#4 S74続: competitors pricing + japan_presence Batch 9 — ゲーム/クラウド/日本サービス等 15社
-- 2026-04-27 (累計: 146+15 = 161社 / 172社中 94%)
-- 対象: roblox / epic-games / sony-playstation / snowflake / twilio /
--        ubereats-japan / tabelog / suumo / ikyu / oura /
--        sagawa-express / luup-micromobility / graffer / runway / pika

-- ============================================================
-- ゲーミング / エンタメ (3社)
-- ============================================================

-- Roblox (freemium: 無料 / Robux課金)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '基本無料。Robux (ゲーム内通貨) 購入 $4.99〜。Roblox Premium $4.99/月〜 (毎月Robux付与)。UGCクリエイターエコノミー。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2021,
  japan_users_estimate = 80000000,
  japan_notes_ja     = '日本法人なし。日本でも若年層を中心に急成長。教育利用 (Roblox Education) で学校導入事例あり。メタバース・UGCゲームの代表格。'
WHERE id = 'roblox';

-- Epic Games (freemium: Fortnite無料 / アイテム課金)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'Fortnite無料。V-Bucks (課金通貨) $7.99〜。Unreal Engine 5は無料 (売上5%ロイヤルティ)。Epic Games Store 手数料12%。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2018,
  japan_notes_ja     = 'Epic Games Japan法人あり。Fortniteは日本でも人気。Unreal Engine 5 で国内ゲーム開発者に広く利用。Apple/Googleとの訴訟で注目。'
WHERE id = 'epic-games';

-- PlayStation (Sony) (freemium: PS Plus Essential $9.99/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 9.99,
  pricing_notes_ja   = 'PS Plus Essential $9.99/月。Extra $14.99/月 (カタログ追加)。Premium $17.99/月 (クラシック)。PSゲーム本体¥7,000〜¥9,000。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 1994,
  japan_users_estimate = 116000000,
  japan_notes_ja     = 'ソニー・インタラクティブエンタテインメント (SIE)。PS5 累計販売台数5600万台超。日本発ゲーム機の代表格。ウェルビーイング/スポーツ × PS Move 連携。'
WHERE id = 'sony-playstation';

-- ============================================================
-- データ / クラウド / 通信インフラ (2社)
-- ============================================================

-- Snowflake (enterprise: $2/クレジット〜)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '使用量課金 ($2〜/クレジット、ストレージ $23/TB/月)。30日間無料トライアル。エンタープライズは要見積。Snowpark AI機能。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2022,
  japan_notes_ja     = 'Snowflake Japan法人あり。国内データプラットフォーム需要で急成長。SoftBank/NTT/楽天グループ等導入事例。AI活用×データ分析の基盤として注目。'
WHERE id = 'snowflake';

-- Twilio (paid: 従量課金 $0.0075/SMS〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'SMS $0.0075/件〜 (日本向け $0.0817)。音声通話 $0.0150/分〜。WhatsApp/LINE等チャネル統合。Twilio Flex コンタクトセンター別途。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2019,
  japan_notes_ja     = 'Twilio Japan法人あり。国内スタートアップのSMS認証・プッシュ通知基盤として普及。LINEビジネス連携も可能。SendGrid (メール) も統合。'
WHERE id = 'twilio';

-- ============================================================
-- 日本 フードデリバリー / グルメ (2社)
-- ============================================================

-- Uber Eats Japan (paid: 注文ごと配送料 ¥50〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '配送料 ¥50〜 (Eats Pass会員¥49/月は無料配送)。サービス料 5〜15%。Eats Pass ¥698/月で無料配送対象。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2016,
  japan_users_estimate = 10000000,
  japan_notes_ja     = 'Uber Eats Japan合同会社。国内フードデリバリー最大手。出前館と市場二分。AI配達最適化・ヘルシー食提案。生活OS食事管理機能と競合。'
WHERE id = 'ubereats-japan';

-- 食べログ (freemium: プレミアム ¥400/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 2.70,
  pricing_notes_ja   = 'プレミアム会員 ¥400/月 (約$2.7)。通常は無料閲覧可。レストラン向け有料掲載プランあり。ぐるなびと並ぶ2大グルメサービス。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2005,
  japan_users_estimate = 100000000,
  japan_notes_ja     = 'カカクコム。月間PV10億超。星評価で飲食店格付けの文化を定着。AI検索・食べログMAGAZINEで情報収集競合。生活OS飲食ログ機能と競合。'
WHERE id = 'tabelog';

-- ============================================================
-- 日本 不動産 / 旅行 (2社)
-- ============================================================

-- SUUMO (free: 無料 / 広告収益モデル)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'ユーザー利用無料。不動産会社掲載課金モデル。SUUMO賃貸・マンション・注文住宅など多展開。AI物件提案機能開発中。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2009,
  japan_notes_ja     = 'リクルート。日本最大の不動産ポータル。HOME'SとAtHomeが競合2位3位。住まい管理・引越し費用比較で生活OS不動産機能と競合。'
WHERE id = 'suumo';

-- 一休.com (freemium: 一休プレミアム ¥550/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 3.70,
  pricing_notes_ja   = '一休.comプレミアム会員 ¥550/月 (特別優待・早割)。基本予約は無料。Yahoo!グループ。高級ホテル・レストランに特化。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 1999,
  japan_users_estimate = 5000000,
  japan_notes_ja     = 'ヤフー子会社。高級ホテル・旅館・レストランの予約サービス。JTBやじゃらんと競合。プレミアム体験ログで生活OS旅行機能と競合。'
WHERE id = 'ikyu';

-- ============================================================
-- ヘルスウェアラブル (1社)
-- ============================================================

-- Oura Ring (paid: Membership $5.99/月 + Ring $299〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 5.99,
  pricing_notes_ja   = 'Oura Ring Gen 3 $299〜 (リング本体)。Oura Membership $5.99/月 (詳細データ解析)。睡眠スコア・HRV・体温計測。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2022,
  japan_notes_ja     = '日本公式販売あり。$5.2B評価額。Apple Watch / Fitbit / Samsung Ring と競合。睡眠・体温・生理周期管理で健康管理機能と直接競合。'
WHERE id = 'oura';

-- ============================================================
-- 日本 物流 / モビリティ (2社)
-- ============================================================

-- 佐川急便 (paid: 荷物サイズ別 ¥850〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 5.70,
  pricing_notes_ja   = '飛脚宅急便 ¥850〜 (60サイズ)。法人契約で割引。SGホールディングス (東証プライム)。EC出荷・集荷サービス。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 1957,
  japan_notes_ja     = 'SGホールディングス。ヤマト運輸と並ぶ2大宅配会社。EC物流の主要プレイヤー。配送追跡AIとスマートロッカー展開中。EC側面で競合。'
WHERE id = 'sagawa-express';

-- LUUP (電動シェアサイクル/キックボード) (paid: ¥200/解錠+¥15/分)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 1.30,
  pricing_notes_ja   = '解錠料 ¥200+¥15/分。月額パス ¥1,180/月 (平日30分無料)。電動キックボード・電動自転車のシェアサービス。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2018,
  japan_users_estimate = 2000000,
  japan_notes_ja     = '株式会社Luup。東京・大阪・名古屋等都市部でシェア拡大。ソフトバンク/ヤマハ出資。マイクロモビリティで移動×健康×環境の3方向で競合。'
WHERE id = 'luup-micromobility';

-- ============================================================
-- GovTech / AI動画 (2社)
-- ============================================================

-- Graffer (行政手続きDX) (freemium: 個人無料 / 自治体向け有料)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '個人ユーザー無料。自治体向けSaaS (グラファー行政手続き/スマート申請) は要見積。住民票取得・引越し手続きのオンライン化。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2017,
  japan_notes_ja     = '株式会社グラファー。デジタル庁連携・マイナンバーカード活用。全国200以上の自治体導入。行政DX×個人のペーパーワーク削減で生活OS公的機能と競合。'
WHERE id = 'graffer';

-- Runway (AI video generation) (freemium: Basic 無料 / Standard $12/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 12.00,
  pricing_notes_ja   = 'Standard $12/月 (625クレジット/月)。Pro $28/月 (2250クレジット)。Gen-3 Alpha Turbo。Text/Image→Video AI。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。クリエイター・映像制作者に人気。Sora/Kling/Pika/Heygenとの競合激化。日本語テキスト→動画対応拡大中。'
WHERE id = 'runway';

-- ============================================================
-- AI動画生成 (1社)
-- ============================================================

-- Pika (AI video) (freemium: Basic 無料 / Standard $8/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 8.00,
  pricing_notes_ja   = 'Standard $8/月 (700クレジット)。Pro $28/月 (2000クレジット)。Pika 1.5/2.1 でリップシンク・音声追加・エフェクト。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。Pika Labs (Y Combinator/a16z/Spark Capital $55M)。Runway/Kling/Sora と競合。短尺SNS動画制作ユーザーに人気。'
WHERE id = 'pika';

-- ============================================================
-- seed achievement
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S74続: competitors pricing+japan_presence Batch9 — ゲーム/クラウド/日本サービス等 15社',
  'roblox/epic-games/sony-playstation/snowflake/twilio/ubereats-japan/tabelog/suumo/ikyu/oura/sagawa-express/luup-micromobility/graffer/runway/pika の pricing+japan_presence 充填。累計161社 (172社中94%)。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
