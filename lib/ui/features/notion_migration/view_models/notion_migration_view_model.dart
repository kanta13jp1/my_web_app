import 'package:flutter/foundation.dart';

import '../data/notion_migration_gateway.dart';
import '../data/notion_vault_manifest_service.dart';
import '../domain/notion_migration_models.dart';

enum NotionMigrationLoadStatus { initial, loading, ready, failure }

class NotionMigrationViewModel extends ChangeNotifier {
  NotionMigrationViewModel({
    required NotionMigrationGateway gateway,
    NotionVaultManifestPicker? vaultManifestPicker,
    NotionVaultManifestParser? vaultManifestParser,
  })  : _gateway = gateway,
        _vaultManifestPicker =
            vaultManifestPicker ?? const FilePickerNotionVaultManifestPicker(),
        _vaultManifestParser =
            vaultManifestParser ?? const NotionVaultManifestParser();

  final NotionMigrationGateway _gateway;
  final NotionVaultManifestPicker _vaultManifestPicker;
  final NotionVaultManifestParser _vaultManifestParser;

  NotionMigrationLoadStatus _loadStatus = NotionMigrationLoadStatus.initial;
  NotionMigrationSnapshot _snapshot = const NotionMigrationSnapshot();
  bool _isCreating = false;
  bool _isInventoryRunning = false;
  bool _isReconciliationRunning = false;
  bool _isWbsStaging = false;
  bool _isVaultManifestSelecting = false;
  bool _isVaultManifestStaging = false;
  NotionVaultManifestPreview? _vaultManifestPreview;
  bool _authenticationRequired = false;
  String? _errorMessage;
  String? _noticeMessage;

  NotionMigrationLoadStatus get loadStatus => _loadStatus;
  NotionMigrationSnapshot get snapshot => _snapshot;
  bool get isCreating => _isCreating;
  bool get isInventoryRunning => _isInventoryRunning;
  bool get isReconciliationRunning => _isReconciliationRunning;
  bool get isWbsStaging => _isWbsStaging;
  bool get isVaultManifestSelecting => _isVaultManifestSelecting;
  bool get isVaultManifestStaging => _isVaultManifestStaging;
  NotionVaultManifestPreview? get vaultManifestPreview => _vaultManifestPreview;
  bool get authenticationRequired => _authenticationRequired;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;

