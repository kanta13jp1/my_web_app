import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/procrastination_reset/data/procrastination_reset_gateway.dart';
import 'package:my_web_app/ui/features/procrastination_reset/domain/procrastination_reset_models.dart';
import 'package:my_web_app/ui/features/procrastination_reset/procrastination_reset_feature.dart';

void main() {
  testWidgets('3つの入力から5分プランを作り、開始と完了を記録できる', (tester) async {
    final gateway = _MemoryGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ProcrastinationResetFeature(
          gateway: gateway,
          now: () => DateTime(2026, 8, 24, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('大きなタスクを、\n5分の行動に変える。'), findsOneWidget);
    expect(find.text('今日の5分プラン'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('procrastination-task-field')),
      '記事を書く',
    );
    await tester.enterText(
      find.byKey(const Key('procrastination-action-field')),
      'タイトル案を3つ書く',
    );
    await tester.enterText(
      find.byKey(const Key('procrastination-first-move-field')),
      'メモを開く',
    );
    final createButton = find.byKey(const Key('create-procrastination-plan'));
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('active-procrastination-task')),
      findsOneWidget,
    );
    expect(find.text('記事を書く'), findsWidgets);
    expect(find.text('タイトル案を3つ書く'), findsOneWidget);
    expect(find.text('メモを開く'), findsWidgets);

    final startButton = find.byKey(const Key('start-procrastination-session'));
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('procrastination-timer')), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    final completeButton = find.byKey(
      const Key('complete-procrastination-session'),
    );
    expect(completeButton, findsOneWidget);

    await tester.tap(completeButton);
    await tester.pumpAndSettle();

    expect(find.text('今日の5分プラン'), findsOneWidget);
    expect(find.textContaining('これまで 1 回'), findsOneWidget);
    expect(find.textContaining('タイトル案を3つ書く」を完了'), findsOneWidget);
  });

  testWidgets('画面幅に応じて1列と2列を切り替える', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final gateway = _MemoryGateway();

    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpWidget(
      MaterialApp(home: ProcrastinationResetFeature(gateway: gateway)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('procrastination-reset-narrow')),
      findsOneWidget,
    );

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();
    expect(find.byKey(const Key('procrastination-reset-wide')), findsOneWidget);
  });
}

class _MemoryGateway implements ProcrastinationResetGateway {
  ProcrastinationResetSnapshot snapshot = const ProcrastinationResetSnapshot();

  @override
  Future<ProcrastinationResetSnapshot> load() async => snapshot;

  @override
  Future<void> save(ProcrastinationResetSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}
