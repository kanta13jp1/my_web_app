-- PS#4 S71: competitors pricing + japan_presence Batch 2 — AI/SaaS 18社
-- 2026-04-27 (comparison_page Phase A+B デプロイ後、pricing/japan_presence UI反映を最大化)
-- 対象: openai / anthropic / perplexity / mistral / cohere / replit / lovable / devin /
--        figma / canva / elevenlabs / databricks / clickup / atlassian / dropbox /
--        duolingo / calm / bluesky

-- ============================================================
-- AI チャット / LLM (5社)
-- ============================================================

-- OpenAI (freemium: Free GPT-4o mini / Plus $20 / Pro $200 / Team $30)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 20.00,
  pricing_notes_ja   = 'ChatGPT Plus $20/月。Pro $200/月 (o1 pro, 無制限)。Team $30/user/月。日本語完全対応。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2023,
  japan_notes_ja     = '2023年東京オフィス開設。日本語UI/API完全対応。日本語トークン長問題を2024年改善。'
WHERE id = 'openai';

-- Anthropic (freemium: Free Claude.ai / Pro $20 / Max $100 / Team $30)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 20.00,
  pricing_notes_ja   = 'Claude Pro $20/月。Max $100/月 (claude-opus-4-7, 最高性能)。API従量課金別。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2024,
  japan_notes_ja     = '2024年日本語対応強化。日本法人未設立。Opus/Sonnet/Haiku 3グレード。Claude Code CLI リリース。'
WHERE id = 'anthropic';

