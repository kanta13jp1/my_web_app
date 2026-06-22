import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AbstinenceGuardItem {
  final String id;
  final String label;
  final String interruptionSignal;
  final String eliminationAction;
  final String replacementAction;
  final bool isDigital;
  final bool isImpulse;

  const AbstinenceGuardItem({
    required this.id,
    required this.label,
    required this.interruptionSignal,
    required this.eliminationAction,
    required this.replacementAction,
    this.isDigital = false,
    this.isImpulse = false,
  });
}

class AbstinenceGuardState {
  final AbstinenceGuardItem item;
  final bool isEnabled;
  final int slipCount;

  const AbstinenceGuardState({
    required this.item,
    required this.isEnabled,
    required this.slipCount,
  });
}

class AbstinenceSlipDailyCount {
  final DateTime date;
  final int count;

  const AbstinenceSlipDailyCount({
    required this.date,
    required this.count,
  });

  String get label => DateFormat('M/d').format(date);
}

class AbstinenceQuitStep {
  final String id;
  final String label;

  const AbstinenceQuitStep({
    required this.id,
    required this.label,
  });
}

class AbstinenceQuitStepState {
  final AbstinenceQuitStep step;
  final bool isCompleted;

  const AbstinenceQuitStepState({
    required this.step,
    required this.isCompleted,
  });
}

class AbstinenceQuitProtocolStatus {
  final AbstinenceGuardItem item;
  final bool isEnabled;
  final int slipCount;
  final List<AbstinenceQuitStepState> steps;

  const AbstinenceQuitProtocolStatus({
    required this.item,
    required this.isEnabled,
    required this.slipCount,
    required this.steps,
  });

  int get completedCount => steps.where((step) => step.isCompleted).length;

  int get totalCount => steps.length;

  bool get isLockedForToday =>
      isEnabled && totalCount > 0 && completedCount == totalCount;
}

class AbstinenceDisciplineCategory {
  final String id;
  final String label;
  final String description;
  final String principle;
  final int defaultMoneySaved;
  final int defaultTimeSavedMinutes;
  final int weight;

  const AbstinenceDisciplineCategory({
    required this.id,
    required this.label,
    required this.description,
    required this.principle,
    required this.defaultMoneySaved,
    required this.defaultTimeSavedMinutes,
    this.weight = 1,
  });
}

class AbstinenceDisciplineEntry {
  final String id;
  final String categoryId;
  final int moneySaved;
  final int timeSavedMinutes;
  final String note;
  final DateTime recordedAt;

  const AbstinenceDisciplineEntry({
    required this.id,
    required this.categoryId,
    required this.moneySaved,
    required this.timeSavedMinutes,
    required this.note,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'categoryId': categoryId,
      'moneySaved': moneySaved,
      'timeSavedMinutes': timeSavedMinutes,
      'note': note,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  static AbstinenceDisciplineEntry? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final categoryId = json['categoryId']?.toString();
    final recordedAt = DateTime.tryParse(json['recordedAt']?.toString() ?? '');
    if (id == null || id.isEmpty || categoryId == null || categoryId.isEmpty) {
      return null;
    }
    if (recordedAt == null) {
      return null;
    }

    return AbstinenceDisciplineEntry(
      id: id,
      categoryId: categoryId,
      moneySaved: AbstinenceGuardStore.parseIntValue(json['moneySaved']),
      timeSavedMinutes:
          AbstinenceGuardStore.parseIntValue(json['timeSavedMinutes']),
      note: json['note']?.toString() ?? '',
      recordedAt: recordedAt,
    );
  }
}

class AbstinenceDisciplineCategorySummary {
  final AbstinenceDisciplineCategory category;
  final List<AbstinenceDisciplineEntry> entries;

  const AbstinenceDisciplineCategorySummary({
    required this.category,
    required this.entries,
  });

  int get count => entries.length;

  int get totalMoneySaved =>
      entries.fold(0, (sum, entry) => sum + entry.moneySaved);

  int get totalTimeSavedMinutes =>
      entries.fold(0, (sum, entry) => sum + entry.timeSavedMinutes);
}

class AbstinenceDisciplineSnapshot {
  final List<AbstinenceDisciplineEntry> entries;
  final List<AbstinenceDisciplineCategorySummary> summaries;
  final int streakDays;

  const AbstinenceDisciplineSnapshot({
    this.entries = const <AbstinenceDisciplineEntry>[],
    this.summaries = const <AbstinenceDisciplineCategorySummary>[],
    this.streakDays = 0,
  });

  int get totalRepCount => entries.length;

  int get totalMoneySaved =>
      entries.fold(0, (sum, entry) => sum + entry.moneySaved);

  int get totalTimeSavedMinutes =>
      entries.fold(0, (sum, entry) => sum + entry.timeSavedMinutes);

  int get disciplineScore => summaries.fold(
        streakDays * 2,
        (sum, summary) => sum + (summary.count * summary.category.weight),
      );

