import '../models/asset_liability_workbook.dart';
import 'asset_liability_monthly_state_store.dart';

/// 給与明細 (`payslips` / `salary_incomes`) と収入予定 (`AssetLiabilityIncomePlan`) を
/// 突合・正規化する純関数群の置き場。
///
/// 背景:
/// 利用者が確定給与明細 (例: 2026-08-25 マイティリンク 421,277円) をアップロードして
/// いても、資産管理ダッシュボードの資金繰り・トリアージ計算 (`monthlyIncomePlans`) に
/// 未受取の概算プレースホルダー (例: 給料 450,000円 / received: false) が残存し、
/// 「入金予定が着金したか確認する」アラートが誤発火したり、手元資金見込みが過大に
/// 水増しされる問題を防ぐ。
///
/// 挙動:
/// 1. 給与明細から該当月の確定給与 (金額 > 0, pay_date 有効) を抽出。
/// 2. 同一給与サイクルまたは同日の「給料」系収入予定が存在する場合:
///    - 未受取 (`received: false`) であれば受取済み (`received: true`) に更新。
///    - 概算金額 (例: 450,000円) であれば確定金額 (例: 421,277円) に更新。
///    - 会社名があれば反映 (例: 'マイティリンク給与')。
///    - 同一サイクル・同日の重複した未受取給与予定は1件に統合 (重複プレースホルダーを排除)。
/// 3. 収入予定が存在しない場合でも、給与明細を「受取済み給与」として収入予定へ注入。
class AssetSalaryReconciliationService {
  const AssetSalaryReconciliationService._();

