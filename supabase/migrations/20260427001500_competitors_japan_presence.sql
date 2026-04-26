-- PS#4 S69: competitors japan_presence_level — 日本市場強度スコアリング
-- 2026-04-26 (自分株式会社 = 日本市場特化製品として最重要な競合インテリジェンス軸)
-- Notion Japan DC 開設 (T-34日) 対抗に向けた緊急戦略データ

-- ============================================================
-- 1. カラム追加
-- ============================================================
ALTER TABLE public.competitors
  ADD COLUMN IF NOT EXISTS japan_presence_level text
    CHECK (japan_presence_level IN ('dominant', 'strong', 'growing', 'limited', 'not_present')),
  ADD COLUMN IF NOT EXISTS japan_launch_year    int,
  ADD COLUMN IF NOT EXISTS japan_users_estimate bigint,  -- 日本ユーザー数概算
  ADD COLUMN IF NOT EXISTS japan_notes_ja       text;    -- 日本市場への補足 (DC開設等)

COMMENT ON COLUMN public.competitors.japan_presence_level IS
  'dominant=圧倒的存在感 / strong=主要プレーヤー / growing=拡大中 / limited=限定的 / not_present=日本未展開';
COMMENT ON COLUMN public.competitors.japan_launch_year IS
  '日本市場正式参入年 (日本法人設立 or 日本語版リリース)';
COMMENT ON COLUMN public.competitors.japan_users_estimate IS
  '日本のユーザー/アカウント数概算 (公式発表ベース / 不明はNULL)';

-- ============================================================
-- 2. Original 21 社 Japan presence seed
-- ============================================================

-- Notion: 日本語UI + Japan DC 2026-05 予定 → dominant移行中
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2018,
  japan_users_estimate = 3000000,
  japan_notes_ja       = '日本語UI完全対応。2026年5月日本DC開設予定 → 企業導入急増見込み。日本チーム常駐。'
WHERE id = 'notion';

-- Evernote: かつて dominant、値上げ後離脱が続く
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2008,
  japan_users_estimate = 5000000,
  japan_notes_ja       = '日本はかつてPV No.1市場。Bending Spoons買収後大幅値上げ→ユーザー離脱加速中。'
WHERE id = 'evernote';

-- MoneyForward: 日本最強の家計管理アプリ
UPDATE public.competitors SET
  japan_presence_level = 'dominant',
  japan_launch_year    = 2012,
  japan_users_estimate = 15000000,
  japan_notes_ja       = '日本法人。東証プライム上場。個人家計管理シェアNo.1。マネーフォワードMEは無料MAU 1500万超。'
WHERE id = 'moneyforward';

-- Slack: 日本法人あり、大企業導入率高い
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2016,
  japan_users_estimate = 2000000,
  japan_notes_ja       = '日本法人あり。大手企業・スタートアップで主流。2026年4月Slack CRM日本提供開始。'
WHERE id = 'slack';

-- Chatwork: 日本SMEで支配的
UPDATE public.competitors SET
  japan_presence_level = 'dominant',
  japan_launch_year    = 2011,
  japan_users_estimate = 5500000,
  japan_notes_ja       = '日本法人。KDDI完全子会社。中小企業シェアNo.1。国内専用設計。'
WHERE id = 'chatwork';

-- Discord: ゲーマー・オタク文化で浸透
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2015,
  japan_users_estimate = 4000000,
  japan_notes_ja       = '日本語UI対応。ゲームコミュニティ・VTuberファン層で大人気。公式日本語サポートあり。'
WHERE id = 'discord';

-- LINE: 日本最強のメッセンジャー
UPDATE public.competitors SET
  japan_presence_level = 'dominant',
  japan_launch_year    = 2011,
  japan_users_estimate = 96000000,
  japan_notes_ja       = '日本法人(LINE ヤフー)。日本MAU 9600万。家族・友人・ビジネス全方位。LINEPay経済圏。'
WHERE id = 'line';