-- Perplexity AI (freemium: Free / Pro $20/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 20.00,
  pricing_notes_ja   = 'Pro $20/月。無料プランは日次クエリ制限あり。API別料金。ソース引用型AI検索。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2024,
  japan_notes_ja     = '日本語クエリ対応。日本法人なし。2024年日本ユーザー急増。SoftBank連携報道あり。'
WHERE id = 'perplexity';

-- Mistral AI (API課金 / La Plateforme)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'API従量課金 ($0.25/1M tokens〜)。エンタープライズ要見積。UI版 Le Chat は無料。',
  japan_presence_level = 'limited',
  japan_launch_year  = NULL,
  japan_notes_ja     = '日本法人なし。欧州規制遵守AIとして企業向けに採用事例あり。日本語対応は基本水準。'
WHERE id = 'mistral';

-- Cohere (エンタープライズAPI)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'API従量課金 (Command R+ $3/1M input tokens)。エンタープライズSLA要見積。RAG特化。',
  japan_presence_level = 'limited',
  japan_launch_year  = NULL,
  japan_notes_ja     = '日本法人なし。大企業向けRAG/検索AI。日本でも一部採用例あり。日本語マルチリンガル対応。'
WHERE id = 'cohere';

-- ============================================================
-- AI コーディング (3社)
-- ============================================================

-- Replit (freemium: Free / Core $25/月 / Teams $40/user)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 25.00,
  pricing_notes_ja   = 'Core $25/月 (年払い$15/月)。Teams $40/user/月。AI Agentが自律的にコード生成。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2022,
  japan_notes_ja     = '日本語コミュニティ活発。日本法人なし。学生・インディーデブに人気。日本語UIあり。'
WHERE id = 'replit';

-- Lovable (freemium: Free 5msg/日 / Starter $20/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 20.00,
  pricing_notes_ja   = 'Starter $20/月。Team $50/月。無料プランは1日5メッセージ。React/Supabase自動生成。',
  japan_presence_level = 'limited',
  japan_launch_year  = NULL,
  japan_notes_ja     = '日本法人なし。英語UI主体。2024年急成長 — 「ノーコード Flutter/React 自動化」として注目。'
WHERE id = 'lovable';

-- Devin by Cognition AI (paid: Team $500/月)
UPDATE public.competitors SET
  pricing_tier       = 'paid',
  pricing_start_usd  = 500.00,
  pricing_notes_ja   = 'Teamプラン $500/月 (ACUs上限あり)。使い切り追加 ACU有料。エンジニア自律代替を標榜。',
  japan_presence_level = 'limited',
  japan_launch_year  = NULL,
  japan_notes_ja     = '日本法人なし。2024年公開後話題沸騰も実運用ハードル高い。日本では一部スタートアップ試験導入。'
WHERE id = 'devin';

-- ============================================================
-- デザイン / クリエイティブ (2社)
-- ============================================================

-- Figma (freemium: Starter無料 / Professional $15/editor / Organization $45)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 15.00,
  pricing_notes_ja   = 'Professional $15/editor/月 (年払い)。Organization $45/editor/月。AI機能 (Make Designs) 含む。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2020,
  japan_notes_ja     = '日本法人あり (2022)。国内デザイナーの標準ツール。Figma Config Japan 2024開催。UI開発者にも必須。'
WHERE id = 'figma';

-- Canva (freemium: Free / Pro $15/月 / Teams $10/user)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 13.00,
  pricing_notes_ja   = 'Pro $13/月 (年払い)。Teams $10/user/月。AI画像生成・Magic Write含む。教育機関無料。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2018,
  japan_notes_ja     = '日本法人あり。日本語テンプレート豊富。SMB・教育機関で急速普及。キャンバ株式会社 2022設立。'
WHERE id = 'canva';

-- ============================================================
-- 音声 / メディア AI (1社)
-- ============================================================

-- ElevenLabs (freemium: Free 10k chars / Starter $5/月 / Creator $22/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 5.00,
  pricing_notes_ja   = 'Starter $5/月 (30k chars)。Creator $22/月 (100k chars)。日本語音声クローン対応。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2024,
  japan_notes_ja     = '2024年日本語音声品質大幅向上。日本語TTS市場でVoicePeakと競合。日本法人未設立。'
WHERE id = 'elevenlabs';

-- ============================================================
-- エンタープライズ SaaS (3社)
-- ============================================================

-- Databricks (enterprise: Lakehouse / 使用量課金)
UPDATE public.competitors SET
  pricing_tier       = 'enterprise',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = 'DBU (Databricks Unit) 課金。クラウドプロバイダーと合算。エンタープライズ要見積。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2020,
  japan_notes_ja     = '日本法人あり (2020)。大手日本企業 (パナソニック等) 採用実績。Japan Summit 定期開催。'
WHERE id = 'databricks';

-- ClickUp (freemium: Free / Unlimited $7/user / Business $12/user)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 7.00,
  pricing_notes_ja   = 'Unlimited $7/user/月 (年払い)。Business $12/user/月。AI Brainは全プラン$5/user/月追加。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2022,
  japan_notes_ja     = '日本語UI対応。日本法人なし。Notion・Asana対抗として国内スタートアップで採用増。'
WHERE id = 'clickup';

-- Atlassian (Jira/Confluence): freemium: Free (10users) / Standard $7.75/user
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 7.75,
  pricing_notes_ja   = 'Jira Standard $7.75/user/月。Confluence Standard $4.75/user/月。10ユーザー無料。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2012,
  japan_notes_ja     = '日本法人あり (Atlassian株式会社)。大手SIer・エンタープライズの標準ツール。Japan Summit 定期開催。'
WHERE id = 'atlassian';

-- ============================================================
-- ファイルストレージ / 教育 / ウェルネス (4社)
-- ============================================================

-- Dropbox (freemium: Free 2GB / Plus $9.99/月 / Business $15/user)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 9.99,
  pricing_notes_ja   = 'Plus $9.99/月 (年払い)。Business $15/user/月。Dash AI (ファイル検索AI) 含む。',
  japan_presence_level = 'strong',
  japan_launch_year  = 2010,
  japan_notes_ja     = '日本法人あり。企業での利用は縮小傾向だがクリエイター・フリーランスには根強い。日本語完全対応。'
WHERE id = 'dropbox';

-- Duolingo (freemium: Free / Super $13/月 or $84/年)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 7.00,
  pricing_notes_ja   = 'Super $6.99/月 (年払い$84)。月払い $13/月。日本は世界有数の大市場。英語学習No.1アプリ。',
  japan_presence_level = 'dominant',
  japan_launch_year  = 2015,
  japan_notes_ja     = '日本は世界3位の大市場。英語・韓国語・フランス語等21言語。AI会話練習 (Lily) 追加。日本語UI完全対応。'
WHERE id = 'duolingo';

-- Calm (freemium: Free / Premium $70/年 ≈$5.83/月)
UPDATE public.competitors SET
  pricing_tier       = 'freemium',
  pricing_start_usd  = 5.83,
  pricing_notes_ja   = 'Premium $70/年 (月割$5.83)。Calm for Business 要見積。睡眠・瞑想・ストレス管理。',
  japan_presence_level = 'limited',
  japan_launch_year  = NULL,
  japan_notes_ja     = '日本語コンテンツ少。日本法人なし。ウェルビーイング系アプリとして知名度はあるが普及率低い。'
WHERE id = 'calm';

-- Bluesky (free: 完全無料 / 将来有料機能検討中)
UPDATE public.competitors SET
  pricing_tier       = 'free',
  pricing_start_usd  = NULL,
  pricing_notes_ja   = '完全無料。分散型SNS (AT Protocol)。将来的に有料プレミアム機能検討中。',
  japan_presence_level = 'growing',
  japan_launch_year  = 2023,
  japan_notes_ja     = '日本は世界最大の Bluesky ユーザー国。X代替として急増。日本語対応。Starter Pack機能が日本語コミュニティ形成に寄与。'
WHERE id = 'bluesky';

-- ============================================================
-- seed achievement
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S71: competitors pricing+japan_presence Batch2 — AI/SaaS 18社',
  'openai/anthropic/perplexity/mistral/cohere/replit/lovable/devin/figma/canva/elevenlabs/databricks/clickup/atlassian/dropbox/duolingo/calm/bluesky の pricing_tier/pricing_start_usd/pricing_notes_ja/japan_presence_level/japan_notes_ja を充填。comparison_page Phase A+B デプロイ後の UI 表示最大化。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
