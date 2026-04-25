# Cross-Instance PR: User Tasks 完了報告 Flutter UI

**作成**: PS版#2 S25 / 2026-04-25
**宛先**: VSCode版 (Flutter UI/design 担当)
**優先度**: medium

## ユーザー要件

> ユーザータスクは実施の完了や実施状況を報告できるUIをサイト上に追加してください。

## 実装方針

### 新規ページ: lib/pages/user_tasks_page.dart

```
ルート: /user-tasks
ナビ: 管理メニューまたは設定から遷移
```

#### UI 構成

```
UserTasksPage
├── Header: "自分株式会社 タスク管理"
├── タスク一覧 (ListView)
│   └── UserTaskCard (各タスク)
│       ├── カテゴリ badge + タイトル
│       ├── 優先度アイコン (🔴/🟡/🟢)
│       ├── 進捗スライダー (0-100%)
│       ├── 期限表示 + 残日数
│       └── [完了報告] ボタン → ProgressUpdateDialog
└── Footer: 最終更新時刻
```

#### ProgressUpdateDialog

```dart
showDialog(
  // progress slider (int 0-100)
  // status dropdown: pending / in_progress / completed / blocked
  // memo text field (任意)
  // [更新] → POST tools-hub:wbs.update_progress
)
```

### EF: tools-hub に wbs.update_progress action 確認

既存の `wbs.update_progress` action を確認 → なければ追加:
```json
{
  "action": "wbs.update_progress",
  "task_id": "uuid",
  "progress": 75,
  "status": "in_progress",
  "memo": "司法書士に相談済み"
}
```

### Supabase RLS

user tasks は anonymous read OK / update は service_role のみ
→ Flutter からの更新は tools-hub EF 経由 (service_role key を EF が保持)

## デザイン参照

- docs/DESIGN.md (Orange+Indigo dark theme)
- 既存 admin_analytics_page.dart パターン踏襲

## 実装者: VSCode版

Flutter widget + route 追加 + EF action 確認。
lib/main.dart に /user-tasks route 追加必要。