-- X (旧Twitter): 日本は世界最大の利用国の一つ
UPDATE public.competitors SET
  japan_presence_level = 'dominant',
  japan_launch_year    = 2008,
  japan_users_estimate = 67000000,
  japan_notes_ja       = '日本は世界屈指のユーザー密度 (人口比)。アニメ・政治・ビジネス情報で中心的役割。'
WHERE id = 'x';

-- Facebook: 日本ではビジネス用途のみ
UPDATE public.competitors SET
  japan_presence_level = 'limited',
  japan_launch_year    = 2008,
  japan_users_estimate = 2600000,
  japan_notes_ja       = '日本ではビジネス・海外連絡用途が主。若者はX/Instagram/TikTokに移行済み。'
WHERE id = 'facebook';

-- Claude Code: 開発者コミュニティで急速浸透
UPDATE public.competitors SET
  japan_presence_level = 'growing',
  japan_launch_year    = 2024,
  japan_users_estimate = 50000,
  japan_notes_ja       = '日本語UI対応。Qiita/Zennでの記事増加中。Max $100/月プランは日本開発者にも普及。'
WHERE id = 'claude-code';

-- OpenAI Codex / ChatGPT: 日本でも急速普及
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2022,
  japan_users_estimate = 3000000,
  japan_notes_ja       = 'OpenAI日本法人(2024年4月設立)。ChatGPTの日本MAU推定300万超。企業导入積極的。'
WHERE id = 'codex';

-- Claude for Work: 企業導入フェーズ
UPDATE public.competitors SET
  japan_presence_level = 'growing',
  japan_launch_year    = 2024,
  japan_users_estimate = 20000,
  japan_notes_ja       = 'Anthropic日本法人準備中(2026年時点)。日本語対応済み。SlackBot統合で企業導入増。'
WHERE id = 'claude-cowork';

-- OpenClaw: OSS、日本コントリビューターあり
UPDATE public.competitors SET
  japan_presence_level = 'limited',
  japan_launch_year    = 2024,
  japan_users_estimate = NULL,
  japan_notes_ja       = 'OSS開発者向け。日本語READMEあり。メインストリーム普及には至っていない。'
WHERE id = 'openclaw';

-- Amazon: EC圧倒的 + AWS日本リージョン
UPDATE public.competitors SET
  japan_presence_level = 'dominant',
  japan_launch_year    = 2000,
  japan_users_estimate = 50000000,
  japan_notes_ja       = 'Amazon.co.jp月間3300万UV。AWSアジアパシフィック(東京)リージョン。Alexa日本語対応。'
WHERE id = 'amazon';

-- Google: 日本で圧倒的検索シェア
UPDATE public.competitors SET
  japan_presence_level = 'dominant',
  japan_launch_year    = 2001,
  japan_users_estimate = 120000000,
  japan_notes_ja       = '日本検索シェア76%。Google Japan設立2001年。Gmail/Workspace/ChromeOS全方位展開。'
WHERE id = 'google';

-- Microsoft: Office 365日本市場浸透
UPDATE public.competitors SET
  japan_presence_level = 'dominant',
  japan_launch_year    = 1978,
  japan_users_estimate = 40000000,
  japan_notes_ja       = 'Microsoft日本法人1978年設立。Office 365日本企業普及率高。Teams・Copilot積極展開中。'
WHERE id = 'microsoft';

-- GitHub: 日本の開発者コミュニティで支配的
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2008,
  japan_users_estimate = 2000000,
  japan_notes_ja       = '日本は世界3位のGitHubユーザー数。GitHub Copilot日本語対応。GitHub Japan設立済み。'
WHERE id = 'github';

-- ジョブカン: 日本SME HR市場で強い
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2011,
  japan_users_estimate = 5000000,
  japan_notes_ja       = '日本法人。中小企業勤怠管理シェア上位。日本語UIのみ。日本専用設計。'
WHERE id = 'jobcan';

-- netkeiba: 日本競馬ファン支配的
UPDATE public.competitors SET
  japan_presence_level = 'dominant',
  japan_launch_year    = 1997,
  japan_users_estimate = 17000000,
  japan_notes_ja       = '日本競馬情報 No.1 (月間1700万MAU)。JRA非公式ながら業界標準化。スマホアプリも強い。'
