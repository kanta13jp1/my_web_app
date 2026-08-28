import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';
import 'package:my_web_app/services/wbs_kanban_service.dart';

WbsTask _task({
  required String id,
  required String title,
  String status = 'pending',
  int progress = 0,
  String aiReviewStatus = 'pending',
}) {
  return WbsTask(
    id: id,
    category: '開発',
    categoryIcon: 'D',
    categoryOrder: 1,
    title: title,
    description: 'Supabase WBSの実データ',
    instance: 'codex',
    status: status,
    progress: progress,
    priority: 'high',
    ownerInstance: 'codex',
    aiReviewStatus: aiReviewStatus,
  );
}

Widget _board({
  required List<WbsTask> tasks,
  required bool canManage,
  required WbsKanbanMoveCallback onMove,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: WbsKanbanBoard(
        tasks: tasks,
        loading: false,
        canManage: canManage,
        movingTaskIds: const <String>{},
        onMove: onMove,
      ),
    ),
  );
}

void main() {
  test('review lane is derived from the existing AI review contract', () {
    final tasks = [
      _task(id: 'pending', title: '未着手'),
      _task(
        id: 'review',
        title: 'レビュー対象',
        status: 'in_progress',
        progress: 100,
        aiReviewStatus: 'requested',
      ),
      _task(id: 'done', title: '完了', status: 'completed', progress: 100),
    ];

    final grouped = groupWbsTasksByKanbanLane(tasks);

    expect(grouped[WbsKanbanLane.pending]!.single.id, 'pending');
    expect(grouped[WbsKanbanLane.review]!.single.id, 'review');
    expect(grouped[WbsKanbanLane.completed]!.single.id, 'done');
  });

  testWidgets('renders all five lanes with real WBS task values', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _board(
        tasks: [_task(id: 'real', title: '本番WBSタスク')],
        canManage: true,
        onMove: (_, __) async {},
      ),
    );

    for (final label in ['未着手', '進行中', 'レビュー中', '完了', 'ブロック中']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('本番WBSタスク'), findsOneWidget);
    expect(find.textContaining('カードをドラッグ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop drag moves a card to the selected lane', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    WbsTask? movedTask;
    WbsKanbanLane? movedLane;
    await tester.pumpWidget(
      _board(
        tasks: [_task(id: 'drag-me', title: 'ドラッグ対象')],
        canManage: true,
        onMove: (task, lane) async {
          movedTask = task;
          movedLane = lane;
        },
      ),
    );

    final source = tester.getCenter(
      find.byKey(const Key('wbs-kanban-task-drag-me')),
    );
    final target = tester.getCenter(
      find.byKey(const Key('wbs-kanban-column-inProgress')),
    );
    final gesture = await tester.startGesture(source);
    await tester.pump();
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedTask?.id, 'drag-me');
    expect(movedLane, WbsKanbanLane.inProgress);
  });

  testWidgets('mobile layout offers an explicit accessible move menu', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    WbsKanbanLane? movedLane;
    await tester.pumpWidget(
      _board(
        tasks: [_task(id: 'touch', title: 'タッチ操作対象')],
        canManage: true,
        onMove: (_, lane) async => movedLane = lane,
      ),
    );

    await tester.tap(find.byKey(const Key('wbs-kanban-move-touch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ブロック中').last);
    await tester.pumpAndSettle();

    expect(movedLane, WbsKanbanLane.blocked);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only users see real data without move controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _board(
        tasks: [_task(id: 'readonly', title: '閲覧専用タスク')],
        canManage: false,
        onMove: (_, __) async {},
      ),
    );

    expect(find.text('閲覧専用タスク'), findsOneWidget);
    expect(find.textContaining('閲覧モード'), findsOneWidget);
    expect(find.byKey(const Key('wbs-kanban-move-readonly')), findsNothing);
    expect(find.byType(Draggable<WbsTask>), findsNothing);
    expect(find.byType(LongPressDraggable<WbsTask>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
