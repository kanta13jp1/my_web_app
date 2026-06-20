import 'dart:convert';

import 'package:my_web_app/services/mirror_tombstone_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 資産管理ページの表示モード。情報量を段階的に開示する。
enum AssetManagementDisplayMode { minimum, standard, full }

/// 各セクションの重要度ティア。モードとの対応:
/// minimum → essential のみ / standard → essential+standard / full → 全部。
enum AssetManagementSectionTier { essential, standard, full }

/// ページ内セクションの識別子(pin/hide カスタムの単位)。
enum AssetManagementSectionId {
  monthlyFlow,
  calendar,
  proposals,
  salaryBreakdown,
  recurringFixedCost,
  subscriptionFixedCost,
  disposable,
  quickActions,
  wasteAi,
  deadlines,
  threeMonth,
  debtPlanner,
  workbookBoard,
  assetLiability,
  flow,
  subscriptions,
  mustTasks,
  chart,
}

/// セクション単位の表示上書き。auto はティア×モードの既定に従う。
enum AssetManagementSectionVisibilityOverride { auto, pinned, hidden }

/// セクションID → 上書き設定のマップ。
typedef AssetManagementSectionOverrides
    = Map<AssetManagementSectionId, AssetManagementSectionVisibilityOverride>;

extension AssetManagementDisplayModeLabel on AssetManagementDisplayMode {
  String get label {
    switch (this) {
      case AssetManagementDisplayMode.minimum:
        return 'ミニマム';
      case AssetManagementDisplayMode.standard:
        return '標準';
      case AssetManagementDisplayMode.full:
        return 'フル';
    }
  }

  String get description {
    switch (this) {
      case AssetManagementDisplayMode.minimum:
        return '最重要のみ: 収支・残高・借金返済・カレンダー';
      case AssetManagementDisplayMode.standard:
        return '優先度の高い機能まで表示';
      case AssetManagementDisplayMode.full:
        return '全機能表示(従来どおり)';
    }
  }

  String get storageId => name;
}

extension AssetManagementSectionIdMeta on AssetManagementSectionId {
  String get storageId => name;

  String get label {
    switch (this) {
      case AssetManagementSectionId.monthlyFlow:
        return '当月収支の概観';
      case AssetManagementSectionId.calendar:
        return 'マネーカレンダー';
      case AssetManagementSectionId.proposals:
        return '提案カード';
      case AssetManagementSectionId.salaryBreakdown:
        return '給与消費内訳';
      case AssetManagementSectionId.recurringFixedCost:
        return '定期固定費';
      case AssetManagementSectionId.subscriptionFixedCost:
        return 'サブスク (AI/クラウド)';
      case AssetManagementSectionId.disposable:
        return '裁量余資金';
      case AssetManagementSectionId.quickActions:
        return 'フロー記録ボタン';
      case AssetManagementSectionId.wasteAi:
        return '浪費抑制トレーニングAI';
      case AssetManagementSectionId.deadlines:
        return '締切チェックリスト';
      case AssetManagementSectionId.threeMonth:
        return '3ヶ月俯瞰';
      case AssetManagementSectionId.debtPlanner:
        return '借金返済プラン';
      case AssetManagementSectionId.workbookBoard:
        return '資産・負債ワークブックボード';
      case AssetManagementSectionId.assetLiability:
        return '資産負債(①②)';
      case AssetManagementSectionId.flow:
        return '収支(④)';
      case AssetManagementSectionId.subscriptions:
        return '固定費(③)';
      case AssetManagementSectionId.mustTasks:
        return '必須タスク(⑤)';
      case AssetManagementSectionId.chart:
        return 'グラフ';
    }
  }

