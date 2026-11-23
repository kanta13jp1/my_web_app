import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

WbsTask _nodeTask({
  required String id,
  required String title,
  String? parentTaskId,
  int progress = 40,
}) {
  return WbsTask(
    id: id,
    category: '開発',
    categoryIcon: 'code',
    categoryOrder: 1,
    title: title,
    description: '',
    instance: 'claude',
    status: 'in_progress',
    progress: progress,
    priority: 'medium',
    ownerInstance: 'claude',
    parentTaskId: parentTaskId,
  );
}

void main() {
  group('WbsTask parent_task_id parsing & hierarchy tree (#2222)', () {
    test('parses parent_task_id and parent_id without inferring from titles',
        () {
      final t1 = WbsTask.fromMap(const <String, dynamic>{
        'id': 't1',
        'category': '開発',
        'title': '親タスク',
        'parent_task_id': 'root-1',
      });
      final t2 = WbsTask.fromMap(const <String, dynamic>{
        'id': 't2',
        'category': '開発',
        'title': 'フォールバック',
        'parent_id': '  root-2  ',
      });
      final t3 = WbsTask.fromMap(const <String, dynamic>{
        'id': 't3',
        'category': '開発',
        'title': 'Phase 1 > Subtask A',
        'parent_task_id': '   ',
      });

      expect(t1.parentTaskId, 'root-1');
      expect(t2.parentTaskId, 'root-2');
      expect(t3.parentTaskId, isNull);
    });

    test('builds depths 0/1/2, hides collapsed descendants, keeps siblings',
        () {
      final rootA = _nodeTask(id: 'a', title: '親A');
      final childA1 = _nodeTask(id: 'a1', title: '子A1', parentTaskId: 'a');
      final grandA1x = _nodeTask(
        id: 'a1x',
        title: '孫A1x',
        parentTaskId: 'a1',
      );
      final rootB = _nodeTask(id: 'b', title: '親B');

      final expanded =
          buildWbsHierarchyNodes([rootA, childA1, grandA1x, rootB]);
      expect(
        expanded
            .map((n) => '${n.task.id}@${n.depth}:${n.totalDescendantCount}'),
        ['a@0:2', 'a1@1:1', 'a1x@2:0', 'b@0:0'],
      );

      final collapsedA = buildWbsHierarchyNodes(
        [rootA, childA1, grandA1x, rootB],
        collapsedParentIds: const <String>{'a'},
      );
      expect(collapsedA.map((n) => n.task.id), ['a', 'b']);

      final collapsedChild = buildWbsHierarchyNodes(
        [rootA, childA1, grandA1x, rootB],
        collapsedParentIds: const <String>{'a1'},
      );
      expect(collapsedChild.map((n) => n.task.id), ['a', 'a1', 'b']);
    });

    test(
      'falls back orphan and cyclic tasks to valid roots without infinite loop',
      () {
        final orphan = _nodeTask(
          id: 'orphan',
          title: '孤立タスク',
          parentTaskId: 'missing-parent',
        );
        final selfLoop = _nodeTask(
          id: 'self',
          title: '自己参照タスク',
          parentTaskId: 'self',
        );
        final cycA = _nodeTask(id: 'ca', title: '循環A', parentTaskId: 'cc');
        final cycB = _nodeTask(id: 'cb', title: '循環B', parentTaskId: 'ca');
        final cycC = _nodeTask(id: 'cc', title: '循環C', parentTaskId: 'cb');

        final nodes = buildWbsHierarchyNodes([
          orphan,
          selfLoop,
          cycA,
          cycB,
          cycC,
        ]);
        expect(nodes.length, 5);
        expect(
          nodes.firstWhere((n) => n.task.id == 'orphan').isOrphanFallback,
          isTrue,
        );
        expect(
          nodes.firstWhere((n) => n.task.id == 'self').brokeCycle,
          isTrue,
        );
        expect(
          nodes.any((n) => n.task.id == 'ca' && n.brokeCycle && n.depth == 0),
          isTrue,
        );
      },
    );
  });

  group('WbsCategoryHierarchySection responsive UI (#2222)', () {
    Future<void> verifySectionAtViewport(
      WidgetTester tester,
      Size size,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tasks = [
        _nodeTask(id: 'p1', title: '親 epic タスク'),
        _nodeTask(id: 'c1', title: '子タスク 1', parentTaskId: 'p1'),
        _nodeTask(id: 'g1', title: '孫タスク 1', parentTaskId: 'c1'),
        _nodeTask(id: 'p2', title: '独立タスク'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: WbsCategoryHierarchySection(
                category: '開発',
                categoryIcon: 'code',
                tasks: tasks,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final parentLeft =
          tester.getRect(find.byKey(const ValueKey('wbs_task_p1'))).left;
      final childLeft =
          tester.getRect(find.byKey(const ValueKey('wbs_task_c1'))).left;
      final grandLeft =
          tester.getRect(find.byKey(const ValueKey('wbs_task_g1'))).left;

      expect(childLeft, greaterThan(parentLeft));
      expect(grandLeft, greaterThan(childLeft));
      expect(find.text('子2件'), findsOneWidget);
      expect(find.text('子1件'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wbs_toggle_children_p1')));
      await tester.pumpAndSettle();
      expect(find.text('子タスク 1'), findsNothing);
      expect(find.text('孫タスク 1'), findsNothing);
      expect(find.text('独立タスク'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wbs_expand_all_開発')));
      await tester.pumpAndSettle();
      expect(find.text('子タスク 1'), findsOneWidget);
      expect(find.text('孫タスク 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wbs_collapse_all_開発')));
      await tester.pumpAndSettle();
      expect(find.text('子タスク 1'), findsNothing);

      await tester.tap(find.byKey(const Key('wbs_toggle_category_開発')));
      await tester.pumpAndSettle();
      expect(find.text('親 epic タスク'), findsNothing);

      await tester.tap(find.byKey(const Key('wbs_toggle_category_開発')));
      await tester.pumpAndSettle();
      expect(find.text('親 epic タスク'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    testWidgets(
      'renders indented tree and collapse controls on desktop 1280x900',
      (tester) async {
        await verifySectionAtViewport(tester, const Size(1280, 900));
      },
    );

    testWidgets(
      'renders indented tree and collapse controls on mobile 390x844',
      (tester) async {
        await verifySectionAtViewport(tester, const Size(390, 844));
      },
    );
  });
}
