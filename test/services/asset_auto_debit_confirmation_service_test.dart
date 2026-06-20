import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_auto_debit_confirmation_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  const service = AssetAutoDebitConfirmationService();
  const planning = AssetLiabilityPlanningService();

  group('AssetAutoDebitConfirmationService', () {
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
}
