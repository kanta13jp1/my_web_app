---
name: WBS/資産管理/NotebookLM flood の実態 (2026-07-16 セッション)
description: WBS guard の挙動・資産管理クラスタの実装状況・NotebookLM 352 件氾濫の構造
type: project
---

## 新規発見

### WBS の仕組み
- `wbs_tasks` は migration 駆動。`wbs_guard_open_github_issue_completion` トリガーが、**open** な GitHub Issue 紐づきタスクを completed/100% にできないよう保護 (`ai_review_status IN (approved/verified/passed/manual_override)` を同一 UPDATE で設定すれば通過)。
- `GitHub Issues WBS Sync` は **GitHub を真実源**に WBS を追随 (closed issue → WBS completed)。よって偽完了は数時間で巻き戻る。
- **stale row 多数**: GitHub で closed なのに WBS で pending/in_progress のまま残る行が多い (sync 未走 or リンク切れ)。migration で `github_issue_state='CLOSED' + status=completed + ai_review_status='manual_override'` で正当修復可。
- 同一 Issue に WBS 行が 2 本 (「GitHub Issue」行 +「ユーザー要望」行) 存在するケースが多い (別 dedup 軸)。

### 資産管理クラスタ (~17 Issue → 中核は実装済み)
- 実装済み: ショート検知→振替提案 (`_buildTransferSuggestions` planning:1729) / 提案→transfer_task (`_createTransferTaskFromSuggestion` page:3534) / 支払原資未設定レビュー (page:22396/22598) / 明細照合 engine (planning:1187) / status→残高即時再計算 (planning:1693 + page:8181 毎 build 再構築)。
- 未実装 (真の残): 仮内訳 (#3349 / `provisional` grep=0)、自動実行 (#3443 / `user_settings_service.dart` 不在)、各 wizard/UI (#3329/#3326/#3291)、`PaymentFundingRule` (#3354)。
- 本セッションで core 着地: `card_statement_reconciliation_planner.dart` (#3329/#3326/#3349) + `payment_confirmation_gate.dart` (#3291)。→ 残件は #3443 のみ。

### NotebookLM Issue flood
- `label:notebooklm` open = **352 件**、triage 済み 1、priority:high 1 (#2967)。
- 生成源: `notebooklm_requirements_to_issues.py` が 114 notebook × 3 要望を自動抽出。source notebook が **アプリと無関係** (CATS 障害通知 / Cursor changelog / ENEOS 買収) 多数。
- テーマ重複が既存実装と対応: 承認 (~20) → `ai_review_status`+guard、モデルルーティング/コスト (~54) → `ai_router_cost_optimization.ts`+migration `20260610140000`。
- #2967 (P1) は「復旧してさらに 3件/notebook 抽出」= 氾濫増加方向 → **relevance gate + cap 付き復旧**に再定義すべき。

### remote env
- 有: node22 (`--experimental-strip-types` 可)、python3、git、gh は無く GitHub MCP (`mcp__github__*`)。
- 無: dart / flutter / deno。deno.land は proxy 403。WBS 更新は curl でなく migration。

**Why:** これらは次回 WBS 削減・資産管理実装・NotebookLM drain の前提知識。
**How to apply:** 資産管理は #3443 だけ実装レーンへ。NotebookLM は drain (script) + throttle (#2967 再定義) の両輪。WBS 削減は migration 経由。