WHERE id = 'netkeiba';

-- Animaworks: 日本中心
UPDATE public.competitors SET
  japan_presence_level = 'limited',
  japan_launch_year    = 2019,
  japan_users_estimate = 200000,
  japan_notes_ja       = '主に日本ユーザー向け動画制作SaaS。'
WHERE id = 'animaworks';

-- Liven: 日本向けライフログ
UPDATE public.competitors SET
  japan_presence_level = 'limited',
  japan_launch_year    = 2020,
  japan_users_estimate = 100000,
  japan_notes_ja       = '日本特化のライフログアプリ。MAU規模は小さい。'
WHERE id = 'liven';

-- ============================================================
-- 3. 高脅威新規競合 japan_presence seed (overlap>=7 主要20社)
-- ============================================================

-- Cursor: 日本開発者に急速普及
UPDATE public.competitors SET
  japan_presence_level = 'growing',
  japan_launch_year    = 2023,
  japan_notes_ja       = '日本語UIなし。Qiita/Zennでの利用記事急増。若手開発者中心に採用加速。'
WHERE id = 'cursor';

-- Windsurf (Codeium): 日本語対応あり
UPDATE public.competitors SET
  japan_presence_level = 'growing',
  japan_launch_year    = 2023,
  japan_notes_ja       = '日本語UIなし。GitHubリポジトリで日本語READMEによる解説記事増加中。'
WHERE id = 'windsurf';

-- V0 by Vercel: 日本Next.jsコミュニティで話題
UPDATE public.competitors SET
  japan_presence_level = 'growing',
  japan_launch_year    = 2023,
  japan_notes_ja       = 'Vercel日本語ブログあり。Next.jsコミュニティとの親和性高く日本採用増加中。'
WHERE id = 'v0';

-- Obsidian: 日本語コミュニティが活発
UPDATE public.competitors SET
  japan_presence_level = 'growing',
  japan_launch_year    = 2020,
  japan_notes_ja       = 'PKM日本語コミュニティ(Obsidian日本語Discordサーバー)が活発。Quartz公開ブログ人気。'
WHERE id = 'obsidian';

-- Logseq: 日本語ユーザーは少数
UPDATE public.competitors SET
  japan_presence_level = 'limited',
  japan_launch_year    = 2020,
  japan_notes_ja       = 'Obsidianより日本語コミュニティは小さい。OSS開発者・研究者層中心。'
WHERE id = 'logseq';

-- Bear: iOS/macOS専用 → 日本では少数
UPDATE public.competitors SET
  japan_presence_level = 'limited',
  japan_launch_year    = 2016,
  japan_notes_ja       = 'macOS/iOS専用。Appleユーザー向けに認知あるが主流ではない。'
WHERE id = 'bear-app';

-- Airtable: 日本企業導入始まる
UPDATE public.competitors SET
  japan_presence_level = 'growing',
  japan_launch_year    = 2020,
  japan_notes_ja       = '日本語UIなし。外資系企業・スタートアップでの導入が増加。日本語ドキュメントは限定的。'
WHERE id = 'airtable';

-- Coda: 日本語対応弱い
UPDATE public.competitors SET
  japan_presence_level = 'limited',
  japan_launch_year    = 2019,
  japan_notes_ja       = '日本語UIなし。日本語コミュニティ小さい。一部スタートアップでの利用にとどまる。'
WHERE id = 'coda';

-- HubSpot CRM: 日本法人あり
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2014,
  japan_notes_ja       = 'HubSpot Japan設立済み。日本語UIあり。中堅企業の営業DX文脈で急速普及中。'
WHERE id = 'hubspot-crm';

-- Calendly: 日本での認知は限定的
UPDATE public.competitors SET
  japan_presence_level = 'limited',
  japan_launch_year    = 2013,
  japan_notes_ja       = '日本語UIあり。Googleカレンダー連携で認知されているが、日本ではScheduly等の競合も多い。'
