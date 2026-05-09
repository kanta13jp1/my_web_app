# Cross-Instance PR — /project-gantt Phase 1 段階導入 5 view → Win Codex

> **Author**: Win Claude (Win版#132 part 190 / 2026-05-09 JST)
> **Target**: Win Codex
> **Parent EPIC**: [#2220](https://github.com/kanta13jp1/my_web_app/issues/2220) (= 76 atomic / 29 Phase A + 47 Phase B)
> **Phase 1 atomic Issues**: [#2223](https://github.com/kanta13jp1/my_web_app/issues/2223) [#2224](https://github.com/kanta13jp1/my_web_app/issues/2224) [#2225](https://github.com/kanta13jp1/my_web_app/issues/2225) [#2227](https://github.com/kanta13jp1/my_web_app/issues/2227) [#2233](https://github.com/kanta13jp1/my_web_app/issues/2233)
> **Deadline**: 2026-05-30 (= 21 day buffer / 5 atomic / 4 days/atomic)

## 概要

Part 189-b で起票した EPIC #2220 (= /project-gantt 76 view 追加 / 29 Phase A + 47 Phase B atomic) の **段階導入 Phase 1** として、user 直接 ask の「次に追加すべき 5 つ」を Win Codex hand-off.

EPIC #2220 累計 76 atomic を一気に投げると Codex も work-in-progress 過大. Phase 1 = 5 view を最優先 ship → Phase 2-4 で残 71 view を順次消化する流れ.

## 振分判定 ([INSTANCE-ROLES] 5 質問 score 化)

| Q | 内容 | A | 理由 |
|---|------|---|------|
| Q1 | 設計判断 / 仕様策定が必要? | NO | EPIC #2220 + 各 atomic に受け入れ条件確定済 |
| Q2 | docs / memory / Roadmap 更新が必要? | NO | 実装後 ROADMAP append のみ (= 実装内 docs だけ) |
| Q3 | UI design tokens / 競合分析が必要? | NO | 既存 `/project-gantt` 7 view の design tokens 流用 |
| Q4 | sensitive secrets / 法務 / 個人情報? | NO | 純 UI tab + 既存 `wbs.list_tasks` action 再利用 |
| Q5 | mobile UAT / AI 大学 contents 必要? | NO | mobile UAT は本 PR 完了後の別 session task |

→ **全 NO = Win Codex 担当** ([INSTANCE-ROLES] rule)

## Phase 1 scope (= 5 atomic / 4 days/atomic)

| Issue | View name | 想定実装 |
|-------|-----------|----------|
| [#2223](https://github.com/kanta13jp1/my_web_app/issues/2223) | カンバンボードView | 未着手・進行中・レビュー中・完了・ブロック中 column / drag-drop で status 移動 |
| [#2224](https://github.com/kanta13jp1/my_web_app/issues/2224) | カレンダーView | 開始予定 / 完了予定 / 締切を日付ベースで表示 |
| [#2225](https://github.com/kanta13jp1/my_web_app/issues/2225) | ガントチャートView | タスク期間 / 依存関係 / 遅延を横軸時間で表示 |
| [#2227](https://github.com/kanta13jp1/my_web_app/issues/2227) | バックログView | 未着手 issue を優先度順 list 表示 |
| [#2233](https://github.com/kanta13jp1/my_web_app/issues/2233) | ブロッカーView | 他タスクを止めている issue だけ filter 表示 |

## 実装方針

### 1. 既存 `lib/pages/project_gantt_page.dart` 拡張

```dart
// 既存 7 tab に 5 tab 追加
enum ViewType {
  // 既存
  developmentWbs, timeline, myProject, graph, aiPerspective, dependencyRepair, csv,
  // Phase 1 追加
  kanban, calendar, gantt, backlog, blocker,
}
```

### 2. data layer = 既存 `app-hub` `wbs.list_tasks` action 再利用 ([EF-CAP-50] 維持)

新 EF 不要. 必要なら `wbs.list_tasks` の filter parameter を拡張:

```typescript
// supabase/functions/app-hub/wbs.ts
type ListTasksParams = {
  // 既存
  instance?: string; status?: string; ...
  // Phase 1 追加 (= optional)
  blocker_only?: boolean;     // ブロッカーView 用
  due_range?: [string, string]; // カレンダーView 用
}
```

### 3. UI tokens = 既存 `docs/DESIGN.md` Orange + Indigo dark theme 準拠

新 token 追加禁止. 既存 `Theme.of(context).colorScheme.{primary|secondary|...}` のみ使用.

### 4. drag-drop = カンバンView only

```dart
// lib/widgets/project_gantt/kanban_column.dart
class KanbanColumn extends StatelessWidget {
  // DragTarget<TaskCard> で status 変更 → wbs.update_progress action
}
```

### 5. ガントチャート = 既存 `gantt_chart` package or 自前 Painter

既存 view (= `timeline`) で `CustomPaint` 使用済. 同 pattern で gantt 描画推奨. 外部 package 追加は要確認.

## 受け入れ条件 (= 5 atomic 全て)

各 atomic の受け入れ条件 (= EPIC #2220 atomic body 参照):

- [ ] `/project-gantt` から該当 view tab を選択できる
- [ ] view が想定 UI で表示される
- [ ] [REAL-DATA] 遵守 — Supabase WBS データを使用 (= ダミーなし)
- [ ] [DESIGN.md] dark theme tokens 準拠
- [ ] `flutter analyze --no-fatal-warnings` 0 warning
- [ ] mobile + web 両方で動作確認

加えて Phase 1 全体:

- [ ] 既存 7 view を破壊しない (= regression なし)
- [ ] `wbs.list_tasks` action の backward compat 維持
- [ ] 5 atomic を 1 PR で ship OR 5 PR に split (= Codex 判断)

## CI / テスト

```bash
# Code quality
dart format lib/pages/project_gantt_page.dart --set-exit-if-changed
flutter analyze --no-fatal-warnings

# Tests
flutter test test/widget/project_gantt/kanban_view_test.dart
flutter test test/widget/project_gantt/calendar_view_test.dart
flutter test test/widget/project_gantt/gantt_view_test.dart
flutter test test/widget/project_gantt/backlog_view_test.dart
flutter test test/widget/project_gantt/blocker_view_test.dart

# E2E (= optional)
npx playwright test e2e/project_gantt_phase1.spec.ts
```

## 参考 / 関連

- 親 EPIC: [#2220](https://github.com/kanta13jp1/my_web_app/issues/2220) (= 76 atomic / Phase A 29 + Phase B 47)
- Phase A atomic 一覧: #2221-#2249 (= P0 8 / P1 9 / P2 7 / P3 5)
- Phase B atomic 一覧: #2251-#2297 (= 12 カテゴリ)
- PR #2298 (= part 190 / Phase B 47 atomic ship)
- 既存 `/project-gantt` page: <https://my-web-app-b67f4.web.app/project-gantt>
- 関連 EPIC: [#2204](https://github.com/kanta13jp1/my_web_app/issues/2204) (= Google Calendar 全機能 / Phase 4 ある)

## 段階導入 sequence (= Codex Phase 1 → Phase 2-4)

| Phase | Scope | 期限 | 担当 |
|-------|-------|------|------|
| **Phase 1 (= 本 doc)** | 5 view (= #2223 #2224 #2225 #2227 #2233) | 2026-05-30 | Win Codex |
| Phase 2 | 残 P0 3 view (= #2221 #2222 #2226 #2228) + P1 4 view | 2026-06-15 | Win Codex (= 別 hand-off doc) |
| Phase 3 | P1 残 5 + P2 7 view | 2026-06-30 | Win Codex |
| Phase 4 | P3 5 + Phase B 47 view (= 段階消化) | 2026-09-30 | Win Codex (= 月単位 batch) |

## Win Claude side フォロー

- Phase 1 PR 提出後: status comment 5 件 (= 各 atomic) + EPIC #2220 status comment 1 件
- Phase 2 hand-off doc: Phase 1 完了確認後、別 session で起票
- mobile UAT: Phase 1 完了後 mobile版インスタンス hand-off (= dormant 解除)

## Philosophy Alignment ([PHILOSOPHY-22])

- 主要実装: 76 atomic 一括投げ → 段階導入 5 view で Codex work-in-progress 制御
- 該当原則: #1 (CEO 感) #2 (mission) #5 (商品=価値) #6 (時間=資本) #7 (資産負債) #8 (KPI) #9 (IPO)
- 整合性スコア: **7/9 ✅**

---

> **Hand-off ship**: Win Claude part 190 (2026-05-09 JST). cross-instance-pr md by Win Claude / 実装 PR by Win Codex.
