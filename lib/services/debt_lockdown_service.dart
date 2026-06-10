import 'dart:convert';

import 'package:my_web_app/services/waste_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebtLockdownRule {
  const DebtLockdownRule({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

class DebtLockdownViolation {
  const DebtLockdownViolation({
    required this.id,
    required this.category,
    required this.note,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final String category;
  final String note;
  final double amount;
  final DateTime createdAt;

  factory DebtLockdownViolation.fromJson(Map<String, dynamic> json) {
    return DebtLockdownViolation(
      id: json['id']?.toString() ?? '',
      category:
          json['category']?.toString() ?? DebtLockdownService.otherCategory,
      note: json['note']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'category': category,
      'note': note,
      'amount': amount,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

class DebtLockdownSnapshot {
  const DebtLockdownSnapshot({
    required this.remainingDebt,
    required this.isEnabled,
    required this.isReleased,
    required this.startedAt,
    required this.rules,
    required this.completedRuleIds,
    required this.todayViolations,
    required this.currentCompliantStreakDays,
    required this.recentViolations,
  });

  final double remainingDebt;
  final bool isEnabled;
  final bool isReleased;
  final DateTime? startedAt;
  final List<DebtLockdownRule> rules;
  final Set<String> completedRuleIds;
  final List<DebtLockdownViolation> todayViolations;
  final int currentCompliantStreakDays;
  final List<DebtLockdownViolation> recentViolations;

  bool get isActive => isEnabled && !isReleased;

  int get completedRuleCount => completedRuleIds.length;

  bool get allRulesCompletedToday => completedRuleIds.length >= rules.length;
}

enum DebtSafetySeverity { info, warning, danger }

class DebtSafetyDebtInput {
  const DebtSafetyDebtInput({
    required this.accountId,
    required this.accountName,
    required this.balance,
    required this.annualRate,
  });

  final String accountId;
  final String accountName;
  final double balance;
  final double annualRate;
}

class DebtAnnualRateRisk {
  const DebtAnnualRateRisk({
    required this.accountName,
    required this.annualRate,
    required this.principal,
    required this.legalCapAnnualRate,
    required this.blocksRegistration,
  });

  final String accountName;
  final double annualRate;
  final double principal;
  final double legalCapAnnualRate;
  final bool blocksRegistration;

  DebtSafetySeverity get severity => blocksRegistration
      ? DebtSafetySeverity.danger
      : DebtSafetySeverity.warning;

  String get title =>
      blocksRegistration ? '年利20%超のため登録できません' : '元本別の上限金利を超える可能性があります';

  String get detail {
    final capLabel = DebtLockdownService.formatAnnualRate(legalCapAnnualRate);
    final rateLabel = DebtLockdownService.formatAnnualRate(annualRate);
    if (blocksRegistration) {
      return '$accountName は年利 $rateLabel です。出資法の上限金利20%を超える可能性があるため、この条件は保存せず、登録貸金業者か確認してください。';
    }
    return '$accountName は年利 $rateLabel です。元本別の利息制限法上限 $capLabel を超える可能性があるため、契約条件を確認してください。';
  }
}

class DebtSafetyGuidance {
  const DebtSafetyGuidance({
    required this.id,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.url,
    required this.severity,
  });

  final String id;
  final String title;
  final String body;
  final String actionLabel;
  final String url;
  final DebtSafetySeverity severity;
}

class DebtEducationNotice {
  const DebtEducationNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.url,
    required this.severity,
  });

  final String id;
  final String title;
  final String body;
  final String actionLabel;
  final String url;
  final DebtSafetySeverity severity;
}

class DebtSafetySnapshot {
  const DebtSafetySnapshot({
    required this.totalDebt,
    required this.debtCount,
    required this.annualRateRisks,
    required this.guidanceCards,
    required this.educationNotices,
  });

  final double totalDebt;
  final int debtCount;
  final List<DebtAnnualRateRisk> annualRateRisks;
  final List<DebtSafetyGuidance> guidanceCards;
  final List<DebtEducationNotice> educationNotices;

  bool get hasBlockingAnnualRates =>
      annualRateRisks.any((risk) => risk.blocksRegistration);

  bool get shouldShowSelfExclusionGuidance =>
      guidanceCards.any((guidance) => guidance.id == 'lending_self_exclusion');

  bool get hasSignals =>
      annualRateRisks.isNotEmpty ||
      guidanceCards.isNotEmpty ||
      educationNotices.isNotEmpty;
}

class DebtLockdownService {
  const DebtLockdownService({this.nowProvider});

  static const String otherCategory = 'その他';
  static const double statutoryBlockAnnualRate = 0.20;
  static const double selfExclusionDebtTotalThreshold = 1000000;
  static const int selfExclusionDebtCountThreshold = 5;

  static const String selfExclusionGuidanceUrl =
      'https://www.j-fsa.or.jp/personal/useful/question/selfcontrol.php';
  static const String lendingConsultationUrl =
      'https://www.j-fsa.or.jp/personal/borrowing/';
  static const String registeredLenderSearchUrl =
      'https://www.fsa.go.jp/ordinary/kensaku/index.html';
  static const String illegalLenderWarningUrl =
      'https://www.fsa.go.jp/ordinary/chuui/index.html';
  static const String badContractorWarningUrl =
      'https://www.j-fsa.or.jp/personal/bad_contractor/';
  static const String youngFraudWarningUrl =
      'https://www.j-fsa.or.jp/topics/association/for_young.php';

  static const List<DebtLockdownRule> builtinRules = <DebtLockdownRule>[
    DebtLockdownRule(
      id: 'essentials_only',
      label: '必需品以外に金を使わない',
      description: '生活維持と返済に関係しない支出を増やさない。',
    ),
    DebtLockdownRule(
      id: 'no_waste_spending',
      label: '浪費カテゴリをゼロにする',
      description: '酒、たばこ、夜遊び、ギャンブル、課金を禁止する。',
    ),
    DebtLockdownRule(
      id: 'daily_debt_check',
      label: '残債と家計を毎日1回確認する',
      description: '逃避せず、残債・支出・返済計画を見直す。',
    ),
    DebtLockdownRule(
      id: 'one_repayment_action',
      label: '返済前進アクションを1件やる',
      description: '返済、収入増、固定費削減のどれかを必ず進める。',
    ),
    DebtLockdownRule(
      id: 'no_new_escape',
      label: '新しい逃避を始めない',
      description: '新規サブスク、趣味買い、勉強のつまみ食いを増やさない。',
    ),
  ];

  static const String _enabledKey = 'debt_lockdown_enabled_v1';
  static const String _startedAtKey = 'debt_lockdown_started_at_v1';
  static const String _historyKey = 'debt_lockdown_history_v1';

  final DateTime Function()? nowProvider;

  DateTime _now() => nowProvider?.call() ?? DateTime.now();

  static List<String> get violationCategories => <String>[
        ...WasteTrackingService.categoryLabels,
        otherCategory,
      ];

  static bool isRegistrableAnnualRate(double annualRate) =>
      annualRate >= 0 && annualRate <= statutoryBlockAnnualRate;

  static double legalAnnualRateCapForPrincipal(double principal) {
    final amount = principal.abs();
    if (amount >= 1000000) {
      return 0.15;
    }
    if (amount >= 100000) {
      return 0.18;
    }
    return statutoryBlockAnnualRate;
  }

  static String formatAnnualRate(double annualRate) {
    final percent = annualRate * 100;
    if (percent == percent.roundToDouble()) {
      return '${percent.round()}%';
    }
    return '${percent.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}%';
  }

  static DebtAnnualRateRisk? evaluateAnnualRate({
    required String accountName,
    required double annualRate,
    double? principal,
  }) {
    if (annualRate <= 0) {
      return null;
    }

    final principalAmount = (principal ?? 0).abs();
    final legalCap = legalAnnualRateCapForPrincipal(principalAmount);
    final blocksRegistration = annualRate > statutoryBlockAnnualRate;
    final exceedsPrincipalCap = annualRate > legalCap;
    if (!blocksRegistration && !exceedsPrincipalCap) {
      return null;
    }

    return DebtAnnualRateRisk(
      accountName: accountName,
      annualRate: annualRate,
      principal: principalAmount,
      legalCapAnnualRate: legalCap,
      blocksRegistration: blocksRegistration,
    );
  }

  static DebtSafetySnapshot buildSafetySnapshot({
    required Iterable<DebtSafetyDebtInput> debts,
  }) {
    final activeDebts =
        debts.where((debt) => debt.balance.abs() > 0).toList(growable: false);
    final totalDebt = activeDebts.fold<double>(
      0,
      (sum, debt) => sum + debt.balance.abs(),
    );
    final annualRateRisks = activeDebts
        .map(
          (debt) => evaluateAnnualRate(
            accountName: debt.accountName,
            annualRate: debt.annualRate,
            principal: debt.balance.abs(),
          ),
        )
        .whereType<DebtAnnualRateRisk>()
        .toList(growable: false);

    final shouldShowSelfExclusion =
        activeDebts.length >= selfExclusionDebtCountThreshold ||
            totalDebt >= selfExclusionDebtTotalThreshold ||
            annualRateRisks.any((risk) => risk.blocksRegistration);
    final guidanceCards = <DebtSafetyGuidance>[
      if (shouldShowSelfExclusion)
        const DebtSafetyGuidance(
          id: 'lending_self_exclusion',
          title: '貸付自粛制度を確認',
          body: '新たな借入れを自分の意思だけで止めにくい状態です。日本貸金業協会の貸付自粛制度と生活再建相談を確認してください。',
          actionLabel: '制度を見る',
          url: selfExclusionGuidanceUrl,
          severity: DebtSafetySeverity.warning,
        ),
      if (shouldShowSelfExclusion)
        const DebtSafetyGuidance(
          id: 'lending_consultation',
          title: '貸金業相談・紛争解決センター',
          body: '返済や借入れで困っている場合は、早めに公的な相談窓口へつなげます。',
          actionLabel: '相談窓口',
          url: lendingConsultationUrl,
          severity: DebtSafetySeverity.info,
        ),
      if (annualRateRisks.any((risk) => risk.blocksRegistration))
        const DebtSafetyGuidance(
          id: 'illegal_lender_warning',
          title: '違法業者・高金利の疑い',
          body: '年利20%を超える条件や登録確認できない業者からは借入れしないでください。',
          actionLabel: '金融庁の注意',
          url: illegalLenderWarningUrl,
          severity: DebtSafetySeverity.danger,
        ),
      if (shouldShowSelfExclusion || annualRateRisks.isNotEmpty)
        const DebtSafetyGuidance(
          id: 'registered_lender_search',
          title: '登録貸金業者を確認',
          body: '新しい借入れや借換えを検討する前に、金融庁の登録貸金業者情報検索サービスで確認してください。',
          actionLabel: '登録検索',
          url: registeredLenderSearchUrl,
          severity: DebtSafetySeverity.info,
        ),
    ];

    final educationNotices =
        shouldShowSelfExclusion || annualRateRisks.isNotEmpty
            ? const <DebtEducationNotice>[
                DebtEducationNotice(
                  id: 'name_lending',
                  title: '名義貸しに注意',
                  body: '自分名義で借りて他人に渡す話は、返済義務だけが残る典型的なトラブルです。頼まれても登録しないでください。',
                  actionLabel: '事例を見る',
                  url: youngFraudWarningUrl,
                  severity: DebtSafetySeverity.warning,
                ),
                DebtEducationNotice(
                  id: 'credit_card_cashing',
                  title: 'クレジットカード現金化に注意',
                  body: 'ショッピング枠の現金化や後払い現金化は、手数料負担と規約違反のリスクが高い取引です。',
                  actionLabel: '注意喚起',
                  url: badContractorWarningUrl,
                  severity: DebtSafetySeverity.warning,
                ),
                DebtEducationNotice(
                  id: 'registered_lender_check',
                  title: '借入先の登録確認',
                  body: '業者名、電話番号、登録番号が確認できない場合は、連絡や申込みを止めて登録検索で確認してください。',
                  actionLabel: '検索する',
                  url: registeredLenderSearchUrl,
                  severity: DebtSafetySeverity.info,
                ),
              ]
            : const <DebtEducationNotice>[];

    return DebtSafetySnapshot(
      totalDebt: totalDebt,
      debtCount: activeDebts.length,
      annualRateRisks: annualRateRisks,
      guidanceCards: guidanceCards,
      educationNotices: educationNotices,
    );
  }

  Future<DebtLockdownSnapshot> loadSnapshot({
    required double remainingDebt,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final now = _now();
    final history = _readHistory(store.getString(_historyKey));
    final isReleased = remainingDebt <= 0;
    final storedEnabled = store.getBool(_enabledKey) ?? false;

    if (isReleased && storedEnabled) {
      await store.setBool(_enabledKey, false);
    }

    final todayRecord = history[_dateKey(now)] ?? _emptyDayRecord();

    return DebtLockdownSnapshot(
      remainingDebt: remainingDebt,
      isEnabled: !isReleased && storedEnabled,
      isReleased: isReleased,
      startedAt: _parseDate(store.getString(_startedAtKey)),
      rules: builtinRules,
      completedRuleIds: _readCompletedRuleIds(todayRecord),
      todayViolations: _sortViolations(_readViolations(todayRecord)),
      currentCompliantStreakDays: _calculateCompliantStreak(history, now: now),
      recentViolations: _recentViolations(history),
    );
  }

  Future<DebtLockdownSnapshot> setEnabled(
    bool enabled, {
    required double remainingDebt,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    if (enabled && remainingDebt <= 0) {
      await store.setBool(_enabledKey, false);
      return loadSnapshot(remainingDebt: remainingDebt, prefs: store);
    }

    await store.setBool(_enabledKey, enabled);
    if (enabled && (store.getString(_startedAtKey) ?? '').isEmpty) {
      await store.setString(_startedAtKey, _now().toUtc().toIso8601String());
    }
    return loadSnapshot(remainingDebt: remainingDebt, prefs: store);
  }

  Future<DebtLockdownSnapshot> toggleRule(
    String ruleId,
    bool completed, {
    required double remainingDebt,
    SharedPreferences? prefs,
  }) async {
    if (!builtinRules.any((rule) => rule.id == ruleId)) {
      throw ArgumentError.value(ruleId, 'ruleId', 'unknown rule');
    }

    final store = prefs ?? await SharedPreferences.getInstance();
    final history = _readHistory(store.getString(_historyKey));
    final todayKey = _dateKey(_now());
    final todayRecord = Map<String, dynamic>.from(
      history[todayKey] ?? _emptyDayRecord(),
    );
    final completedRuleIds = _readCompletedRuleIds(todayRecord);

    if (completed) {
      completedRuleIds.add(ruleId);
    } else {
      completedRuleIds.remove(ruleId);
    }

    todayRecord['completed_rule_ids'] = completedRuleIds.toList()..sort();
    todayRecord['updated_at'] = _now().toUtc().toIso8601String();
    history[todayKey] = todayRecord;

    await _saveHistory(store, history);
    return loadSnapshot(remainingDebt: remainingDebt, prefs: store);
  }

  Future<DebtLockdownSnapshot> recordViolation({
    required String category,
    required String note,
    required double amount,
    required double remainingDebt,
    SharedPreferences? prefs,
  }) async {
    final trimmedNote = note.trim();
    if (trimmedNote.isEmpty) {
      throw ArgumentError('note must not be empty');
    }

    final normalizedCategory =
        WasteTrackingService.normalizeCategory(category) ??
            (category.trim().isEmpty ? otherCategory : category.trim());
    final store = prefs ?? await SharedPreferences.getInstance();
    final now = _now();
    final history = _readHistory(store.getString(_historyKey));
    final todayKey = _dateKey(now);
    final todayRecord = Map<String, dynamic>.from(
      history[todayKey] ?? _emptyDayRecord(),
    );
    final violations = _readViolations(todayRecord);

    violations.add(
      DebtLockdownViolation(
        id: 'debt_lockdown_${now.microsecondsSinceEpoch}_${violations.length}',
        category: normalizedCategory,
        note: trimmedNote,
        amount: amount,
        createdAt: now,
      ),
    );

    todayRecord['violations'] =
        violations.map((entry) => entry.toJson()).toList();
    todayRecord['updated_at'] = now.toUtc().toIso8601String();
    history[todayKey] = todayRecord;

    await _saveHistory(store, history);
    return loadSnapshot(remainingDebt: remainingDebt, prefs: store);
  }

  Future<void> _saveHistory(
    SharedPreferences store,
    Map<String, Map<String, dynamic>> history,
  ) async {
    await store.setString(_historyKey, jsonEncode(history));
  }

  Map<String, Map<String, dynamic>> _readHistory(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, Map<String, dynamic>>{};
      }

      final history = <String, Map<String, dynamic>>{};
      decoded.forEach((key, value) {
        if (key is! String || value is! Map) {
          return;
        }
        history[key] = Map<String, dynamic>.from(value);
      });
      return history;
    } catch (_) {
      return <String, Map<String, dynamic>>{};
    }
  }

  Map<String, dynamic> _emptyDayRecord() {
    return <String, dynamic>{
      'completed_rule_ids': <String>[],
      'violations': <Map<String, dynamic>>[],
    };
  }

  Set<String> _readCompletedRuleIds(Map<String, dynamic> record) {
    return ((record['completed_rule_ids'] as List<dynamic>?) ?? const [])
        .map((entry) => entry.toString())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }

  List<DebtLockdownViolation> _readViolations(Map<String, dynamic> record) {
    return ((record['violations'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map(
          (entry) =>
              DebtLockdownViolation.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList();
  }

  List<DebtLockdownViolation> _sortViolations(
    List<DebtLockdownViolation> values,
  ) {
    final sorted = List<DebtLockdownViolation>.from(values);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  List<DebtLockdownViolation> _recentViolations(
    Map<String, Map<String, dynamic>> history,
  ) {
    final values =
        history.values.expand(_readViolations).toList(growable: false);
    final sorted = _sortViolations(values);
    if (sorted.length <= 5) {
      return sorted;
    }
    return sorted.take(5).toList(growable: false);
  }

  int _calculateCompliantStreak(
    Map<String, Map<String, dynamic>> history, {
    required DateTime now,
  }) {
    var streak = 0;
    var current = DateTime(now.year, now.month, now.day);

    while (true) {
      final record = history[_dateKey(current)];
      if (record == null) {
        break;
      }

      final hasViolations = _readViolations(record).isNotEmpty;
      final completedRuleIds = _readCompletedRuleIds(record);
      final isCompliant =
          !hasViolations && completedRuleIds.length >= builtinRules.length;
      if (!isCompliant) {
        break;
      }

      streak += 1;
      current = current.subtract(const Duration(days: 1));
    }

    return streak;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _dateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
