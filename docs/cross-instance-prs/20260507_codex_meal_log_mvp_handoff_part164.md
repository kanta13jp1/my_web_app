# Cross-Instance PR: 食事ログ MVP 実装 hand-off (= Issue #1665 / #1269)

> **作成**: Win版#132 part 164 / 2026-05-07
> **From**: Win Claude (= architect / design)
> **To**: Win Codex (= 実装)
> **優先度**: high (= P1 / 期限 2026-05-22 / 残 15 日)
> **関連**: Issue [#1665](https://github.com/kanta13jp1/my_web_app/issues/1665) / Issue [#1269](https://github.com/kanta13jp1/my_web_app/issues/1269) (= parent) / [docs/MEAL_LOG_MVP_DESIGN_SPEC.md](../MEAL_LOG_MVP_DESIGN_SPEC.md)

---

## 概要

Issue #1665 (= 食事ログ MVP / 親 #1269) の実装を Win Codex に hand-off。Win Claude territory (= architect + UI design) で `docs/MEAL_LOG_MVP_DESIGN_SPEC.md` 完成済 (= 10 section / schema + EF action + UI レイアウト + 受け入れ条件)。

## Codex 依頼内容

### 1. Migration 作成

`supabase/migrations/<YYYYMMDDHHMMSS>_create_meal_logs.sql` 新規:

- spec §2.2 の SQL ブロックをそのまま使用
- 命名 timestamp は `[DEVELOPMENT_ACHIEVEMENTS_FORMAT]` 規約遵守

### 2. EF action 4 件追加

`supabase/functions/lifestyle-hub/index.ts` に追加:

- `meal_log.add` (= INSERT / RLS 自動適用 / no admin client)
- `meal_log.list` (= SELECT with optional date range)
- `meal_log.summary_today` (= aggregate kcal + macro by meal_type)
- `meal_log.delete` (= DELETE with owner check)

詳細 I/O は spec §2.1 の表参照。

### 3. Flutter UI 拡張

`lib/pages/recipe_meal_planner_page.dart` 編集:

- TabController length 3 → 4
- TabBar tabs に 4 番目「食事ログ」追加 (= `Icons.dinner_dining`)
- TabBarView children に新規 `_buildMealLogTab()` 追加
- 入力 dialog (= `_showMealLogInputDialog(meal_type)`) 実装
- summary section + 一覧 ListView 実装
- DESIGN.md tokens 遵守 (= Orange `#FF6B35` + Indigo `#3D5AFE` + Dark `#0A0A0A`)

詳細レイアウトは spec §3 参照。

### 4. CI + format

- `dart format <abs-path> --set-exit-if-changed` ([DART-FORMAT] 遵守)
- `flutter analyze` 0 errors / 0 warnings
- minimal-e2e-gate workflow pass (= 適切な label 付与)

## 受け入れ条件 (= 9 項目)

spec §5 をそのまま転記:

- [ ] ログイン済みユーザーが食事ログを追加・一覧表示できる
- [ ] 1 日の概算 kcal と主要栄養素 (P/F/C) の合計が表示される
- [ ] 外部 API 未設定でもローカル入力だけで動作する (= 4 number field NULL 許容)
- [ ] `dart format --set-exit-if-changed` + `flutter analyze` 0 errors
- [ ] `meal_logs` table + RLS 4 policy 全有効化
- [ ] `lifestyle-hub` EF に 4 action 追加 / [EF-CAP-50] 維持
- [ ] Admin client 経由 write なし (= `feedback_correction_20260504_schedule_hub_admin_writes` 教訓遵守)
- [ ] minimal-e2e-gate workflow pass
- [ ] PR description に Issue #1665 close note + spec link

## Win Codex 推奨実装順 (= spec §7)

1. migration 作成
2. EF action 4 件追加
3. Flutter UI 4 tab 拡張
4. dart format + flutter analyze
5. PR 作成 (title: `feat(meal-log): MVP 食事ログ統合 (#1665)`)

## 注意

- **[NO-SCOPE-CREEP]** 厳守: 本 MVP は食事ログ + summary のみ。食品 API / バーコード / グラフ / 週次推移は Phase 2 以降。
- **既存 3 tab regression**: レシピ/週間プラン/買い物リストの動作劣化なし要 smoke 確認。
- **Mobile 対応**: `dinner_dining` icon の iOS+Android 表示確認。

## Phase 0 hand-off (= Win Claude territory) 完了 note

本 hand-off 文書は Win Claude triage role の成果物 (= [INSTANCE-ROLES] 遵守 / Codex 振分 5 質問 Q1+Q2 YES → Win Claude design / 実装 = Win Codex)。

cc @kanta13jp1