  String get mindsetStageLabel {
    if (totalRepCount == 0) {
      return '未着手';
    }
    if (streakDays >= 7 || disciplineScore >= 20) {
      return '浪費を断れる';
    }
    if (streakDays >= 3 || disciplineScore >= 8) {
      return '我慢が定着中';
    }
    return '一拍置ける';
  }

  String get mindsetStageDetail {
    if (totalRepCount == 0) {
      return '欲望に勝つより前に、我慢できた事実を先に積み上げます。';
    }
    if (streakDays >= 7 || disciplineScore >= 20) {
      return '衝動より原則が前に出ています。この調子で浪費の入口を細らせます。';
    }
    if (streakDays >= 3 || disciplineScore >= 8) {
      return '我慢が偶然ではなく習慣に変わり始めています。';
    }
    return '止まって選び直す力が生まれています。まずは小さな我慢を増やします。';
  }

  List<AbstinenceDisciplineEntry> get recentEntries {
    final sorted = entries.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return sorted;
  }
}

class AbstinenceGuardSnapshot {
  final List<AbstinenceGuardState> states;
  final List<AbstinenceQuitProtocolStatus> quitProtocolStatuses;
  final AbstinenceDisciplineSnapshot disciplineSnapshot;

  const AbstinenceGuardSnapshot({
    required this.states,
    this.quitProtocolStatuses = const <AbstinenceQuitProtocolStatus>[],
    this.disciplineSnapshot = const AbstinenceDisciplineSnapshot(),
  });

  int get enabledCount => states.where((state) => state.isEnabled).length;

  int get totalSlipCount => states.fold(
        0,
        (sum, state) => sum + state.slipCount,
      );

  int get cleanEnabledCount =>
      states.where((state) => state.isEnabled && state.slipCount == 0).length;

  List<AbstinenceGuardState> get enabledStates =>
      states.where((state) => state.isEnabled).toList();

  List<AbstinenceGuardState> get slippedStates =>
      states.where((state) => state.slipCount > 0).toList();

  List<String> get topEnabledLabels =>
      enabledStates.take(3).map((state) => state.item.label).toList();

  List<String> get enabledLabels =>
      enabledStates.map((state) => state.item.label).toList();

  List<AbstinenceGuardState> get priorityStates {
    final indexedStates = states.asMap().entries.toList();
    indexedStates.sort((a, b) {
      final slipCompare = b.value.slipCount.compareTo(a.value.slipCount);
      if (slipCompare != 0) return slipCompare;

      final enabledCompare =
          (b.value.isEnabled ? 1 : 0).compareTo(a.value.isEnabled ? 1 : 0);
      if (enabledCompare != 0) return enabledCompare;

      return a.key.compareTo(b.key);
    });

    return indexedStates
        .map((entry) => entry.value)
        .where((state) => state.isEnabled || state.slipCount > 0)
        .toList();
  }

  AbstinenceGuardState? get primaryInterference =>
      priorityStates.isEmpty ? null : priorityStates.first;

  List<String> get slipDetails => slippedStates
      .map((state) => '${state.item.label}: ${state.slipCount}回')
      .toList();
}

class AbstinenceGuardSnapshotWithSlipCounts {
  final AbstinenceGuardSnapshot snapshot;
  final List<AbstinenceSlipDailyCount> slipCounts;

  const AbstinenceGuardSnapshotWithSlipCounts({
    required this.snapshot,
    required this.slipCounts,
  });
}

class AbstinenceGuardStore {
  static const List<String> quitProtocolItemIds = <String>[
    'alcohol',
    'smoking',
  ];

  static const Map<String, List<AbstinenceQuitStep>> quitProtocolSteps =
      <String, List<AbstinenceQuitStep>>{
    'alcohol': <AbstinenceQuitStep>[
      AbstinenceQuitStep(
        id: 'remove_stock',
        label: 'Remove every drink from the house today.',
      ),
      AbstinenceQuitStep(
        id: 'block_purchase_route',
        label: 'Avoid the store route where you usually buy alcohol.',
      ),
      AbstinenceQuitStep(
        id: 'prepare_replacement',
        label: 'Prepare water or sparkling water before cravings hit.',
      ),
    ],
    'smoking': <AbstinenceQuitStep>[
      AbstinenceQuitStep(
        id: 'discard_tools',
        label: 'Throw away cigarettes, lighters, and ashtrays.',
      ),
      AbstinenceQuitStep(
        id: 'block_purchase_route',
        label: 'Avoid the place where you usually buy tobacco today.',
      ),
      AbstinenceQuitStep(
        id: 'prepare_replacement',
        label: 'Use a 3-minute walk or deep breathing when the urge spikes.',
      ),
    ],
  };

