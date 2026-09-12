class SalarySpendingEntry {
  const SalarySpendingEntry({
    required this.date,
    required this.amount,
    required this.description,
    required this.sourceLabel,
  });

  final DateTime date;
  final double amount;
  final String description;
  final String sourceLabel;
}

class SalaryIncomeEntry {
  const SalaryIncomeEntry({
    required this.date,
    required this.amount,
    required this.description,
  });

  final DateTime date;
  final double amount;
  final String description;
}

class SalarySpendingCategorySlice {
  const SalarySpendingCategorySlice({
    required this.category,
    required this.amount,
    required this.entryCount,
    required this.ratio,
    required this.sampleDescriptions,
  });

  final String category;
  final double amount;
  final int entryCount;
  final double ratio;
  final List<String> sampleDescriptions;
}

class SalarySpendingBreakdown {
  const SalarySpendingBreakdown({
    required this.salaryDay,
    required this.periodStart,
    required this.periodEndExclusive,
    required this.totalExpense,
    required this.salaryIncomeTotal,
    required this.expenseEntryCount,
    required this.sections,
  });

  final int salaryDay;
  final DateTime periodStart;
  final DateTime periodEndExclusive;
  final double totalExpense;
  final double salaryIncomeTotal;
  final int expenseEntryCount;
  final List<SalarySpendingCategorySlice> sections;

  DateTime get periodEndInclusive =>
      periodEndExclusive.subtract(const Duration(days: 1));

  double? get remainingAfterExpense =>
      salaryIncomeTotal > 0 ? salaryIncomeTotal - totalExpense : null;

  SalarySpendingCategorySlice? get topSection =>
      sections.isEmpty ? null : sections.first;
}

class SalarySpendingBreakdownService {
  const SalarySpendingBreakdownService();

  static const int defaultSalaryDay = 25;

  /// [categorize] が返しうるカテゴリラベル一覧(予算設定 UI の選択肢に使う)。
  /// `_categoryRules` のラベル + フォールバックの「その他」。
  static const List<String> categoryLabels = <String>[
    '住居',
    '食費',
    '通信',
    '光熱費',
    '交通',
    'サブスク',
    '投資・貯蓄',
    '医療',
    '日用品',
    '娯楽・浪費',
    '借入返済',
    '手数料・税金',
    '使途不明金',
    'その他',
  ];

