import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_obsidian_vault_import.dart';
import 'package:my_web_app/services/asset_obsidian_vault_import_service.dart';

void main() {
  const service = AssetObsidianVaultImportService();

  AssetObsidianVaultFile file(String path, String content) =>
      AssetObsidianVaultFile(
        relativePath: path,
        content: content,
        byteSize: content.length,
      );

  test('口座残高表と負債残高表を解析し、既存名へ正規化する', () {
    final preview = service.preview(
      files: [
        file('company/ACCOUNTS_LIST.md', '''
| 確認日 | 口座・サービス名 | 最新確認残高 | 補足 |
| :--- | :--- | ---: | :--- |
| 2026-08-26 | 三井住友銀行 大塚支店 普通預金 | 216,829円 | 確認済み |
| 2026-08-26 | 財布（現金管理） | 32,652円 | 手入力 |
'''),
        file('company/DEBT_MANAGEMENT.md', '''
| 優先順 | 借入・カード名 | 残高（2026-08-26） | 想定年利 |
| :---: | :--- | ---: | :---: |
| **1** | **アコムショッピング** | **-¥2,267,581** | 15.0% |
| **2** | **じぶんローン** | **-¥1,002,058** | 14.5% |
| **合計** | **全2件** | **-¥3,269,639** | - |
'''),
      ],
      existingBalances: [
        AssetObsidianExistingBalance(
          accountName: '三井住友銀行大塚支店',
          observedDate: DateTime(2026, 8, 25),
          amount: 12012,
        ),
      ],
    );

    expect(preview.recognizedFileCount, 2);
    expect(preview.candidates, hasLength(4));
    expect(
      preview.candidates
          .singleWhere((candidate) => candidate.accountName == '現金')
          .amount,
      32652,
    );
    expect(
      preview.candidates
          .singleWhere((candidate) => candidate.accountName == 'じぶん銀行カードローン')
          .amount,
      -1002058,
    );
    final smbc = preview.candidates.singleWhere(
      (candidate) => candidate.accountName == '三井住友銀行大塚支店',
    );
    expect(smbc.status, AssetObsidianImportStatus.update);
    expect(smbc.existingAmount, 12012);
  });

  test('古い残高と同額は選択せず、新規と更新だけを初期選択する', () {
    final preview = service.preview(
      files: [
        file('vault/balances.md', '''
| 確認日 | 口座・サービス名 | 最新確認残高 |
| --- | --- | ---: |
| 2026-08-24 | 現金 | 10,000円 |
| 2026-08-25 | じぶん銀行 | 20,000円 |
| 2026-08-26 | 新口座 | 30,000円 |
'''),
      ],
      existingBalances: [
        AssetObsidianExistingBalance(
          accountName: '現金',
          observedDate: DateTime(2026, 8, 25),
          amount: 9000,
        ),
        AssetObsidianExistingBalance(
          accountName: 'じぶん銀行',
          observedDate: DateTime(2026, 8, 25),
          amount: 20000,
        ),
      ],
    );

    expect(
      preview.candidates.singleWhere((item) => item.accountName == '現金').status,
      AssetObsidianImportStatus.stale,
    );
    expect(
      preview.candidates
          .singleWhere((item) => item.accountName == 'じぶん銀行')
          .status,
      AssetObsidianImportStatus.unchanged,
    );
    expect(preview.initiallySelected.map((item) => item.accountName), ['新口座']);
  });

  test('同額でも保管庫の確認日が新しければ更新候補にする', () {
    final preview = service.preview(
      files: [
        file('vault/balances.md', '''
| 確認日 | 口座・サービス名 | 最新確認残高 |
| --- | --- | ---: |
| 2026-08-26 | 現金 | 10,000円 |
'''),
      ],
      existingBalances: [
        AssetObsidianExistingBalance(
          accountName: '現金',
          observedDate: DateTime(2026, 8, 25),
          amount: 10000,
        ),
      ],
    );

    expect(preview.candidates.single.status, AssetObsidianImportStatus.update);
    expect(preview.initiallySelected.single.accountName, '現金');
  });

  test('同じ最新日で異なる残高は競合として取込不可にする', () {
    final preview = service.preview(
      files: [
        file('vault/a.md', '''
| 確認日 | 口座・サービス名 | 最新確認残高 |
| --- | --- | ---: |
| 2026-08-26 | 現金 | 10,000円 |
'''),
        file('vault/b.md', '''
| 確認日 | 口座・サービス名 | 最新確認残高 |
| --- | --- | ---: |
| 2026-08-26 | 現金 | 12,000円 |
'''),
      ],
      existingBalances: const [],
    );

    final candidate = preview.candidates.single;
    expect(candidate.status, AssetObsidianImportStatus.conflict);
    expect(candidate.conflictingAmounts, [10000, 12000]);
    expect(candidate.isImportable, isFalse);
    expect(preview.recognizedFileCount, 2);
  });

  test('対応表がないMarkdownは残高として解釈しない', () {
    final preview = service.preview(
      files: [
        file('vault/SUBSCRIPTION_LIST.md', '''
| サービス | 月額 |
| --- | ---: |
| サンプル | 1,000円 |
'''),
      ],
      existingBalances: const [],
    );

    expect(preview.candidates, isEmpty);
    expect(preview.recognizedFileCount, 0);
    expect(preview.warnings, contains('対応する残高表が見つかりませんでした。'));
  });
}
