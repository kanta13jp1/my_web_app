import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/kanban_board_page.dart';

void main() {
  group('KanbanBoardPage extracted widgets', () {
    testWidgets(
      'Desktop 1280x800 scrollable KanbanColumnView renders 15 tasks safely',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final tasks = List<Map<String, dynamic>>.generate(
          15,
          (i) => <String, dynamic>{
            'id': 'task-$i',
            'task': 'デスクトップ検証タスク $i',
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1280,
                height: 680,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: KanbanColumnView(
                        id: 'todo',
                        label: 'To Do',
                        icon: Icons.radio_button_unchecked,
                        color: const Color(0xFF6366F1),
                        tasks: tasks,
                        scrollable: true,
                        onAdd: () {},
                        onMove: (_, __) {},
                        onDelete: (_) {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('15'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Mobile 390x844 non-scrollable KanbanColumnView renders inside ListView',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const tasks = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'm-1',
            'task': 'モバイル表示確認タスク 1',
          },
          <String, dynamic>{
            'id': 'm-2',
            'task': 'モバイル表示確認タスク 2',
          },
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  KanbanColumnView(
                    id: 'doing',
                    label: '進行中',
                    icon: Icons.play_circle_outline,
                    color: const Color(0xFFF59E0B),
                    tasks: tasks,
                    scrollable: false,
                    onAdd: () {},
                    onMove: (_, __) {},
                    onDelete: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('進行中'), findsOneWidget);
        expect(find.text('モバイル表示確認タスク 1'), findsOneWidget);
        final rect = tester.getRect(find.byType(KanbanColumnView));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(390));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Light Mode empty KanbanColumnView uses high-contrast onSurfaceVariant',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: KanbanColumnView(
                id: 'todo',
                label: 'To Do',
                icon: Icons.radio_button_unchecked,
                color: const Color(0xFF6366F1),
                tasks: const <Map<String, dynamic>>[],
                scrollable: false,
                onAdd: () {},
                onMove: (_, __) {},
                onDelete: (_) {},
              ),
            ),
          ),
        );

        final emptyFinder = find.text('タスクなし');
        expect(emptyFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(emptyFinder);
        final context = tester.element(emptyFinder);
        final expectedColor = Theme.of(context).colorScheme.onSurfaceVariant;
        expect(textWidget.style?.color, expectedColor);
        expect(textWidget.style?.color, isNot(const Color(0xFFBDBDBD)));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'KanbanSignedOutState and KanbanErrorState trigger callbacks',
      (tester) async {
        var loginCount = 0;
        var retryCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KanbanSignedOutState(
                onLogin: () => loginCount += 1,
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('kanban_signed_out_state')),
          findsOneWidget,
        );
        expect(
          find.text('ログインするとカンバンボードを利用できます。'),
          findsOneWidget,
        );
        expect(find.byType(FilledButton), findsOneWidget);

        await tester.tap(find.text('ログイン'));
        await tester.pump();
        expect(loginCount, 1);

        const errorMessage = 'タスクの読み込みに失敗しました。';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KanbanErrorState(
                message: errorMessage,
                onRetry: () => retryCount += 1,
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('kanban_error_state')),
          findsOneWidget,
        );
        expect(find.text(errorMessage), findsOneWidget);

        await tester.tap(find.text('再試行'));
        await tester.pump();
        expect(retryCount, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'KanbanColumnView handles callbacks and non-String task fields safely',
      (tester) async {
        var addCount = 0;
        String? movedId;
        String? movedStatus;
        String? deletedId;

        const tasks = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 123,
            'task': 456,
            'is_completed': 'unexpected',
          },
          <String, dynamic>{
            'id': null,
            'task': null,
          },
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KanbanColumnView(
                id: 'todo',
                label: 'To Do',
                icon: Icons.radio_button_unchecked,
                color: const Color(0xFF6366F1),
                tasks: tasks,
                scrollable: false,
                onAdd: () => addCount += 1,
                onMove: (id, nextStatus) {
                  movedId = id;
                  movedStatus = nextStatus;
                },
                onDelete: (id) => deletedId = id,
              ),
            ),
          ),
        );

        expect(find.text('456'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();
        expect(addCount, 1);

        await tester.tap(find.byIcon(Icons.more_vert).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('進行中に移動'));
        await tester.pumpAndSettle();
        expect(movedId, '123');
        expect(movedStatus, 'doing');

        await tester.tap(find.byIcon(Icons.more_vert).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('削除'));
        await tester.pumpAndSettle();
        expect(deletedId, '123');
        expect(tester.takeException(), isNull);
      },
    );
  });
}