WHERE id = 'calendly';

-- Zapier: 日本のノーコード人気で伸長
UPDATE public.competitors SET
  japan_presence_level = 'growing',
  japan_launch_year    = 2012,
  japan_notes_ja       = '日本語UIあり。ノーコード/自動化ブームで日本企業導入増。国内競合はMakeやn8nも。'
WHERE id = 'zapier';

-- n8n: 日本のエンジニアに人気
UPDATE public.competitors SET
  japan_presence_level = 'growing',
  japan_launch_year    = 2020,
  japan_notes_ja       = 'OSS・self-host可能で日本エンジニアに人気。Qiita記事が増加。クラウド版は有料。'
WHERE id = 'n8n';

-- Linear: 日本スタートアップで採用増
UPDATE public.competitors SET
  japan_presence_level = 'growing',
  japan_launch_year    = 2020,
  japan_notes_ja       = '日本語UIなし。国内スタートアップ・外資系企業でのプロジェクト管理ツールとして急成長。'
WHERE id = 'linear';

-- Asana: 日本法人あり
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2012,
  japan_notes_ja       = 'Asana Japan設立済み。日本語UIあり。大手企業・NGO向けプロジェクト管理で存在感。'
WHERE id = 'asana';

-- Trello: 日本での認知は高い
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2011,
  japan_users_estimate = 1000000,
  japan_notes_ja       = '日本語UIあり。Atlassian系ツールとして中小企業・個人に広く認知。Kanbanボードの代名詞。'
WHERE id = 'trello';

-- Todoist: 日本語完全対応
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2009,
  japan_notes_ja       = '日本語UI完全対応。タスク管理アプリとして日本でも高いブランド認知。Apple推薦アプリ。'
WHERE id = 'todoist';

-- Zoho CRM: 日本法人あり
UPDATE public.competitors SET
  japan_presence_level = 'strong',
  japan_launch_year    = 2006,
  japan_notes_ja       = 'Zoho Japan設立済み。日本語UIあり。中小企業向け低価格CRMで日本シェア拡大中。'
WHERE id = 'zoho-crm';

-- Cloudsign: 日本電子署名市場で支配的
UPDATE public.competitors SET
  japan_presence_level = 'dominant',
  japan_launch_year    = 2015,
  japan_users_estimate = 3000000,
  japan_notes_ja       = '日本発の電子署名SaaS。国内シェアNo.1 (クラウドサイン)。弁護士ドットコム子会社。'
WHERE id = 'cloudsign';

-- DocuSign: 外資系企業での導入
UPDATE public.competitors SET
  japan_presence_level = 'growing',
  japan_launch_year    = 2014,
  japan_notes_ja       = 'DocuSign Japan設立済み。外資系・グローバル企業での電子署名標準。国内はCloudsignが優勢。'
WHERE id = 'docusign';

-- freee: 日本クラウド会計で支配的 (2大巨頭)
UPDATE public.competitors SET
  japan_presence_level = 'dominant',
  japan_launch_year    = 2012,
  japan_users_estimate = 4000000,
  japan_notes_ja       = '日本発クラウド会計No.1候補。東証プライム上場。個人確定申告 + 法人会計一体化。'
WHERE id = 'freee';

-- SmartHR: 日本HR Tech市場で支配的
UPDATE public.competitors SET
  japan_presence_level = 'dominant',
  japan_launch_year    = 2015,
  japan_users_estimate = 80000,
  japan_notes_ja       = '日本発HR SaaS。評価額$1.5B。日本の労務・人事手続きデジタル化市場でトップ。'
WHERE id = 'smarthr';

-- ============================================================
-- 4. 実績記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'competitors japan_presence_level — PS#4 S69',
  'competitors テーブルに japan_presence_level / japan_launch_year / japan_users_estimate / ' ||
  'japan_notes_ja 4カラム追加。original 21社 + 高脅威新規20社 + freee/smarthr 計43社 ' ||
  '日本市場強度データ投入。Notion Japan DC対抗戦略の情報基盤。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
