-- Win版#132 part 11: 事業化 WBS + AI 自動レビュー/分解 Phase 1
--
-- 契機: ユーザー要請「事業化に必要なタスクを WBS化 + ガントチャート + AI レビュー gate +
-- Stale 自動分解」
-- 設計: docs/BUSINESS_WBS_AI_AUTOMATION.md (4-Phase 計画)
--
-- 本 migration の目的:
--   1. wbs_tasks に AI 自動化用カラム追加
--   2. 事業化マイルストーン 7 件 seed
--   3. 事業化タスク 54 件 seed (8 カテゴリ)
--
-- 後続 (新 session):
--   - Phase 2: wbs-ai-review.yml GHA cron (Gemini Flash で完了 task review)
--   - Phase 3: wbs-stale-subdivide.yml GHA cron (24h 進捗 0 task の自動分解)
--   - Phase 4: project-gantt page UI 拡張 (VSCode 担当)

-- ============================================================
-- 1. wbs_tasks 拡張カラム
-- ============================================================
ALTER TABLE public.wbs_tasks
  ADD COLUMN IF NOT EXISTS parent_task_id uuid REFERENCES public.wbs_tasks(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS ai_review_status text DEFAULT 'pending'
    CHECK (ai_review_status IN ('pending','requested','approved','rejected','manual_override','skip')),
  ADD COLUMN IF NOT EXISTS ai_review_notes text,
  ADD COLUMN IF NOT EXISTS ai_reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS depends_on uuid[] DEFAULT ARRAY[]::uuid[],
  ADD COLUMN IF NOT EXISTS auto_subdivided_at timestamptz,
  ADD COLUMN IF NOT EXISTS stale_threshold_hours int DEFAULT 24
    CHECK (stale_threshold_hours BETWEEN 6 AND 720);

CREATE INDEX IF NOT EXISTS idx_wbs_tasks_ai_review_status
  ON public.wbs_tasks (ai_review_status)
  WHERE ai_review_status IN ('requested','rejected');

CREATE INDEX IF NOT EXISTS idx_wbs_tasks_parent
  ON public.wbs_tasks (parent_task_id);

CREATE INDEX IF NOT EXISTS idx_wbs_tasks_stale_check
  ON public.wbs_tasks (status, updated_at)
  WHERE status = 'in_progress';

COMMENT ON COLUMN public.wbs_tasks.parent_task_id IS
  'parent task UUID (AI subdivide で生成された sub-task は parent にリンク)';
COMMENT ON COLUMN public.wbs_tasks.ai_review_status IS
  'pending → requested (progress=100 で auto) → approved/rejected (AI cron) / manual_override (人間決裁) / skip (review 不要 task)';
COMMENT ON COLUMN public.wbs_tasks.depends_on IS
  '前提タスク UUID 配列。全 completed まで status=pending のまま (cron が unblock)';
COMMENT ON COLUMN public.wbs_tasks.stale_threshold_hours IS
  'AI subdivide cron がこの時間以上更新ない task を分解候補に含める (default 24h / 大規模 168h 等)';

-- ============================================================
-- 2. progress=100 で ai_review_status='requested' に自動遷移する trigger
-- ============================================================
CREATE OR REPLACE FUNCTION public.wbs_request_ai_review_on_complete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- progress 100 達成かつ ai_review_status='pending' なら 'requested' に遷移
  IF NEW.progress = 100
     AND OLD.progress < 100
     AND NEW.ai_review_status = 'pending' THEN
    NEW.ai_review_status := 'requested';
    NEW.status := 'in_progress'; -- AI review 完了まで in_progress に留める
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS wbs_request_ai_review ON public.wbs_tasks;
CREATE TRIGGER wbs_request_ai_review
  BEFORE UPDATE OF progress ON public.wbs_tasks
  FOR EACH ROW EXECUTE FUNCTION public.wbs_request_ai_review_on_complete();

-- ============================================================
-- 3. 事業化マイルストーン 7 件 seed
-- ============================================================
INSERT INTO public.wbs_milestones (code, name, target_date, goal_users, description, color)
VALUES
  ('legal-setup', '法人設立完了',          '2026-09-30',      0, '株式会社設立 + 商標 + 銀行口座', '#0EA5E9'),
  ('mvp-launch',  'MVP 一般公開',         '2026-09-30',   1000, 'Beta → GA 移行 + pricing 確定', '#10B981'),
  ('seed-round',  'Seed 調達完了',         '2026-12-31',      0, 'Seed ¥50M-¥200M クロージング', '#F59E0B'),
  ('paying-100',  '有料 100 顧客',         '2027-03-31',    100, '月額有料 paying 100 / Series A 準備開始', '#8B5CF6'),
  ('series-a',    'Series A 調達完了',     '2027-12-31',  10000, 'Series A ¥500M-¥2B', '#EC4899'),
  ('audit-ready', '監査法人対応完了',      '2028-09-30',  50000, 'J-SOX 対応 + 内部統制構築完了', '#DC2626'),
  ('ipo-listed',  'IPO 上場',              '2029-12-31', 100000, '東証グロース / TSE Growth', '#7C3AED')
ON CONFLICT (code) DO UPDATE SET
  name        = EXCLUDED.name,
  target_date = EXCLUDED.target_date,
  goal_users  = EXCLUDED.goal_users,
  description = EXCLUDED.description,
  color       = EXCLUDED.color;

-- ============================================================
-- 4. 事業化タスク 54 件 seed
-- ============================================================
-- ai_review_status='skip' は WBS UI 上の管理対象だが AI review 不要なもの
-- (例: 「銀行口座開設」みたいな単純 ops は AI が判定する余地がない)

-- owner_instance NOT NULL constraint: temporarily relaxed for bulk INSERT
-- restored after UPDATE derives correct value from instance column
ALTER TABLE public.wbs_tasks ALTER COLUMN owner_instance DROP NOT NULL;

-- This seed intentionally uses instance='all' for business-wide tasks, then a
-- later migration (20260425203000) splits those rows into per-instance copies.
-- Some remote databases already have the newer no-all CHECK constraint, so
-- keep this migration self-contained by temporarily allowing legacy values.
ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_instance_check;
ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_instance_check
  CHECK (instance IN (
    'codex',
    'vscode', 'win', 'windows', 'ps',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule', 'gha',
    'all',
    -- super-set: future migrations add these / hotfix 2026-04-26 to keep this
    -- migration idempotent on re-runs after 225000/230000 introduced new values
    'user', 'gemini', 'copilot'
  )) NOT VALID;

-- Deploy-prod intentionally repairs/re-runs this historical seed. Newer
-- databases already enforce recovery_plan for overdue tasks, so pause that
-- trigger around the bulk seed and backfill recovery metadata immediately after.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'wbs_enforce_recovery_plan_trg'
      AND tgrelid = 'public.wbs_tasks'::regclass
  ) THEN
    EXECUTE 'ALTER TABLE public.wbs_tasks DISABLE TRIGGER wbs_enforce_recovery_plan_trg';
  END IF;
