-- Win版#132 part 246 (2026-06-09 / Win Claude): Complete WBS 設計タスク
-- 「カスタマーオンボーディング設計」 (task a7f97791-3ae7-4b1d-845c-9c1a296175cb / milestone mvp-launch).
--
-- 本タスクは owner_instance='codex' だったが、製品/UX 設計・docs は L3 (Win Claude) のレーン
-- であり ([DYNAMIC-CLAIM] = primary no-op 時の docs/product-light 引き取り)、設計成果物として
-- Win Claude が完了する。owner_instance も 'win' へ是正 (part 244 MVP scope / part 245 SOP と同パターン)。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/CUSTOMER_ONBOARDING_DESIGN.md … 初回 7 日間ジャーニー + アクティベーション基準の v1 baseline。
--       コア 5 機能 (MVP_SCOPE §2) と「自分経営ループ」(入力→俯瞰→提案→ユーザー決定) を初回体験へ
--       翻訳: アクティベーション定義 (5 条件 A-E / 人事+本社+mentor を最小到達) + 指標と v1 目標仮説
--       (TTV / Activation Rate / D1 / D7 = CEO 確認待ち) + 初回セッション (0-10 分 "着任") + 7 日ジャーニー
--       (1 日 1 部署増築 / 人事ファースト / Day7 取締役会=週次定着) + エンプティステート/ナッジ (敬意ベース)
--       + 計測ファネル (7 ステップ / イベント定義は本書 / 実装は L2) + Beta-50/GA 接続 + Deferred (フロー
--       A/B・パーソナライズ・通知実装は下流 task 0e631085 オンボーディング最適化 へ明示引き継ぎ)。
--       アクティベーション閾値の最終確定は CEO の product judgment 待ちの v1 叩き台。
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
  ai_review_notes   = 'Win Claude (architect lane / L3) self-authored deliverable. docs/CUSTOMER_ONBOARDING_DESIGN.md に初回 7 日間ジャーニー + アクティベーション基準の v1 baseline を整備 (コア 5 機能と自分経営ループを初回体験へ翻訳 / アクティベーション 5 条件 + 指標 v1 仮説 + 着任セッション + 7 日ジャーニー + エンプティステート/ナッジ + 計測ファネル + Beta-50/GA 接続 + Deferred を下流最適化 task 0e631085 へ引き継ぎ)。アクティベーション閾値は CEO 確認待ち。コード/スキーマ変更なしの docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-09'),
  end_date          = DATE '2026-06-09',
  remaining_work    = 'Completed by Win Claude (part 246). カスタマーオンボーディング設計は docs/CUSTOMER_ONBOARDING_DESIGN.md。MVP ローンチで新規ユーザーをコア 5 機能へ運ぶ baseline。フロー A/B・パーソナライズ・通知/コーチマーク実装は下流 task 0e631085 (オンボーディング最適化 / beta) が上積みし、アクティベーション閾値は Beta 実測後に CEO 確認で確定する。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-09: Customer onboarding design v1 established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-09 (Win Claude part 246): Customer onboarding design v1 established at docs/CUSTOMER_ONBOARDING_DESIGN.md. Translates the MVP core-5 features and the self-management loop (input -> overview -> AI-mentor proposal -> user decision) into a first-run experience: activation definition (5 conditions A-E, minimally touching HR + HQ + mentor = the must-keep #1/#2/#5), metrics with v1 target hypotheses (TTV < 10min, Activation Rate 30-40%, D1 40-50%, D7 20-30%; thresholds pending CEO confirmation), a 0-10min "appointment" first session, a 7-day journey that adds one department per day HR-first and closes with a Day-7 weekly board-meeting retention ritual, respectful empty-states/nudges (no addiction/surveillance/peer-comparison), a 7-step onboarding funnel with event definitions (instrumentation impl deferred to L2), and Beta-50 / GA gate linkage. Flow A/B testing, personalization, push/coachmark implementation are explicitly handed to downstream task 0e631085 (onboarding optimization, beta). Activation thresholds require CEO product judgment (v1 baseline draft). Docs-only; no code/schema change. Task claimed codex -> win (product/UX design is the L3 lane).'
  END,
  updated_at        = now()
WHERE id = 'a7f97791-3ae7-4b1d-845c-9c1a296175cb';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'カスタマーオンボーディング設計 v1 確立 (初回 7 日間ジャーニー / アクティベーション基準)',
  'docs/CUSTOMER_ONBOARDING_DESIGN.md を新設。MVP のコア 5 機能と「自分経営ループ」を新規ユーザーの初回体験へ翻訳する baseline。アクティベーションを 5 条件 (着任 / 人事に実データ 1 件 / 前日比の俯瞰 / AI mentor 提案への決定 / 別日再訪) で定義し、TTV・Activation Rate・D1・D7 の v1 目標仮説 (CEO 確認待ち) を設定。0-10 分の着任セッションと、1 日 1 部署を人事ファーストで増築し Day7 の週次レビュー (取締役会) で定着させる 7 日間ジャーニー、敬意ベースのエンプティステート/ナッジ、7 ステップ計測ファネル、Beta-50/GA への接続を設計。ADR→PRD→四半期ロードマップ→MVP スコープ→On-call SOP に続く MVP ローンチ準備ドキュメント第 6 弾。フロー最適化は下流 task へ引き継ぎ。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'カスタマーオンボーディング設計 v1 確立 (初回 7 日間ジャーニー / アクティベーション基準)'
);
