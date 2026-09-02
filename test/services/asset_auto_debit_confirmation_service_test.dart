import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_auto_debit_confirmation_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  const service = AssetAutoDebitConfirmationService();
  const planning = AssetLiabilityPlanningService();

  group('AssetAutoDebitConfirmationService', () {
    test(
        'Issue #5216: does not trigger shortfall warning for credit card negative balances with unknown limit',
        () {
      expect(
        autoDebitSourceInsufficient(
          balance: -525792,
          kind: AssetLiabilityAccountKind.creditCard,
          creditLimit: null,
          paymentAmount: 3000,
        ),
        isFalse,
      );
      expect(
        autoDebitSourceInsufficient(
          balance: -525792,
          kind: null,
          creditLimit: null,
          paymentAmount: 3000,
        ),
        isFalse,
      );
      expect(
        autoDebitSourceInsufficient(
          balance: -525792,
          kind: AssetLiabilityAccountKind.creditCard,
          creditLimit: 600000,
          paymentAmount: 80000,
        ),
        isTrue, // 525792 + 80000 = 605792 > 600000
      );
    });

    test('lists direct payments whose date has already passed this month', () {
      // 6/15 時点。ガス(12日)は過去、水道(22日)・家賃/KDDI(25日)は未来。
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 63539},
        baseDate: DateTime(2026, 6, 15),
        includeDefaultFixedPayments: true,
      );
      final pending = service.pendingConfirmations(workbook);
      final ids = pending.map((row) => row.accountId).toSet();

      expect(ids, contains(AssetLiabilityPlanningService.gasBillAccountId));
      expect(
        ids,
        isNot(contains(AssetLiabilityPlanningService.waterBillAccountId)),
      );
      expect(ids, isNot(contains(AssetLiabilityPlanningService.rentAccountId)));

      for (final row in pending) {
        expect(row.isPayment, isTrue);
        expect(row.overdue, isTrue);
        expect(row.paymentDate.isBefore(DateTime(2026, 6, 15)), isTrue);
      }
    });

    test('excludes payments due exactly today (debit not yet certain)', () {
      // 6/12 = ガスの振替日当日。本日分は引落未確定なので確認待ちに含めない。
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 63539},
        baseDate: DateTime(2026, 6, 12),
        includeDefaultFixedPayments: true,
      );
      final ids = service
          .pendingConfirmations(workbook)
          .map((row) => row.accountId)
          .toSet();
      expect(
        ids,
        isNot(contains(AssetLiabilityPlanningService.gasBillAccountId)),
      );
    });

    test('excludes payments already confirmed as paid', () {
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 63539},
        baseDate: DateTime(2026, 6, 15),
        includeDefaultFixedPayments: true,
        paidAccountNames: <String>{
          AssetLiabilityPlanningService.gasBillAccountId,
        },
      );
      final ids = service
          .pendingConfirmations(workbook)
          .map((row) => row.accountId)
          .toSet();
      expect(
        ids,
        isNot(contains(AssetLiabilityPlanningService.gasBillAccountId)),
      );
      expect(service.pendingTotal(workbook), 0);
    });

    test('excludes overdue payments whose payment source is unset', () {
      // 家賃 (支払日25 / 既定では振替元未設定) は 6/26 時点で期日超過だが、
      // 振替元が未設定なので確認待ちから除外する (原資未設定バナー側で修正)。
      // ガス (支払日12 / 振替元=三井住友大塚) は従来どおり確認待ちに残る。
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 63539},
        baseDate: DateTime(2026, 6, 26),
        includeDefaultFixedPayments: true,
      );
      final ids = service
          .pendingConfirmations(workbook)
          .map((row) => row.accountId)
          .toSet();

      // 家賃行が実際に振替元未設定であることを確認 (テスト前提の健全性)。
      final rent = workbook.cashflowRows.firstWhere(
        (row) => row.accountId == AssetLiabilityPlanningService.rentAccountId,
      );
      expect(
        rent.paymentSourceAccountId == null ||
            rent.paymentSourceAccountId!.trim().isEmpty,
        isTrue,
      );

      expect(
        ids,
        isNot(contains(AssetLiabilityPlanningService.rentAccountId)),
      );
      expect(ids, contains(AssetLiabilityPlanningService.gasBillAccountId));
    });
  });

  group('AssetAutoDebitConfirmationService source balance', () {
    AssetLiabilityCashflowRow gasDetailRow(
      List<AssetAutoDebitConfirmation> details,
    ) {
      return details
          .firstWhere(
            (detail) =>
                detail.row.accountId ==
                AssetLiabilityPlanningService.gasBillAccountId,
          )
          .row;
    }

    test('flags pending confirmation when source balance is below amount', () {
      // 振替元(三井住友銀行大塚支店)残高 3,000 < ガス支払額 4,500 → 引落失敗の可能性。
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 3000},
        baseDate: DateTime(2026, 6, 15),
        includeDefaultFixedPayments: true,
      );
      final details = service.pendingConfirmationDetails(workbook);
      final gas = details.firstWhere(
        (detail) =>
            detail.row.accountId ==
            AssetLiabilityPlanningService.gasBillAccountId,
      );

      expect(gas.sourceAccountBalance, 3000);
      expect(gas.sourceBalanceInsufficient, isTrue);
      expect(service.insufficientSourceCount(workbook), 1);
    });

    test('flags later debit when earlier successful debit depletes the balance',
        () {
      // 6/26 時点、残高 5,000。ガス 4,500 (12日) は成功見込み → 残 500。
      // 水道 2,400 (22日) は生残高 5,000 では足りて見えるが、見込み残 500 では
      // 不足 → 警告。行単位の独立比較では取りこぼすケース。
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 5000},
        baseDate: DateTime(2026, 6, 26),
        includeDefaultFixedPayments: true,
      );
      final details = service.pendingConfirmationDetails(workbook);
      final gas = details.firstWhere(
        (detail) =>
            detail.row.accountId ==
            AssetLiabilityPlanningService.gasBillAccountId,
      );
      final water = details.firstWhere(
        (detail) =>
            detail.row.accountId ==
            AssetLiabilityPlanningService.waterBillAccountId,
      );

      expect(gas.sourceAccountBalance, 5000);
      expect(gas.sourceBalanceInsufficient, isFalse);
      expect(water.sourceAccountBalance, 500);
      expect(water.sourceBalanceInsufficient, isTrue);
    });

    test('failed (insufficient) debit does not deplete the running balance',
        () {
      // 残高 3,000: ガス 4,500 (12日) は不足で弾かれる想定 → 残高は減らず、
      // 水道 2,400 (22日) は 3,000 のまま判定 → 警告なし。
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 3000},
        baseDate: DateTime(2026, 6, 26),
        includeDefaultFixedPayments: true,
      );
      final details = service.pendingConfirmationDetails(workbook);
      final gas = details.firstWhere(
        (detail) =>
            detail.row.accountId ==
            AssetLiabilityPlanningService.gasBillAccountId,
      );
      final water = details.firstWhere(
        (detail) =>
            detail.row.accountId ==
            AssetLiabilityPlanningService.waterBillAccountId,
      );

      expect(gas.sourceAccountBalance, 3000);
      expect(gas.sourceBalanceInsufficient, isTrue);
      expect(water.sourceAccountBalance, 3000);
      expect(water.sourceBalanceInsufficient, isFalse);
    });

    test('does not flag when source balance covers the amount', () {
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 63539},
        baseDate: DateTime(2026, 6, 15),
        includeDefaultFixedPayments: true,
      );
      final details = service.pendingConfirmationDetails(workbook);
      final gas = details.firstWhere(
        (detail) =>
            detail.row.accountId ==
            AssetLiabilityPlanningService.gasBillAccountId,
      );

      expect(gas.sourceAccountBalance, 63539);
      expect(gas.sourceBalanceInsufficient, isFalse);
      expect(service.insufficientSourceCount(workbook), 0);
    });

    test('does not flag when source account balance is unknown', () {
      // 振替元を実在しない口座へ上書き → 残高を特定できないので警告しない(安全側)。
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 3000},
        baseDate: DateTime(2026, 6, 15),
        includeDefaultFixedPayments: true,
        paymentSourceAccountIds: const <String, String>{
          AssetLiabilityPlanningService.gasBillAccountId: 'ghost_account',
        },
      );
      final details = service.pendingConfirmationDetails(workbook);
      final gas = details.firstWhere(
        (detail) =>
            detail.row.accountId ==
            AssetLiabilityPlanningService.gasBillAccountId,
      );

      expect(gas.sourceAccountBalance, isNull);
      expect(gas.sourceBalanceInsufficient, isFalse);
      expect(service.insufficientSourceCount(workbook), 0);
    });

    test('details cover the same rows as pendingConfirmations in order', () {
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 63539},
        baseDate: DateTime(2026, 6, 15),
        includeDefaultFixedPayments: true,
      );
      final rows = service.pendingConfirmations(workbook);
      final details = service.pendingConfirmationDetails(workbook);

      expect(details.length, rows.length);
      for (var i = 0; i < rows.length; i++) {
        expect(details[i].row.accountId, rows[i].accountId);
      }
      expect(
        gasDetailRow(details).accountId,
        AssetLiabilityPlanningService.gasBillAccountId,
      );
    });

    test('does not flag when source balance equals the amount (strict <)', () {
      // 残高 4,500 == ガス支払額 4,500 → ちょうど引落できる想定なので警告しない。
      // sourceBalanceInsufficient が < で定義されている境界を固定する。
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 4500},
        baseDate: DateTime(2026, 6, 15),
        includeDefaultFixedPayments: true,
      );
      final details = service.pendingConfirmationDetails(workbook);
      final gas = details.firstWhere(
        (detail) =>
            detail.row.accountId ==
            AssetLiabilityPlanningService.gasBillAccountId,
      );

      expect(gas.row.paymentAmount, 4500);
      expect(gas.sourceAccountBalance, 4500);
      expect(gas.sourceBalanceInsufficient, isFalse);
      expect(service.insufficientSourceCount(workbook), 0);
    });

    test('flags only rows whose own source is short among multiple pending',
        () {
      // 6/25 時点でガス(12日/4,500/振替元=大塚) と 水道(22日/2,400/振替元=神田へ上書き)
      // が確認待ち。大塚 3,000 < ガス 4,500 → ガスのみ警告。神田 50,000 >= 水道 2,400 →
      // 水道は警告しない。各行が「自分の振替元の残高」で判定され、件数がフィルタ後の数
      // (=1, リストの長さ 2 ではない) であることを担保する。
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 3000,
          '三井住友銀行神田支店': 50000,
        },
        baseDate: DateTime(2026, 6, 25),
        includeDefaultFixedPayments: true,
        paymentSourceAccountIds: const <String, String>{
          // '三井住友銀行神田支店' の口座 ID (= 既定の大塚とは別口座)。
          AssetLiabilityPlanningService.waterBillAccountId: 'smbc_kanda_branch',
        },
      );
      final details = service.pendingConfirmationDetails(workbook);
      final gas = details.firstWhere(
        (detail) =>
            detail.row.accountId ==
            AssetLiabilityPlanningService.gasBillAccountId,
      );
      final water = details.firstWhere(
        (detail) =>
            detail.row.accountId ==
            AssetLiabilityPlanningService.waterBillAccountId,
      );

      expect(gas.sourceAccountBalance, 3000);
      expect(gas.sourceBalanceInsufficient, isTrue);
      // 水道は自分の振替元(神田 50,000)で判定される = 大塚の 3,000 を流用しない。
      expect(water.sourceAccountBalance, 50000);
      expect(water.sourceBalanceInsufficient, isFalse);
      expect(service.insufficientSourceCount(workbook), 1);
    });
  });

  group('autoDebitAlternateSourcePaidHint', () {
    test('names the recorded source and prompts the balance update', () {
      final hint = autoDebitAlternateSourcePaidHint('アコムショッピング', '¥36,525');
      expect(hint, contains('アコムショッピング'));
      expect(hint, contains('¥36,525'));
      expect(hint, contains('残高一覧'));
      expect(hint, contains('反映'));
    });
  });

  group('autoDebitSourceInsufficient (credit-line vs asset)', () {
    test('asset account: warns only when balance is below the amount', () {
      expect(
        autoDebitSourceInsufficient(
          balance: 3000,
          kind: AssetLiabilityAccountKind.deposit,
          creditLimit: null,
          paymentAmount: 4500,
        ),
        isTrue,
      );
      expect(
        autoDebitSourceInsufficient(
          balance: 63539,
          kind: AssetLiabilityAccountKind.deposit,
          creditLimit: null,
          paymentAmount: 4500,
        ),
        isFalse,
      );
    });

    test('credit line with no/zero limit never warns (avoid false alarm)', () {
      // ファミペイ (翌月払い=残高常時マイナス) で利用上限未設定 → 誤発火させない。
      for (final limit in const <double?>[null, 0]) {
        expect(
          autoDebitSourceInsufficient(
            balance: -223441,
            kind: AssetLiabilityAccountKind.creditCard,
            creditLimit: limit,
            paymentAmount: 30000,
          ),
          isFalse,
          reason: 'limit=$limit should not warn',
        );
      }
    });

    test('credit line warns only when usage + payment exceeds the limit', () {
      // 利用額 223,441 + 支払 30,000 = 253,441 <= 上限 300,000 → 警告しない。
      expect(
        autoDebitSourceInsufficient(
          balance: -223441,
          kind: AssetLiabilityAccountKind.creditCard,
          creditLimit: 300000,
          paymentAmount: 30000,
        ),
        isFalse,
      );
      // 利用額 280,000 + 支払 30,000 = 310,000 > 上限 300,000 → 警告する。
      expect(
        autoDebitSourceInsufficient(
          balance: -280000,
          kind: AssetLiabilityAccountKind.creditCard,
          creditLimit: 300000,
          paymentAmount: 30000,
        ),
        isTrue,
      );
    });

    test('credit line at exactly the limit does not warn (strict >)', () {
      // 利用額 270,000 + 支払 30,000 = 300,000 == 上限 → 超過でないので警告しない。
      expect(
        autoDebitSourceInsufficient(
          balance: -270000,
          kind: AssetLiabilityAccountKind.creditCard,
          creditLimit: 300000,
          paymentAmount: 30000,
        ),
        isFalse,
      );
    });

    test('shoppingDebt and cardLoan are treated as credit lines too', () {
      for (final kind in const <AssetLiabilityAccountKind>[
        AssetLiabilityAccountKind.shoppingDebt,
        AssetLiabilityAccountKind.cardLoan,
      ]) {
        expect(
          autoDebitSourceInsufficient(
            balance: -100000,
            kind: kind,
            creditLimit: 300000,
            paymentAmount: 50000,
          ),
          isFalse,
          reason: '$kind within limit',
        );
        expect(
          autoDebitSourceInsufficient(
            balance: -280000,
            kind: kind,
            creditLimit: 300000,
            paymentAmount: 50000,
          ),
          isTrue,
          reason: '$kind over limit',
        );
      }
    });

    test('null balance never warns', () {
      expect(
        autoDebitSourceInsufficient(
          balance: null,
          kind: AssetLiabilityAccountKind.deposit,
          creditLimit: null,
          paymentAmount: 4500,
        ),
        isFalse,
      );
    });
  });
}
