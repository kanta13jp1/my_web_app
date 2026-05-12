import 'dart:convert';

class NutritionFacts {
  const NutritionFacts({
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.vegetablesG,
    required this.sodiumMg,
  });

  final int calories;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final double vegetablesG;
  final int sodiumMg;

  NutritionFacts operator +(NutritionFacts other) {
    return NutritionFacts(
      calories: calories + other.calories,
      proteinG: proteinG + other.proteinG,
      fatG: fatG + other.fatG,
      carbsG: carbsG + other.carbsG,
      vegetablesG: vegetablesG + other.vegetablesG,
      sodiumMg: sodiumMg + other.sodiumMg,
    );
  }

  NutritionFacts divideBy(num divisor) {
    if (divisor <= 0) {
      return const NutritionFacts(
        calories: 0,
        proteinG: 0,
        fatG: 0,
        carbsG: 0,
        vegetablesG: 0,
        sodiumMg: 0,
      );
    }
    return NutritionFacts(
      calories: (calories / divisor).round(),
      proteinG: proteinG / divisor,
      fatG: fatG / divisor,
      carbsG: carbsG / divisor,
      vegetablesG: vegetablesG / divisor,
      sodiumMg: (sodiumMg / divisor).round(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'calories': calories,
      'proteinG': proteinG,
      'fatG': fatG,
      'carbsG': carbsG,
      'vegetablesG': vegetablesG,
      'sodiumMg': sodiumMg,
    };
  }

  static NutritionFacts fromJson(Map<String, dynamic> json) {
    return NutritionFacts(
      calories: (json['calories'] as num?)?.round() ?? 0,
      proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
      fatG: (json['fatG'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
      vegetablesG: (json['vegetablesG'] as num?)?.toDouble() ?? 0,
      sodiumMg: (json['sodiumMg'] as num?)?.round() ?? 0,
    );
  }
}

class MealNutritionProfile {
  const MealNutritionProfile({
    required this.id,
    required this.label,
    required this.keywords,
    required this.facts,
    required this.advice,
  });

  final String id;
  final String label;
  final List<String> keywords;
  final NutritionFacts facts;
  final String advice;

  bool matches(String normalizedText) {
    return keywords.any(
      (keyword) =>
          normalizedText.contains(MealNutritionService.normalize(keyword)),
    );
  }
}

class MealNutritionEstimate {
  const MealNutritionEstimate({
    required this.rawText,
    required this.profileId,
    required this.label,
    required this.facts,
    required this.advice,
    required this.confidence,
  });

  final String rawText;
  final String profileId;
  final String label;
  final NutritionFacts facts;
  final String advice;
  final double confidence;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rawText': rawText,
      'profileId': profileId,
      'label': label,
      'facts': facts.toJson(),
      'advice': advice,
      'confidence': confidence,
    };
  }

  static MealNutritionEstimate fromJson(Map<String, dynamic> json) {
    return MealNutritionEstimate(
      rawText: json['rawText'] as String? ?? '',
      profileId: json['profileId'] as String? ?? 'unknown',
      label: json['label'] as String? ?? '推定メニュー',
      facts: NutritionFacts.fromJson(
        (json['facts'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      ),
      advice: json['advice'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MealNutritionLog {
  const MealNutritionLog({required this.loggedAt, required this.estimate});

  final DateTime loggedAt;
  final MealNutritionEstimate estimate;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'loggedAt': loggedAt.toIso8601String(),
      'estimate': estimate.toJson(),
    };
  }

  static MealNutritionLog fromJson(Map<String, dynamic> json) {
    return MealNutritionLog(
      loggedAt:
          DateTime.tryParse(json['loggedAt'] as String? ?? '') ??
          DateTime.now(),
      estimate: MealNutritionEstimate.fromJson(
        (json['estimate'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
    );
  }
}

class NutritionWeekSummary {
  const NutritionWeekSummary({
    required this.logs,
    required this.total,
    required this.dailyAverage,
    required this.warnings,
  });

  final List<MealNutritionLog> logs;
  final NutritionFacts total;
  final NutritionFacts dailyAverage;
  final List<String> warnings;

  bool get hasWarnings => warnings.isNotEmpty;
}

class MealNutritionService {
  static const NutritionFacts dailyTarget = NutritionFacts(
    calories: 2200,
    proteinG: 70,
    fatG: 65,
    carbsG: 280,
    vegetablesG: 350,
    sodiumMg: 2400,
  );

  static const List<MealNutritionProfile> catalog = <MealNutritionProfile>[
    MealNutritionProfile(
      id: 'yoshinoya_unaju',
      label: '吉野家 うな重',
      keywords: <String>['吉野家 うな重', '吉野家 うなぎ', 'うな重'],
      facts: NutritionFacts(
        calories: 750,
        proteinG: 28,
        fatG: 24,
        carbsG: 105,
        vegetablesG: 20,
        sodiumMg: 2200,
      ),
      advice: 'たんぱく質は取れています。次の食事で野菜と汁物の塩分を調整します。',
    ),
    MealNutritionProfile(
      id: 'sukiya_unagyu',
      label: 'すき家 うな牛',
      keywords: <String>['すき家 うな牛', 'うな牛', 'すき家 うなぎ'],
      facts: NutritionFacts(
        calories: 870,
        proteinG: 35,
        fatG: 34,
        carbsG: 108,
        vegetablesG: 15,
        sodiumMg: 2600,
      ),
      advice: '脂質と塩分が高めです。次はサラダ、海藻、味噌汁なしで補正します。',
    ),
    MealNutritionProfile(
      id: 'gyudon',
      label: '牛丼',
      keywords: <String>['牛丼', 'gyudon'],
      facts: NutritionFacts(
        calories: 730,
        proteinG: 25,
        fatG: 25,
        carbsG: 104,
        vegetablesG: 10,
        sodiumMg: 2300,
      ),
      advice: '主食と肉に寄っています。サラダか温野菜を追加します。',
    ),
    MealNutritionProfile(
      id: 'ramen',
      label: 'ラーメン',
      keywords: <String>['ラーメン', 'らーめん', 'ramen'],
      facts: NutritionFacts(
        calories: 690,
        proteinG: 24,
        fatG: 22,
        carbsG: 88,
        vegetablesG: 30,
        sodiumMg: 3100,
      ),
      advice: '塩分が高いのでスープを残し、次の食事はカリウムの多い野菜を選びます。',
    ),
    MealNutritionProfile(
      id: 'curry',
      label: 'カレー',
      keywords: <String>['カレー', 'curry'],
      facts: NutritionFacts(
        calories: 820,
        proteinG: 20,
        fatG: 28,
        carbsG: 120,
        vegetablesG: 60,
        sodiumMg: 2100,
      ),
      advice: '炭水化物が多めです。夜は主食を軽くし、野菜と魚を増やします。',
    ),
    MealNutritionProfile(
      id: 'salad_chicken',
      label: 'サラダチキン',
      keywords: <String>['サラダチキン', '鶏むね', 'chicken salad'],
      facts: NutritionFacts(
        calories: 220,
        proteinG: 30,
        fatG: 5,
        carbsG: 8,
        vegetablesG: 80,
        sodiumMg: 900,
      ),
      advice: 'たんぱく質補給に向いています。炭水化物が必要なら米や芋を少量足します。',
    ),
    MealNutritionProfile(
      id: 'vegetable_salad',
      label: '野菜サラダ',
      keywords: <String>['野菜サラダ', 'サラダ', 'salad'],
      facts: NutritionFacts(
        calories: 140,
        proteinG: 5,
        fatG: 6,
        carbsG: 18,
        vegetablesG: 180,
        sodiumMg: 450,
      ),
      advice: '野菜補正に有効です。主食やたんぱく質が不足しないよう組み合わせます。',
    ),
    MealNutritionProfile(
      id: 'teishoku',
      label: '定食',
      keywords: <String>['定食', '魚定食', '焼き魚'],
      facts: NutritionFacts(
        calories: 680,
        proteinG: 32,
        fatG: 18,
        carbsG: 92,
        vegetablesG: 120,
        sodiumMg: 1900,
      ),
      advice: '比較的バランス良好です。漬物や汁物で塩分を取りすぎないようにします。',
    ),
  ];

  MealNutritionEstimate estimate(String rawText) {
    final normalized = normalize(rawText);
    final profile = catalog.cast<MealNutritionProfile?>().firstWhere(
      (candidate) => candidate!.matches(normalized),
      orElse: () => null,
    );

    if (profile != null) {
      return MealNutritionEstimate(
        rawText: rawText,
        profileId: profile.id,
        label: profile.label,
        facts: profile.facts,
        advice: profile.advice,
        confidence: 0.92,
      );
    }

    return MealNutritionEstimate(
      rawText: rawText,
      profileId: 'generic_meal',
      label: '一般的な外食メニュー',
      facts: const NutritionFacts(
        calories: 650,
        proteinG: 22,
        fatG: 22,
        carbsG: 86,
        vegetablesG: 60,
        sodiumMg: 1800,
      ),
      advice: 'メニュー名を具体化すると推定精度が上がります。野菜量だけは意識して補正します。',
      confidence: 0.45,
    );
  }

  NutritionWeekSummary summarize(
    Iterable<MealNutritionLog> logs, {
    DateTime? now,
  }) {
    final anchor = _dateOnly(now ?? DateTime.now());
    final start = anchor.subtract(const Duration(days: 6));
    final weekLogs = logs.where((log) {
      final day = _dateOnly(log.loggedAt);
      return !day.isBefore(start) && !day.isAfter(anchor);
    }).toList()..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    final total = weekLogs.fold(
      const NutritionFacts(
        calories: 0,
        proteinG: 0,
        fatG: 0,
        carbsG: 0,
        vegetablesG: 0,
        sodiumMg: 0,
      ),
      (sum, log) => sum + log.estimate.facts,
    );
    final average = total.divideBy(7);
    return NutritionWeekSummary(
      logs: weekLogs,
      total: total,
      dailyAverage: average,
      warnings: _buildWarnings(average, weekLogs.length),
    );
  }

  String encodeLogs(List<MealNutritionLog> logs) {
    return jsonEncode(logs.map((log) => log.toJson()).toList());
  }

  List<MealNutritionLog> decodeLogs(String? source) {
    if (source == null || source.trim().isEmpty) {
      return <MealNutritionLog>[];
    }
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      return <MealNutritionLog>[];
    }
    return decoded
        .whereType<Map>()
        .map((item) => MealNutritionLog.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  static String normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static List<String> _buildWarnings(NutritionFacts average, int logCount) {
    if (logCount == 0) {
      return <String>['食事ログがまだありません。まず1食を記録してください。'];
    }
    final warnings = <String>[];
    if (average.vegetablesG < 180) {
      warnings.add(
        '野菜不足: 1日平均${average.vegetablesG.round()}gです。目標350gに届いていません。',
      );
    }
    if (average.sodiumMg > dailyTarget.sodiumMg) {
      warnings.add('塩分過多: 1日平均${average.sodiumMg}mgです。汁物・たれ・外食頻度を調整してください。');
    }
    if (average.calories > 2600) {
      warnings.add('カロリー過多: 1日平均${average.calories}kcalです。夜の主食量を軽くします。');
    }
    if (average.proteinG < 45) {
      warnings.add('たんぱく質不足: 1日平均${average.proteinG.round()}gです。魚・卵・鶏肉を足します。');
    }
    return warnings;
  }
}