  static List<AssetLiabilityIncomePlan> reconcile({
    required List<AssetLiabilityIncomePlan> monthlyIncomePlans,
    required List<Map<String, dynamic>> payslipRows,
    required List<Map<String, dynamic>> payslipSalaryIncomes,
    int salaryDay = 25,
    DateTime? baseDate,
  }) {
    final confirmedPayslips = _extractConfirmedPayslips(
      payslipRows: payslipRows,
      payslipSalaryIncomes: payslipSalaryIncomes,
    );

    if (confirmedPayslips.isEmpty) {
      return List<AssetLiabilityIncomePlan>.from(monthlyIncomePlans);
    }

    final targetCycleMonth = baseDate != null
        ? AssetLiabilityMonthlyStateStore.salaryCycleMonthFor(
            baseDate,
            salaryDay: salaryDay,
          )
        : null;

    final result = <AssetLiabilityIncomePlan>[];
    final reconciledPayslipDates = <String>{};

    for (final plan in monthlyIncomePlans) {
      if (targetCycleMonth != null && _isSalaryPlan(plan)) {
        final planCycleMonth =
            AssetLiabilityMonthlyStateStore.salaryCycleMonthFor(
          plan.date,
          salaryDay: salaryDay,
        );
        if (planCycleMonth != targetCycleMonth) {
          // 既存データ（永続化データ）に混入している過去月・将来月の給与プランを除外する。
          continue;
        }
      }

      final matchingPayslip = _findMatchingPayslip(
        plan: plan,
        confirmedPayslips: confirmedPayslips,
        salaryDay: salaryDay,
        targetCycleMonth: targetCycleMonth,
      );

      if (matchingPayslip == null) {
        result.add(plan);
        continue;
      }

      final dateKey = _dateKey(matchingPayslip.payDate);
      if (reconciledPayslipDates.contains(dateKey)) {
        // すでにこの確定給与明細に紐づく収入予定が受取済みとして反映されているため、
        // 同一日付・同一サイクルの重複プレースホルダー(未受取の概算等)は除外する。
        continue;
      }
      reconciledPayslipDates.add(dateKey);

      final company = matchingPayslip.companyName.trim();
      final reconciledName = plan.name.contains(company) || company.isEmpty
          ? plan.name
          : (plan.name == '給料' || plan.name == '給料予定' || plan.name == '給与'
              ? '$company給与'
              : plan.name);

      result.add(
        AssetLiabilityIncomePlan(
          id: plan.id,
          date: matchingPayslip.payDate,
          name: reconciledName,
          amount: matchingPayslip.netAmount,
          destinationAccountId: plan.destinationAccountId,
          destinationAccountName: plan.destinationAccountName,
          received: true,
        ),
      );
    }

    // 収入予定に給料エントリが全く存在しない給与明細があれば、受取済み収入として補完する。
    // baseDate が指定されている場合は当給与サイクルの給与明細のみを対象とし、過去月・将来月の混入を防ぐ。
    for (final payslip in confirmedPayslips) {
      if (targetCycleMonth != null) {
        final payslipCycleMonth =
            AssetLiabilityMonthlyStateStore.salaryCycleMonthFor(
          payslip.payDate,
          salaryDay: salaryDay,
        );
        if (payslipCycleMonth != targetCycleMonth) {
          continue;
        }
      }
      final dateKey = _dateKey(payslip.payDate);
      if (reconciledPayslipDates.contains(dateKey)) {
        continue;
      }
      reconciledPayslipDates.add(dateKey);
      final company = payslip.companyName.trim();
      result.add(
        AssetLiabilityIncomePlan(
          id: 'payslip_$dateKey',
          date: payslip.payDate,
          name: company.isNotEmpty ? '$company給与' : '給料',
          amount: payslip.netAmount,
          destinationAccountId: null,
          destinationAccountName: null,
          received: true,
        ),
      );
    }

    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  static List<_ConfirmedSalaryPayslip> _extractConfirmedPayslips({
    required List<Map<String, dynamic>> payslipRows,
    required List<Map<String, dynamic>> payslipSalaryIncomes,
  }) {
    final list = <_ConfirmedSalaryPayslip>[];
    final seenDates = <String>{};

    for (final row in payslipRows) {
      final payDate = DateTime.tryParse(row['pay_date']?.toString() ?? '');
      final rawAmount = row['net_amount'] ?? row['amount'];
      final amount = _num(rawAmount);
      if (payDate == null || amount <= 0) continue;
      final dateKey = _dateKey(payDate);
      if (seenDates.contains(dateKey)) continue;
      seenDates.add(dateKey);
      final company = row['company_name']?.toString().trim() ?? '';
      list.add(
        _ConfirmedSalaryPayslip(
          payDate: payDate,
          netAmount: amount,
          companyName: company,
        ),
      );
    }

    for (final row in payslipSalaryIncomes) {
      final payDate = DateTime.tryParse(row['pay_date']?.toString() ?? '');
      final amount = _num(row['amount']);
      if (payDate == null || amount <= 0) continue;
      final dateKey = _dateKey(payDate);
      if (seenDates.contains(dateKey)) continue;
      seenDates.add(dateKey);
      final desc = row['description']?.toString().trim() ?? '';
      list.add(
        _ConfirmedSalaryPayslip(
          payDate: payDate,
          netAmount: amount,
          companyName: desc,
        ),
      );
    }

    return list;
  }

  static bool _isSalaryPlan(AssetLiabilityIncomePlan plan) {
    if (plan.id.startsWith('payslip_')) return true;
    final clean = _cleanLabel(plan.name);
    return clean.contains('給料') ||
        clean.contains('給与') ||
        clean.contains('手当') ||
        clean.contains('salary');
  }

  static _ConfirmedSalaryPayslip? _findMatchingPayslip({
    required AssetLiabilityIncomePlan plan,
    required List<_ConfirmedSalaryPayslip> confirmedPayslips,
    required int salaryDay,
    DateTime? targetCycleMonth,
  }) {
    final cleanPlanName = _cleanLabel(plan.name);

    for (final payslip in confirmedPayslips) {
      if (targetCycleMonth != null) {
        final payslipCycleMonth =
            AssetLiabilityMonthlyStateStore.salaryCycleMonthFor(
          payslip.payDate,
          salaryDay: salaryDay,
        );
        if (payslipCycleMonth != targetCycleMonth) {
          continue;
        }
      }

      final sameDate = _dateKey(plan.date) == _dateKey(payslip.payDate);
      final sameCycle = AssetLiabilityMonthlyStateStore.salaryCycleMonthFor(
            plan.date,
            salaryDay: salaryDay,
          ) ==
          AssetLiabilityMonthlyStateStore.salaryCycleMonthFor(
            payslip.payDate,
            salaryDay: salaryDay,
          );

      if (!sameDate && !sameCycle) {
        continue;
      }

      final isSalary = cleanPlanName.contains('給料') ||
          cleanPlanName.contains('給与') ||
          cleanPlanName.contains('手当') ||
          cleanPlanName.contains('salary') ||
          (payslip.companyName.isNotEmpty &&
              cleanPlanName.contains(_cleanLabel(payslip.companyName)));

      if (isSalary) {
        return payslip;
      }
    }
    return null;
  }

  static String _cleanLabel(String label) {
    return label.toLowerCase().replaceAll(RegExp(r'[\s　・_\-]'), '');
  }

  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static double _num(Object? value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }
}

class _ConfirmedSalaryPayslip {
  final DateTime payDate;
  final double netAmount;
  final String companyName;

  const _ConfirmedSalaryPayslip({
    required this.payDate,
    required this.netAmount,
    required this.companyName,
  });
}
