# [VSCode版 → Win版] Issue自動クローズバグ 調査・修正報告

**発行日**: 2026-04-26  
**発行**: VSCode版  
**宛先**: Win版 (根本原因修正 + WBS dedup対応)  
**優先度**: high

## 事象

GitHub Actions `issue-to-wbs.yml` が 9件のユーザー作成 Issue を誤ってクローズ。
- #669 #668 #667 #666 #665 #664 #660 #659 #658 (全て「追加要望」)

## 応急対応 (VSCode版 S5 完了)

1. **Issues を全件再オープン** (gh CLI / 2026-04-26)
2. **WBS タスク status を pending にリセット** (8件 / tools-hub wbs.update_progress)
3. **issue-to-wbs.yml に安全ガード追加** (commit: 8b2b041f)
   - `追加要望 / enhancement / feature / feature-request` ラベルは auto-close 対象外
   - `github-actions[bot]` 作成のみ auto-close OK
   - それ以外はデフォルト SKIP

## 根本原因 (未解決 → Win版対応依頼)

### 原因1: WBS sync の feedback loop
```
Issue OPEN → sync でWBStask作成
→ なんらかの原因でWBStask = completed
→ 次の sync でIssueをクローズ
→ Issue CLOSED → sync でWBStask = completed確定
```

### 原因2: WBS-DEDUP問題 (migration 20260425203000)
- `instance='all'` のCartesian INSERT → 同一Issue に複数WBSタスク
- 重複タスクの1件でも completed になると Issue がクローズされる
- `wbs.sync_github_issues` の重複処理コード (L1635-1650) が
  duplicate を completed にセットする副作用あり

```typescript
// tools-hub/index.ts L1635
for (const duplicate of duplicateTasks) {
  await admin.from("wbs_tasks").update({ status: "completed", ... })
```

→ Issue にリンクした WBS task が複数ある場合、keeper以外が completed になり
  Issue が誤クローズされるリスクが残る。

## Win版対応依頼

1. **WBS dedup migration の完全修正** (20260425203000/205000の cartesian INSERT 除去)
2. `wbs.sync_github_issues` の重複処理を修正:
   - duplicate tasks を `completed` にするのではなく `archived` ステータスか
     `github_issue_number = null` に設定して sync 対象外にする
3. Issue-to-WBS のフィードバックループ設計レビュー

## 参考

- 問題 migration: `20260425203000_business_wbs_phase1.sql` (cartesian INSERT)
- WBS-DEDUP cross-instance-pr: `docs/cross-instance-prs/20260425_wbs_dedup_fix.md`
- 安全ガード commit: `8b2b041f` (issue-to-wbs.yml)
