/// 資産管理ページの各データ領域が「サーバ同期済み」か「この端末のみ (未同期)」かを
/// 表す出所 (provenance)。
///
/// ローカル永続 (SharedPreferences) を一次ストアとし Supabase へミラーする構成のため、
/// 「サーバにまだ無い = 他端末に出ない」状態を画面上で可視化するのに使う。
enum AssetSyncSource {
  /// Supabase に保存済み (他端末でも参照できる)。
  synced,

  /// この端末のローカルにのみ存在する (サーバ未同期 = 他端末に出ない)。
  localOnly,

  /// まだ何も保存されていない (同期対象なし)。
  empty,
}

/// 同期ステータスを表示する資産管理データ領域。
enum AssetSyncDomain {
  mainAccount,
  watchlist,
  revolving,
  debtOverrides,
  inflow,
  monthlyState,
}

extension AssetSyncDomainLabel on AssetSyncDomain {
  /// 画面表示用の日本語ラベル。
  String get label {
    switch (this) {
      case AssetSyncDomain.mainAccount:
        return 'メイン口座';
      case AssetSyncDomain.watchlist:
        return 'ウォッチリスト';
      case AssetSyncDomain.revolving:
        return 'リボ払い設定';
      case AssetSyncDomain.debtOverrides:
        return '支払日設定';
      case AssetSyncDomain.inflow:
        return '入金予定';
      case AssetSyncDomain.monthlyState:
        return '資産・負債データ';
    }
  }
}

/// 全体の同期ステータスのレベル (チップの色/文言の決定に使う)。
enum AssetSyncLevel {
  /// 未ログイン: 何も同期されない (この端末のみ)。
  loggedOut,

  /// ログイン済みで未同期領域なし。
  allSynced,

  /// ログイン済みだが一部の領域がローカルのみ (未同期)。
  partialLocal,
}

/// 各領域の出所から全体の同期ステータスを算出する純粋クラス (テスト可能)。
class AssetSyncStatusSummary {
  final bool loggedIn;
  final Map<AssetSyncDomain, AssetSyncSource> sources;

  const AssetSyncStatusSummary({
    required this.loggedIn,
    required this.sources,
  });

  bool get isLoggedOut => !loggedIn;

  /// 未同期 (= localOnly) の領域一覧 (enum 宣言順で安定)。
  List<AssetSyncDomain> get localOnlyDomains => <AssetSyncDomain>[
        for (final domain in AssetSyncDomain.values)
          if (sources[domain] == AssetSyncSource.localOnly) domain,
      ];

  /// 未同期領域の件数。
  int get localOnlyCount => localOnlyDomains.length;

  /// 同期対象 (synced か localOnly) のデータが1つでもあるか。
  bool get hasAnyData =>
      sources.values.any((source) => source != AssetSyncSource.empty);

  AssetSyncLevel get level {
    if (!loggedIn) {
      return AssetSyncLevel.loggedOut;
    }
    if (localOnlyCount > 0) {
      return AssetSyncLevel.partialLocal;
    }
    return AssetSyncLevel.allSynced;
  }

  /// 指定領域が画面上で「未同期」バッジを出すべきか。
  bool isLocalOnly(AssetSyncDomain domain) =>
      sources[domain] == AssetSyncSource.localOnly;

  /// 全体ステータスチップの見出し文言。
  String get headline {
    switch (level) {
      case AssetSyncLevel.loggedOut:
        return '未ログイン：この端末にのみ保存';
      case AssetSyncLevel.partialLocal:
        return '未同期 $localOnlyCount 項目';
      case AssetSyncLevel.allSynced:
        return 'サーバ同期済み';
    }
  }
}
