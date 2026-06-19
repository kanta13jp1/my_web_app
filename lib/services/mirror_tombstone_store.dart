import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// トゥームストーン GC の上限/期限。既定はローカル定数だが、サーバ
/// (asset_pref_mirror) から取得した値で上書きできる (#part287 リモート調整)。
class AssetTombstoneGcConfig {
  const AssetTombstoneGcConfig({this.maxCount = 1000, this.maxAgeDays = 365});

  final int maxCount;
  final int maxAgeDays;

  /// ミラー値 (`{'max_count': N, 'max_age_days': M}`) から構築する。
  /// 欠落/不正値は既定を維持し、正の範囲にクランプする。
  factory AssetTombstoneGcConfig.fromMirrorValue(Object? value) {
    const fallback = AssetTombstoneGcConfig();
    if (value is! Map) {
      return fallback;
    }
    int pick(String key, int fallbackValue, int min, int max) {
      final raw = (value[key] as num?)?.toInt();
      if (raw == null) {
        return fallbackValue;
      }
      return raw.clamp(min, max);
    }

    return AssetTombstoneGcConfig(
      maxCount: pick('max_count', fallback.maxCount, 1, 100000),
      maxAgeDays: pick('max_age_days', fallback.maxAgeDays, 1, 36500),
    );
  }

  /// mirror upsert / ローカル保存用の値へ変換する (#part288 設定 UI)。
  Map<String, dynamic> toMirrorValue() {
    return <String, dynamic>{
      'max_count': maxCount,
      'max_age_days': maxAgeDays,
    };
  }
}

/// 削除トゥームストーン(「一度消した ID」の集合)を 1 つの SharedPreferences
/// キー上で管理する汎用ストア。和集合マージやサーバ復元での復活抑止、他端末
/// 削除の伝播に使う。入金予定だけでなく表示設定など他のミラー pref でも
/// 再利用できるよう、ドメイン非依存に切り出した (#part288 汎用化)。
///
/// 保存形式は `[{"id": ..., "at": <iso>}, ...]`。part 285 の旧プレーン配列
/// (`["id", ...]`) も後方互換で読み込む。書き込み・読み出し時に期限切れ
/// (gcConfig.maxAgeDays) と件数超過 (gcConfig.maxCount) を破棄する。
class MirrorTombstoneStore {
  const MirrorTombstoneStore({
    required this.storageKey,
    this.gcConfig = const AssetTombstoneGcConfig(),
    this.nowProvider,
  });

  final String storageKey;
  final AssetTombstoneGcConfig gcConfig;
  final DateTime Function()? nowProvider;

  DateTime _now() => nowProvider?.call() ?? DateTime.now();

  /// 全 write 系メソッド (addId / removeId / prune / mergeRemoteIds) の
  /// read-modify-write を process-wide で直列化するロック。単一 pref blob への
  /// RMW が並行 (= 各呼び出しサイトが unawaited で発火) で交錯すると、後発の
  /// write が先発の `setString` 着地前に古い blob を読み、相手の変更を
  /// 取りこぼす lost-update が起こり得る (= stale tombstone 残存 → 他端末へ
  /// 誤伝播)。読み取り (`activeIds` / `decodeMirror`) はスナップショットで
  /// 十分なためロック不要。
  ///
  /// 防御的ハードニング: 現行の legacy `SharedPreferences` は cache を
  /// `setString` 内で同期更新し、本ストアの read→write 間に await を挟まない
  /// ため back-to-back の発火では実際には取りこぼさない。だが
  /// `SharedPreferencesAsync` への移行や read/write 間に await が入る将来の
  /// 改修では race が顕在化する。同期レイヤの姉妹 [AssetSyncDirtyKeysStore]
  /// (#3415) と同型のガードを横展開し、その回帰を構造的に封じる。
  /// `const` コンストラクタとは両立する (static はインスタンス state でない)。
  static Future<void> _writeLock = Future<void>.value();

