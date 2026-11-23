import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'salary_spending_breakdown_service.dart';

/// 支出を価値基準の3カテゴリ＋要確認へ区分する (#1368)。
enum SpendingValueCategory {
  consumption,
  waste,
  investment,
  needsReview,
}

extension SpendingValueCategoryLabel on SpendingValueCategory {
  String get label {
    switch (this) {
      case SpendingValueCategory.consumption:
        return '消費';
      case SpendingValueCategory.waste:
        return '浪費';
      case SpendingValueCategory.investment:
        return '投資';
      case SpendingValueCategory.needsReview:
        return '要確認';
    }
  }
}

/// 分類結果の確定経路。
enum SpendingValueClassificationSource {
  userConfirmed,
  ruleSuggested,
}

/// 手動入力またはCSVインポートで「消費・浪費・投資」ラベル付き登録する支出項目 (#1368)。
class AssetSpendingValueCustomEntry {
  const AssetSpendingValueCustomEntry({
    required this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.category,
    this.sourceLabel = '手入力・CSVインポート',
  });

  final String id;
  final DateTime date;
  final double amount;
  final String description;
  final SpendingValueCategory category;
  final String sourceLabel;

  SalarySpendingEntry toSalarySpendingEntry() {
    return SalarySpendingEntry(
      date: date,
      amount: amount,
      description: description,
      sourceLabel: sourceLabel,
      categoryDescription: description,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'description': description,
      'category': category.name,
      'sourceLabel': sourceLabel,
    };
  }

  static AssetSpendingValueCustomEntry? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final date = DateTime.tryParse(json['date']?.toString() ?? '');
    final amountRaw = json['amount'];
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw?.toString() ?? '');
    final description = json['description']?.toString().trim() ?? '';
    final category = AssetSpendingValueClassificationService.parseCategory(
          json['category']?.toString(),
        ) ??
        SpendingValueCategory.needsReview;
    if (id.isEmpty ||
        date == null ||
        amount == null ||
        amount <= 0 ||
        description.isEmpty) {
      return null;
    }
    final rawSource = json['sourceLabel']?.toString().trim() ?? '';
    return AssetSpendingValueCustomEntry(
      id: id,
      date: date,
      amount: amount,
      description: description,
      category: category,
      sourceLabel: rawSource.isEmpty ? '手入力・CSVインポート' : rawSource,
    );
  }
}

/// 分類済み支出1件の明細情報。
class ClassifiedSpendingEntry {
  const ClassifiedSpendingEntry({
    required this.fingerprint,
    required this.entry,
    required this.category,
    required this.rawCategory,
    required this.source,
    required this.reason,
    required this.isCandidateWaste,
    this.customEntryId,
  });

  final String fingerprint;
  final SalarySpendingEntry entry;
  final SpendingValueCategory category;
  final String rawCategory;
  final SpendingValueClassificationSource source;
  final String reason;
  final bool isCandidateWaste;
  final String? customEntryId;
}

/// カテゴリ別の実績・目安比率・差分集計。
class SpendingValueCategoryBucket {
  const SpendingValueCategoryBucket({
    required this.category,
    required this.amount,
    required this.count,
    required this.actualPercent,
    required this.idealPercent,
    required this.deltaPercent,
    required this.deltaAmount,
  });

  final SpendingValueCategory category;
  final double amount;
  final int count;
  final double actualPercent;
  final double idealPercent;
  final double deltaPercent;
  final double deltaAmount;
}

/// 消費・浪費・投資ダッシュボード用の決定論的レポート。
class SpendingValueRatioReport {
  const SpendingValueRatioReport({
    required this.entries,
    required this.consumption,
    required this.waste,
    required this.investment,
    required this.classifiedTotal,
    required this.needsReviewTotal,
    required this.needsReviewCount,
    required this.idealConsumptionPercent,
    required this.idealWastePercent,
    required this.idealInvestmentPercent,
    required this.adviceList,
  });

