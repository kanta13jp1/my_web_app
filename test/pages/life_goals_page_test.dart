import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/life_goals_page.dart';

void main() {
  group('LifeGoalsPage extracted widgets', () {
    testWidgets(
      'LifeGoalCard wraps metadata inside 390x844 mobile viewport',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const goal = <String, dynamic>{
          'id': 'goal-1',
          'title': 'テスト人生目標タイトル',
          'description': '詳細テキスト',
          'progress': 50,
          'status': 'active',
          'priority': 5,
          'target_date': '2026-12-31',
          'recurrence': 'weekly',
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: SizedBox(
                width: 390,
                height: 844,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    LifeGoalCard(
                      goal: goal,
                      children: const <Map<String, dynamic>>[],
                      isDark: false,
                      levelColor: const Color(0xFF10B981),
                      categoryLabel: '🏠 ライフスタイル',
                      onDelete: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Wrap), findsOneWidget);
        const labels = <String>[
          '🏠 ライフスタイル',
          '2026/12/31',
          '毎週',
        ];
        for (final label in labels) {
          final rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(390));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'LifeGoalsSignedOutState renders prompt and triggers onLogin',
      (tester) async {
        var loginTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LifeGoalsSignedOutState(
                onLogin: () => loginTapped = true,
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('life_goals_signed_out_state')),
          findsOneWidget,
        );
        expect(
          find.text('ログインすると人生目標を保存・管理できます。'),
          findsOneWidget,
        );
        expect(find.text('ログイン'), findsOneWidget);

        await tester.tap(find.text('ログイン'));
        await tester.pump();

        expect(loginTapped, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'LifeGoalsErrorState renders message and triggers onRetry',
      (tester) async {
        var retried = false;
        const message = '目標の読み込みに失敗しました。通信状況を確認して再試行してください。';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LifeGoalsErrorState(
                message: message,
                onRetry: () => retried = true,
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('life_goals_error_state')),
          findsOneWidget,
        );
        expect(find.text(message), findsOneWidget);
        expect(find.text('再試行'), findsOneWidget);

        await tester.tap(find.text('再試行'));
        await tester.pump();

        expect(retried, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'LifeGoalCard popup menu triggers onAddChild and onDelete',
      (tester) async {
        var addChildCount = 0;
        var deleteCount = 0;
        const goal = <String, dynamic>{
          'id': 'goal-2',
          'title': '週次レビューを続ける',
          'progress': 20,
          'status': 'active',
          'priority': 3,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LifeGoalCard(
                goal: goal,
                children: const <Map<String, dynamic>>[],
                isDark: false,
                levelColor: const Color(0xFF6366F1),
                categoryLabel: '💼 キャリア',
                onAddChild: () => addChildCount += 1,
                onDelete: () => deleteCount += 1,
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('子目標を追加'), findsNWidgets(2));

        await tester.tap(find.text('子目標を追加').last);
        await tester.pumpAndSettle();
        expect(addChildCount, 1);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        await tester.tap(find.text('削除'));
        await tester.pumpAndSettle();
        expect(deleteCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
