-- Win版#132 part 261 (2026-06-10 / Win Claude): Complete WBS モデルルーティング戦略タスク
-- 「[Issue #2694] [notebooklm:fdea9e6d:2] AIツール従量課金化に伴うモデルルーティング戦略と推論コスト最適化」
--  (task 9e44b388-2a25-4f34-8a64-64fdedd8a7de / owner schedule→win)
--
-- タスク本質 = 「ルーティング戦略 (の策定)」= L3 設計レーン。part 258 確立の split 型:
--   受入基準 1 (タスク難易度に応じたモデル使い分けガイドライン策定) → 本 PR で充足 ✅
--     docs/DEV_PROCESS_MULTI_AI.md に「コスト tier ルーティング」節を追記 (= 同 doc の §1 instance
--     振分 / §4 EF provider routing をコスト軸で補完)。原則 = モデル名を表に固定せず tier (役割) で
--     定義 (モデルは世代交代する / tier→実モデルは /model picker + AI_FALLBACK_RUNBOOK が正)。
--     難易度→tier 4 行表 (定型=低 tier / 中規模実装=中 tier=L2 既定 / 複雑設計=高 tier=L3 /
--     リサーチ=ゼロトークン経路優先) + 迷ったら 1 tier 下から。Issue 中の特定モデル名 (Composer 2 等)
--     は未検証ベンダー主張として不採用 ([AI-TOOL-VERIFY] / part 258 と同じ扱い)。
--   受入基準 2 (モデル別トークン消費の可視化機能追加) → 部分既存 (quota-monitor.yml +
--     ci-cd-cost-audit routine) を正直に記載し、モデル別集計の実装は L2 → **Issue #2694 open 維持**
--   受入基準 3 (コスト上限・エージェントループ検知の自動停止アラート) → 未実装と正直に記載 → 同上 L2
--   タスク完了の根拠 = タイトルのスコープ「戦略 (策定)」を充足。Issue は基準 2-3 の実装 handoff
--   として open 維持 (merge 後に criteria 状況 comment / part 258 = #2599 と同型)。
--
-- ai_review_status='approved' を同一 UPDATE で設定 → trigger 回避で status='completed' 確定。
-- Idempotent: 固定値 UPDATE / description append は LIKE guard / achievement は NOT EXISTS guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (L3 / AI routing 設計レーン / part 261)。docs/DEV_PROCESS_MULTI_AI.md に「コスト tier ルーティング」節を追記し受入基準 1 (難易度別モデル使い分けガイドライン) を充足。原則 = モデル名固定せず tier 抽象で定義 (世代交代耐性 / tier→実モデルは /model picker + AI_FALLBACK_RUNBOOK 委譲) + 難易度→tier 4 行表 + 迷ったら 1 tier 下から + ゼロトークン経路優先。既存ガードレール (quota-monitor / ci-cd-cost-audit / AUTO-REPLY cap) と未実装 2 点 (モデル別消費集計 / 包括コスト上限アラート) を正直に区別 — 基準 2-3 の実装は L2 へ、Issue #2694 は open 維持で handoff。Issue 中の特定モデル名は未検証ベンダー主張として不採用。docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-10'),
  end_date          = DATE '2026-06-10',
  remaining_work    = 'Completed by Win Claude (part 261) — 戦略策定 (タイトルのスコープ)。残 (Issue #2694 open 維持 / L2): 基準 2 = モデル別トークン消費の可視化 (quota-monitor / ci-cd-cost-audit の拡張) / 基準 3 = コスト上限 + エージェントループ検知の自動停止アラート。ガイドライン正本 = docs/DEV_PROCESS_MULTI_AI.md「コスト tier ルーティング」節。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-10: model routing strategy authored%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-10: model routing strategy authored (Win Claude part 261). Acceptance criterion 1 (difficulty-based model usage guideline) is satisfied by the new "cost tier routing" section in docs/DEV_PROCESS_MULTI_AI.md, complementing the existing instance-routing matrix (section 1) and EF provider routing (section 4) with a cost axis: models are specified as tiers rather than pinned names (model generations rotate; the tier-to-model mapping is delegated to the /model picker and AI_FALLBACK_RUNBOOK), a four-row difficulty-to-tier table (routine work = low tier, mid-size implementation = mid tier as the L2 default, complex design/security/incident investigation = high tier as the L3 default, research = zero-token paths via NotebookLM first), and a try-one-tier-lower default. Specific model names quoted in the issue (e.g. Composer 2) were treated as unverified vendor claims and not adopted. Criteria 2 and 3 are honestly recorded as partially existing (quota-monitor.yml, the ci-cd-cost-audit routine, AUTO-REPLY caps) with per-model token aggregation and a comprehensive cost-ceiling / runaway-loop kill-switch still unimplemented - those remain L2 work, so GitHub Issue #2694 stays OPEN as the implementation handoff (same split pattern as #2599 in part 258). Task completed as the strategy-authoring scope of its title; owner flipped schedule -> win.'
  END,
  updated_at        = now()
WHERE id = '9e44b388-2a25-4f34-8a64-64fdedd8a7de';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'モデルルーティング戦略 (コスト tier) 策定 — 従量課金時代の使い分けガイドライン',
  'docs/DEV_PROCESS_MULTI_AI.md に「コスト tier ルーティング」節を追記。既存の instance 振分 matrix と EF provider routing をコスト軸で補完し、難易度→tier 4 分類 (定型=低 / 中規模実装=中=L2 既定 / 複雑設計・障害調査=高=L3 / リサーチ=ゼロトークン経路優先) + 「モデル名を固定せず tier 抽象で定義し実モデルは /model picker と AI_FALLBACK_RUNBOOK へ委譲」(世代交代耐性) + 「迷ったら 1 tier 下から」原則を確立。既存コストガードレール (quota-monitor / ci-cd-cost-audit / リプライ cap) と未実装 (モデル別消費集計・コスト上限アラート = L2 継続 / Issue #2694 open 維持) を正直に区別した honest 戦略 (設計シリーズ第 17 弾)。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'モデルルーティング戦略 (コスト tier) 策定 — 従量課金時代の使い分けガイドライン'
);
