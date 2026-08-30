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
    expect(preview.warnings, contains('対応する残高表または解約済みサブスク表が見つかりませんでした。'));
  });

  test('解約・停止済みセクションだけを解析し、登録中サブスクへ一意に照合する', () {
    final preview = service.preview(
      files: [
        file('company/SUBSCRIPTION_LIST.md', '''
## 1. 直接確認済み 有効サブスクリプション
| サービス名 | プラン・内容 | 月額（税込） | 次回更新日 | 判定 / 方針 | 備考 |
| --- | --- | ---: | --- | --- | --- |
| Notion | Plus | 1,650円 | 2026-09-01 | 継続 | 有効 |

## 2. 解約・定期請求停止済みサービス
| サービス名 | プラン・内容 | 終了日 / 停止日 | 状態 | 備考 |
| --- | --- | --- | --- | --- |
| Xbox Game Pass | Ultimate | 2026-08-20 | 解約完了 | 履歴は保持 |
| netkeiba | プレミアム | 2026-08-21 | 停止済み | - |
| 未確定サービス | - | 2026-08-22 | 解約予定 | まだ有効 |
'''),
      ],
      existingBalances: const [],
      existingSubscriptions: const [
        AssetObsidianExistingSubscription(
          id: 'sub_xbox',
          name: 'MICROSOFT*XBOX GAME',
          amount: 1550,
        ),
        AssetObsidianExistingSubscription(
          id: 'sub_notion',
          name: 'Notion',
          amount: 1650,
        ),
      ],
    );

    expect(preview.recognizedFileCount, 0);
    expect(preview.recognizedCancellationFileCount, 1);
    expect(preview.subscriptionCancellations, hasLength(2));
    final xbox = preview.subscriptionCancellations.singleWhere(
      (candidate) => candidate.sourceSubscriptionName == 'Xbox Game Pass',
    );
    expect(xbox.status, AssetObsidianSubscriptionCancellationStatus.matched);
    expect(xbox.matchedSubscriptionId, 'sub_xbox');
    expect(xbox.matchedMonthlyAmount, 1550);
    expect(xbox.isDeletable, isTrue);
    final netkeiba = preview.subscriptionCancellations.singleWhere(
      (candidate) => candidate.sourceSubscriptionName == 'netkeiba',
    );
    expect(
      netkeiba.status,
      AssetObsidianSubscriptionCancellationStatus.notRegistered,
    );
    expect(netkeiba.isDeletable, isFalse);
    expect(
      preview.initiallySelectedSubscriptionCancellations.map(
        (candidate) => candidate.matchedSubscriptionId,
      ),
      ['sub_xbox'],
    );
  });

  test('同名の登録中サブスクが複数ある場合は競合として削除不可にする', () {
    final preview = service.preview(
      files: [
        file('vault/SUBSCRIPTION_LIST.md', '''
## 解約・定期請求停止済みサービス
| サービス名 | 終了日 / 停止日 | 状態 |
| --- | --- | --- |
| Yousician | 2026-08-20 | 解約済み |
'''),
      ],
      existingBalances: const [],
      existingSubscriptions: const [
        AssetObsidianExistingSubscription(
          id: 'sub_yousician_a',
          name: 'Yousician',
          amount: 2000,
        ),
        AssetObsidianExistingSubscription(
          id: 'sub_yousician_b',
          name: 'Yousician',
          amount: 3000,
        ),
      ],
    );

    final candidate = preview.subscriptionCancellations.single;
    expect(
      candidate.status,
      AssetObsidianSubscriptionCancellationStatus.conflict,
    );
    expect(candidate.isDeletable, isFalse);
    expect(candidate.conflictingSubscriptionNames, ['Yousician', 'Yousician']);
  });

  test('有効一覧から消えただけのサブスクは削除候補にしない', () {
    final preview = service.preview(
      files: [
        file('vault/SUBSCRIPTION_LIST.md', '''
## 直接確認済み 有効サブスクリプション
| サービス名 | 月額（税込） | 状態 |
| --- | ---: | --- |
| Notion | 1,650円 | 有効 |
'''),
      ],
      existingBalances: const [],
      existingSubscriptions: const [
        AssetObsidianExistingSubscription(
          id: 'sub_chatgpt',
          name: 'ChatGPT',
          amount: 3000,
        ),
      ],
    );

    expect(preview.subscriptionCancellations, isEmpty);
  });

  test('区切り記号が異なる一般名は同一サブスクとして照合しない', () {
    final preview = service.preview(
      files: [
        file('vault/SUBSCRIPTION_LIST.md', '''
## 解約・定期請求停止済みサービス
| サービス名 | 終了日 / 停止日 | 状態 |
| --- | --- | --- |
| A/B | 2026-08-20 | 解約完了 |
| Foo-Bar | 2026-08-20 | 停止済み |
'''),
      ],
      existingBalances: const [],
      existingSubscriptions: const [
        AssetObsidianExistingSubscription(
          id: 'sub_ab',
          name: 'AB',
          amount: 1000,
        ),
        AssetObsidianExistingSubscription(
          id: 'sub_foo',
          name: 'Foo Bar',
          amount: 1000,
        ),
      ],
    );

    expect(preview.subscriptionCancellations, hasLength(2));
    expect(
      preview.subscriptionCancellations.map((candidate) => candidate.status),
      everyElement(AssetObsidianSubscriptionCancellationStatus.notRegistered),
    );
    expect(preview.initiallySelectedSubscriptionCancellations, isEmpty);
  });

  test('完了状態を含むだけの予定・否定表現は削除候補にしない', () {
    final preview = service.preview(
      files: [
        file('vault/SUBSCRIPTION_LIST.md', '''
## 解約・定期請求停止済みサービス
| サービス名 | 終了日 / 停止日 | 状態 |
| --- | --- | --- |
| Service A | 2026-08-20 | 解約完了予定 |
| Service B | 2026-08-20 | 未解約済み |
| Service C | 2026-08-20 | 解約済みではない |
| Service D | 2026-08-20 | 停止済み予定 |
'''),
      ],
      existingBalances: const [],
      existingSubscriptions: const [
        AssetObsidianExistingSubscription(
          id: 'sub_a',
          name: 'Service A',
          amount: 1000,
        ),
        AssetObsidianExistingSubscription(
          id: 'sub_b',
          name: 'Service B',
          amount: 1000,
        ),
        AssetObsidianExistingSubscription(
          id: 'sub_c',
          name: 'Service C',
          amount: 1000,
        ),
        AssetObsidianExistingSubscription(
          id: 'sub_d',
          name: 'Service D',
          amount: 1000,
        ),
      ],
    );

    expect(preview.subscriptionCancellations, isEmpty);
  });
}
