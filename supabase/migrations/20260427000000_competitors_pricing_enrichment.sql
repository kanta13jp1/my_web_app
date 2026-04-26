-- PS#4 S68: competitors pricing enrichment — pricing_tier / pricing_start_usd / pricing_notes_ja
-- 2026-04-26 (PS#4 次フェーズ: jp_strength全完結後の価格データ充実)
-- 対象: original 21 + 高脅威新規20社 計41社

-- ============================================================
-- 1. カラム追加
-- ============================================================
ALTER TABLE public.competitors
  ADD COLUMN IF NOT EXISTS pricing_tier       text CHECK (pricing_tier IN ('free', 'freemium', 'paid', 'enterprise')),
  ADD COLUMN IF NOT EXISTS pricing_start_usd  numeric,   -- 最安有料プラン (月額USD / NULLなら無料のみ)
  ADD COLUMN IF NOT EXISTS pricing_notes_ja   text;      -- 日本語価格メモ (¥換算・年払い条件等)

COMMENT ON COLUMN public.competitors.pricing_tier IS
  'free=完全無料 / freemium=無料+有料プランあり / paid=有料のみ / enterprise=要見積';
COMMENT ON COLUMN public.competitors.pricing_start_usd IS
  '最安有料プランの月額USD概算 (年払い換算)。NULL = 無料プランのみ存在 / 0 = 完全無料';
COMMENT ON COLUMN public.competitors.pricing_notes_ja IS
  '日本語価格補足 (¥換算・日本独自プラン・年払い割引率等)';

-- ============================================================
-- 2. Original 21 社 pricing seed
-- ============================================================

-- Notion (freemium: Free / Plus $16 / Business $18 / Enterprise 要見積)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 16.00,
  pricing_notes_ja = 'Plusプラン $16/月 (年払い$8/月)。Businessは$18/月。日本語UIあり。'
WHERE id = 'notion';

-- Evernote (freemium: Personal $14.99 / Professional $17.99)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 14.99,
  pricing_notes_ja = 'Personalプラン $14.99/月。無料プランは1デバイス制限あり。'
WHERE id = 'evernote';

-- MoneyForward (freemium: 無料 / プレミアム ¥500/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 3.30,
  pricing_notes_ja = 'プレミアムプラン ¥500/月 (約$3.30)。年払い¥5300で11ヶ月相当。'
WHERE id = 'moneyforward';

-- Slack (freemium: Pro $7.25/user/month / Business+ $12.50)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 7.25,
  pricing_notes_ja = 'Proプラン $7.25/user/月 (年払い)。日本円 約¥1,100/user/月。'
WHERE id = 'slack';

-- Chatwork (freemium: Business ¥600/user/月 / Enterprise ¥960)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 4.00,
  pricing_notes_ja = 'Businessプラン ¥600/user/月。無料プランはメンバー上限あり。'
WHERE id = 'chatwork';

-- Discord (freemium: Nitro $9.99/月 / Basic $2.99)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 2.99,
  pricing_notes_ja = 'Nitro Basic $2.99/月。本体コミュニティ機能は完全無料。'
WHERE id = 'discord';

-- LINE (free: LINE本体無料 / LINE WORKS有料)
UPDATE public.competitors SET
  pricing_tier = 'free', pricing_start_usd = 0,
  pricing_notes_ja = 'LINE本体は完全無料。法人向けLINE WORKS Lightは無料プランあり。'
WHERE id = 'line';

-- X / Twitter (freemium: Basic $3/月 / Premium $8 / Premium+ $22)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 3.00,
  pricing_notes_ja = 'X Premium (旧Blue) $8/月。日本では¥980/月。API利用は別途有料。'
WHERE id = 'x';

-- Facebook (free)
UPDATE public.competitors SET
  pricing_tier = 'free', pricing_start_usd = 0,
  pricing_notes_ja = 'Facebookは完全無料。広告収益モデル。Meta Business Suiteも無料。'
WHERE id = 'facebook';

-- Claude Code (paid: Pro $20/月 / Max $100)
UPDATE public.competitors SET
  pricing_tier = 'paid', pricing_start_usd = 20.00,
  pricing_notes_ja = 'Claude Proプラン $20/月で利用可。Max $100/月でコンテキスト拡張。API使用は従量課金。'
WHERE id = 'claude-code';

-- OpenAI Codex → paid (API usage-based)
UPDATE public.competitors SET
  pricing_tier = 'paid', pricing_start_usd = 20.00,
  pricing_notes_ja = 'ChatGPT Plus $20/月 or API従量課金。Codex CLI単体は無料(API keyが必要)。'
WHERE id = 'codex';

-- Claude for Work (enterprise)
UPDATE public.competitors SET
  pricing_tier = 'enterprise', pricing_start_usd = NULL,
  pricing_notes_ja = 'Claude for Work / Team $30/user/月。Enterpriseは要見積。'
WHERE id = 'claude-cowork';

-- OpenClaw (free / OSS)
UPDATE public.competitors SET
  pricing_tier = 'free', pricing_start_usd = 0,
  pricing_notes_ja = 'OSS・完全無料。Claude API keyが別途必要。'
WHERE id = 'openclaw';

-- Amazon (freemium: Amazon Prime ¥600/月 or ¥5900/年)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 14.99,
  pricing_notes_ja = 'Amazon Prime ¥600/月 (年払い¥5900)。AWS/Alexa+は別途。'
WHERE id = 'amazon';

-- Google (freemium: Workspace Individual $9.99/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 9.99,
  pricing_notes_ja = 'Google Workspace Individual $9.99/月。個人Gmailは無料。Gemini Advanced $19.99/月別途。'
WHERE id = 'google';

-- Microsoft (freemium: Microsoft 365 Personal $69.99/年=$5.83/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 5.83,
  pricing_notes_ja = 'Microsoft 365 Personal $69.99/年 (月払い$9.99)。Office基本機能は無料プランあり。'
WHERE id = 'microsoft';

-- GitHub (freemium: Pro $4/月 / Team $4/user/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 4.00,
  pricing_notes_ja = 'GitHub Pro $4/月。Copilot個人 $10/月別途。Enterpriseは$21/user/月。'
WHERE id = 'github';

-- ジョブカン (paid: ¥300/user/月~)
UPDATE public.competitors SET
  pricing_tier = 'paid', pricing_start_usd = 2.00,
  pricing_notes_ja = '勤怠管理 ¥300/user/月〜。HR統合プランは¥600/user/月〜。30日間無料お試し。'
WHERE id = 'jobcan';

-- netkeiba (freemium: プレミアム ¥550/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 3.60,
  pricing_notes_ja = 'netkeibaPREMIUM ¥550/月。過去10年全成績・高精度予想印が解放される。'
WHERE id = 'netkeiba';

-- Animaworks (paid)
UPDATE public.competitors SET
  pricing_tier = 'paid', pricing_start_usd = 39.00,
  pricing_notes_ja = '動画制作SaaSとして月額 ~¥6000相当。詳細はサイト参照。'
WHERE id = 'animaworks';

-- Liven (freemium)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = NULL,
  pricing_notes_ja = 'ライフログ系。基本機能無料、プレミアムプランあり。'
WHERE id = 'liven';

-- ============================================================
-- 3. 高脅威新規競合 pricing (overlap>=7 の主要20社)
-- ============================================================

-- Cursor (AI coding: freemium $20/month Pro)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 20.00,
  pricing_notes_ja = 'Proプラン $20/月 (500回高速モデル使用)。Businessは$40/user/月。'
WHERE id = 'cursor';

-- Windsurf (freemium $15/month Pro)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 15.00,
  pricing_notes_ja = 'Windsurf Pro $15/月。無料プランはFlowsクレジット制限あり。'
WHERE id = 'windsurf';

-- V0 by Vercel (freemium: $20/month Pro)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 20.00,
  pricing_notes_ja = 'v0 Pro $20/月 (200クレジット/月)。Teamは$30/user/月。'
WHERE id = 'v0';

-- Obsidian (freemium: Sync $4/月 / Publish $8/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 4.00,
  pricing_notes_ja = 'ローカルアプリ自体は無料。Obsidian Sync $4/月・Publish $8/月が有料アドオン。'
WHERE id = 'obsidian';

-- Logseq (free / OSS)
UPDATE public.competitors SET
  pricing_tier = 'free', pricing_start_usd = 0,
  pricing_notes_ja = 'オープンソース・完全無料。クラウド同期は開発中 (self-host可)。'
WHERE id = 'logseq';

-- Bear (paid: $2.99/月)
UPDATE public.competitors SET
  pricing_tier = 'paid', pricing_start_usd = 2.99,
  pricing_notes_ja = 'Bear Pro $2.99/月 ($29.99/年)。macOS/iOS専用。試用期間あり。'
WHERE id = 'bear-app';

-- Airtable (freemium: $20/user/月 Team)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 20.00,
  pricing_notes_ja = 'Teamプラン $20/user/月。無料は1000レコード/ベース制限。'
WHERE id = 'airtable';

-- Coda (freemium: $12/user/月 Pro)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 12.00,
  pricing_notes_ja = 'Proプラン $12/user/月。Doc Makerは無料。Teamは$36/user/月。'
WHERE id = 'coda';

-- HubSpot CRM (freemium: Starter $20/user/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 20.00,
  pricing_notes_ja = 'CRM基本機能無料。Starter $20/user/月。Professional $100/user/月。'
WHERE id = 'hubspot-crm';

-- Calendly (freemium: Essentials $10/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 10.00,
  pricing_notes_ja = 'Essentials $10/月。無料プランは1カレンダー・1イベントタイプ。'
WHERE id = 'calendly';

-- Zapier (freemium: Starter $29.99/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 29.99,
  pricing_notes_ja = 'Starterプラン $29.99/月 (750タスク/月)。Professionalは $73.50/月。'
WHERE id = 'zapier';

-- n8n (freemium: Starter $20/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 20.00,
  pricing_notes_ja = 'クラウドStarterプラン $20/月。OSSself-hostは無料 (制限あり)。'
WHERE id = 'n8n';

-- Linear (freemium: Standard $8/user/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 8.00,
  pricing_notes_ja = 'Standardプラン $8/user/月。Plusは $14/user/月。エンタープライズ要見積。'
WHERE id = 'linear';

-- Asana (freemium: Starter $13.49/user/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 13.49,
  pricing_notes_ja = 'Starterプラン $13.49/user/月 (年払い)。Advancedは$30.49/user/月。'
WHERE id = 'asana';

-- Trello (freemium: Standard $5/user/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 5.00,
  pricing_notes_ja = 'Standardプラン $5/user/月。Premiumは$10/user/月。無料プランは基本機能利用可。'
WHERE id = 'trello';

-- Todoist (freemium: Pro $4/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 4.00,
  pricing_notes_ja = 'Proプラン $4/月 (年払い)。無料プランは5プロジェクト制限。'
WHERE id = 'todoist';

-- Zoho CRM (freemium: Standard $14/user/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 14.00,
  pricing_notes_ja = 'Standardプラン $14/user/月 (年払い)。無料プランは3ユーザーまで。'
WHERE id = 'zoho-crm';

-- Cloudsign (paid: ¥11,000/月 standard plan)
UPDATE public.competitors SET
  pricing_tier = 'paid', pricing_start_usd = 72.00,
  pricing_notes_ja = '電子署名Standardプラン ¥11,000/月 (100送信/月)。ビジネスは¥17,000/月。'
WHERE id = 'cloudsign';

-- DocuSign (freemium: Personal $10/月)
UPDATE public.competitors SET
  pricing_tier = 'freemium', pricing_start_usd = 10.00,
  pricing_notes_ja = 'Personalプラン $10/月 (5通/月)。Standardは$25/user/月。'
WHERE id = 'docusign';

-- ============================================================
-- 4. 実績記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'competitors pricing enrichment — PS#4 S68',
  'competitors テーブルに pricing_tier / pricing_start_usd / pricing_notes_ja 3カラム追加。' ||
  'original 21社 + 高脅威新規20社 計41社の価格データを投入。' ||
  'フロントエンドの比較ページで価格ランキング・ティアフィルター機能が実装可能に。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
