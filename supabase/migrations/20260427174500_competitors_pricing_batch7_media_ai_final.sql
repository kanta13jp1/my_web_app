-- PS#4 S73 完結: competitors pricing + japan_presence Batch 7 — 日本メディア/AI推論/ノートSaaS等 15社
-- 2026-04-27 (累計: 116+15 = 131社 / 172社中 76%)
-- 対象: niconico / ameba / hatena / lifenet-insurance / groq-ai /
--        nvidia-geforce-now / xbox-cloud-gaming / harvey-ai / langchain-inc / kore-ai /
--        yamato-transport / graffer / mem-ai / anytype / craft-docs

-- ============================================================
-- 日本メディア / コンテンツ (3社)
-- ============================================================

-- niconico (freemium: 無料会員 / プレミアム ¥550/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 3.70,
  pricing_notes_ja   = 'プレミアム会員 ¥550/月 (約$3.7)。無料会員は混雑時視聴制限あり。ニコ生/ニコニコ動画/ニコニコ超会議。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2006,
  japan_users_estimate = 70000000,
  japan_notes_ja     = 'ドワンゴ/KADOKAWA。日本最大の動画/生放送プラットフォーム。アニメ・ゲーム・政治討論。コメント流れる UI は文化的アイコン。'
WHERE id = 'niconico';

-- Ameba (無料: ブログ/SNS無料 / Amebaマンガ課金あり)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'Amebaブログ・Ameba Ownd は無料。Amebaマンガはコイン課金。Ameba 芸能人ブログで圧倒的知名度。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2004,
  japan_users_estimate = 65000000,
  japan_notes_ja     = 'サイバーエージェント。Amebaブログは日本最大のブログサービス (6500万ユーザー)。Ameba Ownd でHP作成も。'
WHERE id = 'ameba';

-- Hatena (freemium: 無料/はてなブログ Pro ¥600/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 4.00,
  pricing_notes_ja   = 'はてなブログ Pro ¥600/月 (約$4)。はてなブックマーク・はてなID 無料。B!ブックマークで情報収集。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2001,
  japan_notes_ja     = '京都発IT企業。はてなブックマーク=日本最大のソーシャルブックマーク。エンジニアコミュニティで影響力大。'
WHERE id = 'hatena';

-- ============================================================
-- 日本 FinTech / 保険 (1社)
-- ============================================================

-- Lifenet Insurance (paid: ネット生保 月¥1600〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 11.00,
  pricing_notes_ja   = 'かぞくへの保険 月¥1,620〜 (約$11)。定期死亡保険・就労不能保険。ネット完結・中間コスト削減で低価格。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2008,
  japan_notes_ja     = '日本初のネット専業生命保険。東証グロース上場。財務管理観点で競合。スマホアプリで保険管理の簡便化を推進。'
WHERE id = 'lifenet-insurance';

-- ============================================================
-- AI 推論 / LLM インフラ (2社)
-- ============================================================

-- Groq AI (paid: API $0.05/1M tokens〜 / GroqCloud無料枠)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'GroqCloud 無料枠あり (Rate-limited)。Llama3-70B $0.59/1M tokens。LPU (Language Processing Unit) で世界最速推論。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。2024年高速推論で世界的注目。日本のAIエンジニアも利用。Cerebras と同様に GPU代替チップ路線。'
WHERE id = 'groq-ai';

-- ============================================================
-- クラウドゲーミング (2社)
-- ============================================================

-- NVIDIA GeForce Now (freemium: Free / Priority $9.99/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 9.99,
  pricing_notes_ja   = 'Priority $9.99/月 (RTX 4080 6時間セッション)。Ultimate $19.99/月 (RTX 4080 8時間)。PCゲームをクラウドで。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2022,
  japan_notes_ja     = '日本法人なし (NVIDIA Japan はある)。2022年日本正式提供開始。高速回線普及でクラウドゲーミング拡大中。'
WHERE id = 'nvidia-geforce-now';

-- Xbox Cloud Gaming (paid: Game Pass Ultimate $14.99/月)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 14.99,
  pricing_notes_ja   = 'Game Pass Ultimate $14.99/月 (PC/Xbox/クラウド)。100+ゲームが対象。GeForce Now と異なりMicrosoft独占タイトル強み。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2021,
  japan_notes_ja     = 'Microsoft (日本法人あり) のサービス。日本でも Xbox Game Pass の認知度向上。Activision Blizzard 買収でコンテンツ強化。'
WHERE id = 'xbox-cloud-gaming';

-- ============================================================
-- Enterprise AI / Legal AI (2社)
-- ============================================================

-- Harvey AI (enterprise: 法務AI 要見積)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'エンタープライズ法律事務所向け要見積。契約書レビュー・法的リサーチ・デューデリジェンス自動化。GPT-4基盤。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。欧米法律事務所中心に導入。日本の大手法律事務所でも試験導入事例あり。Legal Tech競合として注目。'
WHERE id = 'harvey-ai';

-- Kore AI (enterprise: コンバーサーショナルAI 要見積)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'エンタープライズ対話AI基盤。カスタマーサポート自動化・従業員向けボット。マルチチャネル (LINE/Teams/Slack) 対応。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。LINE Business Connect / Teams 統合でカスタマーサポートAI。日本の大企業向けAI導入で候補に上がる。'
WHERE id = 'kore-ai';

-- ============================================================
-- 物流 / モビリティ (1社)
-- ============================================================

-- Yamato Transport (ヤマト運輸) (paid: 荷物サイズ別 ¥940〜)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 6.30,
  pricing_notes_ja   = 'ヤマトホームコンビニエンス。宅急便 ¥940〜 (サイズ別)。法人契約で割引。EC連携でAI配送最適化。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 1976,
  japan_users_estimate = NULL,
  japan_notes_ja     = 'ヤマトホールディングス (東証プライム)。国内宅配シェア約45%。EC拡大で配送需要増加。Amazonとの提携も。EC側面で競合。'
WHERE id = 'yamato-transport';

-- ============================================================
-- ノート / PKM SaaS (3社)
-- ============================================================

-- Mem AI (paid: $14.99/月 / AI-powered note taking)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 14.99,
  pricing_notes_ja   = '$14.99/月。AIが自動でノートを整理・サーフェシング。GPT-4ベースのスマートメモリ。Notion代替として注目。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。英語ユーザーが中心。日本語対応は基本水準。PKM (Personal Knowledge Management) 市場で Notion/Obsidian と競合。'
WHERE id = 'mem-ai';

-- Anytype (freemium: 無料 / Teams $10/user/月予定)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '個人は無料 (ローカル優先)。Teams版は $10/user/月 (予定)。OSSベース / E2E暗号化 / オフライン完全動作。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。Notion代替OSS として日本のエンジニアにも注目。プライバシー重視ユーザー向け。まだ開発中の機能あり。'
WHERE id = 'anytype';

-- Craft Docs (freemium: Free / Pro $4.99/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 4.99,
  pricing_notes_ja   = 'Pro $4.99/月 (年払い)。Mac/iPhone/iPad専用デザイン重視ノート。Apple Design Award 2022受賞。',
  japan_presence_level = 'limited',
  japan_notes_ja     = '日本法人なし。Apple エコシステム使用者 (Mac/iPad) を中心に利用。日本語フォント対応OK。Notionよりシンプルなデザイン重視ツール。'
WHERE id = 'craft-docs';

-- ============================================================
-- seed achievement
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S73 完結: competitors pricing+japan_presence Batch7 (最終) — 日本メディア/AI推論/ノートSaaS等 15社',
  'niconico/ameba/hatena/lifenet-insurance/groq-ai/nvidia-geforce-now/xbox-cloud-gaming/harvey-ai/kore-ai/yamato-transport/mem-ai/anytype/craft-docs の pricing+japan_presence 充填。累計131社 (172社中76%)。pricing enrichment 7 Batch 完結。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