  static const List<AbstinenceDisciplineCategory> disciplineCategories =
      <AbstinenceDisciplineCategory>[
    AbstinenceDisciplineCategory(
      id: 'no_buy',
      label: '買わずに耐えた',
      description: '予定外の買い物、課金、外食、コンビニを見送る。',
      principle: '欲しいかではなく、本当に必要かで止まる。',
      defaultMoneySaved: 1500,
      defaultTimeSavedMinutes: 15,
      weight: 3,
    ),
    AbstinenceDisciplineCategory(
      id: 'no_scroll',
      label: '開かずに戻った',
      description: 'SNS・動画・ゲームを開く前に手を止める。',
      principle: '刺激に飛ぶ前に、今の目的へ戻す。',
      defaultMoneySaved: 0,
      defaultTimeSavedMinutes: 15,
      weight: 2,
    ),
    AbstinenceDisciplineCategory(
      id: 'accept_discomfort',
      label: '不便を受け入れた',
      description: '歩く、自炊する、待つ、片づけるなどを選ぶ。',
      principle: '楽を買う前に、不便に耐える筋力をつける。',
      defaultMoneySaved: 500,
      defaultTimeSavedMinutes: 10,
      weight: 1,
    ),
  ];

  static const List<AbstinenceGuardItem> items = [
    AbstinenceGuardItem(
      id: 'sns',
      label: 'SNS',
      interruptionSignal: '考え始める前に通知やタイムラインを開いてしまう',
      eliminationAction: '通知を切り、ログアウトし、端末を机から離す',
      replacementAction: '紙に次の一手を1行だけ書く',
      isDigital: true,
      isImpulse: true,
    ),
    AbstinenceGuardItem(
      id: 'mobile_games',
      label: 'スマホゲーム',
      interruptionSignal: '5分だけのつもりで起動して流れを失う',
      eliminationAction: 'アプリをホーム画面から外し、課金導線を切る',
      replacementAction: '5分だけ単純作業を先に終わらせる',
      isDigital: true,
      isImpulse: true,
    ),
    AbstinenceGuardItem(
      id: 'alcohol',
      interruptionSignal: '夜に思考が鈍ったタイミングで飲みたくなる',
      eliminationAction: '家に置かず、水と無糖飲料だけを見える場所に置く',
      label: '酒',
      replacementAction: '水を飲む、店に寄らず帰る。',
    ),
    AbstinenceGuardItem(
      id: 'smoking',
      interruptionSignal: '一区切りごとに手持ち無沙汰で吸いたくなる',
      eliminationAction: '灰皿とライターを手元から消し、外に出ない',
      label: '煙草',
      replacementAction: '深呼吸して3分歩く。',
    ),
    AbstinenceGuardItem(
      id: 'gambling',
      interruptionSignal: '負けや焦りを取り返したくなった瞬間に開く',
      eliminationAction: '入金手段を外し、関連ブックマークを削除する',
      label: 'ギャンブル',
      replacementAction: '口座残高を確認して離脱する。',
    ),
    AbstinenceGuardItem(
      id: 'lust',
      interruptionSignal: '刺激を探し始めると作業の文脈が切れる',
      eliminationAction: '刺激源のタブを閉じ、視界から端末を外す',
      label: '性欲',
      replacementAction: '視線を切って作業に戻る。',
    ),
    AbstinenceGuardItem(
      id: 'smartphone',
      interruptionSignal: '目的なく手に取った時点で集中が切れている',
      eliminationAction: '別室に置くか、手の届かない場所で充電する',
      label: 'スマホ',
      replacementAction: '物理的に手放して別室に置く。',
    ),
    AbstinenceGuardItem(
      id: 'video',
      interruptionSignal: 'おすすめを見始めると連続視聴に流れる',
      eliminationAction: '動画サイトを閉じ、検索ではなく作業アプリだけ残す',
      label: '動画',
      replacementAction: '5分だけ紙に次の行動を書く。',
    ),
    AbstinenceGuardItem(
      id: 'manga',
      label: '漫画',
      interruptionSignal: '1話だけのつもりが読み続けてしまう',
      eliminationAction: 'アプリを閉じて、本棚やサイトをブロックする',
      replacementAction: '読みたい衝動はメモして、夜の自由時間へ送る',
      isDigital: true,
      isImpulse: true,
    ),
    AbstinenceGuardItem(
      id: 'eating_out',
      interruptionSignal: '面倒回避で外食に逃げると判断が雑になる',
      eliminationAction: '先に家で食べる物を決め、出費導線を断つ',
      label: '外食',
      replacementAction: '買い置きか固定メニューで済ませる。',
    ),
    AbstinenceGuardItem(
      id: 'masturbation',
      interruptionSignal: '刺激探索が始まった時点で深い思考が止まる',
      eliminationAction: '刺激源を閉じて立ち上がり、冷水で顔を洗う',
      label: 'マスターベーション',
      replacementAction: '立ち上がって冷水で手を洗う。',
    ),
    AbstinenceGuardItem(
      id: 'dating_apps',
      label: '出会い・異性探索',
      interruptionSignal: '承認や刺激を求めて検索や連絡に流れる',
      eliminationAction: '出会い系アプリと関連通知を切り、夜まで開かない',
      replacementAction: '衝動はメモ化して、今日の最重要タスクへ戻る',
      isDigital: true,
      isImpulse: true,
    ),
    AbstinenceGuardItem(
      id: 'touch_hair',
      interruptionSignal: '思考停止時の癖として手が頭に行く',
      eliminationAction: '両手を机の上に置き、姿勢を戻す',
      label: '髪をさわる',
      replacementAction: '両手を机の上に置く。',
    ),
    AbstinenceGuardItem(
      id: 'touch_beard',
      interruptionSignal: '考えが詰まると無意識に触り続ける',
      eliminationAction: '手を離し、メモに論点を3語だけ書く',
      label: '髭をさわる',
      replacementAction: '口元から手を離して深呼吸する。',
    ),
  ];

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String todayKey(DateTime now) =>
      DateFormat('yyyy-MM-dd').format(_startOfDay(now));

