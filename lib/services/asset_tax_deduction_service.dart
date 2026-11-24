import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// 税務・控除支援ツール (#2490 / #2491) の OFF-default フィーチャーフラグ管理。
class AssetTaxToolsFeatureFlagStore {
  const AssetTaxToolsFeatureFlagStore._();

  static const String prefsKey = 'asset_tax_deduction_tools_enabled_v1';

  static Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefsKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> save(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, enabled);
    } catch (_) {
      // 保存失敗時もUI表示は維持する。
    }
  }
}

/// ふるさと納税控除上限試算の家族構成区分 (#2490)。
enum FurusatoMaritalStatus {
  single,
  marriedDualIncome,
  marriedWithSpouseDeduction,
}

/// ふるさと納税控除上限試算の入力モデル (#2490)。
class FurusatoTaxInput {
  final double annualSalaryIncome;
  final FurusatoMaritalStatus maritalStatus;
  final int generalDependentsCount;
  final int specificDependentsCount;
  final int elderlyLivingTogetherCount;
  final int elderlySeparateCount;
  final double? socialInsuranceOverride;
  final double otherDeductions;

  const FurusatoTaxInput({
    required this.annualSalaryIncome,
    this.maritalStatus = FurusatoMaritalStatus.single,
    this.generalDependentsCount = 0,
    this.specificDependentsCount = 0,
    this.elderlyLivingTogetherCount = 0,
    this.elderlySeparateCount = 0,
    this.socialInsuranceOverride,
    this.otherDeductions = 0,
  });
}

/// ふるさと納税控除上限の決定論的試算結果 (#2490)。
class FurusatoTaxEstimate {
  final double annualSalaryIncome;
  final double salaryDeduction;
  final double salaryIncome;
  final double socialInsuranceUsed;
  final bool socialInsuranceEstimated;
  final double incomeTaxDeductionTotal;
  final double residentTaxDeductionTotal;
  final double taxableIncomeForIncomeTax;
  final double taxableIncomeForResidentTax;
  final double incomeTaxRate;
  final double residentTaxIncomePortion;
  final int estimatedLimitYen;
  final int selfBurdenYen;
  final List<String> notes;

  const FurusatoTaxEstimate({
    required this.annualSalaryIncome,
    required this.salaryDeduction,
    required this.salaryIncome,
    required this.socialInsuranceUsed,
    required this.socialInsuranceEstimated,
    required this.incomeTaxDeductionTotal,
    required this.residentTaxDeductionTotal,
    required this.taxableIncomeForIncomeTax,
    required this.taxableIncomeForResidentTax,
    required this.incomeTaxRate,
    required this.residentTaxIncomePortion,
    required this.estimatedLimitYen,
    required this.selfBurdenYen,
    required this.notes,
  });
}

/// 国税庁 No.1410 / No.2260 および総務省公開計算式準拠のふるさと納税控除上限シミュレーター (#2490)。
class AssetFurusatoTaxCalculator {
  const AssetFurusatoTaxCalculator._();

  static const int selfBurdenYen = 2000;

  /// 給与所得控除額（国税庁 No.1410 準拠・令和2年分以降）。
  static double calculateSalaryDeduction(double salary) {
    final s = max(0.0, salary);
    if (s <= 0) return 0;
    if (s <= 1625000) return min(s, 550000);
    if (s <= 1800000) return s * 0.40 - 100000;
    if (s <= 3600000) return s * 0.30 + 80000;
    if (s <= 6600000) return s * 0.20 + 440000;
    if (s <= 8500000) return s * 0.10 + 1100000;
    return 1950000;
  }

  /// 所得税率（国税庁 No.2260 速算表）。
  static double marginalIncomeTaxRate(double taxableIncome) {
    if (taxableIncome <= 0) return 0;
    if (taxableIncome <= 1949000) return 0.05;
    if (taxableIncome <= 3299000) return 0.10;
    if (taxableIncome <= 6949000) return 0.20;
    if (taxableIncome <= 8999000) return 0.23;
    if (taxableIncome <= 17999000) return 0.33;
    if (taxableIncome <= 39999000) return 0.40;
    return 0.45;
  }

