import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_obsidian_vault_import.dart';
import 'package:my_web_app/widgets/asset_obsidian_vault_import_dialog.dart';

void main() {
  AssetObsidianVaultSelection selection() => const AssetObsidianVaultSelection(
        vaultName: 'company',
        files: [
          AssetObsidianVaultFile(
            relativePath: 'company/ACCOUNTS_LIST.md',
            byteSize: 200,
            content: '''
| 確認日 | 口座・サービス名 | 最新確認残高 |
| --- | --- | ---: |
| 2026-08-26 | 現金 | 32,652円 |
| 2026-08-24 | じぶん銀行 | 20,000円 |
''',
          ),
        ],
      );

  testWidgets('差分プレビュー後に選択残高だけを確認して反映する', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AssetObsidianApplySelection? applied;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetObsidianVaultImportDialog(
            pickerSupported: true,
            existingBalances: [
              AssetObsidianExistingBalance(
                accountName: 'じぶん銀行',
                observedDate: DateTime(2026, 8, 25),
                amount: 10000,
              ),
            ],
            pickVault: () async => selection(),
            onApply: (selection) async => applied = selection,
          ),
        ),
      ),
    );

    expect(find.textContaining('Markdown本文はこのブラウザ内だけ'), findsOneWidget);
    await tester.tap(find.text('Obsidian保管庫を選択'));
    await tester.pumpAndSettle();

    expect(find.text('company'), findsOneWidget);
    expect(find.text('残高候補 2件'), findsOneWidget);
    expect(find.text('新規'), findsOneWidget);
    expect(find.text('古い'), findsOneWidget);
    expect(find.text('選択した1件を確認'), findsOneWidget);

    await tester.tap(find.text('選択した1件を確認'));
    await tester.pumpAndSettle();
    expect(find.text('残高1件を反映しますか？'), findsOneWidget);
    expect(find.textContaining('使途不明金は自動生成しません'), findsOneWidget);

    await tester.tap(find.text('この内容で反映'));
    await tester.pumpAndSettle();
    expect(applied, isNotNull);
    expect(applied!.balances, hasLength(1));
    expect(applied!.balances.single.accountName, '現金');
    expect(applied!.subscriptionCancellations, isEmpty);
  });

  testWidgets('フォルダー選択のキャンセル後もダイアログを維持する', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetObsidianVaultImportDialog(
            pickerSupported: true,
            existingBalances: const [],
            pickVault: () async => null,
            onApply: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Obsidian保管庫を選択'));
    await tester.pumpAndSettle();
    expect(find.text('Obsidian保管庫から資産情報を取込'), findsOneWidget);
    expect(find.text('Obsidian保管庫を選択'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('解約済みサブスクをプレビューし、確認後に選択IDだけを渡す', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AssetObsidianApplySelection? applied;
    const cancellationSelection = AssetObsidianVaultSelection(
      vaultName: 'company',
      files: [
        AssetObsidianVaultFile(
          relativePath: 'company/SUBSCRIPTION_LIST.md',
          byteSize: 300,
          content: '''
## 2. 解約・定期請求停止済みサービス
| サービス名 | 終了日 / 停止日 | 状態 |
| --- | --- | --- |
| Xbox Game Pass | 2026-08-20 | 解約完了 |
| Notion | 2026-08-21 | 解約済み |
| sub_xbox | 2026-08-21 | 停止済み |
''',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetObsidianVaultImportDialog(
            pickerSupported: true,
            existingBalances: const [],
            existingSubscriptions: const [
              AssetObsidianExistingSubscription(
                id: 'sub_xbox',
                name: 'Xbox Game Pass',
                amount: 1550,
              ),
              AssetObsidianExistingSubscription(
                id: 'sub_notion',
                name: 'Notion',
                amount: 1650,
              ),
            ],
            pickVault: () async => cancellationSelection,
            onApply: (selection) async => applied = selection,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Obsidian保管庫を選択'));
    await tester.pumpAndSettle();

    expect(find.text('解約表 1件'), findsOneWidget);
    expect(find.text('解約済みサブスクの削除候補'), findsOneWidget);
    expect(find.text('削除候補'), findsNWidgets(2));
    expect(find.text('未登録'), findsOneWidget);
    expect(find.text('選択した2件を確認'), findsOneWidget);

    final cancellationCheckboxes = find.byType(Checkbox);
    expect(cancellationCheckboxes, findsNWidgets(3));
    const notionCandidate = AssetObsidianSubscriptionCancellationCandidate(
      sourceSubscriptionName: 'Notion',
      sourceStatus: '解約済み',
      status: AssetObsidianSubscriptionCancellationStatus.matched,
      sourcePaths: <String>['company/SUBSCRIPTION_LIST.md'],
      endedAt: '2026-08-21',
      matchedSubscriptionId: 'sub_notion',
      matchedSubscriptionName: 'Notion',
      matchedMonthlyAmount: 1650,
    );
    final notionCheckbox = find.descendant(
      of: find.byKey(
        ValueKey('obsidian-cancellation-${notionCandidate.id}'),
      ),
      matching: find.byType(Checkbox),
    );
    expect(notionCheckbox, findsOneWidget);
    await tester.tap(notionCheckbox);
    await tester.pumpAndSettle();
    expect(find.text('選択した1件を確認'), findsOneWidget);

    await tester.tap(find.text('選択した1件を確認'));
    await tester.pumpAndSettle();
    expect(find.text('サブスク1件を反映しますか？'), findsOneWidget);
    expect(find.textContaining('過去の月次履歴・取引履歴は残します'), findsOneWidget);
    expect(find.text('・Xbox Game Pass: ¥1,550/月'), findsOneWidget);

    await tester.tap(find.text('この内容で反映'));
    await tester.pumpAndSettle();
    expect(applied, isNotNull);
    expect(applied!.balances, isEmpty);
    expect(applied!.subscriptionCancellations, hasLength(1));
    expect(
      applied!.subscriptionCancellations.single.matchedSubscriptionId,
      'sub_xbox',
    );
  });

  testWidgets('最終確認で戻ると適用せずプレビューへ戻る', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AssetObsidianApplySelection? applied;
    const cancellationSelection = AssetObsidianVaultSelection(
      vaultName: 'company',
      files: [
        AssetObsidianVaultFile(
          relativePath: 'company/SUBSCRIPTION_LIST.md',
          byteSize: 200,
          content: '''
## 解約・定期請求停止済みサービス
| サービス名 | 終了日 / 停止日 | 状態 |
| --- | --- | --- |
| Xbox Game Pass | 2026-08-20 | 解約完了 |
''',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetObsidianVaultImportDialog(
            pickerSupported: true,
            existingBalances: const [],
            existingSubscriptions: const [
              AssetObsidianExistingSubscription(
                id: 'sub_xbox',
                name: 'Xbox Game Pass',
                amount: 1550,
              ),
            ],
            pickVault: () async => cancellationSelection,
            onApply: (selection) async => applied = selection,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Obsidian保管庫を選択'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('選択した1件を確認'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '戻る'));
    await tester.pumpAndSettle();

    expect(applied, isNull);
    expect(find.text('解約済みサブスクの削除候補'), findsOneWidget);
    expect(find.text('選択した1件を確認'), findsOneWidget);
  });
}