  static String _enabledKey(DateTime now, String id) =>
      'abstinence_enabled_${todayKey(now)}_$id';

  static String _slipKey(DateTime now, String id) =>
      'abstinence_slips_${todayKey(now)}_$id';

  static String _quitProtocolStepKey(
    DateTime now,
    String itemId,
    String stepId,
  ) =>
      'abstinence_quit_step_${todayKey(now)}_${itemId}_$stepId';

  static String _disciplineEntriesKey(DateTime now) =>
      'abstinence_discipline_entries_${todayKey(now)}';

  static AbstinenceDisciplineCategory? _disciplineCategoryById(
    String categoryId,
  ) {
    for (final category in disciplineCategories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }

  static String? _currentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static Future<AbstinenceGuardSnapshot> loadSnapshot({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final date = _startOfDay(now ?? DateTime.now());
    final storedStates = await _loadStatesForDate(
      date: date,
      prefs: prefs,
    );

    final protocolPrefs = prefs ?? await SharedPreferences.getInstance();
    return _buildSnapshotFromStoredStates(
      date: date,
      storedStates: storedStates,
      prefs: protocolPrefs,
    );
  }

  static Future<Map<String, AbstinenceGuardSnapshot>> loadSnapshotsByDate({
    required DateTime startDate,
    required DateTime endDate,
    SharedPreferences? prefs,
  }) async {
    final start = _startOfDay(startDate);
    final end = _startOfDay(endDate);
    final rangeStart = start.isAfter(end) ? end : start;
    final rangeEnd = start.isAfter(end) ? start : end;
    final protocolPrefs = prefs ?? await SharedPreferences.getInstance();
    final statesByDate = await _loadStatesForDateRange(
      startDate: rangeStart,
      endDate: rangeEnd,
      prefs: prefs,
    );

    return <String, AbstinenceGuardSnapshot>{
      for (final date in _dateRange(startDate: rangeStart, endDate: rangeEnd))
        todayKey(date): _buildSnapshotFromStoredStates(
          date: date,
          storedStates: statesByDate[todayKey(date)] ??
              const <String, _StoredAbstinenceState>{},
          prefs: protocolPrefs,
        ),
    };
  }

  static Future<AbstinenceGuardSnapshotWithSlipCounts>
      loadSnapshotWithSlipCounts({
    required String itemId,
    int days = 7,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final safeDays = days.clamp(1, 31).toInt();
    final date = _startOfDay(now ?? DateTime.now());
    final startDate = date.subtract(Duration(days: safeDays - 1));
    final protocolPrefs = prefs ?? await SharedPreferences.getInstance();
    final statesByDate = await _loadStatesForDateRange(
      startDate: startDate,
      endDate: date,
      prefs: prefs,
    );
    final storedStates =
        statesByDate[todayKey(date)] ?? <String, _StoredAbstinenceState>{};

    return AbstinenceGuardSnapshotWithSlipCounts(
      snapshot: _buildSnapshotFromStoredStates(
        date: date,
        storedStates: storedStates,
        prefs: protocolPrefs,
      ),
      slipCounts: _slipCountsFromDateStates(
        itemId: itemId,
        startDate: startDate,
        days: safeDays,
        statesByDate: statesByDate,
      ),
    );
  }

  static Future<void> setEnabled({
    required String itemId,
    required bool isEnabled,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final date = _startOfDay(now ?? DateTime.now());
    if (prefs != null) {
      await _setEnabledInPrefs(
        store: prefs,
        date: date,
        itemId: itemId,
        isEnabled: isEnabled,
      );
      return;
    }

    final userId = _currentUserId();
    if (userId != null) {
      try {
        final current = await _loadSupabaseItemState(
          userId: userId,
          date: date,
          itemId: itemId,
        );
        final next = _StoredAbstinenceState(
          isEnabled: isEnabled,
          slipCount: isEnabled ? (current?.slipCount ?? 0) : 0,
        );
        await _writeSupabaseItemState(
          userId: userId,
          date: date,
          itemId: itemId,
          state: next,
        );
        return;
      } catch (e) {
        debugPrint('AbstinenceGuardStore.setEnabled supabase fallback: $e');
      }
    }

    final store = await SharedPreferences.getInstance();
    await _setEnabledInPrefs(
      store: store,
      date: date,
      itemId: itemId,
      isEnabled: isEnabled,
    );
  }

  static Future<void> incrementSlip({
    required String itemId,
    String triggerNote = '',
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final occurredAt = now ?? DateTime.now();
    final date = _startOfDay(occurredAt);
    if (prefs != null) {
      await _incrementSlipInPrefs(store: prefs, date: date, itemId: itemId);
      return;
    }

    final userId = _currentUserId();
    if (userId != null) {
      try {
        final current = await _loadSupabaseItemState(
          userId: userId,
          date: date,
          itemId: itemId,
        );
        final next = _StoredAbstinenceState(
          isEnabled: current?.isEnabled ?? true,
          slipCount: (current?.slipCount ?? 0) + 1,
        );
        await _writeSupabaseItemState(
          userId: userId,
          date: date,
          itemId: itemId,
          state: next,
        );
        await _insertSupabaseSlipLog(
          userId: userId,
          itemId: itemId,
          slippedAt: occurredAt,
          triggerNote: triggerNote,
        );
        return;
      } catch (e) {
        debugPrint('AbstinenceGuardStore.incrementSlip supabase fallback: $e');
      }
    }

    final store = await SharedPreferences.getInstance();
    await _incrementSlipInPrefs(store: store, date: date, itemId: itemId);
  }

  static Future<List<AbstinenceSlipDailyCount>> loadSlipCountsByDate({
    required String itemId,
    int days = 7,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final safeDays = days.clamp(1, 31).toInt();
    final anchorDate = _startOfDay(now ?? DateTime.now());
    final startDate = anchorDate.subtract(Duration(days: safeDays - 1));
    final statesByDate = await _loadStatesForDateRange(
      startDate: startDate,
      endDate: anchorDate,
      prefs: prefs,
    );

    return _slipCountsFromDateStates(
      itemId: itemId,
      startDate: startDate,
      days: safeDays,
      statesByDate: statesByDate,
    );
  }

  static Future<void> clearSlip({
    required String itemId,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final date = _startOfDay(now ?? DateTime.now());
    if (prefs != null) {
      await _clearSlipInPrefs(store: prefs, date: date, itemId: itemId);
      return;
    }

    final userId = _currentUserId();
    if (userId != null) {
      try {
        final current = await _loadSupabaseItemState(
          userId: userId,
          date: date,
          itemId: itemId,
        );
        final next = _StoredAbstinenceState(
          isEnabled: current?.isEnabled ?? false,
          slipCount: 0,
        );
        await _writeSupabaseItemState(
          userId: userId,
          date: date,
          itemId: itemId,
          state: next,
        );
        return;
      } catch (e) {
        debugPrint('AbstinenceGuardStore.clearSlip supabase fallback: $e');
      }
    }

    final store = await SharedPreferences.getInstance();
    await _clearSlipInPrefs(store: store, date: date, itemId: itemId);
  }

  static Future<void> setQuitProtocolStep({
    required String itemId,
    required String stepId,
    required bool isCompleted,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final date = _startOfDay(now ?? DateTime.now());
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setBool(
      _quitProtocolStepKey(date, itemId, stepId),
      isCompleted,
    );
  }

  static Future<void> recordDisciplineRep({
    required String categoryId,
    int? moneySaved,
    int? timeSavedMinutes,
    String note = '',
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final date = _startOfDay(now ?? DateTime.now());
    final category = _disciplineCategoryById(categoryId);
    if (category == null) {
      throw ArgumentError.value(categoryId, 'categoryId', 'Unknown category');
    }

    final store = prefs ?? await SharedPreferences.getInstance();
    final entries = _loadDisciplineEntriesFromPrefs(store, date).toList();
    entries.add(
      AbstinenceDisciplineEntry(
        id: '${todayKey(date)}_${categoryId}_${DateTime.now().microsecondsSinceEpoch}',
        categoryId: categoryId,
        moneySaved: (moneySaved ?? category.defaultMoneySaved).clamp(
          0,
          1 << 31,
        ),
        timeSavedMinutes: (timeSavedMinutes ?? category.defaultTimeSavedMinutes)
            .clamp(0, 1 << 31),
        note: note.trim(),
        recordedAt: now ?? DateTime.now(),
      ),
    );
    await _writeDisciplineEntries(store, date, entries);
  }

  static Future<void> removeDisciplineRep({
    required String entryId,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final date = _startOfDay(now ?? DateTime.now());
    final store = prefs ?? await SharedPreferences.getInstance();
    final entries = _loadDisciplineEntriesFromPrefs(store, date)
        .where((entry) => entry.id != entryId)
        .toList();
    await _writeDisciplineEntries(store, date, entries);
  }

  static Future<Map<String, _StoredAbstinenceState>> _loadStatesForDate({
    required DateTime date,
    SharedPreferences? prefs,
  }) async {
    if (prefs != null) {
      return _loadStatesFromPrefs(prefs, date);
    }

    final userId = _currentUserId();
    if (userId != null) {
      try {
        final supabaseStates = await _loadStatesFromSupabase(
          userId: userId,
          date: date,
        );
        if (supabaseStates.isNotEmpty) {
          return supabaseStates;
        }

        final store = await SharedPreferences.getInstance();
        final localStates = _loadStatesFromPrefs(store, date);
        final meaningfulLocalStates = _meaningfulStatesOnly(localStates);
        if (meaningfulLocalStates.isNotEmpty) {
          // Backfill legacy local records so they survive across devices.
          await _writeSupabaseStatesBatch(
            userId: userId,
            date: date,
            statesByItemId: meaningfulLocalStates,
          );
          return localStates;
        }

        return supabaseStates;
      } catch (e) {
        debugPrint('AbstinenceGuardStore.loadSnapshot supabase fallback: $e');
      }
    }

    final store = await SharedPreferences.getInstance();
    return _loadStatesFromPrefs(store, date);
  }

  static Future<Map<String, Map<String, _StoredAbstinenceState>>>
      _loadStatesForDateRange({
    required DateTime startDate,
    required DateTime endDate,
    SharedPreferences? prefs,
  }) async {
    final start = _startOfDay(startDate);
    final end = _startOfDay(endDate);
    if (prefs != null) {
      return _loadStatesDateRangeFromPrefs(
        store: prefs,
        startDate: start,
        endDate: end,
      );
    }

    final userId = _currentUserId();
    if (userId != null) {
      try {
        final supabaseStates = await _loadStatesDateRangeFromSupabase(
          userId: userId,
          startDate: start,
          endDate: end,
        );
        final store = await SharedPreferences.getInstance();
        final localBackfill = <String, Map<String, _StoredAbstinenceState>>{};

        for (final date in _dateRange(startDate: start, endDate: end)) {
          final key = todayKey(date);
          if ((supabaseStates[key] ?? const <String, _StoredAbstinenceState>{})
              .isNotEmpty) {
            continue;
          }
          final localStates = _loadStatesFromPrefs(store, date);
          final meaningfulLocalStates = _meaningfulStatesOnly(localStates);
          if (meaningfulLocalStates.isEmpty) {
            continue;
          }
          supabaseStates[key] = localStates;
          localBackfill[key] = meaningfulLocalStates;
        }

        if (localBackfill.isNotEmpty) {
          await _writeSupabaseStatesDateRangeBatch(
            userId: userId,
            statesByDateKey: localBackfill,
          );
        }

        return supabaseStates;
      } catch (e) {
        debugPrint(
          'AbstinenceGuardStore.loadSlipCounts supabase fallback: $e',
        );
      }
    }

    final store = await SharedPreferences.getInstance();
    return _loadStatesDateRangeFromPrefs(
      store: store,
      startDate: start,
      endDate: end,
    );
  }

  static Map<String, Map<String, _StoredAbstinenceState>>
      _loadStatesDateRangeFromPrefs({
    required SharedPreferences store,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return <String, Map<String, _StoredAbstinenceState>>{
      for (final date in _dateRange(startDate: startDate, endDate: endDate))
        todayKey(date): _loadStatesFromPrefs(store, date),
    };
  }

  static Map<String, _StoredAbstinenceState> _loadStatesFromPrefs(
    SharedPreferences store,
    DateTime date,
  ) {
    final map = <String, _StoredAbstinenceState>{};
    for (final item in items) {
      map[item.id] = _StoredAbstinenceState(
        isEnabled: store.getBool(_enabledKey(date, item.id)) ?? false,
        slipCount: store.getInt(_slipKey(date, item.id)) ?? 0,
      );
    }
    return map;
  }

  static Future<Map<String, _StoredAbstinenceState>> _loadStatesFromSupabase({
    required String userId,
    required DateTime date,
  }) async {
    final dynamic rowsRaw = await Supabase.instance.client
        .from('abstinence_daily_status')
        .select('item_id,is_enabled,slip_count')
        .eq('user_id', userId)
        .eq('status_date', todayKey(date));

    final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
    final map = <String, _StoredAbstinenceState>{};

    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final itemId = row['item_id']?.toString();
      if (itemId == null || itemId.isEmpty) {
        continue;
      }
      map[itemId] = _StoredAbstinenceState(
        isEnabled: row['is_enabled'] == true,
        slipCount: _parseSlipCount(row['slip_count']),
      );
    }

    return map;
  }

  static Future<Map<String, Map<String, _StoredAbstinenceState>>>
      _loadStatesDateRangeFromSupabase({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final dynamic rowsRaw = await Supabase.instance.client
        .from('abstinence_daily_status')
        .select('status_date,item_id,is_enabled,slip_count')
        .eq('user_id', userId)
        .gte('status_date', todayKey(startDate))
        .lte('status_date', todayKey(endDate));

    final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
    final map = <String, Map<String, _StoredAbstinenceState>>{};

    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final statusDate = row['status_date']?.toString();
      final itemId = row['item_id']?.toString();
      if (statusDate == null ||
          statusDate.isEmpty ||
          itemId == null ||
          itemId.isEmpty) {
        continue;
      }
      map.putIfAbsent(
        statusDate,
        () => <String, _StoredAbstinenceState>{},
      )[itemId] = _StoredAbstinenceState(
        isEnabled: row['is_enabled'] == true,
        slipCount: _parseSlipCount(row['slip_count']),
      );
    }

    return map;
  }

  static int _parseSlipCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int parseIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Future<void> _setEnabledInPrefs({
    required SharedPreferences store,
    required DateTime date,
    required String itemId,
    required bool isEnabled,
  }) async {
    await store.setBool(_enabledKey(date, itemId), isEnabled);
    if (!isEnabled) {
      await store.setInt(_slipKey(date, itemId), 0);
    }
  }

  static Future<void> _incrementSlipInPrefs({
    required SharedPreferences store,
    required DateTime date,
    required String itemId,
  }) async {
    final key = _slipKey(date, itemId);
    final current = store.getInt(key) ?? 0;
    await store.setInt(key, current + 1);
  }

  static Future<void> _clearSlipInPrefs({
    required SharedPreferences store,
    required DateTime date,
    required String itemId,
  }) async {
    await store.setInt(_slipKey(date, itemId), 0);
  }

  static AbstinenceQuitProtocolStatus? _loadQuitProtocolStatus({
    required DateTime date,
    required String itemId,
    required AbstinenceGuardState? itemState,
    SharedPreferences? prefs,
  }) {
    final state = itemState;
    final steps = quitProtocolSteps[itemId];
    if (state == null || steps == null || steps.isEmpty) {
      return null;
    }

    final stepStates = steps.map((step) {
      final isCompleted =
          prefs?.getBool(_quitProtocolStepKey(date, itemId, step.id)) ?? false;
      return AbstinenceQuitStepState(
        step: step,
        isCompleted: isCompleted,
      );
    }).toList();

    return AbstinenceQuitProtocolStatus(
      item: state.item,
      isEnabled: state.isEnabled,
      slipCount: state.slipCount,
      steps: stepStates,
    );
  }

  static AbstinenceDisciplineSnapshot _loadDisciplineSnapshot({
    required DateTime date,
    required SharedPreferences prefs,
  }) {
    final entries = _loadDisciplineEntriesFromPrefs(prefs, date);
    final summaries = disciplineCategories.map((category) {
      final categoryEntries = entries
          .where((entry) => entry.categoryId == category.id)
          .toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return AbstinenceDisciplineCategorySummary(
        category: category,
        entries: categoryEntries,
      );
    }).toList();

    return AbstinenceDisciplineSnapshot(
      entries: entries,
      summaries: summaries,
      streakDays: _computeDisciplineStreak(date: date, prefs: prefs),
    );
  }

  static int _computeDisciplineStreak({
    required DateTime date,
    required SharedPreferences prefs,
  }) {
    var streak = 0;
    for (var offset = 0; offset < 365; offset += 1) {
      final candidate = date.subtract(Duration(days: offset));
      final entries = _loadDisciplineEntriesFromPrefs(prefs, candidate);
      if (entries.isEmpty) {
        break;
      }
      streak += 1;
    }
    return streak;
  }

  static List<AbstinenceDisciplineEntry> _loadDisciplineEntriesFromPrefs(
    SharedPreferences store,
    DateTime date,
  ) {
    final rawEntries =
        store.getStringList(_disciplineEntriesKey(date)) ?? const <String>[];
    final entries = <AbstinenceDisciplineEntry>[];

    for (final rawEntry in rawEntries) {
      try {
        final decoded = jsonDecode(rawEntry);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final entry = AbstinenceDisciplineEntry.fromJson(decoded);
        if (entry != null &&
            _disciplineCategoryById(entry.categoryId) != null) {
          entries.add(entry);
        }
      } catch (_) {
        continue;
      }
    }

    entries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return entries;
  }

  static Future<void> _writeDisciplineEntries(
    SharedPreferences store,
    DateTime date,
    List<AbstinenceDisciplineEntry> entries,
  ) async {
    if (entries.isEmpty) {
      await store.remove(_disciplineEntriesKey(date));
      return;
    }

    final encodedEntries = entries
        .map((entry) => jsonEncode(entry.toJson()))
        .toList(growable: false);
    await store.setStringList(_disciplineEntriesKey(date), encodedEntries);
  }

  static Future<_StoredAbstinenceState?> _loadSupabaseItemState({
    required String userId,
    required DateTime date,
    required String itemId,
  }) async {
    final dynamic row = await Supabase.instance.client
        .from('abstinence_daily_status')
        .select('is_enabled,slip_count')
        .eq('user_id', userId)
        .eq('status_date', todayKey(date))
        .eq('item_id', itemId)
        .maybeSingle();

    if (row is! Map<String, dynamic>) {
      return null;
    }

    return _StoredAbstinenceState(
      isEnabled: row['is_enabled'] == true,
      slipCount: _parseSlipCount(row['slip_count']),
    );
  }

  static Future<void> _writeSupabaseItemState({
    required String userId,
    required DateTime date,
    required String itemId,
    required _StoredAbstinenceState state,
  }) async {
    await Supabase.instance.client.from('abstinence_daily_status').upsert(
      {
        'user_id': userId,
        'status_date': todayKey(date),
        'item_id': itemId,
        'is_enabled': state.isEnabled,
        'slip_count': state.slipCount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,status_date,item_id',
    );
  }

  static Future<void> _insertSupabaseSlipLog({
    required String userId,
    required String itemId,
    required DateTime slippedAt,
    String triggerNote = '',
  }) async {
    try {
      await Supabase.instance.client.from('abstinence_slips').insert({
        'user_id': userId,
        'item_id': itemId,
        'slipped_at': slippedAt.toIso8601String(),
        if (triggerNote.trim().isNotEmpty) 'trigger_note': triggerNote.trim(),
      });
    } catch (e) {
      debugPrint('AbstinenceGuardStore slip log insert skipped: $e');
    }
  }

  static Map<String, _StoredAbstinenceState> _meaningfulStatesOnly(
    Map<String, _StoredAbstinenceState> source,
  ) {
    final result = <String, _StoredAbstinenceState>{};
    source.forEach((itemId, state) {
      if (state.isEnabled || state.slipCount > 0) {
        result[itemId] = state;
      }
    });
    return result;
  }

  static Future<void> _writeSupabaseStatesBatch({
    required String userId,
    required DateTime date,
    required Map<String, _StoredAbstinenceState> statesByItemId,
  }) async {
    if (statesByItemId.isEmpty) return;
    final rows = statesByItemId.entries
        .map(
          (entry) => <String, dynamic>{
            'user_id': userId,
            'status_date': todayKey(date),
            'item_id': entry.key,
            'is_enabled': entry.value.isEnabled,
            'slip_count': entry.value.slipCount,
            'updated_at': DateTime.now().toIso8601String(),
          },
        )
        .toList();
    await Supabase.instance.client.from('abstinence_daily_status').upsert(
          rows,
          onConflict: 'user_id,status_date,item_id',
        );
  }

  static Future<void> _writeSupabaseStatesDateRangeBatch({
    required String userId,
    required Map<String, Map<String, _StoredAbstinenceState>> statesByDateKey,
  }) async {
    if (statesByDateKey.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final rows = <Map<String, dynamic>>[];
    statesByDateKey.forEach((dateKey, statesByItemId) {
      for (final entry in statesByItemId.entries) {
        rows.add(<String, dynamic>{
          'user_id': userId,
          'status_date': dateKey,
          'item_id': entry.key,
          'is_enabled': entry.value.isEnabled,
          'slip_count': entry.value.slipCount,
          'updated_at': now,
        });
      }
    });
    if (rows.isEmpty) return;
    await Supabase.instance.client.from('abstinence_daily_status').upsert(
          rows,
          onConflict: 'user_id,status_date,item_id',
        );
  }

  static AbstinenceGuardSnapshot _buildSnapshotFromStoredStates({
    required DateTime date,
    required Map<String, _StoredAbstinenceState> storedStates,
    required SharedPreferences prefs,
  }) {
    final states = items.map((item) {
      final stored = storedStates[item.id] ??
          const _StoredAbstinenceState(
            isEnabled: false,
            slipCount: 0,
          );
      return AbstinenceGuardState(
        item: item,
        isEnabled: stored.isEnabled,
        slipCount: stored.slipCount,
      );
    }).toList();

    final stateByItemId = <String, AbstinenceGuardState>{
      for (final state in states) state.item.id: state,
    };
    final quitProtocolStatuses = quitProtocolItemIds
        .map(
          (itemId) => _loadQuitProtocolStatus(
            date: date,
            itemId: itemId,
            itemState: stateByItemId[itemId],
            prefs: prefs,
          ),
        )
        .whereType<AbstinenceQuitProtocolStatus>()
        .toList();
    final disciplineSnapshot = _loadDisciplineSnapshot(
      date: date,
      prefs: prefs,
    );

    return AbstinenceGuardSnapshot(
      states: states,
      quitProtocolStatuses: quitProtocolStatuses,
      disciplineSnapshot: disciplineSnapshot,
    );
  }

  static List<AbstinenceSlipDailyCount> _slipCountsFromDateStates({
    required String itemId,
    required DateTime startDate,
    required int days,
    required Map<String, Map<String, _StoredAbstinenceState>> statesByDate,
  }) {
    return List<AbstinenceSlipDailyCount>.generate(
      days,
      (index) {
        final date = startDate.add(Duration(days: index));
        final states = statesByDate[todayKey(date)] ??
            const <String, _StoredAbstinenceState>{};
        return AbstinenceSlipDailyCount(
          date: date,
          count: states[itemId]?.slipCount ?? 0,
        );
      },
      growable: false,
    );
  }

  static Iterable<DateTime> _dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) sync* {
    var current = _startOfDay(startDate);
    final end = _startOfDay(endDate);
    while (!current.isAfter(end)) {
      yield current;
      current = current.add(const Duration(days: 1));
    }
  }
}

class _StoredAbstinenceState {
  final bool isEnabled;
  final int slipCount;

  const _StoredAbstinenceState({
    required this.isEnabled,
    required this.slipCount,
  });
}
