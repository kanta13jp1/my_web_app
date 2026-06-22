import 'package:supabase_flutter/supabase_flutter.dart';

enum CorporateAccountingSoftware { none, freee, moneyForward, yayoi, other }

extension CorporateAccountingSoftwareLabel on CorporateAccountingSoftware {
  String get id {
    switch (this) {
      case CorporateAccountingSoftware.none:
        return 'none';
      case CorporateAccountingSoftware.freee:
        return 'freee';
      case CorporateAccountingSoftware.moneyForward:
        return 'money_forward';
      case CorporateAccountingSoftware.yayoi:
        return 'yayoi';
      case CorporateAccountingSoftware.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case CorporateAccountingSoftware.none:
        return '未定';
      case CorporateAccountingSoftware.freee:
        return 'freee';
      case CorporateAccountingSoftware.moneyForward:
        return 'マネーフォワード';
      case CorporateAccountingSoftware.yayoi:
        return '弥生';
      case CorporateAccountingSoftware.other:
        return 'その他';
    }
  }
}

CorporateAccountingSoftware corporateAccountingSoftwareFromId(String? id) {
  switch (id) {
    case 'freee':
      return CorporateAccountingSoftware.freee;
    case 'money_forward':
      return CorporateAccountingSoftware.moneyForward;
    case 'yayoi':
      return CorporateAccountingSoftware.yayoi;
    case 'other':
      return CorporateAccountingSoftware.other;
    case 'none':
    default:
      return CorporateAccountingSoftware.none;
  }
}

class CorporateBankSimulationInput {
  const CorporateBankSimulationInput({
    required this.otherBankMonthlyTransferCount,
    this.sameBankMonthlyTransferCount = 0,
    required this.needsOverseasRemittance,
    required this.accountingSoftware,
  });

  final int otherBankMonthlyTransferCount;
  final int sameBankMonthlyTransferCount;
  final bool needsOverseasRemittance;
  final CorporateAccountingSoftware accountingSoftware;

  int get totalMonthlyTransferCount =>
      otherBankMonthlyTransferCount + sameBankMonthlyTransferCount;
}

class CorporateBankFeePlan {
  const CorporateBankFeePlan({
    required this.planKey,
    required this.bankKey,
    required this.bankName,
    required this.planName,
    required this.monthlyBaseFeeYen,
    required this.sameBankTransferFeeYen,
    required this.otherBankTransferFeeYen,
    required this.freeTransferCount,
    required this.overseasRemittanceAvailable,
    required this.overseasReceiptAvailable,
    required this.apiAvailable,
    required this.supportedAccountingSoftware,
    required this.sourceUrls,
    required this.sourceCheckedAt,
    required this.notes,
    this.active = true,
  });

  final String planKey;
  final String bankKey;
  final String bankName;
  final String planName;
  final int monthlyBaseFeeYen;
  final int sameBankTransferFeeYen;
  final int otherBankTransferFeeYen;
  final int freeTransferCount;
  final bool overseasRemittanceAvailable;
  final bool overseasReceiptAvailable;
  final bool apiAvailable;
  final List<String> supportedAccountingSoftware;
  final List<String> sourceUrls;
  final String sourceCheckedAt;
  final String notes;
  final bool active;

  String get displayName => '$bankName $planName';

  bool supportsAccountingSoftware(CorporateAccountingSoftware software) {
    if (software == CorporateAccountingSoftware.none) return true;
    final normalized = supportedAccountingSoftware.toSet();
    return normalized.contains(software.id) || normalized.contains('other');
  }

