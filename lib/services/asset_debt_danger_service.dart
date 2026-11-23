import 'dart:convert';

import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/widgets/debt_legal_disclaimer_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 返済危険度判定のしきい値および案内バナー表示設定 (#1370)。
class DebtDangerSettings {
  final double repaymentToIncomeThreshold;
  final int stagnantMonthsThreshold;
  final bool bannerDismissed;

  const DebtDangerSettings({
    this.repaymentToIncomeThreshold = 1 / 3,
    this.stagnantMonthsThreshold = 3,
    this.bannerDismissed = false,
  });

  DebtDangerSettings copyWith({
    double? repaymentToIncomeThreshold,
    int? stagnantMonthsThreshold,
    bool? bannerDismissed,
  }) {
    return DebtDangerSettings(
      repaymentToIncomeThreshold:
          repaymentToIncomeThreshold ?? this.repaymentToIncomeThreshold,
      stagnantMonthsThreshold:
          stagnantMonthsThreshold ?? this.stagnantMonthsThreshold,
      bannerDismissed: bannerDismissed ?? this.bannerDismissed,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'repayment_to_income_threshold': repaymentToIncomeThreshold,
      'stagnant_months_threshold': stagnantMonthsThreshold,
      'banner_dismissed': bannerDismissed,
    };
  }

  factory DebtDangerSettings.fromJson(Map<String, dynamic> json) {
    final rawRatio = json['repayment_to_income_threshold'];
    final ratio = rawRatio is num
        ? rawRatio.toDouble().clamp(0.15, 0.60).toDouble()
        : 1 / 3;
    final rawMonths = json['stagnant_months_threshold'];
    final months = rawMonths is num ? rawMonths.toInt().clamp(2, 6) : 3;
    final dismissed = json['banner_dismissed'] == true;
    return DebtDangerSettings(
      repaymentToIncomeThreshold: ratio,
      stagnantMonthsThreshold: months,
      bannerDismissed: dismissed,
    );
  }
}

/// 返済危険度判定設定の端末ローカル永続化ストア (#1370)。
class AssetDebtDangerSettingsStore {
  const AssetDebtDangerSettingsStore._();

  static const String prefsKey = 'asset_debt_danger_settings_v1';

  static Future<DebtDangerSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.trim().isEmpty) {
        return const DebtDangerSettings();
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return DebtDangerSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return DebtDangerSettings.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      // 設定読込失敗時は既定値へフォールバックする。
    }
    return const DebtDangerSettings();
  }

  static Future<void> save(DebtDangerSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, jsonEncode(settings.toJson()));
    } catch (_) {
      // 保存失敗時も画面操作自体はブロックしない。
    }
  }
}

/// 返済負担・残高推移の注意レベル (#1370)。
enum DebtDangerLevel { safe, caution, elevated }

/// 債務整理手続きの基礎知識ガイド項目 (#1370 AC3)。
class DebtReliefOptionGuide {
  final String id;
  final String title;
  final String summary;
  final String typicalPeriod;
  final String keyNote;

  const DebtReliefOptionGuide({
    required this.id,
    required this.title,
    required this.summary,
    required this.typicalPeriod,
    required this.keyNote,
  });
}

/// 返済危険度の判定結果 (#1370)。
class DebtDangerAssessment {
  final DebtDangerLevel level;
  final bool isAlertTriggered;
  final double monthlyScheduledPayment;
  final double? monthlyIncome;
  final double? repaymentToIncomeRatio;
  final bool exceedsIncomeRatioThreshold;
  final int consecutiveNonDecreasingMonths;
  final bool isDebtBalanceStagnant;
  final bool hasNegativeAmortization;
  final List<String> reasons;
  final DebtDangerSettings settings;

  const DebtDangerAssessment({
    required this.level,
    required this.isAlertTriggered,
    required this.monthlyScheduledPayment,
    required this.monthlyIncome,
    required this.repaymentToIncomeRatio,
    required this.exceedsIncomeRatioThreshold,
    required this.consecutiveNonDecreasingMonths,
    required this.isDebtBalanceStagnant,
    required this.hasNegativeAmortization,
    required this.reasons,
    required this.settings,
  });
}

/// 返済危険度の判定と債務整理・公的相談窓口ガイドを提供するサービス (#1370)。
class AssetDebtDangerService {
  const AssetDebtDangerService._();

