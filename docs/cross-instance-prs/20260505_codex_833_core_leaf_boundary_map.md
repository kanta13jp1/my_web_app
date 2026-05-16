# Win Codex hand off: #833 Core/Leaf 境界マップ (= part 156)

> **From**: Win Claude (= part 156)
> **To**: Win Codex
> **Priority**: medium
> **Issue**: [#833](https://github.com/kanta13jp1/my_web_app/issues/833)
> **Spec**: [`docs/CORE_LEAF_BOUNDARY_MAP_SPEC.md`](../CORE_LEAF_BOUNDARY_MAP_SPEC.md)
> **推定工数**: 8h
> **期限**: 2026-05-15 (= 10 day)

## Summary

Vibe Coding (= NotebookLM `ddde5a4b`) を応用した core/leaf governance マップ. 主要 dir/機能を `core` / `leaf` / `mixed` に programmatic 分類 + Issue/WBS 必須記録 + GHA 静的検証 + AI 開発原則ページ参照可能化.

## Hand off scope (= 7 件 / 8h)

1. migration `create_core_leaf_classifications.sql` + initial seed (= ~50 path 事前分類) (2h)
2. migration `add_wbs_tasks_boundary_class.sql` (0.5h)
3. `tools-hub.governance.classify_path` action (1.5h)
4. GHA workflow `core-leaf-coverage-check.yml` (1h)
5. GitHub Issue template 更新 (= boundary_class dropdown) (0.5h)
6. Flutter UI: `core_leaf_map_page.dart` 新規 + ai_dev_principles_page button + project_gantt badge (2h)
7. dart format + flutter analyze + smoke test (0.5h)

## 受け入れ条件 (= Issue #833 / 5 件)

- [ ] 主要 dir/機能を core/leaf/mixed に分類
- [ ] core 変更時の review 観点明記 (= 6 観点 / spec §6)
- [ ] Issue/WBS に境界分類 記録
- [ ] AI 開発原則ページから参照可
- [ ] テスト/静的検証で分類欠落検出 (= GHA workflow)

## 重要 cross-link

**[VIBE_SANDBOX_SPEC] と同 NotebookLM `ddde5a4b` 三つ子完結**:

| Issue | spec | 役割 | ship part |
|---|---|---|---|
| #839 + #1209 | VIBE_SANDBOX_SPEC | runtime sandbox | part 155 (= 統合 第 1) |
| #833 | CORE_LEAF_BOUNDARY_MAP | governance | part 156 (= 三つ子完結) |

実装時 [`docs/VIBE_SANDBOX_SPEC.md`](../VIBE_SANDBOX_SPEC.md) と整合性必須 (= AI が触っていい範囲を runtime + governance 両面で同期).

## 6 観点 immutable list (= spec §6)

core 変更 PR の必須 review checklist (= AI が削除/変更禁止):

1. 認証 (RLS / auth.uid / role escalation)
2. DB (migration reversible / production data 破壊なし)
3. 課金 (Stripe webhook / billing logic / refund)
4. 外部投稿 (Qiita/dev.to/Slack/Discord / rate limit / token)
5. Secrets (env var / rotation / leak audit)
6. rollback (1-commit revert で本番復旧可)

## ルール遵守 check

- [x] [EF-FIRST] (= tools-hub action 拡張 / 新 EF 不要)
- [x] [EF-CAP-50] (= 50 維持)
- [x] [REAL-DATA] (= core_leaf_classifications 実テーブル)
- [x] [DART-FORMAT] (= 絶対パス + pipe なし)
- [ ] [DYNAMIC-CLAIM] cap (= Codex 着手時 wbs.claim_task)
- [ ] [WORKDIR-ISOLATION]
- [ ] [VIBE_SANDBOX_SPEC] cross-link 整合性

## 関連

- spec: `docs/CORE_LEAF_BOUNDARY_MAP_SPEC.md` (= 11 section / 9 原則 / NOT to do 7 + MUST do 10)
- 関連 spec: `docs/VIBE_SANDBOX_SPEC.md` (= 三つ子第 1+2)
- 既存 EF: `supabase/functions/tools-hub/`
- 既存 page: `lib/pages/ai_dev_principles_page.dart` / `lib/pages/project_gantt_page.dart`
- NotebookLM: `ddde5a4b-ce1a-405d-8291-a334a9371454`

## 起票元 part

- part 156 / Win Claude / 2026-05-05
- 1 session 3 spec ship record (= #768 + #772 + #833) / chain merge primary 含めて 4 PR merged
