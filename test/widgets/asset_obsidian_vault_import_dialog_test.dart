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
    List<AssetObsidianImportCandidate>? applied;
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
            onApply: (candidates) async => applied = candidates,
          ),
        ),
      ),
    );

    expect(find.textContaining('Markdown本文はこのブラウザ内だけ'), findsOneWidget);
    await tester.tap(find.text('Obsidian保管庫を選択'));
    await tester.pumpAndSettle();

    expect(find.text('company'), findsOneWidget);
    expect(find.text('候補 2件'), findsOneWidget);
    expect(find.text('新規'), findsOneWidget);
    expect(find.text('古い'), findsOneWidget);
    expect(find.text('選択した1件を確認'), findsOneWidget);

    await tester.tap(find.text('選択した1件を確認'));
    await tester.pumpAndSettle();
    expect(find.text('1件の残高を本日分として反映しますか？'), findsOneWidget);
    expect(find.textContaining('使途不明金は自動生成しません'), findsOneWidget);

    await tester.tap(find.text('この内容で反映'));
    await tester.pumpAndSettle();
    expect(applied, isNotNull);
    expect(applied, hasLength(1));
    expect(applied!.single.accountName, '現金');
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
    expect(find.text('Obsidian保管庫から残高を取込'), findsOneWidget);
    expect(find.text('Obsidian保管庫を選択'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