  static const List<DebtReliefOptionGuide> debtReliefOptions =
      <DebtReliefOptionGuide>[
    DebtReliefOptionGuide(
      id: 'ninni_seiri',
      title: '任意整理',
      summary: '裁判所を介さず貸金業者等と将来利息のカットや返済期間の調整を交渉する手続きです。',
      typicalPeriod: '原則3〜5年の分割返済',
      keyNote: '対象債権者を選べるため、自動車ローンや保証人付き債務を外して進められる場合があります。',
    ),
    DebtReliefOptionGuide(
      id: 'kojin_saisei',
      title: '個人再生',
      summary: '裁判所への申立てにより負債総額を大幅に圧縮し、原則3〜5年で分割返済する手続きです。',
      typicalPeriod: '原則3年（最長5年）の再生計画',
      keyNote: '住宅資金特別条項を利用することで自宅を残したまま手続きできる場合があります。',
    ),
    DebtReliefOptionGuide(
      id: 'jiko_hasan',
      title: '自己破産',
      summary: '収入や資産から返済が困難な場合に、裁判所の免責決定を得て法的返済義務の免除を受ける手続きです。',
      typicalPeriod: '同時廃止は数ヶ月程度（管財事件は半年〜）',
      keyNote: '生活必需品など一定範囲の自由財産は手元に残りますが、一定の職業制限や財産処分を伴う場合があります。',
    ),
    DebtReliefOptionGuide(
      id: 'tokutei_chotei',
      title: '特定調停',
      summary: '簡易裁判所の調停委員が仲介し、債権者との返済条件の見直しについて合意を目指す手続きです。',
      typicalPeriod: '合意成立後3〜5年程度',
      keyNote: '費用を抑えて申立て可能ですが、期日対応や調書の効力等について事前の確認が重要です。',
    ),
  ];

  static const List<DebtConsultationResource> publicConsultationResources =
      <DebtConsultationResource>[
    DebtConsultationResource(
      id: 'houterasu',
      title: '法テラス（日本司法支援センター）',
      subtitle: '経済的に余裕のない方向けの無料法律相談・弁護士/司法書士費用の立替制度等の案内窓口です。',
      url: 'https://www.houterasu.or.jp/',
      phoneHint: '0570-078374（平日 9:00〜21:00 / 土 9:00〜17:00）',
    ),
    DebtConsultationResource(
      id: 'nichibenren',
      title: '日本弁護士連合会（ひまわりお悩み110番）',
      subtitle: '全国の弁護士会相談窓口への案内・債務整理の一般的な情報提供を行っています。',
      url: 'https://www.nichibenren.or.jp/',
      phoneHint: '0570-783-110（全国統一ナビダイヤル）',
    ),
    DebtConsultationResource(
      id: 'shiho_shoshi',
      title: '日本司法書士会連合会',
      subtitle: '各地の司法書士会による多重債務・クレジット/サラ金相談窓口の検索ができます。',
      url: 'https://www.shiho-shoshi.or.jp/',
    ),
    DebtConsultationResource(
      id: 'zenginkyo',
      title: '全国銀行協会（カウンセリングサービス）',
      subtitle: '銀行のカードローンや多重債務に関する無料カウンセリング・生活再建支援相談を行えます。',
      url: 'https://www.zenginkyo.or.jp/adr/counseling/',
    ),
    DebtConsultationResource(
      id: 'kokusen',
      title: '国民生活センター（消費者ホットライン 188）',
      subtitle: '最寄りの消費生活センターや多重債務相談窓口につなぐ公的ホットラインです。',
      url: 'https://www.kokusen.go.jp/',
      phoneHint: '局番なし 188（いやや）',
    ),
  ];

