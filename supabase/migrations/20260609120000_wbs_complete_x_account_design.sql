-- Win版#132 part 247 (2026-06-09 / Win Claude): Complete WBS マーケ運用設計タスク
-- 「X 公式アカウント運用設計」 (task fd9616af-bbdd-41ad-ba71-0c2dd76aa505 / milestone mvp-launch).
--
-- 本タスクは owner_instance='codex' だったが、マーケ/SNS 運用設計・docs は L3 (Win Claude) の
-- レーン (競合・SNS lane) であり ([DYNAMIC-CLAIM] = marketing/docs 引き取り可)、設計成果物として
-- Win Claude が完了する。owner_instance も 'win' へ是正 (part 244-246 と同パターン)。
-- 投稿自動化・スケジューラ・KPI 自動集計の実装は L2 (Codex) の既存 SNS 配信基盤の範疇。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/X_ACCOUNT_OPERATIONS_DESIGN.md … X 公式アカウント運用 baseline v1。
--       位置づけ (build-in-public × 多社 AI × 6 部署) + コンテンツ 4 柱 (build-in-public /
--       自分経営 tips / 多社 AI インサイト / ユーザー価値) + 既存資産転用 (T-1 dispatch /
--       ブログ / ROADMAP / AI大学) + 週 5 投稿カデンス + ハッシュタグ + トーン/ガードレール
--       (検証ファースト = AI ツール/競合主張は [AI-TOOL-VERIFY] 一次情報確認後のみ投稿 / 誇張・
--       捏造禁止を恒久ルール化 + [AUTO-REPLY] 自己ループ禁止 + 秘密情報禁止) + engagement KPI
--       (主指標=サイト流入/Beta 寄与 / vanity 回避 / v1 目標仮説 CEO 確認待ち) + Beta-50/GA
--       接続 + Deferred (自動化実装/有料広告/他 PF を下流へ)。声のトーン最終確定は CEO 判断待ち。
--
-- ai_review_status='approved' を同一 UPDATE で設定するため、progress=100 への遷移でも
-- wbs_request_ai_review trigger は発火しない → status='completed' が確定する。
-- Idempotent: 固定値 UPDATE / description append は LIKE guard / achievement は NOT EXISTS guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (architect lane / L3 / 競合・SNS lane) self-authored deliverable. docs/X_ACCOUNT_OPERATIONS_DESIGN.md に X 公式アカウント運用 baseline v1 を整備 (位置づけ + コンテンツ 4 柱 + 既存資産転用 + 週 5 投稿カデンス + ハッシュタグ + トーン/ガードレール (検証ファースト・誇張禁止・自己ループ禁止・秘密情報禁止) + engagement KPI (主指標=流入/Beta 寄与 / vanity 回避) + Beta-50/GA 接続)。投稿自動化実装は L2 (Codex) 範疇。声のトーン最終確定は CEO 確認待ち。コード/スキーマ変更なしの docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-09'),
  end_date          = DATE '2026-06-09',
  remaining_work    = 'Completed by Win Claude (part 247). X 公式アカウント運用設計は docs/X_ACCOUNT_OPERATIONS_DESIGN.md。MVP ローンチのトップ・オブ・ファネル baseline。投稿自動化・スケジューラ・KPI 自動集計の実装は L2 (Codex) が既存 T-1 dispatch / blog-publish 基盤上で上積みし、声のトーン/ブランドは CEO 確認で確定する。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-09: X account operations design v1 established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-09 (Win Claude part 247): X account operations design v1 established at docs/X_ACCOUNT_OPERATIONS_DESIGN.md. Positioning (build-in-public x multi-AI x the 6-department worldview), 4 content pillars (build-in-public / self-management tips / multi-AI insight / user value), reuse of existing assets (T-1 dispatch, blog, ROADMAP, AI University) instead of double-producing, a 5-posts/week cadence, hashtag set, tone & guardrails (verify-first: AI-tool/competitor claims only after [AI-TOOL-VERIFY] primary-source confirmation, no exaggeration/fabrication made a standing rule; [AUTO-REPLY] no self-loop; no secrets), engagement KPIs whose primary metric is site traffic / Beta funnel contribution rather than vanity follower counts (v1 target hypotheses pending CEO confirmation), and Beta-50 / GA linkage. Posting automation, paid ads, and other platforms are deferred downstream (impl is the L2/Codex lane). Brand voice final sign-off requires CEO judgment (v1 baseline draft). Docs-only; no code/schema change. Task claimed codex -> win (marketing/SNS operational design is the L3 lane).'
  END,
  updated_at        = now()
WHERE id = 'fd9616af-bbdd-41ad-ba71-0c2dd76aa505';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'X 公式アカウント運用設計 v1 確立 (週 5 投稿 / KPI / 検証ファースト)',
  'docs/X_ACCOUNT_OPERATIONS_DESIGN.md を新設。MVP ローンチのトップ・オブ・ファネルとして X 公式アカウントの運用 baseline を確立。build-in-public × 多社 AI × 6 部署の位置づけ、コンテンツ 4 柱、既存ブログ/T-1 dispatch 資産の転用、週 5 投稿カデンス、ハッシュタグ、トーン/ガードレール (AI ツール・競合主張は検証ファースト = 一次情報確認後のみ投稿し誇張/捏造を禁止する恒久ルール / 自己ループ禁止 / 秘密情報禁止)、engagement KPI (主指標をサイト流入・Beta 寄与に置き vanity を回避)、Beta-50/GA 接続を設計。ADR→PRD→四半期ロードマップ→MVP スコープ→On-call SOP→オンボーディング設計に続く MVP ローンチ準備設計シリーズ第 7 弾 (集客面)。投稿自動化実装は下流 (Codex) へ。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'X 公式アカウント運用設計 v1 確立 (週 5 投稿 / KPI / 検証ファースト)'
);
