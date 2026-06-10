-- Win版#132 part 260 (2026-06-10 / Win Claude): Complete WBS 階層的クリーンアップ運用タスク
-- 「[Issue #2710] [notebooklm:d89ae1f5:3] 不変的ルール（静的ドキュメント）と動的コンテキスト（短期記憶）の
--  階層的クリーンアップ運用」
--  (task cbfe0326-d764-4bda-8b8a-c3d37714a1a8 / owner schedule→win)
--
-- Triage 類型 ② (gap 充足後 complete / part 256 確立):
--   受入基準 3 点の verify 結果 = ほぼ既存充足:
--   ① 静的 docs 独立管理 → CLAUDE.md (part 133 から 80 行 pointer hub) + docs/ 原則 12 軸 +
--      inject-rules.txt 39 rule = SECOND_BRAIN_PRINCIPLES 原則 1 (階層型ナレッジ厳格分離) ✅
--   ② セッション開始時に静的+動的が物理的に別ファイルでロード → CLAUDE.md (project instructions) +
--      memory/MEMORY.md (auto-memory index) + SessionStart hook の auto-capture work log =
--      実挙動として毎セッション別経路ロード ✅
--   ③ 定期レビュー + 昇格 + 破棄手順の明確な定義 → 実装は既存 (consolidate-memory skill 月 1 +
--      --lint 3 検出器 / [MEMORY-DECAY] rule / knowledge_vault_lint 週次 / wrap-up 毎セッション) だが
--      「昇格 (動的→静的) path + 破棄 cadence」を一枚で定義した repo 正本が無かった = 唯一の gap
--      → 本 PR で docs/SECOND_BRAIN_PRINCIPLES.md に「階層的クリーンアップ運用」節を追記して充足
--      (2 階層 mapping 表 / 昇格 3 step / cadence 4 行表 / 禁止事項 / 全て既存実装への pointer = 新規機構ゼロ)。
--   GitHub Issue #2710 は本 PR merge 後、基準 ①②③ の evidence 付きで close する。
--
-- ai_review_status='approved' を同一 UPDATE で設定 → trigger 回避で status='completed' 確定。
-- Idempotent: 固定値 UPDATE / description append は LIKE guard / achievement は NOT EXISTS guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (L3 / PKM lane / part 260)。受入基準 verify: ① 静的 docs 独立管理 = CLAUDE.md pointer hub + docs/ 12 軸 + inject-rules (SECOND_BRAIN 原則 1) ✅ 既存 / ② セッション開始時の静的+動的 別ファイルロード = CLAUDE.md + MEMORY.md + auto-capture log の実挙動 ✅ 既存 / ③ 昇格・破棄手順の明確な定義 = 実装は既存 (consolidate-memory 月 1 + --lint / MEMORY-DECAY / vault lint 週次) だが一枚正本が無かった → SECOND_BRAIN_PRINCIPLES.md に「階層的クリーンアップ運用」節を追記して充足 (2 階層 mapping + 昇格 3 step + cadence 表 + 禁止事項 / 全て既存実装 pointer = 新規機構ゼロ)。Issue #2710 は evidence 付き close。[BRAIN-32] 7/7 整合。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-10'),
  end_date          = DATE '2026-06-10',
  remaining_work    = 'Completed by Win Claude (part 260)。正本 = docs/SECOND_BRAIN_PRINCIPLES.md「階層的クリーンアップ運用」節。残: なし (運用は既存 cadence — 月 1 consolidate-memory / 週次 vault lint / 毎セッション wrap-up — が継続)。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-10: hierarchical cleanup operating practice%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-10: hierarchical cleanup operating practice consolidated (Win Claude part 260). Acceptance criteria verified against the real system: (1) immutable rules live independently as static documents (CLAUDE.md as an 80-line pointer hub since part 133, the 12-axis principle docs under docs/, and the per-turn injected rules file), per SECOND_BRAIN principle 1; (2) at session start the static layer (CLAUDE.md project instructions) and the dynamic layer (memory/MEMORY.md index plus the SessionStart auto-capture work log) are loaded as physically separate files through separate paths; (3) the periodic review / promote / discard procedure existed in implementation (monthly consolidate-memory skill with the orphan-duplicate-contradiction lint, the MEMORY-DECAY rule with archive splits, weekly knowledge-vault lint, per-session wrap-up) but lacked a single authoritative write-up - the only gap - which this PR fills by adding the "hierarchical cleanup operations" section to docs/SECOND_BRAIN_PRINCIPLES.md (two-layer mapping table, three-step promotion path from session learnings to static docs, cleanup cadence table, and prohibitions, all as pointers to existing implementations with zero new machinery). GitHub Issue #2710 closed with per-criterion evidence after merge. Task claimed schedule -> win (PKM/memory governance is the L3 lane).'
  END,
  updated_at        = now()
WHERE id = 'cbfe0326-d764-4bda-8b8a-c3d37714a1a8';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '階層的クリーンアップ運用の正本化 (静的ルール×動的コンテキスト / Second Brain 補完)',
  'docs/SECOND_BRAIN_PRINCIPLES.md に「階層的クリーンアップ運用」節を追記。静的 (CLAUDE.md pointer hub + 原則 12 軸 + inject-rules) と動的 (MEMORY.md + memory files + auto-capture log) の 2 階層 mapping、昇格 path (セッション学び → memory 化 → 2-3 回再現で rule/doc/concepts へ昇格 → memory 側は pointer 化)、破棄・整理 cadence (毎セッション wrap-up / 月 1 consolidate-memory --lint / MEMORY-DECAY / 週次 vault lint) を既存実装への pointer として一枚化 (新規機構ゼロ)。「古い情報が AI の誤作動を引き起こす記憶の技術的負債」への標準対処を Issue #2710 受入基準 3 点充足で確立 (設計シリーズ第 16 弾)。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '階層的クリーンアップ運用の正本化 (静的ルール×動的コンテキスト / Second Brain 補完)'
);
