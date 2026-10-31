import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/virtual_org_agent.dart';
import 'package:my_web_app/pages/virtual_organization_page.dart';

void main() {
  Future<VirtualOrgAgentDraft? Function()> pumpDialog(
    WidgetTester tester,
  ) async {
    VirtualOrgAgentDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showDialog<VirtualOrgAgentDraft>(
                  context: context,
                  builder: (_) =>
                      const VirtualOrgAgentDialog(departments: ['CEO', 'CMO']),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  testWidgets('名前が空なら閉じずにエラーを出す', (tester) async {
    final result = await pumpDialog(tester);
    await tester.tap(find.text('登録'));
    await tester.pumpAndSettle();
    expect(find.text('エージェント名を入力してください'), findsOneWidget);
    expect(find.byType(VirtualOrgAgentDialog), findsOneWidget);
    expect(result(), isNull);
  });

  testWidgets('入力が妥当なら先頭の部署を既定に draft を返す', (tester) async {
    final result = await pumpDialog(tester);
    await tester.enterText(find.byType(TextField).first, 'マーケAI');
    await tester.tap(find.text('登録'));
    await tester.pumpAndSettle();
    expect(find.byType(VirtualOrgAgentDialog), findsNothing);
    expect(result()?.name, 'マーケAI');
    expect(result()?.department, 'CEO');
  });

  testWidgets('自動実行しない記録であることを明記する', (tester) async {
    await pumpDialog(tester);
    expect(find.textContaining('自動でタスクを実行することはありません'), findsOneWidget);
  });
}
