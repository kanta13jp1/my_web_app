import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// 1日の食事スロット。うどん縛りは3食すべてをコンビニうどんで通すと
/// その日が「遵守日」になる。
enum KonbiniUdonMealSlot { breakfast, lunch, dinner }

extension KonbiniUdonMealSlotLabel on KonbiniUdonMealSlot {
  String get label {
    switch (this) {
      case KonbiniUdonMealSlot.breakfast:
        return '朝';
      case KonbiniUdonMealSlot.lunch:
        return '昼';
      case KonbiniUdonMealSlot.dinner:
        return '夜';
    }
  }

  String get storageId => name;
}

/// うどん以外を食べてしまった記録。金額は「うどんとの差額」ではなく
/// 実際に払った額をそのまま入れる(振り返り用の事実記録)。
class KonbiniUdonViolation {
  const KonbiniUdonViolation({
    required this.id,
    required this.mealSlot,
    required this.note,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final KonbiniUdonMealSlot? mealSlot;
  final String note;
  final double amount;
  final DateTime createdAt;

  String get mealSlotLabel => mealSlot?.label ?? 'その他';

  factory KonbiniUdonViolation.fromJson(Map<String, dynamic> json) {
    final rawSlot = json['meal_slot']?.toString();
    KonbiniUdonMealSlot? slot;
    for (final candidate in KonbiniUdonMealSlot.values) {
      if (candidate.storageId == rawSlot) {
        slot = candidate;
      }
    }
    return KonbiniUdonViolation(
      id: json['id']?.toString() ?? '',
      mealSlot: slot,
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
      'meal_slot': mealSlot?.storageId,
      'note': note,
      'amount': amount,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

/// 節約計算の前提値。うどん単価と「縛りなしの場合の月間食費」は
/// 利用者が自分の実態に合わせて上書きできる。
class KonbiniUdonChallengeConfig {
  const KonbiniUdonChallengeConfig({
    required this.udonUnitPrice,
    required this.baselineMonthlyFoodCost,
  });

  /// コンビニうどん1食あたりの想定価格(円)。
  final double udonUnitPrice;

  /// 縛りをしない場合の月間食費の目安(円)。
  /// 初期値は総務省家計調査の単身世帯食料費を参考にした概算。
  final double baselineMonthlyFoodCost;

  static const KonbiniUdonChallengeConfig defaults = KonbiniUdonChallengeConfig(
    udonUnitPrice: KonbiniUdonChallengeService.defaultUdonUnitPrice,
    baselineMonthlyFoodCost:
        KonbiniUdonChallengeService.defaultBaselineMonthlyFoodCost,
  );

  factory KonbiniUdonChallengeConfig.fromJson(Map<String, dynamic> json) {
    return KonbiniUdonChallengeConfig(
      udonUnitPrice: max(
        0.0,
        (json['udon_unit_price'] as num?)?.toDouble() ??
            KonbiniUdonChallengeService.defaultUdonUnitPrice,
      ),
      baselineMonthlyFoodCost: max(
        0.0,
        (json['baseline_monthly_food_cost'] as num?)?.toDouble() ??
            KonbiniUdonChallengeService.defaultBaselineMonthlyFoodCost,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'udon_unit_price': udonUnitPrice,
      'baseline_monthly_food_cost': baselineMonthlyFoodCost,
    };
  }
}

/// うどん縛りによる食費圧縮の試算。月間節約額は返済シミュレーションの
/// extraMonthlyPayment にそのまま渡せる。
class KonbiniUdonSavingsEstimate {
  const KonbiniUdonSavingsEstimate({
    required this.monthlyUdonCost,
    required this.monthlyBaselineFoodCost,
    required this.monthlySavings,
  });

  final double monthlyUdonCost;
  final double monthlyBaselineFoodCost;
  final double monthlySavings;

  double get dailySavings =>
      monthlySavings / KonbiniUdonChallengeService.averageDaysPerMonth;

  bool get hasSavings => monthlySavings > 0;
}

enum KonbiniUdonHealthAdvisoryLevel { none, info, warning, danger }

/// 連続日数に応じた健康ガードレール。節約は健康を犠牲にした瞬間に
/// 医療費として跳ね返り、返済計画そのものを壊す。
class KonbiniUdonHealthAdvisory {
  const KonbiniUdonHealthAdvisory({
    required this.level,
    required this.title,
    required this.body,
  });

  final KonbiniUdonHealthAdvisoryLevel level;
  final String title;
  final String body;
}

class KonbiniUdonChallengeSnapshot {
  const KonbiniUdonChallengeSnapshot({
    required this.remainingDebt,
    required this.isEnabled,
    required this.isReleased,
    required this.startedAt,
    required this.config,
    required this.todayUdonSlots,
    required this.todayViolations,
    required this.currentStreakDays,
    required this.totalCompliantDays,
    required this.recentViolations,
  });

  final double remainingDebt;
  final bool isEnabled;
  final bool isReleased;
  final DateTime? startedAt;
  final KonbiniUdonChallengeConfig config;
  final Set<KonbiniUdonMealSlot> todayUdonSlots;
  final List<KonbiniUdonViolation> todayViolations;
  final int currentStreakDays;
  final int totalCompliantDays;
  final List<KonbiniUdonViolation> recentViolations;

  bool get isActive => isEnabled && !isReleased;

  bool get isTodayCompliant =>
      todayViolations.isEmpty &&
      todayUdonSlots.length >= KonbiniUdonMealSlot.values.length;

  KonbiniUdonSavingsEstimate get savings =>
      KonbiniUdonChallengeService.estimateSavings(config);

  /// 遵守日数 × 1日あたり節約額の概算累計。
  double get cumulativeSavings => totalCompliantDays * savings.dailySavings;

  KonbiniUdonHealthAdvisory get healthAdvisory =>
      KonbiniUdonChallengeService.healthAdvisoryFor(currentStreakDays);
}

/// 「借金を完済するまで、コンビニのうどんしか食ってはいけない」縛りの
/// 記録・節約試算・健康ガードレールを担うサービス。
///
/// 完済(残債0)で自動的に釈放される。記録は端末ローカル
/// (SharedPreferences)のみで、ネットワークやDBには書き込まない。
class KonbiniUdonChallengeService {
  const KonbiniUdonChallengeService({this.nowProvider});

  static const double defaultUdonUnitPrice = 200;
  static const double defaultBaselineMonthlyFoodCost = 45000;
  static const double averageDaysPerMonth = 30.4;

  static const int infoStreakThresholdDays = 3;
  static const int warningStreakThresholdDays = 7;
  static const int dangerStreakThresholdDays = 14;

  static const String pledgeText = '借金を完済するまで、食事はコンビニのうどんしか食わない。浮いた食費は全額返済に回す。';

  static const String healthDisclaimer = '本機能は自己規律のためのゲームであり、医学・栄養学上の助言ではありません。'
      '単一食の継続は栄養が偏ります。卵・わかめ・ねぎ等のトッピングで補い、'
      '体調に異変を感じたら直ちに縛りを中断してください。';

  static const String releaseMessage =
      '完済おめでとうございます。うどん縛りは解除されました。最初の一食は、好きなものを。';

  static const String _enabledKey = 'konbini_udon_challenge_enabled_v1';
  static const String _startedAtKey = 'konbini_udon_challenge_started_at_v1';
  static const String _historyKey = 'konbini_udon_challenge_history_v1';
  static const String _configKey = 'konbini_udon_challenge_config_v1';

  final DateTime Function()? nowProvider;

  DateTime _now() => nowProvider?.call() ?? DateTime.now();

  static KonbiniUdonSavingsEstimate estimateSavings(
    KonbiniUdonChallengeConfig config,
  ) {
    final monthlyUdonCost = max(0.0, config.udonUnitPrice) *
        KonbiniUdonMealSlot.values.length *
        averageDaysPerMonth;
    final baseline = max(0.0, config.baselineMonthlyFoodCost);
    return KonbiniUdonSavingsEstimate(
      monthlyUdonCost: monthlyUdonCost,
      monthlyBaselineFoodCost: baseline,
      monthlySavings: max(0.0, baseline - monthlyUdonCost),
    );
  }

  static KonbiniUdonHealthAdvisory healthAdvisoryFor(int consecutiveDays) {
    if (consecutiveDays >= dangerStreakThresholdDays) {
      return const KonbiniUdonHealthAdvisory(
        level: KonbiniUdonHealthAdvisoryLevel.danger,
        title: '健康最優先: 縛りの緩和を強く推奨します',
        body: '単一食が14日以上続いています。ここから先は健康リスクが節約メリットを上回ります。'
            '野菜とタンパク質を含む食事へ切り替え、体調不良があれば医療機関の受診を検討してください。'
            '健康を損なうと医療費と収入減で、返済計画そのものが崩れます。',
      );
    }
    if (consecutiveDays >= warningStreakThresholdDays) {
      return const KonbiniUdonHealthAdvisory(
        level: KonbiniUdonHealthAdvisoryLevel.warning,
        title: '栄養不足リスクが高まっています',
        body: 'うどん縛りが7日以上続いています。タンパク質・ビタミン・食物繊維が不足しがちです。'
            '卵・サラダチキン・わかめのトッピングを必須にして、疲労感や集中力低下を感じたら'
            '縛りを緩めてください。',
      );
    }
    if (consecutiveDays >= infoStreakThresholdDays) {
      return const KonbiniUdonHealthAdvisory(
        level: KonbiniUdonHealthAdvisoryLevel.info,
        title: 'トッピングで栄養を補ってください',
        body: '連続遵守おつかれさまです。卵・わかめ・ねぎ・サラダチキンのトッピングは'
            '「うどんの範囲内」です。価格を抑えたままタンパク質とミネラルを補えます。',
      );
    }
    return const KonbiniUdonHealthAdvisory(
      level: KonbiniUdonHealthAdvisoryLevel.none,
      title: '',
      body: '',
    );
  }

  Future<KonbiniUdonChallengeSnapshot> loadSnapshot({
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

    return KonbiniUdonChallengeSnapshot(
      remainingDebt: remainingDebt,
      isEnabled: !isReleased && storedEnabled,
      isReleased: isReleased,
      startedAt: _parseDate(store.getString(_startedAtKey)),
      config: _readConfig(store.getString(_configKey)),
      todayUdonSlots: _readUdonSlots(todayRecord),
      todayViolations: _sortViolations(_readViolations(todayRecord)),
      currentStreakDays: _calculateStreak(history, now: now),
      totalCompliantDays: _countCompliantDays(history),
      recentViolations: _recentViolations(history),
    );
  }

  Future<KonbiniUdonChallengeSnapshot> setEnabled(
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

  Future<KonbiniUdonChallengeSnapshot> toggleMealSlot(
    KonbiniUdonMealSlot slot,
    bool ateUdon, {
    required double remainingDebt,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final history = _readHistory(store.getString(_historyKey));
    final todayKey = _dateKey(_now());
    final todayRecord = Map<String, dynamic>.from(
      history[todayKey] ?? _emptyDayRecord(),
    );
    final slots = _readUdonSlots(todayRecord);

    if (ateUdon) {
      slots.add(slot);
    } else {
      slots.remove(slot);
    }

    todayRecord['udon_slots'] = slots.map((entry) => entry.storageId).toList()
      ..sort();
    todayRecord['updated_at'] = _now().toUtc().toIso8601String();
    history[todayKey] = todayRecord;

    await _saveHistory(store, history);
    return loadSnapshot(remainingDebt: remainingDebt, prefs: store);
  }

  Future<KonbiniUdonChallengeSnapshot> recordViolation({
    required String note,
    required double amount,
    KonbiniUdonMealSlot? slot,
    required double remainingDebt,
    SharedPreferences? prefs,
  }) async {
    final trimmedNote = note.trim();
    if (trimmedNote.isEmpty) {
      throw ArgumentError('note must not be empty');
    }

    final store = prefs ?? await SharedPreferences.getInstance();
    final now = _now();
    final history = _readHistory(store.getString(_historyKey));
    final todayKey = _dateKey(now);
    final todayRecord = Map<String, dynamic>.from(
      history[todayKey] ?? _emptyDayRecord(),
    );
    final violations = _readViolations(todayRecord);

    violations.add(
      KonbiniUdonViolation(
        id: 'konbini_udon_${now.microsecondsSinceEpoch}_${violations.length}',
        mealSlot: slot,
        note: trimmedNote,
        amount: amount,
        createdAt: now,
      ),
    );

    // うどん以外を食べたスロットは遵守チェックからも外す。
    final slots = _readUdonSlots(todayRecord);
    if (slot != null) {
      slots.remove(slot);
    }

    todayRecord['udon_slots'] = slots.map((entry) => entry.storageId).toList()
      ..sort();
    todayRecord['violations'] =
        violations.map((entry) => entry.toJson()).toList();
    todayRecord['updated_at'] = now.toUtc().toIso8601String();
    history[todayKey] = todayRecord;

    await _saveHistory(store, history);
    return loadSnapshot(remainingDebt: remainingDebt, prefs: store);
  }

  Future<KonbiniUdonChallengeSnapshot> updateConfig({
    required double udonUnitPrice,
    required double baselineMonthlyFoodCost,
    required double remainingDebt,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final config = KonbiniUdonChallengeConfig(
      udonUnitPrice: max(0.0, udonUnitPrice),
      baselineMonthlyFoodCost: max(0.0, baselineMonthlyFoodCost),
    );
    await store.setString(_configKey, jsonEncode(config.toJson()));
    return loadSnapshot(remainingDebt: remainingDebt, prefs: store);
  }

  Future<void> _saveHistory(
    SharedPreferences store,
    Map<String, Map<String, dynamic>> history,
  ) async {
    await store.setString(_historyKey, jsonEncode(history));
  }

  KonbiniUdonChallengeConfig _readConfig(String? raw) {
    if (raw == null || raw.isEmpty) {
      return KonbiniUdonChallengeConfig.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return KonbiniUdonChallengeConfig.defaults;
      }
      return KonbiniUdonChallengeConfig.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return KonbiniUdonChallengeConfig.defaults;
    }
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
      'udon_slots': <String>[],
      'violations': <Map<String, dynamic>>[],
    };
  }

  Set<KonbiniUdonMealSlot> _readUdonSlots(Map<String, dynamic> record) {
    final rawSlots = ((record['udon_slots'] as List<dynamic>?) ?? const [])
        .map((entry) => entry.toString())
        .toSet();
    return KonbiniUdonMealSlot.values
        .where((slot) => rawSlots.contains(slot.storageId))
        .toSet();
  }

  List<KonbiniUdonViolation> _readViolations(Map<String, dynamic> record) {
    return ((record['violations'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map(
          (entry) =>
              KonbiniUdonViolation.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList();
  }

  List<KonbiniUdonViolation> _sortViolations(
    List<KonbiniUdonViolation> values,
  ) {
    final sorted = List<KonbiniUdonViolation>.from(values);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  List<KonbiniUdonViolation> _recentViolations(
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

  bool _isCompliantRecord(Map<String, dynamic> record) {
    return _readViolations(record).isEmpty &&
        _readUdonSlots(record).length >= KonbiniUdonMealSlot.values.length;
  }

  int _countCompliantDays(Map<String, Map<String, dynamic>> history) {
    return history.values.where(_isCompliantRecord).length;
  }

  /// 連続遵守日数。今日が未完了(違反なし・3食未記録)の場合は昨日から
  /// 遡って数える。今日すでに違反があるなら連続は0。
  int _calculateStreak(
    Map<String, Map<String, dynamic>> history, {
    required DateTime now,
  }) {
    var current = DateTime(now.year, now.month, now.day);
    final todayRecord = history[_dateKey(current)];

    if (todayRecord != null) {
      if (_readViolations(todayRecord).isNotEmpty) {
        return 0;
      }
      if (!_isCompliantRecord(todayRecord)) {
        current = current.subtract(const Duration(days: 1));
      }
    } else {
      current = current.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (true) {
      final record = history[_dateKey(current)];
      if (record == null || !_isCompliantRecord(record)) {
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
