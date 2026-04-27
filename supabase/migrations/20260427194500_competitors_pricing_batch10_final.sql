-- PS#4 S74最終: competitors pricing + japan_presence Batch 10 — 残全社完結 22社
-- 2026-04-27 (累計: 161+22 = 183社 ※重複IDも含む全更新 / 実質172社 100%)
-- 対象: cohere-ai / criteo / curon / devin-cognition / google-health /
--        hrmos / hubspot / hugging-face / itandi / jalan /
--        kincone / kingoftime / moneyforward-cloud / money-tree /
--        perplexity-ai / pipedream / poshmark / replicate /
--        sakura-internet / toyota-connected / viz-ai / zoho

-- ============================================================
-- AI LLM 重複 ID (cohere-ai / devin-cognition / hugging-face / perplexity-ai) 4社
-- ============================================================

-- Cohere AI (freemium: Trial無料 / Production $3/1M tokens〜)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'Command R+ API $3/1M input tokens。Trial (無料枠) あり。Embed/Rerank/Classify API も提供。企業向けRAG特化。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。企業向けLLM (RAG・エンタープライズ検索) で注目。商用利用可能なモデル提供でGPT対抗。日本語モデル強化中。Salesforce/Oracle出資。'
WHERE id = 'cohere-ai';

-- Devin (Cognition AI) (enterprise: Teams $500/月)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = 500.00,
  pricing_notes_ja   = 'Teamsプラン $500/月 (ACUs付き)。Enterprise 要見積。SWEエージェント・GitHub統合・コードレビュー自動化。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。初の「AIソフトウェアエンジニア」として2024年衝撃的デビュー。SWEbench 13.86%達成。日本企業でも試験導入事例拡大中。'
WHERE id = 'devin-cognition';

-- Hugging Face (freemium: Pro $9/月) — hugging-face ID
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 9.00,
  pricing_notes_ja   = 'Pro $9/月 (優先GPU+private Spaces)。Enterprise $20/user/月。OSS AIモデルのハブ。Inference API無料枠あり。',
  japan_presence_level = 'growing',
  japan_notes_ja     = '日本法人なし。日本のAIエンジニア・研究者のモデルハブとして標準。rinna/cyberagent等日本語LLMも多数ホスト。'
WHERE id = 'hugging-face';

-- Perplexity AI (freemium: Pro $20/月) — perplexity-ai ID
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 20.00,
  pricing_notes_ja   = 'Pro $20/月 (GPT-4o/Claude/Gemini選択・Deep Research)。無料は基本検索のみ。引用付きAI回答が特徴。',
  japan_presence_level = 'growing',
  japan_notes_ja     = '日本法人なし。日本のリサーチ・学習用途で急速普及。SoftBank Visionファンド出資で日本展開加速予定。'
WHERE id = 'perplexity-ai';

-- ============================================================
-- CRM 重複 ID (hubspot / zoho) 2社
-- ============================================================

-- HubSpot (freemium: Starter $20/user/月) — hubspot ID
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 20.00,
  pricing_notes_ja   = 'CRM基本機能無料。Starter $20/user/月。Professional $100/user/月。HubSpot AI (Breeze) 搭載。',
  japan_presence_level = 'growing',
  japan_notes_ja     = 'HubSpot Japan法人あり。国内CRM/MA市場でSalesforce対抗として成長中。日本語サポート・日本語ドキュメント完備。スタートアップ向け割引あり。'
WHERE id = 'hubspot';

-- Zoho (freemium: CRM Free〜Standard $14/user/月) — zoho ID
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 14.00,
  pricing_notes_ja   = 'CRM Standard $14/user/月。Zoho One (45+アプリ) $37/user/月。Free 3ユーザーまで。コストパフォーマンス最高クラス。',
  japan_presence_level = 'growing',
  japan_notes_ja     = 'Zoho Japan法人あり。日本語対応のオールインワンビジネスSaaS。中小企業向けコスパ重視でHubSpot/Salesforce対抗。会計・HR・プロジェクト管理まで。'
WHERE id = 'zoho';

-- ============================================================
-- 日本 HR SaaS (3社)
-- ============================================================