  static double _floorTo1000(double value) {
    if (!value.isFinite || value <= 0) return 0;
    return ((value ~/ 1000) * 1000).toDouble();
  }

  static FurusatoTaxEstimate estimate(FurusatoTaxInput input) {
    final salary = max(0.0, input.annualSalaryIncome);
    final salaryDeduction = calculateSalaryDeduction(salary);
    final salaryIncome = max(0.0, salary - salaryDeduction);

    final overrideSoc = input.socialInsuranceOverride;
    final bool socialEstimated = overrideSoc == null || overrideSoc < 0;
    final socialInsuranceUsed = socialEstimated ? salary * 0.15 : overrideSoc;

    final double basicIncomeTax;
    final double basicResidentTax;
    if (salaryIncome <= 24000000) {
      basicIncomeTax = 480000;
      basicResidentTax = 430000;
    } else if (salaryIncome <= 24500000) {
      basicIncomeTax = 320000;
      basicResidentTax = 290000;
    } else if (salaryIncome <= 25000000) {
      basicIncomeTax = 160000;
      basicResidentTax = 150000;
    } else {
      basicIncomeTax = 0;
      basicResidentTax = 0;
    }

    var spouseIncomeTax = 0.0;
    var spouseResidentTax = 0.0;
    if (input.maritalStatus ==
        FurusatoMaritalStatus.marriedWithSpouseDeduction) {
      if (salaryIncome <= 9000000) {
        spouseIncomeTax = 380000;
        spouseResidentTax = 330000;
      } else if (salaryIncome <= 9500000) {
        spouseIncomeTax = 260000;
        spouseResidentTax = 220000;
      } else if (salaryIncome <= 10000000) {
        spouseIncomeTax = 130000;
        spouseResidentTax = 110000;
      }
    }

    final genDep = max(0, input.generalDependentsCount);
    final specDep = max(0, input.specificDependentsCount);
    final eldTogether = max(0, input.elderlyLivingTogetherCount);
    final eldSep = max(0, input.elderlySeparateCount);

    final depIncomeTax = genDep * 380000.0 +
        specDep * 630000.0 +
        eldTogether * 580000.0 +
        eldSep * 480000.0;
    final depResidentTax = genDep * 330000.0 +
        specDep * 450000.0 +
        eldTogether * 450000.0 +
        eldSep * 380000.0;

    final other = max(0.0, input.otherDeductions);
    final incomeTaxDeductionTotal = basicIncomeTax +
        spouseIncomeTax +
        depIncomeTax +
        socialInsuranceUsed +
        other;
    final residentTaxDeductionTotal = basicResidentTax +
        spouseResidentTax +
        depResidentTax +
        socialInsuranceUsed +
        other;

    final taxableIncomeForIncomeTax = _floorTo1000(
      salaryIncome - incomeTaxDeductionTotal,
    );
    final taxableIncomeForResidentTax = _floorTo1000(
      salaryIncome - residentTaxDeductionTotal,
    );

    final taxRate = marginalIncomeTaxRate(taxableIncomeForIncomeTax);
    final residentIncomePortion = taxableIncomeForResidentTax * 0.10;
    final denominator = 0.90 - taxRate * 1.021;

    final int limitYen;
    if (salary <= 0 || residentIncomePortion <= 0 || denominator <= 0) {
      limitYen = 0;
    } else {
      final specialPart = (residentIncomePortion * 0.20) / denominator;
      limitYen = ((specialPart + selfBurdenYen) ~/ 1000) * 1000;
    }

    final notes = <String>[
      '国税庁（給与所得控除 No.1410 / 所得税速算表 No.2260）および総務省の控除上限式にもとづく決定論的概算です。',
      if (socialEstimated)
        '社会保険料は未入力のため給与収入の15%で概算しています。源泉徴収票の実績値を入力すると精度が上がります。',
      '住宅ローン控除・医療費控除等を併用する場合、実際の控除上限が下がることがあります。',
    ];

    return FurusatoTaxEstimate(
      annualSalaryIncome: salary,
      salaryDeduction: salaryDeduction,
      salaryIncome: salaryIncome,
      socialInsuranceUsed: socialInsuranceUsed,
      socialInsuranceEstimated: socialEstimated,
      incomeTaxDeductionTotal: incomeTaxDeductionTotal,
      residentTaxDeductionTotal: residentTaxDeductionTotal,
      taxableIncomeForIncomeTax: taxableIncomeForIncomeTax,
      taxableIncomeForResidentTax: taxableIncomeForResidentTax,
      incomeTaxRate: taxRate,
      residentTaxIncomePortion: residentIncomePortion,
      estimatedLimitYen: limitYen,
      selfBurdenYen: limitYen > 0 ? selfBurdenYen : 0,
      notes: List<String>.unmodifiable(notes),
    );
  }
}