  /// [action] を前の write 完了後に直列実行し、その結果/例外を呼び出し元へ
  /// 伝播する。ロック鎖自体は失敗で途切れさせない (onError で吸収)。
  /// `catchError` は非 void future を null 完了させ TypeError になり得るため、
  /// `prune` (Future<int>) / `mergeRemoteIds` (Future<Set>) にも対応できるよう
  /// `then<void>((_) {}, onError:)` でロック鎖を void 化する。
  Future<T> _runLocked<T>(Future<T> Function() action) {
    final run = _writeLock.then((_) => action());
    _writeLock = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  /// トゥームストーン ID 集合をミラー upsert 用の値へ変換する
  /// (`{'ids': [...]}`)。ページと統合テストで同一の形を共有する (#part287)。
  static Map<String, dynamic> encodeMirror(Iterable<String> ids) {
    return <String, dynamic>{
      'ids': [
        for (final id in ids)
          if (id.isNotEmpty) id,
      ],
    };
  }

  /// ミラー値 (`{'ids': [...]}`) から ID リストを取り出す。形が不正なら空。
  static List<String> decodeMirror(Object? value) {
    if (value is! Map) {
      return const <String>[];
    }
    final rawIds = value['ids'];
    if (rawIds is! List) {
      return const <String>[];
    }
    return <String>[
      for (final id in rawIds)
        if ((id?.toString() ?? '').isNotEmpty) id.toString(),
    ];
  }

  /// 有効な (期限内・上限内の) 削除済み ID 集合を返す。
  Set<String> activeIds(SharedPreferences store) {
    return <String>{
      for (final entry in _gcEntries(_readEntries(store.getString(storageKey))))
        entry['id']!,
    };
  }

  /// ID を 1 件トゥームストーン化する (タイムスタンプ付きで追記し GC)。
  /// read-modify-write を [_runLocked] で直列化する。
  Future<void> addId(SharedPreferences store, String id) {
    if (id.isEmpty) {
      return Future<void>.value();
    }
    return _runLocked(() async {
      final entries = _gcEntries(_readEntries(store.getString(storageKey)))
        ..removeWhere((entry) => entry['id'] == id);
      entries.add(<String, String>{
        'id': id,
        'at': _now().toUtc().toIso8601String(),
      });
      await _writeEntries(store, entries);
    });
  }

  /// ID のトゥームストーンを解除する (再追加を許す / #part291)。
  /// 表示設定 override のように ID (= sectionId) が再利用されるドメイン向け。
  /// read-modify-write を [_runLocked] で直列化する。
  Future<void> removeId(SharedPreferences store, String id) {
    return _runLocked(() async {
      final entries = _gcEntries(_readEntries(store.getString(storageKey)));
      final before = entries.length;
      entries.removeWhere((entry) => entry['id'] == id);
      if (entries.length != before) {
        await _writeEntries(store, entries);
      }
    });
  }

  /// 期限切れ・上限超過のトゥームストーンを今すぐ掃除し、削除件数を返す
  /// (手動 GC / #part291)。読み出し時にも GC されるが、件数を見せる用途。
  /// read-modify-write を [_runLocked] で直列化する。
  Future<int> prune(SharedPreferences store) {
    return _runLocked(() async {
      final entries = _readEntries(store.getString(storageKey));
      final kept = _gcEntries(entries);
      final removed = entries.length - kept.length;
      if (removed > 0) {
        await _writeEntries(store, kept);
      }
      return removed;
    });
  }

  /// 他端末由来の ID 群を取り込む。実際に取り込んだ (空でない) ID 集合を返す。
  /// ローカル項目の削除はドメイン側 (呼び出し元) が行う。
  /// read-modify-write を [_runLocked] で直列化する。
  Future<Set<String>> mergeRemoteIds(
    SharedPreferences store,
    Iterable<String> remoteIds,
  ) {
    final incoming = remoteIds.where((id) => id.isNotEmpty).toSet();
    if (incoming.isEmpty) {
      return Future<Set<String>>.value(incoming);
    }
    return _runLocked(() async {
      final entries = _gcEntries(_readEntries(store.getString(storageKey)));
      final existingIds = <String>{for (final entry in entries) entry['id']!};
      final nowIso = _now().toUtc().toIso8601String();
      for (final id in incoming) {
        if (existingIds.add(id)) {
          entries.add(<String, String>{'id': id, 'at': nowIso});
        }
      }
      await _writeEntries(store, _gcEntries(entries));
      return incoming;
    });
  }

  /// 後方互換読み込み: 旧形式 (["id",...]) と新形式 ([{"id","at"},...]) の
  /// 双方を受け付ける。旧形式やタイムスタンプ欠落は現時刻を付与する
  /// (= 既存トゥームストーンを即時に期限切れさせない)。
  List<Map<String, String>> _readEntries(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <Map<String, String>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, String>>[];
      }
      final nowIso = _now().toUtc().toIso8601String();
      final entries = <Map<String, String>>[];
      for (final entry in decoded) {
        if (entry is String) {
          if (entry.isNotEmpty) {
            entries.add(<String, String>{'id': entry, 'at': nowIso});
          }
        } else if (entry is Map) {
          final id = entry['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            entries.add(<String, String>{
              'id': id,
              'at': entry['at']?.toString() ?? nowIso,
            });
          }
        }
      }
      return entries;
    } catch (_) {
      return <Map<String, String>>[];
    }
  }

  /// 期限切れ (>gcConfig.maxAgeDays) を捨て、件数超過分は新しい順に残す。
  List<Map<String, String>> _gcEntries(List<Map<String, String>> entries) {
    final now = _now();
    final maxAgeDays = gcConfig.maxAgeDays;
    final kept = <Map<String, String>>[];
    for (final entry in entries) {
      final at = DateTime.tryParse(entry['at'] ?? '');
      if (at == null || now.difference(at).inDays <= maxAgeDays) {
        kept.add(entry);
      }
    }
    if (kept.length > gcConfig.maxCount) {
      // 件数上限超過分は実際の削除時刻('at')が新しい順で残す。
      // mergeRemoteIds はリモート ID を末尾に追記するため、純粋な挿入順依存
      // (旧 sublist)だと旧形式の混在やマージ順次第で新しいトゥームストーンを
      // 取りこぼし得る(=削除済み項目が他端末から復活し得る)。
      // 同時刻('at' が等しい)場合は挿入が新しい方(末尾)を優先し、従来の
      // 「最古の挿入を捨てる」挙動を保つ(固定クロック下での安定性)。
      final order = <MapEntry<int, Map<String, String>>>[
        for (var i = 0; i < kept.length; i++) MapEntry(i, kept[i]),
      ]..sort((a, b) {
          final atA = DateTime.tryParse(a.value['at'] ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final atB = DateTime.tryParse(b.value['at'] ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final byAt = atB.compareTo(atA);
          return byAt != 0 ? byAt : b.key.compareTo(a.key);
        });
      return <Map<String, String>>[
        for (final entry in order.take(gcConfig.maxCount)) entry.value,
      ];
    }
    return kept;
  }

  /// 実際の blob 書き込みプリミティブ。呼び出しは必ず [_runLocked] のロック
  /// 区間 *内* からのみ行うこと (= 各 write 系メソッド経由)。ここで再度
  /// [_runLocked] を取得すると、外側のロック区間が本 write の完了を待ち、本
  /// write が同じロック鎖の解放を待つ self-deadlock になるため、本メソッド
  /// 自体はロックを取らない。
  Future<void> _writeEntries(
    SharedPreferences store,
    List<Map<String, String>> entries,
  ) async {
    await store.setString(storageKey, jsonEncode(entries));
  }
}