  final List<ClassifiedSpendingEntry> entries;
  final SpendingValueCategoryBucket consumption;
  final SpendingValueCategoryBucket waste;
  final SpendingValueCategoryBucket investment;
  final double classifiedTotal;
  final double needsReviewTotal;
  final int needsReviewCount;
  final double idealConsumptionPercent;
  final double idealWastePercent;
  final double idealInvestmentPercent;
  final List<String> adviceList;

  double get overallTotal => classifiedTotal + needsReviewTotal;
}

/// 「消費・浪費・投資」の自動分類・CSVインポート・理想割合比較を行うサービス (#1368)。
class AssetSpendingValueClassificationService {
  const AssetSpendingValueClassificationService._();

  static const double defaultIdealConsumptionPercent = 70;
  static const double defaultIdealWastePercent = 5;
  static const double defaultIdealInvestmentPercent = 25;

  static const List<String> _explicitWasteKeywords = <String>[
    'ギャンブル',
    'パチンコ',
    'スロット',
    '競馬',
    '競艇',
    '競輪',
    'カジノ',
    '宝くじ',
    'atm手数料',
    '振込手数料',
    '遅延損害金',
    '延滞金',
    'タバコ',
    'たばこ',
    '衝動買い',
    '酒',
  ];

  static const List<String> _unknownWithdrawalKeywords = <String>[
    '使途不明',
    '用途不明',
    '残高差分',
    '自動記録',
    'atm引出',
    '現金引出',
    '現金出金',
    '引出し',
    '引出',
  ];

  static const List<String> _investmentKeywords = <String>[
    'nisa',
    'つみたて',
    '投資信託',
    '投資',
    '株式',
    '積立',
    '貯蓄',
    '証券',
    '書籍',
    '技術書',
    '参考書',
    '書店',
    '学習',
    '講座',
    '資格',
    'セミナー',
  ];

  static const List<String> _consumptionKeywords = <String>[
    '家賃',
    '住居',
    '管理費',
    '食費',
    'スーパー',
    '食品',
    'コンビニ',
    '光熱費',
    '電気',
    'ガス',
    '水道',
    '通信',
    '携帯',
    'スマホ',
    '医療',
    '病院',
    '薬局',
    '交通',
    '電車',
    '通勤',
    '日用品',
    '保険',
  ];

