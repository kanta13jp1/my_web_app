---
title: "カンバンボードを AI が自動ソートする — 「優先度の判断」を外注する設計"
tags: productivity,AI,個人開発,saas
published: false
---

# カンバンボードを AI が自動ソートする — 「優先度の判断」を外注する設計

## カンバンの「並び順」は誰が決めるか

Trello・Notion・Linear ——— カンバンボードはどれも「タスクを並べ替える」という作業を人間がやる前提で設計されている。

ドラッグ&ドロップで並べ替え、ラベルを付け、フィルターをかける。この作業に費やす時間は「実際の仕事」ではない。

自分株式会社の WBS システムは AI がこの並び順を自動決定する。

---

## rescue_score による自動ソート

前回の WBS 記事で紹介した `rescue_score` がカンバンのソートエンジンになっている:

```
rescue_score =
  (期限超過日数 × 40) +   ← 期限切れは緊急
  (更新停滞日数 × 20) +   ← 放置は危険
  (priority_rank × 25) + ← high は重要
  (進捗率 × 15)           ← 着手済みは継続
```

この計算式で全タスクをスコアリングし、**降順で表示**する。人間が並べ替える必要はない。

---

## 実装: Supabase View + Flutter

### Supabase 側 (ソート済みビュー)

```sql
-- カンバン表示用のソート済みビュー
CREATE VIEW wbs_kanban AS
SELECT
  id,
  title,
  status,
  progress,
  priority,
  instance,
  end_date,
  updated_at,
  -- rescue_score 計算
  (
    GREATEST(0, EXTRACT(DAY FROM (NOW() - end_date::TIMESTAMPTZ))) * 40 +
    GREATEST(0, EXTRACT(DAY FROM (NOW() - updated_at))) * 20 +
    CASE priority
      WHEN 'critical' THEN 100
      WHEN 'high'     THEN 75
      WHEN 'medium'   THEN 50
      WHEN 'low'      THEN 25
      ELSE 0
    END * 25 / 100 +
    progress * 15 / 100
  ) AS rescue_score
FROM wbs_tasks
WHERE status != 'completed'
ORDER BY rescue_score DESC;
```

### Flutter 側 (カンバン UI)

```dart
class KanbanBoard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(kanbanTasksProvider);

    return tasks.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, _) => Text('Error: $err'),
      data: (taskList) => Row(
        children: KanbanLane.values.map((lane) =>
          KanbanColumn(
            lane: lane,
            tasks: taskList.where((t) => t.status == lane.name).toList(),
            // rescue_score で既にソート済み → 追加ソート不要
          ),
        ).toList(),
      ),
    );
  }
}
```

---

## AI 自動分類: ステータス推奨

カンバンのレーン (Todo / In Progress / Review / Done) への自動割り当てにも AI を使う。

### ヒューリスティック自動分類

```typescript
// tools-hub内の自動分類ロジック
function wbsTaskLane(task: Record<string, unknown>): string {
  const status = String(task.status ?? "pending");
  const progress = Number(task.progress ?? 0);

  if (status === "completed") return "done";
  if (status === "blocked") return "blocked";
  if (progress > 0 && progress < 100) return "in_progress";
  if (status === "in_progress") return "in_progress";
  return "todo";
}
```

### Claude AI による推奨

セッション開始時、AI が WBS データ全体を見て「今すぐ着手すべきタスク」を推奨する:

```typescript
const systemPrompt = `
あなたは生産性コーチです。
以下の WBS タスクリスト (rescue_score 降順) を見て、
このセッションで取り組むべきタスクを1つ選び、理由を説明してください。

タスク一覧:
${tasksJson}

選択基準: 期限・重要度・前回からの継続性・インスタンス適合性
`;
```

---

## 「スウィミングレーン」: インスタンス別視点

10インスタンスが並行作業するため、カンバンは「誰のタスクか」でフィルタリングできる:

```dart
// インスタンス別フィルター
final filteredTasks = allTasks
  .where((t) => t.instance == currentInstance)
  .toList();
// → rescue_score ソートは維持したまま絞り込む
```

VSCode版を開けば VSCode版のタスクのみ、PS#2版なら PS#2版のタスクのみ表示される。

---

## Trello・Linear との違い

| 機能 | Trello | Linear | 自分株式会社 WBS カンバン |
|------|--------|--------|------------------------|
| ソート方法 | 手動D&D | 優先度ラベル | rescue_score 自動 |
| AI 優先度推奨 | ✗ | △ | ◎ |
| インスタンス別フィルター | ✗ | プロジェクト別 | ◎ (10インスタンス) |
| DB 直結 | ✗ (API) | ✗ (API) | ◎ (Supabase直結) |
| Webhook 連携 | ◎ | ◎ | △ |
| Gantt ビュー | △ | ◎ | ◎ |
| 月額 | $5〜 | $8〜 | $0 |

---

## ソート設計で重要なこと

AI 自動ソートを設計するとき、注意すべき点:

**1. スコアの透明性**

なぜこのタスクが上位に来るか、ユーザーが理解できる必要がある。`rescue_score` の内訳を表示することでブラックボックス感を排除する。

**2. 手動オーバーライドを残す**

AI のソートが常に正しいとは限らない。「今日はこれをやる」と人間が決めた場合に、一時的に固定できる仕組みが必要。

**3. 時間依存の減衰**

期限が遠いタスクは自然とスコアが低くなる。しかし「重要だが期限が遠い」タスクが永遠に埋もれないよう、定期的なレビューをセッション末尾に組み込む。

---

## まとめ

- 「並び替え」は AI が得意で人間が嫌う作業
- rescue_score で期限・停滞・優先度・進捗を統合スコア化
- Supabase View でソート済みデータを提供し、Flutter は表示に集中
- 手動オーバーライドとスコア透明性は必須

カンバンボードの本質は「今何をすべきか一目でわかること」。その判断を AI に委ねることで、人間は「実際の作業」に集中できる。

---

## 関連記事

- [WBS × AI タスク管理設計](./2026-09-12-wbs-task-management-ai-assistant.md)
- [競合190社自動モニタリング](./2026-09-26-competitor-monitoring-190-companies.md)
- [Supabase Edge Functions × AI コスト内訳](./2026-08-22-supabase-edge-functions-ai-cost.md)

---

*自分株式会社 — 21社競合のベストを1つに統合するライフマネジメントアプリ*  
*本番: https://my-web-app-b67f4.web.app/*