/// 医療費控除トラッカーの支出カテゴリ (#2491)。
enum MedicalExpenseCategory { hospital, pharmacy, transport, other }

extension MedicalExpenseCategoryLabel on MedicalExpenseCategory {
  String get label {
    switch (this) {
      case MedicalExpenseCategory.hospital:
        return '病院・診療';
      case MedicalExpenseCategory.pharmacy:
        return '薬局・医薬品';
      case MedicalExpenseCategory.transport:
        return '通院交通費';
      case MedicalExpenseCategory.other:
        return 'その他医療費';
    }
  }
}

/// 個別の医療費支出レコード (#2491)。
class MedicalExpenseEntry {
  final String id;
  final DateTime date;
  final MedicalExpenseCategory category;
  final double amount;
  final double reimbursementAmount;
  final String memo;

  const MedicalExpenseEntry({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    this.reimbursementAmount = 0,
    this.memo = '',
  });

  double get netAmount => max(0.0, amount - max(0.0, reimbursementAmount));

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'date': date.toIso8601String(),
      'category': category.name,
      'amount': amount,
      'reimbursement_amount': reimbursementAmount,
      'memo': memo,
    };
  }

  factory MedicalExpenseEntry.fromJson(Map<String, dynamic> json) {
    final catName = json['category']?.toString();
    final cat = MedicalExpenseCategory.values.firstWhere(
      (value) => value.name == catName,
      orElse: () => MedicalExpenseCategory.hospital,
    );
    return MedicalExpenseEntry(
      id: json['id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      category: cat,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      reimbursementAmount:
          (json['reimbursement_amount'] as num?)?.toDouble() ?? 0,
      memo: json['memo']?.toString() ?? '',
    );
  }
}

/// 医療費控除の月別集計バケット (#2491)。
class MedicalExpenseMonthlyBucket {
  final int month;
  final double grossAmount;
  final double reimbursementAmount;
  final double netAmount;

  const MedicalExpenseMonthlyBucket({
    required this.month,
    required this.grossAmount,
    required this.reimbursementAmount,
    required this.netAmount,
  });
}

/// 年間の医療費累計・控除基準到達判定サマリー (#2491)。
class MedicalExpenseYearSummary {
  final int taxYear;
  final List<MedicalExpenseEntry> entries;
  final double grossTotal;
  final double reimbursementTotal;
  final double netTotal;
  final double deductionThreshold;
  final double estimatedDeduction;
  final double amountToThreshold;
  final bool isDeductionEligible;
  final bool isApproachingThreshold;
  final bool isAtCap;
  final Map<MedicalExpenseCategory, double> categoryTotals;
  final List<MedicalExpenseMonthlyBucket> monthlyBuckets;

  const MedicalExpenseYearSummary({
    required this.taxYear,
    required this.entries,
    required this.grossTotal,
    required this.reimbursementTotal,
    required this.netTotal,
    required this.deductionThreshold,
    required this.estimatedDeduction,
    required this.amountToThreshold,
    required this.isDeductionEligible,
    required this.isApproachingThreshold,
    required this.isAtCap,
    required this.categoryTotals,
    required this.monthlyBuckets,
  });
}

/// 国税庁 No.1120 準拠の年間医療費累計・控除到達アラート算出サービス (#2491)。
class AssetMedicalExpenseService {
  const AssetMedicalExpenseService._();

  static const double standardThreshold = 100000;
  static const double maxDeductionCap = 2000000;

