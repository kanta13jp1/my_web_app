---
title: "Flutter WebでMS Project風ガントチャートを実装 — CustomPaintで左右同期スクロール"
tags: Flutter,個人開発,buildinpublic,UI
published: false
---

# Flutter WebでMS Project風ガントチャートを実装

## 動機

WBSの進捗を可視化したかった。タスク一覧とタイムライン(ガントバー)を同時に表示して、左右をスクロールしても常に同期させる必要がある。

## アーキテクチャ

```
Row(
  children: [
    // 左ペイン: タスク名・担当者 (固定幅)
    SizedBox(width: 300, child: TaskListPane()),
    // 右ペイン: タイムライン (横スクロール)
    Expanded(child: TimelinePane()),
  ],
)
```

左右のスクロールを同期させるために **2つの `ScrollController` をリンク**。

## 実装

### 左右スクロール同期

```dart
class GanttChartPage extends StatefulWidget {
  const GanttChartPage({super.key});
}

class _GanttChartPageState extends State<GanttChartPage> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 左ペインの縦スクロールと右ペインの縦スクロールを同期
    _verticalController.addListener(() {
      if (_rightVerticalController.offset != _verticalController.offset) {
        _rightVerticalController.jumpTo(_verticalController.offset);
      }
    });
  }
}
```

### CustomPaintでガントバーを描画

```dart
class GanttBarPainter extends CustomPainter {
  final List<WbsTask> tasks;
  final DateTime startDate;
  final double dayWidth;

  const GanttBarPainter({
    required this.tasks,
    required this.startDate,
    required this.dayWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final y = i * 40.0 + 8;
      final startX = task.startDate.difference(startDate).inDays * dayWidth;
      final width = task.duration.inDays * dayWidth;

      // バーの色: 進捗率で変化
      paint.color = _progressColor(task.progressRate);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(startX, y, width, 24),
          const Radius.circular(4),
        ),
        paint,
      );

      // 進捗バー (内側)
      paint.color = _progressColor(task.progressRate).withAlpha(200);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(startX, y, width * task.progressRate / 100, 24),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  Color _progressColor(int progress) {
    if (progress >= 100) return const Color(0xFF4CAF50); // 完了: 緑
    if (progress >= 50) return const Color(0xFFFF9800);  // 中途: オレンジ
    return const Color(0xFFFF5722);                       // 低進捗: 赤
  }

  @override
  bool shouldRepaint(GanttBarPainter oldDelegate) => true;
}
```

### WbsTaskモデル

```dart
class WbsTask {
  final String id;
  final String title;
  final String? assignee;
  final DateTime startDate;
  final Duration duration;
  final int progressRate; // 0-100
  final List<String> dependencies; // 依存タスクID

  const WbsTask({
    required this.id,
    required this.title,
    this.assignee,
    required this.startDate,
    required this.duration,
    required this.progressRate,
    this.dependencies = const [],
  });
}
```

## Supabaseとの連携

WBSデータはSupabaseの `wbs_tasks` テーブルから取得:

```sql
CREATE TABLE wbs_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  assignee text,
  start_date date NOT NULL,
  end_date date NOT NULL,
  progress_rate int DEFAULT 0 CHECK (progress_rate BETWEEN 0 AND 100),
  dependencies uuid[],
  user_id uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);
```

## 詰まったポイント

### CustomPaintの再描画タイミング

`shouldRepaint` で `true` を返すと毎フレーム再描画。パフォーマンスのため、タスクデータが変化した時だけ再描画するように修正:

```dart
@override
bool shouldRepaint(GanttBarPainter oldDelegate) =>
    oldDelegate.tasks != tasks || oldDelegate.startDate != startDate;
```

### 日付ヘッダーと縦グリッド線の位置合わせ

タイムラインヘッダー (月/日付) と実際のガントバーのX座標を一致させるには、同じ `startDate` と `dayWidth` 定数を使うことが重要。

## まとめ

Flutter WebのCustomPaintは複雑なビジュアライゼーションに強い。ガントチャートのような「独自のグリッドレイアウト」は既存ウィジェットで作るより、CustomPaintで一から描いた方が柔軟。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Flutter #buildinpublic #個人開発 #UI
