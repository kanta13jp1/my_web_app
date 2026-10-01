import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/agent_tool_policy_preview_page.dart';

void main() {
  testWidgets('read preview is explicitly a simulation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AgentToolPolicyPreviewPage(
          preview: (role, scopes) async =>
              {'allowed': true, 'blocked_reason': null},
        ),
      ),
    );
    await tester.tap(find.text('保存せずに確認'));
    await tester.pumpAndSettle();
    expect(find.text('試し判定：要求を満たします'), findsOneWidget);
    expect(find.text('これは試し判定です。実行時には別途権限を確認します。'), findsOneWidget);
  });

  testWidgets(
      'invalid request shows a reason and clears stale result on editing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AgentToolPolicyPreviewPage(
          preview: (role, scopes) async =>
              {'allowed': false, 'blocked_reason': 'invalid_requested_scope'},
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'read, unknown');
    await tester.tap(find.text('保存せずに確認'));
    await tester.pumpAndSettle();
    expect(find.text('試し判定：操作を止めます'), findsOneWidget);
    expect(find.text('未知の操作名、空欄、または不正な入力が含まれています。'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'read');
    await tester.pump();
    expect(find.text('試し判定：操作を止めます'), findsNothing);
  });

  testWidgets('failed communication can be retried without granting permission',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AgentToolPolicyPreviewPage(
          preview: (role, scopes) async {
            if (calls++ == 0) {
              throw StateError('controlled offline');
            }
            return {'allowed': true, 'blocked_reason': null};
          },
        ),
      ),
    );
    await tester.tap(find.text('保存せずに確認'));
    await tester.pumpAndSettle();
    expect(find.textContaining('確認できませんでした。'), findsOneWidget);
    expect(find.text('試し判定：要求を満たします'), findsNothing);
    await tester.tap(find.text('保存せずに確認'));
    await tester.pumpAndSettle();
    expect(find.text('試し判定：要求を満たします'), findsOneWidget);
    expect(find.textContaining('確認できませんでした。'), findsNothing);
    expect(calls, 2);
  });
}