  static MedicalExpenseYearSummary summarizeYear({
    required int taxYear,
    required List<MedicalExpenseEntry> entries,
    double? annualTotalIncome,
  }) {
    final yearEntries = entries
        .where((entry) => entry.date.year == taxYear)
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));

    var grossTotal = 0.0;
    var reimbursementTotal = 0.0;
    final categoryTotals = <MedicalExpenseCategory, double>{
      for (final category in MedicalExpenseCategory.values) category: 0.0,
    };
    final monthlyGross = List<double>.filled(12, 0.0);
    final monthlyReimburse = List<double>.filled(12, 0.0);

    for (final entry in yearEntries) {
      final safeAmount = max(0.0, entry.amount);
      final safeReimburse = max(0.0, entry.reimbursementAmount);
      final safeNet = max(0.0, safeAmount - safeReimburse);
      grossTotal += safeAmount;
      reimbursementTotal += safeReimburse;
      categoryTotals[entry.category] =
          (categoryTotals[entry.category] ?? 0.0) + safeNet;
      final idx = entry.date.month - 1;
      monthlyGross[idx] += safeAmount;
      monthlyReimburse[idx] += safeReimburse;
    }

    final netTotal = max(0.0, grossTotal - reimbursementTotal);
    final double threshold;
    if (annualTotalIncome != null &&
        annualTotalIncome.isFinite &&
        annualTotalIncome > 0 &&
        annualTotalIncome < 2000000) {
      threshold = annualTotalIncome * 0.05;
    } else {
      threshold = standardThreshold;
    }

    final rawDeduction = max(0.0, netTotal - threshold);
    final estimatedDeduction = min(maxDeductionCap, rawDeduction);
    final isEligible = netTotal > threshold;
    final isApproaching =
        !isEligible && threshold > 0 && netTotal >= threshold * 0.80;
    final isAtCap = estimatedDeduction >= maxDeductionCap;
    final amountToThreshold = max(0.0, threshold - netTotal);

    final monthlyBuckets = <MedicalExpenseMonthlyBucket>[
      for (var m = 1; m <= 12; m++)
        MedicalExpenseMonthlyBucket(
          month: m,
          grossAmount: monthlyGross[m - 1],
          reimbursementAmount: monthlyReimburse[m - 1],
          netAmount: max(0.0, monthlyGross[m - 1] - monthlyReimburse[m - 1]),
        ),
    ];

    return MedicalExpenseYearSummary(
      taxYear: taxYear,
      entries: List<MedicalExpenseEntry>.unmodifiable(yearEntries),
      grossTotal: grossTotal,
      reimbursementTotal: reimbursementTotal,
      netTotal: netTotal,
      deductionThreshold: threshold,
      estimatedDeduction: estimatedDeduction,
      amountToThreshold: amountToThreshold,
      isDeductionEligible: isEligible,
      isApproachingThreshold: isApproaching,
      isAtCap: isAtCap,
      categoryTotals: Map<MedicalExpenseCategory, double>.unmodifiable(
        categoryTotals,
      ),
      monthlyBuckets: List<MedicalExpenseMonthlyBucket>.unmodifiable(
        monthlyBuckets,
      ),
    );
  }
}

/// 医療費明細リストの端末ローカル永続化ストア (#2491)。
class AssetMedicalExpenseStore {
  const AssetMedicalExpenseStore._();

  static const String prefsKey = 'asset_medical_expense_entries_v1';

  static Future<List<MedicalExpenseEntry>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.trim().isEmpty) {
        return const <MedicalExpenseEntry>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <MedicalExpenseEntry>[];
      }
      final entries = <MedicalExpenseEntry>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          entries.add(MedicalExpenseEntry.fromJson(item));
        } else if (item is Map) {
          entries.add(
            MedicalExpenseEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
      entries.sort((a, b) => b.date.compareTo(a.date));
      return List<MedicalExpenseEntry>.unmodifiable(entries);
    } catch (_) {
      return const <MedicalExpenseEntry>[];
    }
  }

  static Future<void> save(List<MedicalExpenseEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        prefsKey,
        jsonEncode(entries.map((e) => e.toJson()).toList(growable: false)),
      );
    } catch (_) {
      // 保存失敗時もUI状態は保持する。
    }
  }
}