  factory CorporateBankFeePlan.fromSupabase(Map<String, dynamic> row) {
    return CorporateBankFeePlan(
      planKey: row['plan_key']?.toString() ?? '',
      bankKey: row['bank_key']?.toString() ?? '',
      bankName: row['bank_name']?.toString() ?? '',
      planName: row['plan_name']?.toString() ?? '',
      monthlyBaseFeeYen: _intFrom(row['monthly_base_fee_yen']),
      sameBankTransferFeeYen: _intFrom(row['same_bank_transfer_fee_yen']),
      otherBankTransferFeeYen: _intFrom(row['other_bank_transfer_fee_yen']),
      freeTransferCount: _intFrom(row['free_transfer_count']),
      overseasRemittanceAvailable: row['overseas_remittance_available'] == true,
      overseasReceiptAvailable: row['overseas_receipt_available'] == true,
      apiAvailable: row['api_available'] == true,
      supportedAccountingSoftware: _stringListFrom(
        row['supported_accounting_software'],
      ),
      sourceUrls: _stringListFrom(row['source_urls']),
      sourceCheckedAt: row['source_checked_at']?.toString() ?? '',
      notes: row['notes']?.toString() ?? '',
      active: row['active'] != false,
    );
  }

  static int _intFrom(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _stringListFrom(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}

class CorporateBankCostResult {
  const CorporateBankCostResult({
    required this.plan,
    required this.input,
    required this.monthlyBaseFeeYen,
    required this.monthlySameBankTransferCostYen,
    required this.monthlyOtherBankTransferCostYen,
    required this.monthlyTotalYen,
    required this.annualTotalYen,
    required this.meetsRequirements,
    required this.warnings,
  });

  final CorporateBankFeePlan plan;
  final CorporateBankSimulationInput input;
  final int monthlyBaseFeeYen;
  final int monthlySameBankTransferCostYen;
  final int monthlyOtherBankTransferCostYen;
  final int monthlyTotalYen;
  final int annualTotalYen;
  final bool meetsRequirements;
  final List<String> warnings;
}

class CorporateBankWbsTaskDraft {
  const CorporateBankWbsTaskDraft({
    required this.title,
    required this.description,
    required this.priority,
  });

  final String title;
  final String description;
  final String priority;

  Map<String, dynamic> toToolsHubBody() {
    return {
      'action': 'wbs.add_task',
      'category': '法人設立・銀行口座',
      'category_icon': '🏦',
      'category_order': 30,
      'title': title,
      'description': description,
      'instance': 'codex1',
      'owner_instance': 'codex1',
      'priority': priority,
      'status': 'pending',
      'progress': 0,
      'milestone_code': 'corporate-bank-account-cost-2926',
    };
  }
}

class CorporateBankAccountCostService {
  const CorporateBankAccountCostService({SupabaseClient? supabase})
      : _supabase = supabase;

  final SupabaseClient? _supabase;

  static const List<CorporateBankFeePlan> builtInPlans = <CorporateBankFeePlan>[
    CorporateBankFeePlan(
      planKey: 'gmo-aozora-standard',
      bankKey: 'gmo-aozora',
      bankName: 'GMOあおぞらネット銀行',
      planName: '通常',
      monthlyBaseFeeYen: 0,
      sameBankTransferFeeYen: 0,
      otherBankTransferFeeYen: 130,
      freeTransferCount: 0,
      overseasRemittanceAvailable: true,
      overseasReceiptAvailable: false,
      apiAvailable: true,
      supportedAccountingSoftware: <String>['freee', 'money_forward', 'yayoi'],
      sourceCheckedAt: '2026-06-06',
      sourceUrls: <String>[
        'https://gmo-aozora.com/business/service/payment.html',
        'https://gmo-aozora.com/business/service/overseas-remittance/',
        'https://gmo-aozora.com/business/api-cooperation/',
        'https://gmo-aozora.com/business/contents/faq.html',
      ],
      notes: '他行宛130円。海外送金はWise連携の送金専用で別途申込と審査が必要。',
    ),
    CorporateBankFeePlan(
      planKey: 'gmo-aozora-tokutoku',
      bankKey: 'gmo-aozora',
      bankName: 'GMOあおぞらネット銀行',
      planName: '振込料金とくとく会員',
      monthlyBaseFeeYen: 500,
      sameBankTransferFeeYen: 0,
      otherBankTransferFeeYen: 121,
      freeTransferCount: 0,
      overseasRemittanceAvailable: true,
      overseasReceiptAvailable: false,
      apiAvailable: true,
      supportedAccountingSoftware: <String>['freee', 'money_forward', 'yayoi'],
      sourceCheckedAt: '2026-06-06',
      sourceUrls: <String>[
        'https://gmo-aozora.com/business/service/payment.html',
        'https://gmo-aozora.com/business/service/overseas-remittance/',
        'https://gmo-aozora.com/business/api-cooperation/',
      ],
      notes: '月額500円で他行宛121円。月56件以上の他行振込で通常プランより有利。',
    ),
    CorporateBankFeePlan(
      planKey: 'sumishin-sbi-corporate',
      bankKey: 'sumishin-sbi',
      bankName: '住信SBIネット銀行',
      planName: '法人口座',
      monthlyBaseFeeYen: 0,
      sameBankTransferFeeYen: 0,
      otherBankTransferFeeYen: 145,
      freeTransferCount: 0,
      overseasRemittanceAvailable: true,
      overseasReceiptAvailable: true,
      apiAvailable: false,
      supportedAccountingSoftware: <String>['freee'],
      sourceCheckedAt: '2026-06-06',
      sourceUrls: <String>[
        'https://www.netbk.co.jp/contents/hojin/charge/',
        'https://www.netbk.co.jp/contents/hojin/gaika/',
        'https://www.netbk.co.jp/contents/hojin/launch/',
      ],
      notes: '他行宛145円。外貨送金・受取サービスは別途申込、審査、初期導入手数料が必要。',
    ),
    CorporateBankFeePlan(
      planKey: 'finswer-bank-free',
      bankKey: 'finswer-bank',
      bankName: 'Finswer Bank',
      planName: 'フリープラン',
      monthlyBaseFeeYen: 0,
      sameBankTransferFeeYen: 13,
      otherBankTransferFeeYen: 90,
      freeTransferCount: 0,
      overseasRemittanceAvailable: false,
      overseasReceiptAvailable: false,
      apiAvailable: true,
      supportedAccountingSoftware: <String>[
        'freee',
        'money_forward',
        'yayoi',
        'other',
      ],
      sourceCheckedAt: '2026-06-06',
      sourceUrls: <String>[
        'https://finswer-bank.finswer.jp/feature/bank',
        'https://finswer-bank.finswer.jp/price-list',
      ],
      notes: '北國銀行フィンサー支店のオンラインバンク。公式機能表に海外送金は掲載なし。',
    ),
  ];

  Future<List<CorporateBankFeePlan>> loadPlans() async {
    final supabase = _supabase;
    if (supabase == null) return builtInPlans;

    final rows = await supabase
        .from('corporate_bank_fee_plans')
        .select()
        .eq('active', true)
        .order('other_bank_transfer_fee_yen', ascending: true);

    if (rows.isEmpty) return builtInPlans;

    return rows
        .whereType<Map<String, dynamic>>()
        .map(CorporateBankFeePlan.fromSupabase)
        .where((plan) => plan.planKey.isNotEmpty && plan.active)
        .toList(growable: false);
  }

  List<CorporateBankCostResult> simulate(
    CorporateBankSimulationInput input, {
    List<CorporateBankFeePlan> plans = builtInPlans,
  }) {
    final results = plans
        .where((plan) => plan.active)
        .map((plan) => _simulatePlan(input, plan))
        .toList(growable: false);

    return results.toList()
      ..sort((a, b) {
        if (a.meetsRequirements != b.meetsRequirements) {
          return a.meetsRequirements ? -1 : 1;
        }
        final cost = a.annualTotalYen.compareTo(b.annualTotalYen);
        if (cost != 0) return cost;
        return a.warnings.length.compareTo(b.warnings.length);
      });
  }

  CorporateBankCostResult? bestResult(List<CorporateBankCostResult> results) {
    if (results.isEmpty) return null;
    return results.firstWhere(
      (result) => result.meetsRequirements,
      orElse: () => results.first,
    );
  }

  List<CorporateBankWbsTaskDraft> buildWbsTaskDrafts(
    CorporateBankSimulationInput input,
    CorporateBankCostResult result,
  ) {
    final plan = result.plan;
    final description = StringBuffer()
      ..writeln('Issue #2926 法人口座コスト自動シミュレーションから生成。')
      ..writeln()
      ..writeln('選定候補: ${plan.displayName}')
      ..writeln('月間他行宛振込: ${input.otherBankMonthlyTransferCount}件')
      ..writeln('月間同行宛振込: ${input.sameBankMonthlyTransferCount}件')
      ..writeln('会計ソフト: ${input.accountingSoftware.label}')
      ..writeln('海外送金要件: ${input.needsOverseasRemittance ? 'あり' : 'なし'}')
      ..writeln('年間見込みコスト: ${result.annualTotalYen}円')
      ..writeln('月額見込みコスト: ${result.monthlyTotalYen}円')
      ..writeln()
      ..writeln('確認メモ: ${plan.notes}');

    if (result.warnings.isNotEmpty) {
      description
        ..writeln()
        ..writeln('要確認:')
        ..writeln(result.warnings.map((warning) => '- $warning').join('\n'));
    }

    if (plan.sourceUrls.isNotEmpty) {
      description
        ..writeln()
        ..writeln('公式ソース:')
        ..writeln(plan.sourceUrls.map((url) => '- $url').join('\n'));
    }

    return <CorporateBankWbsTaskDraft>[
      CorporateBankWbsTaskDraft(
        title: '[#2926] ${plan.bankName}の法人口座開設要件を確認する',
        description: description.toString(),
        priority: result.meetsRequirements ? 'medium' : 'high',
      ),
      CorporateBankWbsTaskDraft(
        title: '[#2926] ${plan.bankName}の申込書類と審査資料を準備する',
        description:
            '登記簿、本人確認、事業内容、取引目的、${input.needsOverseasRemittance ? '海外送金の利用確認書類、' : ''}会計ソフト連携要件を確認する。',
        priority: 'medium',
      ),
      CorporateBankWbsTaskDraft(
        title: '[#2926] ${input.accountingSoftware.label}連携と振込運用を検証する',
        description:
            '${plan.displayName}で入出金明細、総合振込、承認権限、月間${input.totalMonthlyTransferCount}件の振込運用を試算どおりに回せるか確認する。',
        priority: 'medium',
      ),
    ];
  }

  CorporateBankCostResult _simulatePlan(
    CorporateBankSimulationInput input,
    CorporateBankFeePlan plan,
  ) {
    final billableOtherBankCount =
        (input.otherBankMonthlyTransferCount - plan.freeTransferCount).clamp(
      0,
      input.otherBankMonthlyTransferCount,
    );
    final monthlySameBankCost =
        input.sameBankMonthlyTransferCount * plan.sameBankTransferFeeYen;
    final monthlyOtherBankCost =
        billableOtherBankCount * plan.otherBankTransferFeeYen;
    final monthlyTotal =
        plan.monthlyBaseFeeYen + monthlySameBankCost + monthlyOtherBankCost;

    final warnings = <String>[];
    if (input.needsOverseasRemittance && !plan.overseasRemittanceAvailable) {
      warnings.add('海外送金要件を満たす公式掲載がありません。');
    }
    if (!plan.supportsAccountingSoftware(input.accountingSoftware)) {
      warnings.add('${input.accountingSoftware.label}連携は公式掲載またはseedで未確認です。');
    }
    if (input.accountingSoftware != CorporateAccountingSoftware.none &&
        !plan.apiAvailable) {
      warnings.add('APIまたは自動連携は要手動確認です。');
    }

    final meetsRequirements = warnings.isEmpty;

    return CorporateBankCostResult(
      plan: plan,
      input: input,
      monthlyBaseFeeYen: plan.monthlyBaseFeeYen,
      monthlySameBankTransferCostYen: monthlySameBankCost,
      monthlyOtherBankTransferCostYen: monthlyOtherBankCost,
      monthlyTotalYen: monthlyTotal,
      annualTotalYen: monthlyTotal * 12,
      meetsRequirements: meetsRequirements,
      warnings: warnings,
    );
  }
}
