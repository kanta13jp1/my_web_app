import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AbstinenceGuardItem {
  final String id;
  final String label;
  final String replacementAction;

  const AbstinenceGuardItem({
    required this.id,
    required this.label,
    required this.replacementAction,
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

class AbstinenceGuardSnapshot {
  final List<AbstinenceGuardState> states;

  const AbstinenceGuardSnapshot({
    required this.states,
  });

  int get enabledCount => states.where((state) => state.isEnabled).length;

  int get totalSlipCount => states.fold(
        0,
        (sum, state) => sum + state.slipCount,
      );

  int get cleanEnabledCount => states
      .where((state) => state.isEnabled && state.slipCount == 0)
      .length;

  List<AbstinenceGuardState> get enabledStates =>
      states.where((state) => state.isEnabled).toList();

  List<AbstinenceGuardState> get slippedStates =>
      states.where((state) => state.slipCount > 0).toList();

  List<String> get topEnabledLabels =>
      enabledStates.take(3).map((state) => state.item.label).toList();

  List<String> get enabledLabels =>
      enabledStates.map((state) => state.item.label).toList();

  List<String> get slipDetails => slippedStates
      .map((state) => '${state.item.label}: ${state.slipCount}回')
      .toList();
}

class AbstinenceGuardStore {
  static const List<AbstinenceGuardItem> items = [
    AbstinenceGuardItem(
      id: 'alcohol',
      label: '酒',
      replacementAction: '水を飲む、店に寄らず帰る。',
    ),
    AbstinenceGuardItem(
      id: 'smoking',
      label: '煙草',
      replacementAction: '深呼吸して3分歩く。',
    ),
    AbstinenceGuardItem(
      id: 'gambling',
      label: 'ギャンブル',
      replacementAction: '口座残高を確認して離脱する。',
    ),
    AbstinenceGuardItem(
      id: 'lust',
      label: '性欲',
      replacementAction: '視線を切って作業に戻る。',
    ),
    AbstinenceGuardItem(
      id: 'smartphone',
      label: 'スマホ',
      replacementAction: '物理的に手放して別室に置く。',
    ),
    AbstinenceGuardItem(
      id: 'video',
      label: '動画',
      replacementAction: '5分だけ紙に次の行動を書く。',
    ),
    AbstinenceGuardItem(
      id: 'eating_out',
      label: '外食',
      replacementAction: '買い置きか固定メニューで済ませる。',
    ),
    AbstinenceGuardItem(
      id: 'masturbation',
      label: 'マスターベーション',
      replacementAction: '立ち上がって冷水で手を洗う。',
    ),
    AbstinenceGuardItem(
      id: 'touch_hair',
      label: '髪をさわる',
      replacementAction: '両手を机の上に置く。',
    ),
    AbstinenceGuardItem(
      id: 'touch_beard',
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

    return AbstinenceGuardSnapshot(states: states);
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
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final date = _startOfDay(now ?? DateTime.now());
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
        return;
      } catch (e) {
        debugPrint('AbstinenceGuardStore.incrementSlip supabase fallback: $e');
      }
    }

    final store = await SharedPreferences.getInstance();
    await _incrementSlipInPrefs(store: store, date: date, itemId: itemId);
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

  static int _parseSlipCount(dynamic value) {
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
}

class _StoredAbstinenceState {
  final bool isEnabled;
  final int slipCount;

  const _StoredAbstinenceState({
    required this.isEnabled,
    required this.slipCount,
  });
}
