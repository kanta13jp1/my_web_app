-- Win版#132 part 256 (2026-06-10 / Win Claude): ADR 系重複タスク 2 件の completed-by-reference 解消
--  (1) 3e984213-364f-4352-a286-e61f3549629f 「[Issue #1847] ADR directory 確立 — docs/adrs/ + 初回ADR entries」
--  (2) 99785f1a-1636-4c26-a62a-58e12cdfe8fa 「[Issue #1736] ADR文書化運用導入 — AI_FLEET_SYNERGY原則2適用」
--
-- 判定 (SDLC×WBS カバレッジ監査 part 254 の dedup 手順を再適用 / verify 済み):
--   両タスクの実体は part 241 (2026-06-05 / WBS 2e41ebca) で docs/adr/ として完了済み —
--   README.md (運用ガイド: いつ書くか / 命名 / Status lifecycle / TEMPLATE / WBS・Issue・NotebookLM 紐づけ)
--   + TEMPLATE.md + ADR 4 本 (2026-04-30 EF dependency / 2026-06-05 stack 選定・EF-first・2-instance fleet)。
--   ディレクトリ名は Issue 文言の docs/adrs/ でなく docs/adr/ (PRD §8 からも参照される確立済み正本)。
--   2-instance fleet ADR が AI_FLEET_SYNERGY 原則 2 (Plan-Execute-Review 分担) の適用判断に該当。
--   #1736 の残 gap 「cross-instance-pr 必須化」のみ本 PR で README に明文化して充足
--   (ADR の Decision が他レーン実装を生む場合は docs/cross-instance-prs/ handoff 起票必須 + Links 記載)。
--   GitHub Issue #1847 / #1736 は本 PR merge 後に根拠コメント付きで close する。
--
-- 新規成果物は README 1 行 (運用ルール追記) のみの dedup 解消のため development_achievements INSERT なし。
-- ai_review_status='approved' を同一 UPDATE で設定 → trigger 回避で status='completed' 確定。
-- Idempotent: 固定値 UPDATE / description append は LIKE guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (L3 / part 256 dedup triage)。completed-by-reference: 実体は part 241 の docs/adr/ (README 運用ガイド + TEMPLATE + ADR 4 本 / ディレクトリ名は adrs でなく adr / PRD §8 参照の確立済み正本)。初回 ADR entries 要求は 4 本で充足、AI_FLEET_SYNERGY 原則 2 適用は 2026-06-05-two-instance-fleet-architect-implementer.md が該当。Issue #1847 は merge 後 close。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-10'),
  end_date          = DATE '2026-06-10',
  remaining_work    = 'Completed by reference (part 256). 実体 = docs/adr/ (part 241 / WBS 2e41ebca)。残: なし (Issue #1847 close は PR merge 後)。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-10: duplicate of docs/adr%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-10: duplicate of docs/adr established in part 241 (Win Claude part 256 dedup triage). The requested ADR directory exists as docs/adr/ (naming variant of the docs/adrs/ in the issue text) with README operating guide, TEMPLATE.md, and four initial ADR entries including 2026-06-05-two-instance-fleet-architect-implementer.md which applies AI_FLEET_SYNERGY principle 2 (Plan-Execute-Review). Closed as completed-by-reference per the part 254 dedup discipline; GitHub Issue #1847 will be closed with evidence after the PR merges.'
  END,
  updated_at        = now()
WHERE id = '3e984213-364f-4352-a286-e61f3549629f';

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (L3 / part 256 dedup triage)。completed-by-reference + 残 gap 充足: ADR 文書化運用は part 241 の docs/adr/ README が導入済み (いつ書くか / 命名 / Status / WBS・Issue・NotebookLM 紐づけ)。Issue #1736 の残要素「cross-instance-pr 必須化」は本 PR で README に明文化 (Decision が他レーン実装を生む場合は docs/cross-instance-prs/ handoff 起票必須 + Links 記載)。Issue #1736 は merge 後 close。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-10'),
  end_date          = DATE '2026-06-10',
  remaining_work    = 'Completed (part 256). 実体 = docs/adr/ README (part 241) + 本 PR の cross-instance-pr 必須化 1 行。残: なし (Issue #1736 close は PR merge 後)。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-10: ADR operating practice%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-10: ADR operating practice was already introduced in part 241 at docs/adr/README.md (when to write, naming, status lifecycle, template, WBS / Issue / NotebookLM linkage), applying AI_FLEET_SYNERGY principle 2 via the two-instance Architect-Implementer ADR. The one remaining element of Issue #1736 — making a cross-instance handoff mandatory — is satisfied in this PR by an explicit README rule: when an ADR decision spawns work for another lane, filing a docs/cross-instance-prs/ handoff is mandatory and must be referenced in the ADR Links section. Completed by Win Claude part 256 dedup triage; GitHub Issue #1736 will be closed with evidence after the PR merges.'
  END,
  updated_at        = now()
WHERE id = '99785f1a-1636-4c26-a62a-58e12cdfe8fa';