END $$;

INSERT INTO public.wbs_tasks
  (category, category_icon, category_order, title, description, instance, status, progress,
   start_date, end_date, milestone_code, priority, ai_review_status, stale_threshold_hours)
VALUES
  -- ===== ⚖️ business-legal (8) =====
  ('business-legal', '⚖️', 100, '法人形態の決定 (株式 vs 合同会社)', '株式会社・合同会社の比較表 → CEO 決裁', 'all', 'pending', 0,
   '2026-05-01', '2026-05-15', 'legal-setup', 'high', 'pending', 48),
  ('business-legal', '⚖️', 100, '商号・本店所在地の確定', '商標調査 → 商号予約 → 登記住所決定', 'all', 'pending', 0,
   '2026-05-15', '2026-06-15', 'legal-setup', 'high', 'pending', 48),
  ('business-legal', '⚖️', 100, '司法書士・税理士契約', '法人設立 + 顧問税理士 2 社相見積り', 'all', 'pending', 0,
   '2026-06-01', '2026-06-30', 'legal-setup', 'high', 'skip', 72),
  ('business-legal', '⚖️', 100, '株式会社設立登記', '定款認証 → 設立登記 → 印鑑証明', 'all', 'pending', 0,
   '2026-07-01', '2026-09-30', 'legal-setup', 'high', 'pending', 168),
  ('business-legal', '⚖️', 100, '商標出願 (自分株式会社 / Logo)', '弁理士経由で日本商標出願 → 米国 + EU 展開検討', 'all', 'pending', 0,
   '2026-08-01', '2026-10-31', 'legal-setup', 'medium', 'pending', 168),
  ('business-legal', '⚖️', 100, '利用規約 v1.0 起草', 'B2C SaaS 利用規約 / 弁護士 review 込み', 'vscode', 'pending', 0,
   '2026-05-01', '2026-06-30', 'mvp-launch', 'high', 'pending', 72),
  ('business-legal', '⚖️', 100, 'プライバシーポリシー v1.0', 'GDPR / 個人情報保護法準拠 / Cookie consent 含む', 'vscode', 'pending', 0,
   '2026-05-01', '2026-06-30', 'mvp-launch', 'high', 'pending', 72),
  ('business-legal', '⚖️', 100, '特定商取引法表記', '事業者情報 / 返金ポリシー / SaaS 課金条件', 'vscode', 'pending', 0,
   '2026-06-01', '2026-08-31', 'mvp-launch', 'medium', 'pending', 48),

  -- ===== 💰 business-finance (8) =====
  ('business-finance', '💰', 200, '法人銀行口座開設', 'みずほ・三菱 UFJ・住信 SBI ネット銀行 比較 → 開設', 'all', 'pending', 0,
   '2026-09-01', '2026-10-15', 'legal-setup', 'high', 'skip', 168),
  ('business-finance', '💰', 200, '会計ソフト導入 (freee or マネフォ)', 'freee / MoneyForward Cloud 比較 → 契約', 'all', 'pending', 0,
   '2026-09-01', '2026-09-30', 'legal-setup', 'medium', 'skip', 48),
  ('business-finance', '💰', 200, '初期事業計画 (3 年 P/L 予測)', '売上 / コスト / 損益分岐点 / 必要調達額', 'all', 'pending', 0,
   '2026-05-01', '2026-08-31', 'seed-round', 'high', 'pending', 72),
  ('business-finance', '💰', 200, 'Pitch Deck v1.0 (英語版含む)', 'Sequoia template 準拠 / 10-15 slides', 'all', 'pending', 0,
   '2026-08-01', '2026-10-31', 'seed-round', 'high', 'pending', 72),
  ('business-finance', '💰', 200, 'Seed 投資家リスト作成', 'VC 30 社 / Angel 20 名 / 接点経路の整理', 'all', 'pending', 0,
   '2026-09-01', '2026-10-31', 'seed-round', 'high', 'pending', 48),
  ('business-finance', '💰', 200, 'Seed ラウンドクロージング', 'Term sheet 締結 → 着金 → 株主登録', 'all', 'pending', 0,
   '2026-11-01', '2026-12-31', 'seed-round', 'high', 'pending', 168),
  ('business-finance', '💰', 200, '月次決算プロセス確立', '会計 → 残高試算 → 月次 BS/PL → CEO レビュー', 'all', 'pending', 0,
   '2026-10-01', '2027-01-31', 'paying-100', 'medium', 'pending', 48),
  ('business-finance', '💰', 200, 'Series A 準備 (Pitch Deck v2)', 'Seed 後の traction を反映 / グロース指標明示', 'all', 'pending', 0,
   '2027-04-01', '2027-09-30', 'series-a', 'high', 'pending', 72),

  -- ===== 🚀 business-product (8) =====
  ('business-product', '🚀', 300, 'MVP feature scope 確定', 'コア機能 5 個に絞る (現状の比較ページ等は keep)', 'all', 'pending', 0,
   '2026-05-01', '2026-05-31', 'mvp-launch', 'high', 'pending', 48),
  ('business-product', '🚀', 300, 'Beta ユーザー 50 名募集', 'LP CTA + Twitter 告知 + 招待制', 'all', 'pending', 0,
   '2026-06-01', '2026-07-31', 'mvp-launch', 'high', 'pending', 48),
  ('business-product', '🚀', 300, '料金プラン v1.0 確定', 'Free / Pro $10/月 / Team $30/月 (3 plan)', 'all', 'pending', 0,
   '2026-06-01', '2026-08-15', 'mvp-launch', 'high', 'pending', 72),
  ('business-product', '🚀', 300, '決済導入 (Stripe)', 'Stripe Checkout + Webhook + Tax Compliance', 'vscode', 'pending', 0,
   '2026-08-01', '2026-09-15', 'mvp-launch', 'high', 'pending', 72),
  ('business-product', '🚀', 300, 'GA リリース (一般公開)', 'invite-only → public beta → GA', 'all', 'pending', 0,
   '2026-09-01', '2026-09-30', 'mvp-launch', 'high', 'pending', 168),
  ('business-product', '🚀', 300, 'On-call / インシデント対応 SOP', 'PagerDuty 導入 / ランブック整備', 'win', 'pending', 0,
   '2026-09-01', '2026-10-31', 'mvp-launch', 'medium', 'pending', 48),
  ('business-product', '🚀', 300, 'カスタマーオンボーディング設計', '初回 7 日間ジャーニー / アクティベーション基準', 'all', 'pending', 0,
   '2026-08-01', '2026-10-31', 'mvp-launch', 'medium', 'pending', 48),
  ('business-product', '🚀', 300, '機能 release cycle 確立 (隔週)', '隔週 release note / changelog page', 'vscode', 'pending', 0,
   '2026-10-01', '2026-12-31', 'paying-100', 'medium', 'pending', 48),

  -- ===== 📢 business-marketing (8) =====
  ('business-marketing', '📢', 400, 'LP A/B テスト基盤導入', 'GrowthBook / Amplitude experiment', 'vscode', 'pending', 0,
   '2026-05-01', '2026-06-30', 'mvp-launch', 'high', 'pending', 48),
  ('business-marketing', '📢', 400, 'SEO 戦略 (記事 50 本計画)', 'キーワード調査 → 編集カレンダー → ライター手配', 'ps2', 'pending', 0,
   '2026-05-01', '2026-12-31', 'paying-100', 'high', 'pending', 168),
  ('business-marketing', '📢', 400, 'X 公式アカウント運用設計', '週 5 投稿 / hashtag / engagement KPI', 'ps2', 'pending', 0,
   '2026-05-01', '2026-08-31', 'mvp-launch', 'medium', 'pending', 48),
  ('business-marketing', '📢', 400, 'PR Times プレスリリース v1', 'MVP 公開 PR / メディア配信先 50 社', 'ps2', 'pending', 0,
   '2026-09-01', '2026-09-30', 'mvp-launch', 'medium', 'pending', 48),
  ('business-marketing', '📢', 400, 'YouTube 動画 5 本制作', 'デモ / 比較 / 使い方 / ケーススタディ', 'win', 'pending', 0,
   '2026-08-01', '2026-12-31', 'paying-100', 'medium', 'pending', 168),
  ('business-marketing', '📢', 400, 'Paid Ads MVP テスト', 'Google Ads + Meta Ads ¥100K で CPA 測定', 'all', 'pending', 0,
   '2026-10-01', '2026-12-31', 'paying-100', 'medium', 'pending', 48),
  ('business-marketing', '📢', 400, 'リファラル / 紹介プログラム', 'Refer-a-friend → 1 ヶ月無料', 'vscode', 'pending', 0,
   '2026-11-01', '2027-01-31', 'paying-100', 'medium', 'pending', 48),
  ('business-marketing', '📢', 400, 'ブランドガイドライン v1', 'logo / color / typography / voice', 'vscode', 'pending', 0,
   '2026-06-01', '2026-08-31', 'mvp-launch', 'low', 'pending', 72),

  -- ===== 🤝 business-sales (6) =====
  ('business-sales', '🤝', 500, 'B2B Lead 100 件獲得', 'LinkedIn outreach + イベント参加', 'all', 'pending', 0,
   '2026-10-01', '2027-03-31', 'paying-100', 'high', 'pending', 48),
  ('business-sales', '🤝', 500, '法人プラン提案資料 v1', 'B2B 営業 deck / 価格表 / セキュリティ FAQ', 'all', 'pending', 0,
   '2026-10-01', '2026-12-31', 'paying-100', 'high', 'pending', 48),
  ('business-sales', '🤝', 500, 'CS / Onboarding playbook', 'Notion playbook + 動画 5 本', 'ps5', 'pending', 0,
   '2026-11-01', '2027-02-28', 'paying-100', 'medium', 'pending', 72),
  ('business-sales', '🤝', 500, '初期顧客 NPS 調査', '1ヶ月利用ユーザーに NPS / 改善 list', 'all', 'pending', 0,
   '2026-12-01', '2027-03-31', 'paying-100', 'medium', 'pending', 48),
  ('business-sales', '🤝', 500, '解約率 (Churn) 計測ダッシュボード', '月次 churn / cohort retention', 'win', 'pending', 0,
   '2026-12-01', '2027-02-28', 'paying-100', 'medium', 'pending', 48),
  ('business-sales', '🤝', 500, 'SOC 2 Type 1 認証準備', '監査法人選定 → audit prep → 認証取得', 'all', 'pending', 0,
   '2027-04-01', '2027-12-31', 'series-a', 'medium', 'pending', 168),

  -- ===== 👥 business-hr (6) =====
  ('business-hr', '👥', 600, 'CTO / VPoE 候補 5 名リスト', 'YOUTRUST / Wantedly / リファラル', 'all', 'pending', 0,
   '2026-10-01', '2027-01-31', 'series-a', 'high', 'pending', 72),
  ('business-hr', '👥', 600, '評価制度 v1 (1on1 + OKR)', 'OKR 設定 + 月次 1on1 + 半期レビュー', 'all', 'pending', 0,
   '2026-11-01', '2027-03-31', 'series-a', 'medium', 'pending', 72),
  ('business-hr', '👥', 600, '給与 / SO 設計 (CFO 監修)', 'シリーズ A 想定 cap table + ESOP 10-15%', 'all', 'pending', 0,
   '2027-01-01', '2027-06-30', 'series-a', 'high', 'pending', 168),
  ('business-hr', '👥', 600, '採用 first 5 (eng + sales + cs)', 'CTO + senior eng 2 + sales lead + CS', 'all', 'pending', 0,
   '2027-04-01', '2027-12-31', 'series-a', 'high', 'pending', 168),
  ('business-hr', '👥', 600, 'リモート / オフィス勤務制度', 'WFH 標準 / 月 2 出社 / 機材手当', 'all', 'pending', 0,
   '2026-12-01', '2027-03-31', 'paying-100', 'low', 'pending', 48),
  ('business-hr', '👥', 600, '福利厚生 (健康診断 / 保険)', '健保 / 社保 / ストックオプション信託', 'all', 'pending', 0,
   '2027-01-01', '2027-06-30', 'series-a', 'medium', 'pending', 72),

  -- ===== 🏢 business-ops (4) =====
  ('business-ops', '🏢', 700, 'バーチャルオフィス契約', 'Tokyo 1 等地 / 登記住所 / 郵便受取', 'all', 'pending', 0,
   '2026-07-01', '2026-08-31', 'legal-setup', 'medium', 'skip', 48),
  ('business-ops', '🏢', 700, 'IT セキュリティポリシー v1', 'パスワード管理 / 端末暗号化 / VPN', 'all', 'pending', 0,
   '2026-10-01', '2027-01-31', 'paying-100', 'medium', 'pending', 72),
  ('business-ops', '🏢', 700, 'インシデント対応プロセス', 'Runbook + RACI + Postmortem template', 'win', 'pending', 0,
   '2026-11-01', '2027-02-28', 'paying-100', 'medium', 'pending', 48),
  ('business-ops', '🏢', 700, '物理オフィス契約 (シリーズ A 後)', '渋谷 or 六本木 / 100 坪 / 5 年契約', 'all', 'pending', 0,
   '2028-01-01', '2028-06-30', 'audit-ready', 'low', 'skip', 168),

  -- ===== 📈 business-ipo (6) =====
  ('business-ipo', '📈', 800, '内部統制 (J-SOX) 設計', 'AS-IS 調査 + TO-BE 設計 + 文書化', 'all', 'pending', 0,
   '2027-10-01', '2028-06-30', 'audit-ready', 'high', 'pending', 168),
  ('business-ipo', '📈', 800, '監査法人選定 (BIG 4 or 中堅)', 'EY / KPMG / PwC / Deloitte / 太陽 / トーマツ', 'all', 'pending', 0,
   '2028-04-01', '2028-09-30', 'audit-ready', 'high', 'pending', 168),
  ('business-ipo', '📈', 800, '主幹事証券会社選定', '野村 / 大和 / SBI / みずほ 4 社', 'all', 'pending', 0,
   '2028-09-01', '2029-03-31', 'ipo-listed', 'high', 'pending', 168),
  ('business-ipo', '📈', 800, '東証グロース申請書類作成', 'I の部 / II の部 / 申請書一式', 'all', 'pending', 0,
   '2029-04-01', '2029-09-30', 'ipo-listed', 'high', 'pending', 168),
  ('business-ipo', '📈', 800, '上場審査対応', '東証ヒアリング 5 回 / 質疑応答資料', 'all', 'pending', 0,
   '2029-08-01', '2029-12-31', 'ipo-listed', 'high', 'pending', 168),
  ('business-ipo', '📈', 800, 'IPO ロードショー', 'institutional 投資家 30 社訪問', 'all', 'pending', 0,
   '2029-10-01', '2029-12-31', 'ipo-listed', 'high', 'pending', 72)

