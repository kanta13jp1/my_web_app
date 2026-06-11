import 'package:shared_preferences/shared_preferences.dart';

/// 資産管理ページの表示モード。情報量を段階的に開示する。
enum AssetManagementDisplayMode { minimum, standard, full }

/// 各セクションの重要度ティア。モードとの対応:
/// minimum → essential のみ / standard → essential+standard / full → 全部。
enum AssetManagementSectionTier { essential, standard, full }

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

/// 表示モードの永続化と、ティア×モードの可視判定。
class AssetManagementDisplayModeStore {
  const AssetManagementDisplayModeStore();

  /// 既存ユーザーの体験を変えないため、未設定時はフル表示。
  static const AssetManagementDisplayMode defaultMode =
      AssetManagementDisplayMode.full;

  static const String _modeKey = 'asset_management_display_mode_v1';

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

  Future<AssetManagementDisplayMode> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(_modeKey);
    for (final mode in AssetManagementDisplayMode.values) {
      if (mode.storageId == raw) {
        return mode;
      }
    }
    return defaultMode;
  }

  Future<void> save(
    AssetManagementDisplayMode mode, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setString(_modeKey, mode.storageId);
  }
}