  static DebtDangerAssessment evaluate({
    required AssetLiabilityWorkbook workbook,
    double? monthlyIncome,
    List<AssetLiabilityMonthlySnapshot> monthlySnapshots =
        const <AssetLiabilityMonthlySnapshot>[],
    DebtDangerSettings settings = const DebtDangerSettings(),
  }) {
    final totalDebtAbs = workbook.liabilityTotal.abs();
    final plannedIncome = workbook.incomePlans.fold<double>(
      0.0,
      (sum, plan) => sum + (plan.amount > 0 ? plan.amount : 0.0),
    );
    final double? effectiveIncome;
    if (monthlyIncome != null && monthlyIncome.isFinite && monthlyIncome > 0) {
      effectiveIncome = monthlyIncome;
    } else if (plannedIncome > 0) {
      effectiveIncome = plannedIncome;
    } else {
      effectiveIncome = null;
    }

    final scheduled = workbook.monthlyScheduledPaymentTotal > 0
        ? workbook.monthlyScheduledPaymentTotal
        : 0.0;
    final double? ratio = (effectiveIncome != null && effectiveIncome > 0)
        ? scheduled / effectiveIncome
        : null;
    final exceedsRatio = totalDebtAbs > 0 &&
        ratio != null &&
        ratio > settings.repaymentToIncomeThreshold;

    final byMonth = <String, double>{};
    for (final snap in monthlySnapshots) {
      if (snap.monthKey.trim().isEmpty) continue;
      byMonth[snap.monthKey] = snap.liabilityTotal.abs();
    }
    if (byMonth.isNotEmpty && totalDebtAbs > 0) {
      final sortedExistingKeys = byMonth.keys.toList()..sort();
      final newestKey = sortedExistingKeys.last;
      final currentMonthKey =
          '${workbook.baseDate.year.toString().padLeft(4, '0')}-${workbook.baseDate.month.toString().padLeft(2, '0')}';
      if (!byMonth.containsKey(currentMonthKey) &&
          currentMonthKey.compareTo(newestKey) > 0) {
        byMonth[currentMonthKey] = totalDebtAbs;
      }
    }

    var consecutiveNonDecreasing = 0;
    if (byMonth.length >= 2) {
      final orderedKeys = byMonth.keys.toList()..sort();
      var transitions = 0;
      for (var i = orderedKeys.length - 1; i >= 1; i--) {
        final curr = byMonth[orderedKeys[i]] ?? 0;
        final prev = byMonth[orderedKeys[i - 1]] ?? 0;
        if (curr > 0 && prev > 0 && curr >= prev) {
          transitions++;
        } else {
          break;
        }
      }
      consecutiveNonDecreasing = transitions == 0 ? 0 : transitions + 1;
    }

    final isStagnant = totalDebtAbs > 0 &&
        consecutiveNonDecreasing >= settings.stagnantMonthsThreshold;

    final hasNegAmort = totalDebtAbs > 0 &&
        workbook.currentDebtRows.any(
          (row) =>
              row.balance < 0 &&
              !row.fullPaymentEstimate &&
              !row.includedInBillingAccount &&
              row.monthlyInterestEstimate > 0 &&
              row.scheduledPaymentAmount <= row.monthlyInterestEstimate,
        );

    final reasons = <String>[];
    if (exceedsRatio) {
      final pct = (ratio! * 100).toStringAsFixed(0);
      final thresholdPct =
          (settings.repaymentToIncomeThreshold * 100).toStringAsFixed(0);
      reasons.add(
        '月々の返済予定額が月収の約$pct%となり、設定目安（$thresholdPct%）を上回っています。',
      );
    }
    if (isStagnant) {
      reasons.add(
        '借入残高が直近$consecutiveNonDecreasingヶ月連続で減少しておらず、返済負担の長期化が見られます。',
      );
    }
    if (hasNegAmort) {
      reasons.add(
        '月次返済予定額が概算利息以下となっている借入が含まれており、元金が減りにくい状態です。',
      );
    }

    final triggeredCount =
        (exceedsRatio ? 1 : 0) + (isStagnant ? 1 : 0) + (hasNegAmort ? 1 : 0);
    final isTriggered = totalDebtAbs > 0 && triggeredCount > 0;

    final DebtDangerLevel level;
    if (!isTriggered) {
      level = DebtDangerLevel.safe;
    } else if ((ratio != null && ratio >= 0.45) || triggeredCount >= 2) {
      level = DebtDangerLevel.elevated;
    } else {
      level = DebtDangerLevel.caution;
    }

    return DebtDangerAssessment(
      level: level,
      isAlertTriggered: isTriggered,
      monthlyScheduledPayment: scheduled,
      monthlyIncome: effectiveIncome,
      repaymentToIncomeRatio: ratio,
      exceedsIncomeRatioThreshold: exceedsRatio,
      consecutiveNonDecreasingMonths: consecutiveNonDecreasing,
      isDebtBalanceStagnant: isStagnant,
      hasNegativeAmortization: hasNegAmort,
      reasons: List<String>.unmodifiable(reasons),
      settings: settings,
    );
  }
}