-- HRMOS 勤怠 (freemium: 無料〜 ¥200/人/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 1.30,
  pricing_notes_ja   = '30名以下無料。¥200/人/月〜。SmartHR・freee人事と競合。シフト管理・残業アラート。ビズリーチグループ。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2015,
  japan_notes_ja     = 'ビズリーチ(Visional)グループ。勤怠管理から採用管理(HRMOS採用)まで統合HR SaaS。中小〜中堅企業向け。'
WHERE id = 'hrmos';

-- キンコーン (KINCONE) (paid: ¥200/人/月)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 1.30,
  pricing_notes_ja   = '¥200/人/月 (Suicaでの交通費精算・勤怠管理)。30日間無料トライアル。Slack/チャットワーク連携。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2013,
  japan_notes_ja     = 'レコロ株式会社。Suicaタッチで出退勤管理。交通費精算の自動化が特徴。中小企業向けシンプル勤怠管理。'
WHERE id = 'kincone';

-- KING OF TIME (paid: ¥300/人/月)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 2.00,
  pricing_notes_ja   = '¥300/人/月 (100名以上は割引)。顔認証・指静脈・ICカード対応。シフト管理・残業申請。30日無料。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2008,
  japan_users_estimate = 3500000,
  japan_notes_ja     = 'ヒューマンテクノロジーズ。国内勤怠管理SaaS最大手 (350万ユーザー超)。ジョブカン・freee人事と並ぶ3強。多様な打刻方法と柔軟な設定が強み。'
WHERE id = 'kingoftime';

-- ============================================================
-- 日本 会計 / 家計 (2社)
-- ============================================================

-- MoneyForward クラウド (paid: ¥3,980/月〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 26.50,
  pricing_notes_ja   = 'スモールビジネス ¥3,980/月 (クラウド会計+請求書)。法人プレミアム ¥6,980/月。freee会計と日本中小企業向け2強。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2013,
  japan_notes_ja     = 'マネーフォワード株式会社 (東証プライム)。法人向けバックオフィスSaaS (会計/経費/給与/請求)。個人向けMoneyForward MEとセット展開。'
WHERE id = 'moneyforward-cloud';

-- Moneytree (freemium: 無料 / Moneytree LINK 有料)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'Moneytreeアプリは無料。Moneytree LINK (API連携) は法人向け有料。銀行・証券・クレカ一括管理。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2012,
  japan_notes_ja     = '日豪合同会社。日本最大級の個人資産管理アプリ (480万DL)。マネーフォワードMEと直接競合。Open Finance API (LINK) で金融機関B2B展開。'
WHERE id = 'money-tree';

-- ============================================================
-- 日本 ヘルスケア / 不動産 / 旅行 (3社)
-- ============================================================

-- curon (クロン) オンライン診療 (paid: 診察料別)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'アプリ無料。オンライン診察料は各医院設定 (¥1,000〜3,000程度)。保険証連携・処方箋郵送・薬局連携。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2016,
  japan_users_estimate = 1700000,
  japan_notes_ja     = 'MICIN株式会社 (東証グロース)。日本最大級のオンライン診療サービス (170万ダウンロード超)。コロナ禍で急成長。生活OS健康管理×医療アクセス機能と競合。'
WHERE id = 'curon';

-- ITANDI BB (不動産テック) (enterprise: 自治体/不動産会社向け)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '不動産会社向けSaaS (内見予約・電子申込・電子契約)。月額要見積。エンドユーザーは無料。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2015,
  japan_notes_ja     = 'ITANDI株式会社 (NTTグループ)。内見・申込・契約のデジタル化で不動産DX推進。SUUMOやHOME''Sへの物件掲載連携。生活OS不動産管理と間接競合。'
WHERE id = 'itandi';

-- じゃらん (free: 無料 / 広告収益)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'ユーザー利用無料。宿泊施設掲載課金モデル。じゃらんポイント (1%〜)。楽天トラベルと国内2大旅行予約。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 1999,
  japan_users_estimate = 15000000,
  japan_notes_ja     = 'リクルート。国内旅行予約の主要プラットフォーム。楽天トラベルとシェアを争う。旅行ログ・おすすめスポット提案で生活OS旅行機能と競合。'
WHERE id = 'jalan';

-- ============================================================
-- クラウドホスティング / IoT / ヘルスAI (3社)
-- ============================================================

-- さくらインターネット (paid: ¥99/月〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 0.70,
  pricing_notes_ja   = 'さくらのレンタルサーバー ¥99/月〜。VPS ¥880/月〜。クラウド従量課金。高火力クラウド (GPU) ¥0.33/GPU-H〜。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 1999,
  japan_notes_ja     = '東証プライム上場。日本国内データセンター特化。経産省「特定重要物資」指定を受けAI向け高火力クラウド拡充。政府・自治体・教育機関に強い。'
WHERE id = 'sakura-internet';

-- トヨタコネクティッド (enterprise: Connected Car/IoT)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'T-Connect DCM搭載車は月額利用料 (車種により無料期間3年〜)。法人フリートサービスは別途。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2011,
  japan_notes_ja     = 'トヨタコネクティッド株式会社 (トヨタ×Microsoft合弁)。コネクテッドカーのデータ活用・AI予防保全。Mobility as a Service (MaaS) でモビリティOS競合。'
WHERE id = 'toyota-connected';

-- Viz.ai (enterprise: AI医療画像診断)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '病院向けエンタープライズ要見積。脳卒中CT/MRI AI診断。FDA承認取得済み。ルーティング自動化。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。米国病院採用が主。AI画像診断で医師の脳卒中早期発見を支援。日本の医療AI規制整備に伴い参入可能性あり。'
WHERE id = 'viz-ai';

-- ============================================================
-- ワークフロー / マーケットプレイス / ML (3社)
-- ============================================================

-- Pipedream (freemium: Free 10K events/月 / Advanced $29/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 29.00,
  pricing_notes_ja   = 'Freeは10K events/月。Advanced $29/月。Business $99/月。コード+ノーコードハイブリッド自動化。GitHub連携強み。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。開発者向けワークフロー自動化 (Zapier/n8n対抗)。TypeScript/Node.js ネイティブ実行。AI LLMアクション組み込みが強み。'
WHERE id = 'pipedream';

-- Poshmark (free: 販売手数料型)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'ユーザー無料。販売手数料 $15以下→$2.95 / $15超→20%。ソーシャルコマース機能強み。Naver傘下。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本未展開。米国・カナダ・英国等展開。NaverによるCtoCファッションアプリ。Mercari USとの競合分析で参照。日本でのCtoCコマース比較対象。'
WHERE id = 'poshmark';

-- Replicate (paid: GPU秒課金 $0.00014/sec〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'GPU秒課金 (A40 $0.00014/sec〜)。OSS AIモデルAPIとして人気。Stable Diffusion/LLaMA等すぐ使える。クレジット購入制。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。日本のAIエンジニア・プロトタイパーに利用。HuggingFace Spaces対抗。LoRA fine-tuning APIが強み。a16z出資。'
WHERE id = 'replicate';

-- ============================================================
-- Google Health (Google Fitの後継)
-- ============================================================

-- Google Health / Health Connect (free)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '完全無料。Pixel Watchと連携。Health Connect APIで健康データ一元管理。Fitbit統合済み (有料プレミアムあり $9.99/月)。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2013,
  japan_notes_ja     = 'Google Japan法人あり。Fitbit買収でウェアラブル強化。Android端末標準の健康データプラットフォーム。自分株式会社健康管理機能と直接競合。'
WHERE id = 'google-health';

-- Criteo (paid: CPC広告 オークション型)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'CPC課金 (最低予算なし)。リターゲティング広告特化。Commerce Max・Retail Media Network。AI入札最適化。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2012,
  japan_notes_ja     = 'Criteo Japan法人あり。日本最大のリターゲティング広告プラットフォーム。楽天広告・Yahoo!と連携。ECサイト向け広告配信で競合。'
WHERE id = 'criteo';

-- ============================================================
-- seed achievement
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S74最終: competitors pricing+japan_presence Batch10 — 残全社 22社 (100%完結)',
  'cohere-ai/devin-cognition/hugging-face/perplexity-ai/hubspot/zoho/hrmos/kincone/kingoftime/moneyforward-cloud/money-tree/curon/itandi/jalan/sakura-internet/toyota-connected/viz-ai/pipedream/poshmark/replicate/google-health/criteo の pricing+japan_presence 充填。全172社+重複ID pricing enrichment 完結。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
