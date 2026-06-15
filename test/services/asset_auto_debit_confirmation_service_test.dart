import 'package:flutter_test/flutter_test.dart';
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
}
