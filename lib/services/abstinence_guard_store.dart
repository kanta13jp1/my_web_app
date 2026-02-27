import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static String todayKey(DateTime now) => DateFormat('yyyy-MM-dd').format(now);

  static String _enabledKey(DateTime now, String id) =>
      'abstinence_enabled_${todayKey(now)}_$id';

  static String _slipKey(DateTime now, String id) =>
      'abstinence_slips_${todayKey(now)}_$id';

  static Future<AbstinenceGuardSnapshot> loadSnapshot({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final date = now ?? DateTime.now();

    final states = items.map((item) {
      return AbstinenceGuardState(
        item: item,
        isEnabled: store.getBool(_enabledKey(date, item.id)) ?? false,
        slipCount: store.getInt(_slipKey(date, item.id)) ?? 0,
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
    final store = prefs ?? await SharedPreferences.getInstance();
    final date = now ?? DateTime.now();
    await store.setBool(_enabledKey(date, itemId), isEnabled);
    if (!isEnabled) {
      await store.setInt(_slipKey(date, itemId), 0);
    }
  }

  static Future<void> incrementSlip({
    required String itemId,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final date = now ?? DateTime.now();
    final key = _slipKey(date, itemId);
    final current = store.getInt(key) ?? 0;
    await store.setInt(key, current + 1);
  }

  static Future<void> clearSlip({
    required String itemId,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final date = now ?? DateTime.now();
    await store.setInt(_slipKey(date, itemId), 0);
  }
}