  SalarySpendingBreakdown build({
    required DateTime referenceDate,
    Iterable<SalarySpendingEntry> expenses = const <SalarySpendingEntry>[],
    Iterable<SalaryIncomeEntry> incomes = const <SalaryIncomeEntry>[],
    int salaryDay = defaultSalaryDay,
  }) {
    final normalizedSalaryDay = salaryDay.clamp(1, 28).toInt();
    final periodStart = salaryPeriodStartFor(
      referenceDate: referenceDate,
      salaryDay: normalizedSalaryDay,
    );
    final periodEndExclusive = _safeDate(
      periodStart.year,
      periodStart.month + 1,
      normalizedSalaryDay,
    );

    final totalsByCategory = <String, double>{};
    final countsByCategory = <String, int>{};
    final samplesByCategory = <String, List<String>>{};
    var totalExpense = 0.0;
    var expenseEntryCount = 0;

    for (final entry in expenses) {
      if (!_isInRange(entry.date, periodStart, periodEndExclusive)) {
        continue;
      }
      final amount = entry.amount.abs();
      if (amount <= 0) {
        continue;
      }
      final category = categorize(entry.description);
      totalsByCategory[category] = (totalsByCategory[category] ?? 0) + amount;
      countsByCategory[category] = (countsByCategory[category] ?? 0) + 1;
      samplesByCategory.putIfAbsent(category, () => <String>[]);
      if (samplesByCategory[category]!.length < 2) {
        final sample = entry.description.trim().isEmpty
            ? entry.sourceLabel
            : entry.description.trim();
        samplesByCategory[category]!.add(sample);
      }
      totalExpense += amount;
      expenseEntryCount += 1;
    }

    final incomeEntries = incomes.toList(growable: false);
    var salaryIncomeTotal = 0.0;
    for (final entry in incomeEntries) {
      if (!_isInRange(entry.date, periodStart, periodEndExclusive)) {
        continue;
      }
      if (_looksLikeSalary(entry.description) || incomeEntries.length == 1) {
        salaryIncomeTotal += entry.amount.abs();
      }
    }

    final sections = totalsByCategory.entries
        .map(
          (entry) => SalarySpendingCategorySlice(
            category: entry.key,
            amount: entry.value,
            entryCount: countsByCategory[entry.key] ?? 0,
            ratio: totalExpense > 0 ? entry.value / totalExpense : 0,
            sampleDescriptions: List<String>.unmodifiable(
              samplesByCategory[entry.key] ?? const <String>[],
            ),
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return SalarySpendingBreakdown(
      salaryDay: normalizedSalaryDay,
      periodStart: periodStart,
      periodEndExclusive: periodEndExclusive,
      totalExpense: totalExpense,
      salaryIncomeTotal: salaryIncomeTotal,
      expenseEntryCount: expenseEntryCount,
      sections: List<SalarySpendingCategorySlice>.unmodifiable(sections),
    );
  }

  DateTime salaryPeriodStartFor({
    required DateTime referenceDate,
    int salaryDay = defaultSalaryDay,
  }) {
    final normalizedSalaryDay = salaryDay.clamp(1, 28).toInt();
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final currentMonthSalaryDay = _safeDate(
      referenceDate.year,
      referenceDate.month,
      normalizedSalaryDay,
    );
    if (today.isBefore(currentMonthSalaryDay)) {
      return _safeDate(
        referenceDate.year,
        referenceDate.month - 1,
        normalizedSalaryDay,
      );
    }
    return currentMonthSalaryDay;
  }

  String categorize(String description) {
    final text = description.toLowerCase();
    for (final rule in _categoryRules) {
      for (final keyword in rule.keywords) {
        if (text.contains(keyword.toLowerCase())) {
          return rule.label;
        }
      }
    }
    return 'その他';
  }

  static bool _isInRange(DateTime date, DateTime start, DateTime endExclusive) {
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(start) && normalized.isBefore(endExclusive);
  }

  static DateTime _safeDate(int year, int month, int day) {
    final firstOfMonth = DateTime(year, month, 1);
    final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
    final safeDay = day.clamp(1, lastDay).toInt();
    return DateTime(firstOfMonth.year, firstOfMonth.month, safeDay);
  }

  static bool _looksLikeSalary(String description) {
    final text = description.toLowerCase();
    return text.contains('給料') ||
        text.contains('給与') ||
        text.contains('給与明細') ||
        text.contains('payslip') ||
        text.contains('pay slip') ||
        text.contains('salary') ||
        text.contains('payroll') ||
        text.contains('賞与') ||
        text.contains('収入');
  }
}

class _SalarySpendingCategoryRule {
  const _SalarySpendingCategoryRule(this.label, this.keywords);

  final String label;
  final List<String> keywords;
}

const List<_SalarySpendingCategoryRule> _categoryRules =
    <_SalarySpendingCategoryRule>[
  _SalarySpendingCategoryRule('使途不明金', <String>[
    '使途不明金',
    '使途不明',
    '用途不明',
  ]),
  _SalarySpendingCategoryRule('住居', <String>[
    '家賃',
    '住宅',
    '管理費',
    '大東建託',
    'エイブル',
    'ハウスメイト',
    '賃貸',
    'rent',
    'housing',
  ]),
  _SalarySpendingCategoryRule('借入返済', <String>[
    '返済',
    'ローン',
    'loan',
    'リボ',
    '借入',
    'モビット',
    'mobit',
    'アコム',
    'acom',
    'プロミス',
    'promise',
    'smbc',
    'エスエムビーシー',
    'peエスエムビーシー',
    'cl口座',
    'じぶんローン',
    'レイク',
    'アイフル',
    'ペイペイカード',
    'paypayカード',
    '楽天カード',
    'エポス',
    '三井住友',
    'セゾン',
    'カードローン',
  ]),
  _SalarySpendingCategoryRule('食費', <String>[
    '食費',
    'スーパー',
    'コンビニ',
    'セブン',
    'ローソン',
    'ファミマ',
    'restaurant',
    'lunch',
    'dinner',
    'cafe',
    'coffee',
    'grocery',
    'food',
    'starbucks',
  ]),
  _SalarySpendingCategoryRule('通信', <String>[
    '通信',
    '携帯',
    'スマホ',
    'ahamo',
    'povo',
    'linemo',
    'uq',
    'au',
    'rakuten',
    '楽天モバイル',
    'ymobile',
    'ワイモバイル',
    'mobile',
    'docomo',
    'softbank',
    'internet',
    'wifi',
    'sim',
  ]),
  _SalarySpendingCategoryRule('光熱費', <String>[
    '電気',
    'ガス',
    '水道',
    'utility',
    'utilities',
  ]),
  _SalarySpendingCategoryRule('交通', <String>[
    '交通',
    '電車',
    'バス',
    'タクシー',
    'suica',
    'pasmo',
    'taxi',
    'uber',
    'parking',
  ]),
  _SalarySpendingCategoryRule('サブスク', <String>[
    'サブスク',
    'subscription',
    'netflix',
    'spotify',
    'youtube',
    'amazon prime',
    'apple',
    'google',
    'openai',
    'claude',
  ]),
  _SalarySpendingCategoryRule('投資・貯蓄', <String>[
    '投資',
    '証券',
    'nisa',
    '積立',
    '株',
    'crypto',
    'coincheck',
    'bitflyer',
    'reit',
  ]),
  _SalarySpendingCategoryRule('医療', <String>[
    '医療',
    '病院',
    '薬',
    '薬局',
    'pharmacy',
    'clinic',
  ]),
  _SalarySpendingCategoryRule('日用品', <String>[
    '日用品',
    'ドラッグ',
    'amazon',
    '楽天',
    'shopping',
    'store',
  ]),
  _SalarySpendingCategoryRule('娯楽・浪費', <String>[
    '飲み',
    '酒',
    'bar',
    'game',
    'steam',
    'パチンコ',
    'ギャンブル',
    'casino',
  ]),
  _SalarySpendingCategoryRule('手数料・税金', <String>['手数料', '税', 'fee', 'tax']),
];
