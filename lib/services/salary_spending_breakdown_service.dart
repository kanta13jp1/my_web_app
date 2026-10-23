import '../models/receipt_category_allocation.dart';
import 'waste_tracking_service.dart';
import '../models/asset_income_source_evidence.dart';

class SalarySpendingEntry {
  const SalarySpendingEntry({
    required this.date,
    required this.amount,
    required this.description,
    required this.sourceLabel,
    this.categoryDescription,
  });

  final DateTime date;
  final double amount;
  final String description;
  final String sourceLabel;

  /// 用途分類専用の本文。表示用の出所口座名は含めない。
  final String? categoryDescription;
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
  final double? salaryIncomeTotal;
  final int expenseEntryCount;
  final List<SalarySpendingCategorySlice> sections;

  DateTime get periodEndInclusive =>
      periodEndExclusive.subtract(const Duration(days: 1));

  double? get remainingAfterExpense =>
      salaryIncomeTotal == null ? null : salaryIncomeTotal! - totalExpense;

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
    '書籍',
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
    IncomeEvidenceProjection? incomeEvidence,
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
      final smoking = amount.isFinite && amount == amount.truncateToDouble()
          ? WasteTrackingService.reconciledWasteAmount(
              entry.description,
              amount.toInt(),
            )
          : amount;
      final reconciled = smoking > 0 && smoking < amount;
      final receipt =
          ReceiptCategoryAllocation.parse(entry.description, amount);
      final allocations = receipt != null
          ? <String, double>{
              if (receipt.containsKey('食品')) '食費': receipt['食品']!,
              '娯楽・浪費': (receipt['飲酒'] ?? 0) + (receipt['喫煙'] ?? 0),
            }
          : reconciled
              ? <String, double>{
                  '食費': amount - smoking,
                  '娯楽・浪費': smoking.toDouble(),
                }
              : <String, double>{
                  categorize(entry.categoryDescription ?? entry.description):
                      amount,
                };
      for (final allocation in allocations.entries) {
        final category = allocation.key;
        totalsByCategory[category] =
            (totalsByCategory[category] ?? 0) + allocation.value;
        countsByCategory[category] = (countsByCategory[category] ?? 0) + 1;
        samplesByCategory.putIfAbsent(category, () => <String>[]);
        if (samplesByCategory[category]!.length < 2) {
          samplesByCategory[category]!.add(
            entry.description.trim().isEmpty
                ? entry.sourceLabel
                : entry.description.trim(),
          );
        }
      }
      totalExpense += amount;
      expenseEntryCount += 1;
    }

    // Legacy income lists contain no identity evidence and cannot certify a total.
    final salaryIncomeTotal = incomeEvidence?.combinedRecordedTotal?.toDouble();

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
    if (WasteTrackingService.extractWasteCategory(description) == '喫煙' &&
        !RegExp(r'食品|飲酒|酒購入|書籍|内訳').hasMatch(description)) {
      return '娯楽・浪費';
    }
    // 金融機関名を含む手数料を返済元本へ分類しない。
    // fee の部分一致は coffee 等も拾うため単語境界を使う。
    if (text.contains('手数料') || RegExp(r'\bfees?\b').hasMatch(text)) {
      return '手数料・税金';
    }
    if (RegExp(r'\btax(?:es)? payment\b').hasMatch(text) &&
        !RegExp(r'\btax[- ]free\b').hasMatch(text)) {
      return '手数料・税金';
    }
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
  // 商品種別を総合通販の店舗名より先に判定する。購入は読書実績にしない。
  _SalarySpendingCategoryRule('書籍', <String>[
    '書籍',
    '書店',
    '文庫',
  ]),
  // 明示された酒の品目は、コンビニ等の店舗名による食費判定より優先する。
  _SalarySpendingCategoryRule('娯楽・浪費', <String>['酒']),
  _SalarySpendingCategoryRule('食費', <String>[
    '食費',
    '食品',
    'スーパー',
    'コンビニ',
    'セブン',
    'ローソン',
    'ファミマ',
    'ファミリーマート',
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
  // 「税込」「税抜」など価格の注記だけでは税金の支払と判定しない。
  _SalarySpendingCategoryRule('手数料・税金', <String>[
    '税金',
    '納税',
    '所得税',
    '住民税',
    '固定資産税',
    '自動車税',
    '国税',
    '地方税',
    '印紙税',
  ]),
];
