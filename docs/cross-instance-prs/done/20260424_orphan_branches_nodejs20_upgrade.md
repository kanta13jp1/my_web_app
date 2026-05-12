# Cross-Instance PR: orphan branches merge + Node.js 20 deprecation 対応

**作成**: PS#1 S28 / 2026-04-24
**宛先**: PS#5 (orphan mobile fixes) + VSCode版 (GHA actions upgrade)
**期限**: 2026-06-01 (Node.js 20 は 2026-06-02 に強制 Node.js 24 移行)

---

## タスク A: orphan branches マージ → PS#5 担当

### 未マージ branches (main に含まれていない commits あり)

| Branch | 未マージ commits | 内容 |
|--------|----------------|------|
| `claude/mobile-version-task-hQxcq` | 10件 | mobile UI fixes (WCAG / dark bg / WBS-gantt) |
| `claude/mobile-version-task-2B9tz` | 1件 | cross-instance-pr UI Design Rollout |
| `claude/web-version-tasks-oev9R` | 複数 | web page fixes |

### hQxcq の主要 fixes (未マージ)
- `fix(wbs-gantt): hide non-essential columns by default on narrow viewports`
- `fix(ai-university): wrap MarkdownBody in DefaultTextStyle for table cells`
- `fix(home): 最近使った機能 chip label unreadable on dark background`
- `fix(ai-university): bump h2/h3 brightness to meet WCAG AA on dark bg`
- `fix(home): 継続カレンダー title stacked vertically on mobile width`
- `fix(ai-provider-registry): mark Groq as implemented`
- `fix(ai-university): unreadable markdown table cells on dark background`
- `feat(home-menu): register ProjectGanttPage as WBS entry in business menu search`
- `feat: add AppVersion const for APP_VERSION dart-define`

### 対応手順 (PS#5)
```bash
# 各 branch を確認してマージ
git fetch origin claude/mobile-version-task-hQxcq
git log origin/main..origin/claude/mobile-version-task-hQxcq --oneline

# 問題なければ main にマージして branch 削除
git merge origin/claude/mobile-version-task-hQxcq --no-edit
git push origin HEAD:main
git push origin --delete claude/mobile-version-task-hQxcq
git push origin --delete claude/mobile-version-task-2B9tz
git push origin --delete claude/web-version-tasks-oev9R
```

**注意**: マージ前に `flutter analyze` で 0 issues を確認すること。
dart format 差分があれば先に実行して commit。

---

## タスク B: Node.js 20 actions upgrade → VSCode版 担当

### 対象 actions (Node.js 20 → 24 対応が必要)

| Action | 現在バージョン | 対応方法 |
|--------|--------------|---------|
| `FirebaseExtended/action-hosting-deploy` | `@v0` | `@v0` は最新版を自動追従するため upgrade 不要。ただし deprecation warning が出ている → `@v0` のまま様子見 or upstream 確認 |
| `supabase/setup-cli` | `@v1` | `@v1` → `@v2` を確認 |

### 期限
- **2026-06-02**: Node.js 24 がデフォルト化 → `@v0 / @v1` が Node 20 のままなら fail リスク
- **2026-09-16**: Node.js 20 runner 完全削除

### 対応手順 (VSCode版)
```bash
# supabase/setup-cli の最新版確認
# https://github.com/supabase/setup-cli/releases
# v2 があれば deploy-prod.yml の supabase/setup-cli@v1 → @v2 に変更

# FirebaseExtended/action-hosting-deploy は @v0 が latest tag を追従するため
# FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true env var 追加も可
```

ファイル: `.github/workflows/deploy-prod.yml`

## ✅ タスクB完了 (VSCode版 S4 2026-04-25)

- `supabase/setup-cli@v1` → `@v2` 更新 (deploy-prod/dev/staging.yml)
- commit: 7842bd8c
- Node.js 24 互換確保 / deadline 2026-06-02 対応済み