  AssetManagementSectionTier get defaultTier {
    switch (this) {
      case AssetManagementSectionId.monthlyFlow:
      case AssetManagementSectionId.calendar:
      case AssetManagementSectionId.disposable:
      case AssetManagementSectionId.quickActions:
      case AssetManagementSectionId.debtPlanner:
        return AssetManagementSectionTier.essential;
      case AssetManagementSectionId.proposals:
      case AssetManagementSectionId.salaryBreakdown:
      case AssetManagementSectionId.recurringFixedCost:
      case AssetManagementSectionId.subscriptionFixedCost:
      case AssetManagementSectionId.deadlines:
      case AssetManagementSectionId.threeMonth:
      case AssetManagementSectionId.workbookBoard:
      case AssetManagementSectionId.assetLiability:
      case AssetManagementSectionId.flow:
      case AssetManagementSectionId.subscriptions:
      case AssetManagementSectionId.mustTasks:
        return AssetManagementSectionTier.standard;
      case AssetManagementSectionId.wasteAi:
      case AssetManagementSectionId.chart:
        return AssetManagementSectionTier.full;
    }
  }
}

extension AssetManagementSectionVisibilityOverrideLabel
    on AssetManagementSectionVisibilityOverride {
  String get storageId => name;

  String get label {
    switch (this) {
      case AssetManagementSectionVisibilityOverride.auto:
        return '自動';
      case AssetManagementSectionVisibilityOverride.pinned:
        return '常に表示';
      case AssetManagementSectionVisibilityOverride.hidden:
        return '隠す';
    }
  }
}

/// サーバ全体集計 (display_mode_experiment_summary rpc) の整形結果。
class AssetDisplayModeServerSummary {
  const AssetDisplayModeServerSummary({
    required this.summaryLabel,
    required this.weekly,
    this.firstEventAt,
    this.weeklyRetention = const <Map<String, dynamic>>[],
  });

  final String summaryLabel;
  final List<Map<String, dynamic>> weekly;

  /// 実験の最初のイベント時刻 (= 実験開始)。イベント0件なら null。
  final DateTime? firstEventAt;

  /// 週末時点 as-of の標準維持率% ({week_start, rate})。rate は null 可。
  final List<Map<String, dynamic>> weeklyRetention;
}

/// ミラー上の表示設定がローカルより新しい場合の差分。
class AssetMirrorPrefsDiff {
  const AssetMirrorPrefsDiff({this.mode, this.overrides});

  final AssetManagementDisplayMode? mode;
  final AssetManagementSectionOverrides? overrides;

  bool get isEmpty => mode == null && overrides == null;
}

/// 表示モード実験の観測値(ローカル計測)。
class AssetDisplayModeStats {
  const AssetDisplayModeStats({
    required this.initialMode,
    required this.initialHadData,
    required this.switchCount,
    required this.lastChangedAt,
  });

  /// 初回解決で保存されたモード(未解決なら null)。
  final String? initialMode;

  /// 初回解決時に既存データがあったか(=既存ユーザー判定)。
  final bool? initialHadData;

  /// ユーザーが手動でモードを切り替えた回数。
  final int switchCount;

  final DateTime? lastChangedAt;
}

/// 表示モード・セクション上書きの永続化と可視判定。
class AssetManagementDisplayModeStore {
  const AssetManagementDisplayModeStore({this.nowProvider});

  final DateTime Function()? nowProvider;

  DateTime _now() => nowProvider?.call() ?? DateTime.now();

  /// セクション上書きを「自動へ戻した(=削除した)」section の削除トゥームストーン。
  /// ミラー取込時に、消したはずの上書きがサーバ残存分から復活するのを防ぐ
  /// (#part291: MirrorTombstoneStore の 2 例目の消費者)。
  static const String _overrideDeletedKey =
      'asset_management_section_override_deleted_v1';

  MirrorTombstoneStore get _overrideTombstones => MirrorTombstoneStore(
        storageKey: _overrideDeletedKey,
        nowProvider: nowProvider,
      );