ON CONFLICT DO NOTHING;
-- 注: wbs_tasks に UNIQUE 制約は title + category にないため初回のみ INSERT。
-- 重複起動した場合は何もしない (idempotent)。

UPDATE public.wbs_tasks
SET recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'business WBS phase1 seed re-run: review with the current realistic schedule and assign owner follow-up before resuming.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW())
WHERE category LIKE 'business-%'
  AND status <> 'completed'
  AND COALESCE(planned_end_date, end_date) < CURRENT_DATE
  AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'wbs_enforce_recovery_plan_trg'
      AND tgrelid = 'public.wbs_tasks'::regclass
  ) THEN
    EXECUTE 'ALTER TABLE public.wbs_tasks ENABLE TRIGGER wbs_enforce_recovery_plan_trg';
  END IF;
END $$;

-- Derive owner_instance: 'all' tasks owned by 'win' (architect), specific instance tasks own themselves
UPDATE public.wbs_tasks
SET owner_instance = CASE WHEN instance = 'all' THEN 'win' ELSE instance END
WHERE category LIKE 'business-%' AND owner_instance IS NULL;

-- Restore NOT NULL constraint
ALTER TABLE public.wbs_tasks ALTER COLUMN owner_instance SET NOT NULL;

-- ============================================================
-- 5. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '事業化 WBS + AI 自動化 Phase 1',
  $md$Win版#132 part 11。ユーザー要請「事業化タスク WBS化 + ガントチャート + AI レビュー gate + Stale 自動分解」を受けた 4-Phase 計画の Phase 1 実装。wbs_tasks に AI 自動化用 6 カラム追加 (parent_task_id / ai_review_status / ai_review_notes / ai_reviewed_at / depends_on / auto_subdivided_at / stale_threshold_hours) + progress=100 で auto-request review trigger + 7 マイルストーン (legal-setup / mvp-launch / seed-round / paying-100 / series-a / audit-ready / ipo-listed) + 54 事業化タスク (legal 8 / finance 8 / product 8 / marketing 8 / sales 6 / hr 6 / ops 4 / ipo 6)。後続: Phase 2 = wbs-ai-review.yml (Gemini Flash) / Phase 3 = wbs-stale-subdivide.yml / Phase 4 = project-gantt page UI 拡張 (VSCode)。docs/BUSINESS_WBS_AI_AUTOMATION.md。$md$,
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
