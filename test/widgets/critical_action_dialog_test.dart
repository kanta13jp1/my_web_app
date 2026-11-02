import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/critical_action_dialog.dart';

void main() {
  testWidgets('requires both the delay and exact confirmation phrase', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showCriticalActionDialog(
                  context: context,
                  title: '完全に削除しますか？',
                  impact: '保存したデータは復元できません。',
                  actionLabel: '削除する',
                  confirmationPhrase: '削除する',
                );
              },
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pump();

    final confirmFinder = find.byKey(
      const Key('critical_action_confirm_button'),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('残り3秒'), findsOneWidget);
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('critical_action_confirmation_input')),
      '削除する',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('実行できます。'), findsOneWidget);
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNotNull);

    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('cancel remains immediately available', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showCriticalActionDialog(
                  context: context,
                  title: '削除しますか？',
                  impact: 'この操作は取り消せません。',
                  actionLabel: '削除',
                );
              },
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('critical_action_cancel_button')));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