  /// 削除トゥームストーン済み section の storageId 集合。
  Future<Set<String>> loadDeletedSectionIds({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return _overrideTombstones.activeIds(store);
  }

  /// 削除トゥームストーンをミラー upsert 用の値へ変換する (`{'ids': [...]}`)。
  Future<Map<String, dynamic>> encodeDeletedSectionIdsMirror({
    SharedPreferences? prefs,
  }) async {
    final ids = await loadDeletedSectionIds(prefs: prefs);
    return MirrorTombstoneStore.encodeMirror(ids);
  }

  /// ミラー値 (`{'ids': [...]}`) から section storageId リストを取り出す。
  static List<String> decodeDeletedSectionIdsMirror(Object? value) =>
      MirrorTombstoneStore.decodeMirror(value);

  /// 表示設定 3 種 (mode / section_overrides / section_override_deleted) を
  /// 1 行 jsonb へ集約する (#part293 upsert 回数削減)。
  static Map<String, dynamic> buildAggregatedMirrorValue({
    required AssetManagementDisplayMode mode,
    required AssetManagementSectionOverrides overrides,
    required Iterable<String> deletedIds,
  }) {
    return <String, dynamic>{
      'mode': mode.storageId,
      'section_overrides': <String, String>{
        for (final entry in overrides.entries)
          entry.key.storageId: entry.value.storageId,
      },
      'section_override_deleted': <String>[
        for (final id in deletedIds)
          if (id.isNotEmpty) id,
      ],
    };
  }

  /// 集約ミラー値を、既存の evaluateMirrorPrefRows が解釈できる per-key 行
  /// (display_mode / section_overrides) へ変換する。形が不正なら空。
  static List<Map<String, dynamic>> aggregatedMirrorToRows(
    Object? value, {
    required String updatedAt,
  }) {
    if (value is! Map) {
      return const <Map<String, dynamic>>[];
    }
    final rows = <Map<String, dynamic>>[];
    final mode = value['mode'];
    if (mode != null) {
      rows.add(<String, dynamic>{
        'pref_key': 'display_mode',
        'value': <String, dynamic>{'mode': mode.toString()},
        'updated_at': updatedAt,
      });
    }
    final overrides = value['section_overrides'];
    if (overrides is Map) {
      rows.add(<String, dynamic>{
        'pref_key': 'section_overrides',
        'value': Map<String, dynamic>.from(overrides),
        'updated_at': updatedAt,
      });
    }
    return rows;
  }

  /// 集約ミラー値から削除トゥームストーン (section storageId) を取り出す。
  static List<String> aggregatedDeletedSectionIds(Object? value) {
    if (value is! Map) {
      return const <String>[];
    }
    final raw = value['section_override_deleted'];
    if (raw is! List) {
      return const <String>[];
    }
    return <String>[
      for (final id in raw)
        if ((id?.toString() ?? '').isNotEmpty) id.toString(),
    ];
  }

  /// 他端末由来の override 削除トゥームストーンを取り込み、該当するローカル
  /// 上書きを削除する (端末間の削除伝播 / #part292)。削除した上書き数を返す。
  Future<int> applyRemoteDeletedSectionIds(
    Iterable<String> remoteIds, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final incoming = await _overrideTombstones.mergeRemoteIds(store, remoteIds);
    if (incoming.isEmpty) {
      return 0;
    }
    final current = await loadOverrides(prefs: store);
    final before = current.length;
    current.removeWhere((section, _) => incoming.contains(section.storageId));
    final removed = before - current.length;
    if (removed > 0) {
      final encoded = <String, String>{
        for (final entry in current.entries)
          entry.key.storageId: entry.value.storageId,
      };
      await store.setString(_overridesKey, jsonEncode(encoded));
    }
    return removed;
  }

  /// 期限切れ・上限超過の override 削除トゥームストーンを掃除し件数を返す。
  Future<int> pruneDeletedSectionIds({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return _overrideTombstones.prune(store);
  }

  /// 既存ユーザーの体験を変えないため、未設定時はフル表示。
  static const AssetManagementDisplayMode defaultMode =
      AssetManagementDisplayMode.full;

  /// 新規ユーザー(既存データなし)に提示する初期モード。
  static const AssetManagementDisplayMode newUserDefaultMode =
      AssetManagementDisplayMode.standard;

  /// rpc 戻り値 (jsonb) を表示用ラベルと週次リストへ整形する。
  /// asset_management_page と CFO 室カードで共用。
  static AssetDisplayModeServerSummary parseServerSummary(
    Map<String, dynamic> data,
  ) {
    int countOf(String key) => (data[key] as num?)?.toInt() ?? 0;
    final standardInitial = countOf('initial_standard');
    final retained = countOf('standard_retained');
    final rate = standardInitial == 0
        ? '-'
        : '${(retained * 100 / standardInitial).round()}%';
    final weekly = data['weekly'];
    var trendLabel = '';
    final weeklyMaps = <Map<String, dynamic>>[];
    if (weekly is List && weekly.isNotEmpty) {
      final parts = <String>[];
      for (final raw in weekly.take(4)) {
        if (raw is! Map) {
          continue;
        }
        final week = Map<String, dynamic>.from(raw);
        weeklyMaps.add(week);
        final start = week['week_start']?.toString() ?? '';
        final label = start.length >= 10 ? start.substring(5, 10) : start;
        final initials = (week['initials'] as num?)?.toInt() ?? 0;
        final std = (week['initial_standard'] as num?)?.toInt() ?? 0;
        final switches = (week['switches'] as num?)?.toInt() ?? 0;
        parts.add('$label: 初期$initials(std$std)/切替$switches');
      }
      if (parts.isNotEmpty) {
        trendLabel = ' | 週次 ${parts.join(' → ')}';
      }
    }
    return AssetDisplayModeServerSummary(
      summaryLabel:
          '全体: 初期 min ${countOf('initial_minimum')} / std $standardInitial / full ${countOf('initial_full')}・標準維持率 $rate・切替 ${countOf('switch_total')}回$trendLabel',
      weekly: weeklyMaps,
      firstEventAt: DateTime.tryParse(data['first_event_at']?.toString() ?? '')
          ?.toLocal(),
      weeklyRetention: data['weekly_retention'] is List
          ? <Map<String, dynamic>>[
              for (final raw in data['weekly_retention'] as List)
                if (raw is Map) Map<String, dynamic>.from(raw),
            ]
          : const <Map<String, dynamic>>[],
    );
  }

  /// ミラー行 (asset_pref_mirror) を評価し、ローカル設定より新しく
  /// かつ内容が異なる差分だけを返す。自端末の直近書込みは
  /// [selfWriteMargin] 以内の updated_at として除外する。
  static AssetMirrorPrefsDiff evaluateMirrorPrefRows({
    required List<Map<String, dynamic>> rows,
    required AssetManagementDisplayMode currentMode,
    required AssetManagementSectionOverrides currentOverrides,
    DateTime? localChangedAt,
    Duration selfWriteMargin = const Duration(seconds: 10),
    Set<String> deletedSectionIds = const <String>{},
  }) {
    AssetManagementDisplayMode? newerMode;
    AssetManagementSectionOverrides? newerOverrides;
    for (final row in rows) {
      final updatedAt =
          DateTime.tryParse(row['updated_at']?.toString() ?? '')?.toLocal();
      if (updatedAt == null) {
        continue;
      }
      if (localChangedAt != null &&
          !updatedAt.isAfter(localChangedAt.add(selfWriteMargin))) {
        continue;
      }
      final value = row['value'];
      if (value is! Map) {
        continue;
      }
      if (row['pref_key'] == 'display_mode') {
        final raw = value['mode']?.toString();
        for (final mode in AssetManagementDisplayMode.values) {
          if (mode.storageId == raw && mode != currentMode) {
            newerMode = mode;
          }
        }
      }
      if (row['pref_key'] == 'section_overrides') {
        final candidate = <AssetManagementSectionId,
            AssetManagementSectionVisibilityOverride>{};
        for (final entry in value.entries) {
          // 削除トゥームストーン済み section は復活させない (#part291)。
          if (deletedSectionIds.contains(entry.key.toString())) {
            continue;
          }
          for (final section in AssetManagementSectionId.values) {
            if (section.storageId != entry.key.toString()) {
              continue;
            }
            for (final override
                in AssetManagementSectionVisibilityOverride.values) {
              if (override.storageId == entry.value.toString() &&
                  override != AssetManagementSectionVisibilityOverride.auto) {
                candidate[section] = override;
              }
            }
          }
        }
        var same = candidate.length == currentOverrides.length;
        if (same) {
          for (final entry in candidate.entries) {
            if (currentOverrides[entry.key] != entry.value) {
              same = false;
              break;
            }
          }
        }
        if (!same) {
          newerOverrides = candidate;
        }
      }
    }
    return AssetMirrorPrefsDiff(mode: newerMode, overrides: newerOverrides);
  }

  /// 取り込み前プレビュー用の「旧 → 新」差分行を組み立てる。
  static List<String> describeMirrorPrefsDiff({
    required AssetManagementDisplayMode currentMode,
    required AssetManagementSectionOverrides currentOverrides,
    required AssetMirrorPrefsDiff diff,
  }) {
    final lines = <String>[];
    final newMode = diff.mode;
    if (newMode != null && newMode != currentMode) {
      lines.add('表示モード: ${currentMode.label} → ${newMode.label}');
    }
    final newOverrides = diff.overrides;
    if (newOverrides != null) {
      final keys = <AssetManagementSectionId>{
        ...currentOverrides.keys,
        ...newOverrides.keys,
      };
      for (final section in AssetManagementSectionId.values) {
        if (!keys.contains(section)) {
          continue;
        }
        final before = currentOverrides[section] ??
            AssetManagementSectionVisibilityOverride.auto;
        final after = newOverrides[section] ??
            AssetManagementSectionVisibilityOverride.auto;
        if (before != after) {
          lines.add('${section.label}: ${before.label} → ${after.label}');
        }
      }
    }
    return lines;
  }

  /// サーババックアップからの表示設定復元をユーザーが辞退したか。
  Future<bool> isRestoreDeclined({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return store.getBool(_restoreDeclinedKey) ?? false;
  }

  Future<void> markRestoreDeclined({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setBool(_restoreDeclinedKey, true);
  }

  static const String _restoreDeclinedKey =
      'asset_management_display_restore_declined_v1';
  static const String _modeKey = 'asset_management_display_mode_v1';
  static const String _overridesKey = 'asset_management_section_overrides_v1';
  static const String _eventsKey = 'asset_management_display_mode_events_v1';
  static const int _maxEvents = 50;

  static bool isTierVisible({
    required AssetManagementSectionTier tier,
    required AssetManagementDisplayMode mode,
  }) {
    switch (mode) {
      case AssetManagementDisplayMode.minimum:
        return tier == AssetManagementSectionTier.essential;
      case AssetManagementDisplayMode.standard:
        return tier != AssetManagementSectionTier.full;
      case AssetManagementDisplayMode.full:
        return true;
    }
  }

  /// pin/hide 上書き込みの最終可視判定。
  static bool isSectionVisible({
    required AssetManagementSectionId section,
    required AssetManagementDisplayMode mode,
    AssetManagementSectionVisibilityOverride override =
        AssetManagementSectionVisibilityOverride.auto,
  }) {
    switch (override) {
      case AssetManagementSectionVisibilityOverride.pinned:
        return true;
      case AssetManagementSectionVisibilityOverride.hidden:
        return false;
      case AssetManagementSectionVisibilityOverride.auto:
        return isTierVisible(tier: section.defaultTier, mode: mode);
    }
  }

  Future<AssetManagementDisplayMode> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return _storedMode(store) ?? defaultMode;
  }

  /// 保存済みモードが存在するか(初期解決イベント送信の判定用)。
  Future<bool> hasStoredMode({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return _storedMode(store) != null;
  }

  /// [recordEvent] を false にするとミラー復元などの非ユーザー操作を
  /// 実験ログ (switch 回数) に混入させずに保存できる。
  Future<void> save(
    AssetManagementDisplayMode mode, {
    SharedPreferences? prefs,
    bool recordEvent = true,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setString(_modeKey, mode.storageId);
    if (!recordEvent) {
      return;
    }
    await _appendEvent(store, <String, dynamic>{
      'type': 'switch',
      'to': mode.storageId,
      'at': _now().toUtc().toIso8601String(),
    });
  }

  /// 初回起動時の既定モード解決。保存済みがあればそれを優先し、
  /// なければ「既存データあり=フル / なし(新規)=標準」を保存して返す。
  Future<AssetManagementDisplayMode> resolveInitialMode({
    required bool hasExistingData,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final stored = _storedMode(store);
    if (stored != null) {
      return stored;
    }
    final resolved = hasExistingData ? defaultMode : newUserDefaultMode;
    await store.setString(_modeKey, resolved.storageId);
    await _appendEvent(store, <String, dynamic>{
      'type': 'initial',
      'to': resolved.storageId,
      'has_data': hasExistingData,
      'at': _now().toUtc().toIso8601String(),
    });
    return resolved;
  }

  /// 標準既定実験のローカル統計。サーバ集約は別 Issue で対応。
  Future<AssetDisplayModeStats> loadStats({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final events = _decodeEvents(store.getString(_eventsKey));
    String? initialMode;
    bool? initialHadData;
    var switchCount = 0;
    DateTime? lastChangedAt;
    for (final event in events) {
      final type = event['type']?.toString();
      if (type == 'initial' && initialMode == null) {
        initialMode = event['to']?.toString();
        initialHadData = event['has_data'] == true;
      }
      if (type == 'switch') {
        switchCount += 1;
      }
      final at = DateTime.tryParse(event['at']?.toString() ?? '');
      if (at != null) {
        lastChangedAt = at.toLocal();
      }
    }
    return AssetDisplayModeStats(
      initialMode: initialMode,
      initialHadData: initialHadData,
      switchCount: switchCount,
      lastChangedAt: lastChangedAt,
    );
  }

  Future<void> _appendEvent(
    SharedPreferences store,
    Map<String, dynamic> event,
  ) async {
    final events = _decodeEvents(store.getString(_eventsKey))..add(event);
    final trimmed = events.length <= _maxEvents
        ? events
        : events.sublist(events.length - _maxEvents);
    await store.setString(_eventsKey, jsonEncode(trimmed));
  }

  List<Map<String, dynamic>> _decodeEvents(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<AssetManagementSectionOverrides> loadOverrides({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(_overridesKey);
    final result =
        <AssetManagementSectionId, AssetManagementSectionVisibilityOverride>{};
    if (raw == null || raw.isEmpty) {
      return result;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return result;
      }
      decoded.forEach((key, value) {
        final section = _sectionFor(key?.toString());
        final override = _overrideFor(value?.toString());
        if (section == null || override == null) {
          return;
        }
        if (override != AssetManagementSectionVisibilityOverride.auto) {
          result[section] = override;
        }
      });
      return result;
    } catch (_) {
      return result;
    }
  }

  Future<AssetManagementSectionOverrides> saveOverride(
    AssetManagementSectionId section,
    AssetManagementSectionVisibilityOverride override, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final current = await loadOverrides(prefs: store);
    if (override == AssetManagementSectionVisibilityOverride.auto) {
      current.remove(section);
      // 削除をトゥームストーン化 → ミラー取込でこの section は復活しない。
      await _overrideTombstones.addId(store, section.storageId);
    } else {
      current[section] = override;
      // 再設定は意図的なので、過去の削除トゥームストーンを解除する。
      await _overrideTombstones.removeId(store, section.storageId);
    }
    final encoded = <String, String>{
      for (final entry in current.entries)
        entry.key.storageId: entry.value.storageId,
    };
    await store.setString(_overridesKey, jsonEncode(encoded));
    return current;
  }

  AssetManagementDisplayMode? _storedMode(SharedPreferences store) {
    final raw = store.getString(_modeKey);
    for (final mode in AssetManagementDisplayMode.values) {
      if (mode.storageId == raw) {
        return mode;
      }
    }
    return null;
  }

  AssetManagementSectionId? _sectionFor(String? raw) {
    for (final section in AssetManagementSectionId.values) {
      if (section.storageId == raw) {
        return section;
      }
    }
    return null;
  }

  AssetManagementSectionVisibilityOverride? _overrideFor(String? raw) {
    for (final value in AssetManagementSectionVisibilityOverride.values) {
      if (value.storageId == raw) {
        return value;
      }
    }
    return null;
  }
}