  Future<void> load() async {
    _loadStatus = NotionMigrationLoadStatus.loading;
    _authenticationRequired = false;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      _snapshot = await _gateway.loadLatest();
      _loadStatus = NotionMigrationLoadStatus.ready;
    } catch (error) {
      _setFailure(error);
    }
    notifyListeners();
  }

  Future<bool> createBatch({
    required String workspaceId,
    required String workspaceName,
    required String name,
  }) async {
    if (_isCreating ||
        workspaceId.trim().isEmpty ||
        workspaceName.trim().isEmpty ||
        name.trim().isEmpty) {
      return false;
    }
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _gateway.createBatch(
        workspaceId: workspaceId,
        workspaceName: workspaceName,
        name: name,
      );
      _snapshot = await _gateway.loadLatest();
      _loadStatus = NotionMigrationLoadStatus.ready;
      return true;
    } catch (error) {
      _setFailure(error, keepReady: true);
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<bool> startInventory() => _runInventory(expand: false);

  Future<bool> expandInventory() => _runInventory(expand: true);

  Future<bool> reconcileWbs() async {
    final batch = _snapshot.batch;
    if (batch == null || _isReconciliationRunning) return false;
    _isReconciliationRunning = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final result = await _gateway.reconcileWbs(batch.id);
      final refreshed = await _gateway.loadLatest();
      _snapshot = NotionMigrationSnapshot(
        batch: refreshed.batch,
        progress: refreshed.progress,
        items: refreshed.items,
        capabilities: refreshed.capabilities,
        wbsReconciliation: result,
        wbsStageSummary: refreshed.wbsStageSummary,
        vaultManifestSummary: refreshed.vaultManifestSummary,
      );
      _noticeMessage = result.deletionGatePassed
          ? 'WBSの全ID・全ミラー項目が一致しました。7項目の残りの検証が終わるまでNotion側は保持します。'
          : 'WBSに差分があります。重複・片側のみ・属性不一致を解消するまでNotion側は削除しません。';
      return true;
    } catch (error) {
      _errorMessage = _reconciliationError(error);
      return false;
    } finally {
      _isReconciliationRunning = false;
      notifyListeners();
    }
  }

  Future<bool> stageWbs() async {
    final batch = _snapshot.batch;
    if (batch == null || _isWbsStaging) return false;
    _isWbsStaging = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final result = await _gateway.stageWbs(batch.id);
      final refreshed = await _gateway.loadLatest();
      _snapshot = NotionMigrationSnapshot(
        batch: refreshed.batch,
        progress: refreshed.progress,
        items: refreshed.items,
        capabilities: refreshed.capabilities,
        wbsReconciliation: refreshed.wbsReconciliation,
        wbsStageSummary: result,
        vaultManifestSummary: refreshed.vaultManifestSummary,
      );
      _noticeMessage =
          'WBS ${result.stagedRows}行を安全領域へ保存しました。重複${result.duplicateRows}行と属性差分を解決するまで本番WBS・Notion側は変更しません。';
      return true;
    } catch (error) {
      _errorMessage = _stagingError(error);
      return false;
    } finally {
      _isWbsStaging = false;
      notifyListeners();
    }
  }

  Future<bool> selectVaultManifest() async {
    if (_isVaultManifestSelecting || _isVaultManifestStaging) return false;
    _isVaultManifestSelecting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final picked = await _vaultManifestPicker.pick();
      if (picked == null) return false;
      final preview = _vaultManifestParser.parse(picked);
      _vaultManifestPreview = preview;
      _noticeMessage =
          '${preview.stageableCount}件の構造情報を確認しました。本文・プロパティ値・除外${preview.excludedCount}件のパスは送信しません。';
      return true;
    } catch (error) {
      _errorMessage = _vaultManifestError(error);
      return false;
    } finally {
      _isVaultManifestSelecting = false;
      notifyListeners();
    }
  }

  Future<bool> stageVaultManifest() async {
    final batch = _snapshot.batch;
    final preview = _vaultManifestPreview;
    if (batch == null ||
        preview == null ||
        _isVaultManifestStaging ||
        _isVaultManifestSelecting) {
      return false;
    }
    _isVaultManifestStaging = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final result = await _gateway.stageVaultManifest(
        batchId: batch.id,
        manifest: preview,
      );
      final refreshed = await _gateway.loadLatest();
      _snapshot = NotionMigrationSnapshot(
        batch: refreshed.batch,
        progress: refreshed.progress,
        items: refreshed.items,
        capabilities: refreshed.capabilities,
        wbsReconciliation: refreshed.wbsReconciliation,
        wbsStageSummary: refreshed.wbsStageSummary,
        vaultManifestSummary: result,
      );
      _noticeMessage =
          'Obsidian構造情報${result.stagedEntryCount}件を安全領域へ保存しました。除外${result.excludedCount}件のパス・本文・認証情報は保存していません。';
      return true;
    } catch (error) {
      _errorMessage = _vaultManifestError(error, staging: true);
      return false;
    } finally {
      _isVaultManifestStaging = false;
      notifyListeners();
    }
  }

  Future<bool> _runInventory({required bool expand}) async {
    final batch = _snapshot.batch;
    if (batch == null || _isInventoryRunning) return false;
    _isInventoryRunning = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final result = expand
          ? await _gateway.expandInventory(batch.id)
          : await _gateway.startInventory(batch.id);
      _snapshot = await _gateway.loadLatest();
      _noticeMessage = result.inventoryComplete
          ? 'APIで参照できる範囲の再帰棚卸しが完了しました。次はエクスポートとの全件照合です。'
          : '${result.discovered}件を発見しました。残り${result.remainingToExpand}件を再帰棚卸しします。';
      return true;
    } catch (error) {
      _errorMessage = _inventoryError(error);
      return false;
    } finally {
      _isInventoryRunning = false;
      notifyListeners();
    }
  }

  void _setFailure(Object error, {bool keepReady = false}) {
    _loadStatus = keepReady
        ? NotionMigrationLoadStatus.ready
        : NotionMigrationLoadStatus.failure;
    _authenticationRequired = error is NotionMigrationException &&
        error.code == 'authentication_required';
    _errorMessage = _authenticationRequired
        ? 'この機能を使うにはログインしてください。'
        : '移行台帳を読み込めませんでした。時間をおいて再試行してください。';
  }

  String _inventoryError(Object error) {
    if (error is NotionMigrationException) {
      return switch (error.code) {
        'admin_required' => 'Notion接続の棚卸しは管理者だけが実行できます。',
        'notion_not_configured' => 'サーバー側のNotion接続が未設定です。',
        'batch_not_found' => '移行台帳が見つかりません。再読み込みしてください。',
        _ => 'Notion棚卸しに失敗しました。接続権限と共有範囲を確認してください。',
      };
    }
    return 'Notion棚卸しに失敗しました。接続権限と共有範囲を確認してください。';
  }

  String _reconciliationError(Object error) {
    if (error is NotionMigrationException) {
      return switch (error.code) {
        'admin_required' => 'WBS照合は管理者だけが実行できます。',
        'notion_not_configured' ||
        'wbs_source_not_configured' =>
          'サーバー側のNotion WBS接続が未設定です。',
        'wbs_database_has_multiple_data_sources' =>
          'WBSデータベースに複数のデータソースがあります。対象IDをサーバー設定で明示してください。',
        'batch_not_found' => '移行台帳が見つかりません。再読み込みしてください。',
        _ => 'WBS全件照合に失敗しました。Notion共有範囲と接続状態を確認してください。',
      };
    }
    return 'WBS全件照合に失敗しました。Notion共有範囲と接続状態を確認してください。';
  }

  String _stagingError(Object error) {
    if (error is NotionMigrationException) {
      return switch (error.code) {
        'admin_required' => 'WBS取込は管理者だけが実行できます。',
        'notion_not_configured' ||
        'wbs_source_not_configured' =>
          'サーバー側のNotion WBS接続が未設定です。',
        'wbs_stage_inventory_incomplete' =>
          'Notion WBSの全ページを取得できなかったため、安全領域への取込を中止しました。',
        'batch_not_found' => '移行台帳が見つかりません。再読み込みしてください。',
        _ => 'WBSの安全領域への取込に失敗しました。本番WBSとNotion側は変更していません。',
      };
    }
    return 'WBSの安全領域への取込に失敗しました。本番WBSとNotion側は変更していません。';
  }

  String _vaultManifestError(Object error, {bool staging = false}) {
    if (error is NotionVaultManifestException) {
      return switch (error.code) {
        'manifest_size_invalid' => 'manifestが空か、10MBの上限を超えています。',
        'manifest_json_invalid' => '選択したファイルは有効なJSONではありません。',
        'manifest_policy_invalid' ||
        'manifest_exclusion_policy_invalid' =>
          '安全ポリシーを確認できないmanifestのため取込を中止しました。',
        'manifest_path_invalid' => '安全でない相対パスを検出したため取込を中止しました。',
        'manifest_hash_invalid' => 'ファイル照合ハッシュが不正なため取込を中止しました。',
        _ => 'Obsidian manifestを検証できませんでした。ローカル生成器で再作成してください。',
      };
    }
    if (error is NotionMigrationException &&
        error.code == 'authentication_required') {
      return '安全領域へ保存するにはログインしてください。';
    }
    return staging
        ? 'Obsidian構造情報の安全領域への保存に失敗しました。保管庫とNotion側は変更していません。'
        : 'Obsidian manifestを読み込めませんでした。ファイルを確認してください。';
  }
}