  static SpendingValueCategory? parseCategory(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'consumption':
      case '消費':
        return SpendingValueCategory.consumption;
      case 'waste':
      case '浪費':
        return SpendingValueCategory.waste;
      case 'investment':
      case '投資':
        return SpendingValueCategory.investment;
      case 'needsreview':
      case 'needs_review':
      case '要確認':
        return SpendingValueCategory.needsReview;
      default:
        return null;
    }
  }

  /// 明細ごとに安定した一意キーを生成する。
  static String fingerprintFor(SalarySpendingEntry entry) {
    final normalizedDate = '${entry.date.year.toString().padLeft(4, '0')}-'
        '${entry.date.month.toString().padLeft(2, '0')}-'
        '${entry.date.day.toString().padLeft(2, '0')}';
    final roundedAmount = entry.amount.abs().round();
    final desc = (entry.categoryDescription ?? entry.description)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    final source = entry.sourceLabel.trim().toLowerCase();
    return '$normalizedDate|$roundedAmount|$desc|$source';
  }

  /// 支出1件を分類する。使途不明の引出しは推測で浪費確定せず「要確認」に留める。
  static ClassifiedSpendingEntry classifyEntry(
    SalarySpendingEntry entry, {
    Map<String, SpendingValueCategory> overrides =
        const <String, SpendingValueCategory>{},
    String? customEntryId,
    SpendingValueCategory? explicitCategory,
  }) {
    final fingerprint = fingerprintFor(entry);
    final rawText = (entry.categoryDescription ?? entry.description).trim();
    final normalized = rawText.toLowerCase();
    final rawCategory = SalarySpendingBreakdownService.categorize(rawText);

    final userOverride = overrides[fingerprint] ?? explicitCategory;
    if (userOverride != null) {
      return ClassifiedSpendingEntry(
        fingerprint: fingerprint,
        entry: entry,
        category: userOverride,
        rawCategory: rawCategory,
        source: SpendingValueClassificationSource.userConfirmed,
        reason: 'ユーザー指定（${userOverride.label}）',
        isCandidateWaste: userOverride == SpendingValueCategory.waste ||
            _containsAny(normalized, _unknownWithdrawalKeywords),
        customEntryId: customEntryId,
      );
    }

    // 明確な浪費（ギャンブル・ATM/振込手数料・延滞関連・嗜好）を先に評価。
    for (final keyword in _explicitWasteKeywords) {
      if (normalized.contains(keyword)) {
        return ClassifiedSpendingEntry(
          fingerprint: fingerprint,
          entry: entry,
          category: SpendingValueCategory.waste,
          rawCategory: rawCategory,
          source: SpendingValueClassificationSource.ruleSuggested,
          reason: 'ルール判定（手数料・嗜好・娯楽キーワード: $keyword）',
          isCandidateWaste: true,
          customEntryId: customEntryId,
        );
      }
    }

    // 使途不明な引出し・残高差分は推測で「浪費」確定せず「要確認」として扱う。
    if (_containsAny(normalized, _unknownWithdrawalKeywords) ||
        rawCategory == '使途不明金') {
      return ClassifiedSpendingEntry(
        fingerprint: fingerprint,
        entry: entry,
        category: SpendingValueCategory.needsReview,
        rawCategory: rawCategory,
        source: SpendingValueClassificationSource.ruleSuggested,
        reason: '使途不明の引出し・残高差分は推測で浪費確定せず本人確認待ちとして表示',
        isCandidateWaste: true,
        customEntryId: customEntryId,
      );
    }

    for (final keyword in _investmentKeywords) {
      if (normalized.contains(keyword)) {
        return ClassifiedSpendingEntry(
          fingerprint: fingerprint,
          entry: entry,
          category: SpendingValueCategory.investment,
          rawCategory: rawCategory,
          source: SpendingValueClassificationSource.ruleSuggested,
          reason: 'ルール判定（資産形成・学習キーワード: $keyword）',
          isCandidateWaste: false,
          customEntryId: customEntryId,
        );
      }
    }

    for (final keyword in _consumptionKeywords) {
      if (normalized.contains(keyword)) {
        return ClassifiedSpendingEntry(
          fingerprint: fingerprint,
          entry: entry,
          category: SpendingValueCategory.consumption,
          rawCategory: rawCategory,
          source: SpendingValueClassificationSource.ruleSuggested,
          reason: 'ルール判定（生活必需キーワード: $keyword）',
          isCandidateWaste: false,
          customEntryId: customEntryId,
        );
      }
    }

    switch (rawCategory) {
      case '投資・貯蓄':
      case '書籍':
        return ClassifiedSpendingEntry(
          fingerprint: fingerprint,
          entry: entry,
          category: SpendingValueCategory.investment,
          rawCategory: rawCategory,
          source: SpendingValueClassificationSource.ruleSuggested,
          reason: '用途カテゴリ（$rawCategory）から投資候補に分類',
          isCandidateWaste: false,
          customEntryId: customEntryId,
        );
      case '娯楽・浪費':
        return ClassifiedSpendingEntry(
          fingerprint: fingerprint,
          entry: entry,
          category: SpendingValueCategory.waste,
          rawCategory: rawCategory,
          source: SpendingValueClassificationSource.ruleSuggested,
          reason: '用途カテゴリ（$rawCategory）から浪費候補に分類',
          isCandidateWaste: true,
          customEntryId: customEntryId,
        );
      case '住居':
      case '食費':
      case '通信':
      case '光熱費':
      case '交通':
      case '医療':
      case '日用品':
      case '借入返済':
      case 'サブスク':
        return ClassifiedSpendingEntry(
          fingerprint: fingerprint,
          entry: entry,
          category: SpendingValueCategory.consumption,
          rawCategory: rawCategory,
          source: SpendingValueClassificationSource.ruleSuggested,
          reason: '用途カテゴリ（$rawCategory）から消費候補に分類',
          isCandidateWaste: false,
          customEntryId: customEntryId,
        );
      default:
        return ClassifiedSpendingEntry(
          fingerprint: fingerprint,
          entry: entry,
          category: SpendingValueCategory.needsReview,
          rawCategory: rawCategory,
          source: SpendingValueClassificationSource.ruleSuggested,
          reason: '用途カテゴリ（$rawCategory）のため確認後に分類',
          isCandidateWaste: false,
          customEntryId: customEntryId,
        );
    }
  }

  /// `yyyy-MM-dd,金額,摘要[,消費|浪費|投資|要確認]` 形式のCSVテキストをパースする。
  static List<AssetSpendingValueCustomEntry> parseTaggedImportCsv(
    String rawCsv, {
    int idSeed = 1,
  }) {
    final results = <AssetSpendingValueCustomEntry>[];
    final lines = LineSplitter.split(rawCsv);
    var seq = idSeed;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final cols = line.split(',').map((part) => part.trim()).toList();
      if (cols.length < 3) {
        continue;
      }
      if (cols[0].toLowerCase() == 'date' || cols[0] == '日付') {
        continue;
      }
      final normalizedDateText = cols[0].replaceAll('/', '-');
      final date = DateTime.tryParse(normalizedDateText);
      final amountText = cols[1].replaceAll(RegExp(r'[,¥円\s]'), '');
      final amount = double.tryParse(amountText);
      final description = cols[2];
      if (date == null ||
          amount == null ||
          amount <= 0 ||
          description.isEmpty) {
        continue;
      }
      final rawCategory = cols.length >= 4 ? cols[3] : null;
      final parsedCategory = parseCategory(rawCategory);
      final salaryEntry = SalarySpendingEntry(
        date: date,
        amount: amount,
        description: description,
        sourceLabel: 'CSVインポート',
        categoryDescription: description,
      );
      final category = parsedCategory ?? classifyEntry(salaryEntry).category;
      results.add(
        AssetSpendingValueCustomEntry(
          id: 'csv_${date.toIso8601String().substring(0, 10)}_$seq',
          date: date,
          amount: amount,
          description: description,
          category: category,
          sourceLabel: 'CSVインポート',
        ),
      );
      seq++;
    }
    return List<AssetSpendingValueCustomEntry>.unmodifiable(results);
  }

  /// 支出一覧と手入力/CSV取込一覧から「消費・浪費・投資」割合比較レポートを生成する。
  static SpendingValueRatioReport buildReport({
    required Iterable<SalarySpendingEntry> entries,
    Iterable<AssetSpendingValueCustomEntry> customEntries =
        const <AssetSpendingValueCustomEntry>[],
    Map<String, SpendingValueCategory> overrides =
        const <String, SpendingValueCategory>{},
    double idealConsumptionPercent = defaultIdealConsumptionPercent,
    double idealWastePercent = defaultIdealWastePercent,
    double idealInvestmentPercent = defaultIdealInvestmentPercent,
  }) {
    final classified = <ClassifiedSpendingEntry>[];
    for (final entry in entries) {
      if (entry.amount.abs() <= 0) {
        continue;
      }
      classified.add(classifyEntry(entry, overrides: overrides));
    }
    for (final custom in customEntries) {
      if (custom.amount.abs() <= 0) {
        continue;
      }
      classified.add(
        classifyEntry(
          custom.toSalarySpendingEntry(),
          overrides: overrides,
          customEntryId: custom.id,
          explicitCategory: custom.category,
        ),
      );
    }

    classified.sort((a, b) {
      final dateCmp = b.entry.date.compareTo(a.entry.date);
      if (dateCmp != 0) {
        return dateCmp;
      }
      return b.entry.amount.abs().compareTo(a.entry.amount.abs());
    });

    var consumptionAmount = 0.0;
    var consumptionCount = 0;
    var wasteAmount = 0.0;
    var wasteCount = 0;
    var investmentAmount = 0.0;
    var investmentCount = 0;
    var needsReviewAmount = 0.0;
    var needsReviewCount = 0;

    for (final item in classified) {
      final value = item.entry.amount.abs();
      switch (item.category) {
        case SpendingValueCategory.consumption:
          consumptionAmount += value;
          consumptionCount++;
        case SpendingValueCategory.waste:
          wasteAmount += value;
          wasteCount++;
        case SpendingValueCategory.investment:
          investmentAmount += value;
          investmentCount++;
        case SpendingValueCategory.needsReview:
          needsReviewAmount += value;
          needsReviewCount++;
      }
    }

    final classifiedTotal = consumptionAmount + wasteAmount + investmentAmount;

    SpendingValueCategoryBucket buildBucket(
      SpendingValueCategory category,
      double amount,
      int count,
      double idealPercent,
    ) {
      final actualPercent =
          classifiedTotal > 0 ? (amount / classifiedTotal) * 100.0 : 0.0;
      final deltaPercent =
          classifiedTotal > 0 ? actualPercent - idealPercent : 0.0;
      final idealAmount = classifiedTotal * (idealPercent / 100.0);
      final deltaAmount = classifiedTotal > 0 ? amount - idealAmount : 0.0;
      return SpendingValueCategoryBucket(
        category: category,
        amount: amount,
        count: count,
        actualPercent: actualPercent,
        idealPercent: idealPercent,
        deltaPercent: deltaPercent,
        deltaAmount: deltaAmount,
      );
    }

    final consumptionBucket = buildBucket(
      SpendingValueCategory.consumption,
      consumptionAmount,
      consumptionCount,
      idealConsumptionPercent,
    );
    final wasteBucket = buildBucket(
      SpendingValueCategory.waste,
      wasteAmount,
      wasteCount,
      idealWastePercent,
    );
    final investmentBucket = buildBucket(
      SpendingValueCategory.investment,
      investmentAmount,
      investmentCount,
      idealInvestmentPercent,
    );

    final advice = <String>[];
    if (classifiedTotal <= 0 && needsReviewCount == 0) {
      advice.add(
        '今月の対象支出がまだありません。「支出ラベル入力・CSV取込」から「消費・浪費・投資」を指定して記録できます。',
      );
    } else {
      if (needsReviewCount > 0) {
        advice.add(
          '使途確認待ちの項目が $needsReviewCount件（合計 ${_formatIntYen(needsReviewAmount)}円）あります。'
          '現金引出しや振替の有無を確認のうえ各行のボタンで確定してください。',
        );
      }
      if (classifiedTotal > 0) {
        if (wasteBucket.deltaPercent > 2.0) {
          advice.add(
            '浪費が目安（${idealWastePercent.toStringAsFixed(0)}%）を +${wasteBucket.deltaPercent.toStringAsFixed(1)}pt'
            '（約 ${_formatIntYen(wasteBucket.deltaAmount.abs())}円）上回っています。'
            'ATM・振込手数料や嗜好品の上限ルールを先に確認するのが有効です。',
          );
        }
        if (investmentBucket.deltaPercent < -2.0) {
          advice.add(
            '投資・自己投資が目安（${idealInvestmentPercent.toStringAsFixed(0)}%）より '
            '${investmentBucket.deltaPercent.abs().toStringAsFixed(1)}pt 低め（約 ${_formatIntYen(investmentBucket.deltaAmount.abs())}円不足）です。'
            '浪費や固定費の圧縮分を優先配分する余地があります。',
          );
        }
        if (consumptionBucket.deltaPercent > 5.0) {
          advice.add(
            '消費が目安（${idealConsumptionPercent.toStringAsFixed(0)}%）より '
            '+${consumptionBucket.deltaPercent.toStringAsFixed(1)}pt 高めです。'
            '通信費・サブスクなど固定費の見直しが効果的です。',
          );
        }
        if (wasteBucket.deltaPercent <= 2.0 &&
            investmentBucket.deltaPercent >= -2.0 &&
            consumptionBucket.deltaPercent <= 5.0) {
          advice.add(
            '3分類の比率は設定目安（'
            '${idealConsumptionPercent.toStringAsFixed(0)}:'
            '${idealWastePercent.toStringAsFixed(0)}:'
            '${idealInvestmentPercent.toStringAsFixed(0)}）におおむね沿っています。',
          );
        }
      }
    }

    return SpendingValueRatioReport(
      entries: List<ClassifiedSpendingEntry>.unmodifiable(classified),
      consumption: consumptionBucket,
      waste: wasteBucket,
      investment: investmentBucket,
      classifiedTotal: classifiedTotal,
      needsReviewTotal: needsReviewAmount,
      needsReviewCount: needsReviewCount,
      idealConsumptionPercent: idealConsumptionPercent,
      idealWastePercent: idealWastePercent,
      idealInvestmentPercent: idealInvestmentPercent,
      adviceList: List<String>.unmodifiable(advice),
    );
  }

  static bool _containsAny(String normalizedText, List<String> keywords) {
    for (final keyword in keywords) {
      if (normalizedText.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  static String _formatIntYen(double amount) {
    final digits = amount.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remain = digits.length - i;
      buffer.write(digits[i]);
      if (remain > 1 && remain % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}

/// ユーザーによる分類上書きと手入力・CSV取込支出を端末永続化するストア (#1368)。
class AssetSpendingValueOverrideStore {
  const AssetSpendingValueOverrideStore._();

  static const String _overridesPrefsKey = 'asset_spending_value_overrides_v1';
  static const String _customEntriesPrefsKey =
      'asset_spending_value_custom_entries_v1';

  static Future<Map<String, SpendingValueCategory>> loadOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_overridesPrefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String, SpendingValueCategory>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const <String, SpendingValueCategory>{};
      }
      final result = <String, SpendingValueCategory>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final cat = AssetSpendingValueClassificationService.parseCategory(
          entry.value?.toString(),
        );
        if (key.isNotEmpty && cat != null) {
          result[key] = cat;
        }
      }
      return Map<String, SpendingValueCategory>.unmodifiable(result);
    } catch (_) {
      return const <String, SpendingValueCategory>{};
    }
  }

  static Future<void> saveOverrides(
    Map<String, SpendingValueCategory> overrides,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = <String, String>{
      for (final entry in overrides.entries) entry.key: entry.value.name,
    };
    await prefs.setString(_overridesPrefsKey, jsonEncode(serialized));
  }

  static Future<List<AssetSpendingValueCustomEntry>> loadCustomEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customEntriesPrefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <AssetSpendingValueCustomEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <AssetSpendingValueCustomEntry>[];
      }
      final entries = <AssetSpendingValueCustomEntry>[];
      for (final rawItem in decoded) {
        if (rawItem is! Map) {
          continue;
        }
        final item = AssetSpendingValueCustomEntry.fromJson(
          Map<String, dynamic>.from(rawItem),
        );
        if (item != null) {
          entries.add(item);
        }
      }
      return List<AssetSpendingValueCustomEntry>.unmodifiable(entries);
    } catch (_) {
      return const <AssetSpendingValueCustomEntry>[];
    }
  }

  static Future<void> saveCustomEntries(
    List<AssetSpendingValueCustomEntry> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_customEntriesPrefsKey, encoded);
  }
}
