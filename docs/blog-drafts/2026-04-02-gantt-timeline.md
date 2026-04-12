---
title: Flutter WebでNotionを超えるガントチャート・タイムライン機能を実装した
emoji: 📊
type: tech
topics: [flutter, supabase, gantt, project_management, dart]
published: true
---

# Flutter WebでNotionを超えるガントチャート・タイムライン機能を実装した

## はじめに

「自分株式会社」というAI統合ライフマネジメントアプリを個人開発しています。Notion・Evernote・MoneyForward・X・Slack など21の競合SaaSを1つのアプリで代替することを目標にしています。

今回はNotionの重要機能の一つである**タイムラインビュー（ガントチャート）**をFlutter Web + Supabase Edge Functionで実装しました。

サービスURL: https://my-web-app-b67f4.web.app/

## 実装した機能

### ガントチャートの全体構成

`GanttTimelinePage` を3タブ構成で実装しました：

1. **プロジェクトタブ** — プロジェクト一覧・作成・選択
2. **タイムラインタブ** — タスク・マイルストーンのGanttバー表示
3. **クリティカルパスタブ** — 最遅完了タスクのランキング分析

### バックエンド: gantt-timeline-manager Edge Function

Edge Functionは既存の `app_analytics` テーブルをJSONBメタデータとして流用し、ガントデータを保持します。新規テーブルを増やさないシンプル設計です。

```typescript
// タスク追加 (source='gantt_task' として app_analytics に保存)
const { error } = await adminClient.from("app_analytics").insert({
  user_id: user.id,
  source: "gantt_task",
  metadata: {
    task_id: crypto.randomUUID(),
    project_id,
    name,
    duration_days,
    start_date,
    status: "pending",
    progress: 0,
  },
});
```

### フロントエンド: タスクのGanttバー表示

Flutter の `LinearProgressIndicator` を活用してGanttバーを実装しました。`ClipRRect` で角丸にすることでモダンな見た目を実現しています。

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: LinearProgressIndicator(
    value: progress.clamp(0.0, 1.0),
    minHeight: 12,
    backgroundColor: Colors.grey.shade200,
    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
  ),
),
```

ステータス別カラーはシンプルなswitch文で管理：

```dart
Color statusColor;
switch (status) {
  case 'done':
    statusColor = Colors.green;
  case 'in_progress':
    statusColor = Colors.blue;
  case 'blocked':
    statusColor = Colors.red;
  default:
    statusColor = Colors.grey;
}
```

### クリティカルパス分析

「最も遅く完了するタスク」を特定するシンプルなクリティカルパス計算をEdge Function側に実装しています。

```typescript
const endDates = [];
for (const [taskId, task] of taskMap) {
  const start = new Date(task.start_date ?? Date.now());
  const duration = task.duration_days ?? 1;
  const end = new Date(start.getTime() + duration * 86400000);
  endDates.push({ taskId, name: task.name, endDate: end.toISOString(), duration });
}
endDates.sort((a, b) => new Date(b.endDate).getTime() - new Date(a.endDate).getTime());
```

## 詰まったポイント

### dynamic型エラー (avoid_dynamic_calls)

`supabase.functions.invoke()` の戻り値は `dynamic` 型なので、直接プロパティアクセスすると `avoid_dynamic_calls` エラーが発生します。

```dart
// ❌ エラー
_tasks = (taskRes.data?['tasks'] as List?) ?? [];

// ✅ 修正: 先にMapにキャスト
final taskData = taskRes.data as Map<String, dynamic>?;
_tasks = (taskData?['tasks'] as List?) ?? [];
```

`flutter analyze 0件` 維持のために型安全なアクセスが必要です。

## 競合との比較

| 機能 | Notion Timeline | 自分株式会社 |
|------|----------------|-------------|
| タスク追加 | ✅ | ✅ |
| マイルストーン | ✅ | ✅ |
| クリティカルパス | ❌ | ✅ |
| 無料利用 | ❌ (有料プランのみ) | ✅ |

## まとめ

Notionのタイムラインビューに相当するガントチャート機能をFlutter Webで実装しました。`app_analytics` テーブルの流用でDBスキーマを最小限に保ちつつ、クリティカルパス分析という差別化機能まで実装できました。

引き続き21競合を超えるAI統合プラットフォームを構築中です。

サービスURL: https://my-web-app-b67f4.web.app/
GitHubリポジトリ: https://github.com/kanta13jp1/my_web_app

#FlutterWeb #Supabase #buildinpublic #ProjectManagement
