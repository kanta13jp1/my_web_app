-- WBS 進捗更新 + 本日達成タスク追加 (Windowsアプリ版#129・WBS-SYNC rule 履行)
-- 注: 本来は tools-hub:wbs.update_progress / wbs.add_task EF action 経由が推奨だが
--     EF deploy 反映待ちのため migration で代替 (Win版#128 で EF actions 追加済 / 反映後は migration 廃止)

-- ==============================================
-- 1. 既存タスクの進捗 update
-- ==============================================

-- AI大学 100社達成 (Win#121 完了)
UPDATE wbs_tasks
SET progress = 100, status = 'completed'
WHERE id = '4987301e-ef9a-4855-bee6-5d9ecca978ee';

-- AI大学 78社コンテンツ完全化 (102社で大超過 → completed)
UPDATE wbs_tasks
SET progress = 100, status = 'completed', title = 'AI大学 100社+ コンテンツ完全化'
WHERE id = 'bbd74807-cf64-42f6-a26b-53430bcfc8dd';

-- provider.chat 残65社段階実装 (Inworld/Hyperbolic/Anyscale/Cerebrium 等多数追加)
UPDATE wbs_tasks
SET progress = 80, status = 'in_progress'
WHERE id = 'defe198f-05b7-48f5-b1cb-86568480efef';

-- ==============================================
-- 2. 本日達成タスクを新規追加 (Win#103-129)
-- ==============================================

INSERT INTO wbs_tasks (category, category_icon, category_order, title, description, instance, status, progress, priority, end_date)
VALUES
  ('動画教材', '🎬', 8,
   'NotebookLM→YouTube→Flutter 完全自動化パイプライン',
   '5 動画/シリーズ を 1 セッションで生成 (Scribe / SRT / ffmpeg 4 variant / YouTube unlisted / Flutter embed)',
   'windows', 'completed', 100, 'high', '2026-04-20'),

  ('動画教材', '🎬', 8,
   '開発教訓動画シリーズ #1 (カオスから教義へ)',
   '5 動画 (原版+A/B/C/D) YouTube unlisted 配信 + ai_dev_principles_page 埋込',
   'windows', 'completed', 100, 'high', '2026-04-19'),

  ('動画教材', '🎬', 8,
   '開発教訓動画シリーズ #2 (欠陥の修正：コメントがコードを変えた)',
   '5 動画 (原版+A/B/C/D) YouTube unlisted 配信 + ai_dev_principles_page 埋込',
   'windows', 'completed', 100, 'high', '2026-04-20'),

  ('インフラ', '🏗️', 7,
   '10 インスタンス制 (PS版×6 並列化)',
   'WORKDIR-ISOLATION + STASH-SAFETY + INSTANCE-ROLES + WBS-SYNC 4 rule 永続注入',
   'all', 'completed', 100, 'high', '2026-04-19'),

  ('インフラ', '🏗️', 7,
   'EF cleanup -138 dirs (262→124 / -52.7%)',
   'deploy ∩ delete ∩ Flutter ref 自動判定で safe 84 + dead-orphan 54 削除',
   'windows', 'completed', 100, 'medium', '2026-04-19'),

  ('インフラ', '🏗️', 7,
   'WBS 自動同期仕組み構築 (3 層ガード)',
   'inject-rules WBS-SYNC + tools-hub wbs.* 5 actions + session-start Step 4.5',
   'windows', 'completed', 100, 'high', '2026-04-19'),

  ('品質・安定性', '🛡️', 1,
   '死んでた機能 4 つ復活',
   '競馬AI予想 / 資産管理闘争 / AI タグ提案 / feature_releases routing 修正',
   'windows', 'completed', 100, 'high', '2026-04-19'),

  ('開発自動化', '🤖', 9,
   'YouTube Data API v3 OAuth + scripts/upload_youtube.py',
   'Desktop App OAuth + Test users + resumable upload + retry on 5xx + manifest batch',
   'windows', 'completed', 100, 'high', '2026-04-19'),

  ('開発自動化', '🤖', 9,
   'PostgREST embed shape 知識整備',
   '1:1 join=Map / 1:M=List 戻り型違い → firstMap helper パターン確立',
   'all', 'completed', 100, 'medium', '2026-04-19'),

  ('インフラ', '🏗️', 7,
   'deploy concurrency cancel-in-progress: false 化',
   '並行 push でも全 commit が順次 deploy される (cancel 連鎖解消)',
   'windows', 'completed', 100, 'high', '2026-04-19')

ON CONFLICT DO NOTHING;

-- ==============================================
-- 3. ログ
-- ==============================================
DO $$
DECLARE
  v_total int;
  v_completed int;
  v_in_progress int;
BEGIN
  SELECT COUNT(*) INTO v_total FROM wbs_tasks;
  SELECT COUNT(*) INTO v_completed FROM wbs_tasks WHERE status = 'completed';
  SELECT COUNT(*) INTO v_in_progress FROM wbs_tasks WHERE status = 'in_progress';
  RAISE NOTICE 'wbs_tasks: total=%, completed=%, in_progress=%', v_total, v_completed, v_in_progress;
END $$;
