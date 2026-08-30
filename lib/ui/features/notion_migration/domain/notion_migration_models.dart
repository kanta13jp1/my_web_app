import 'notion_vault_manifest_models.dart';

export 'notion_vault_manifest_models.dart';

enum NotionMigrationBatchStatus {
  inventory,
  migrating,
  verifying,
  awaitingSourceDeletion,
  completed,
  paused,
  failed;

  static NotionMigrationBatchStatus fromStorage(String? value) =>
      switch (value) {
        'migrating' => migrating,
        'verifying' => verifying,
        'awaiting_source_deletion' => awaitingSourceDeletion,
        'completed' => completed,
        'paused' => paused,
        'failed' => failed,
        _ => inventory,
      };

  String get label => switch (this) {
        inventory => '棚卸し中',
        migrating => '移行中',
        verifying => '照合中',
        awaitingSourceDeletion => 'Notion側削除待ち',
        completed => '完了',
        paused => '一時停止',
        failed => '要対応',
      };
}

enum NotionMigrationItemStatus {
  inventoried,
  queued,
  exporting,
  imported,
  verifying,
  verified,
  readyForSourceDeletion,
  sourceDeleted,
  failed,
  skipped;

  static NotionMigrationItemStatus fromStorage(String? value) =>
      switch (value) {
        'queued' => queued,
        'exporting' => exporting,
        'imported' => imported,
        'verifying' => verifying,
        'verified' => verified,
        'ready_for_source_deletion' => readyForSourceDeletion,
        'source_deleted' => sourceDeleted,
        'failed' => failed,
        'skipped' => skipped,
        _ => inventoried,
      };

  String get label => switch (this) {
        inventoried => '棚卸し済み',
        queued => '移行待ち',
        exporting => '書き出し中',
        imported => '取込済み',
        verifying => '照合中',
        verified => '照合済み',
        readyForSourceDeletion => 'Notion側削除可能',
        sourceDeleted => 'Notion側削除済み',
        failed => '要対応',
        skipped => '対象外',
      };
}

class NotionMigrationBatch {
  const NotionMigrationBatch({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.name,
    required this.status,
    required this.createdAt,
  });

  factory NotionMigrationBatch.fromJson(Map<String, dynamic> json) {
    return NotionMigrationBatch(
      id: json['id']?.toString() ?? '',
      workspaceId: json['workspace_id']?.toString() ?? '',
      workspaceName: json['workspace_name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: NotionMigrationBatchStatus.fromStorage(
        json['status']?.toString(),
      ),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String workspaceId;
  final String workspaceName;
  final String name;
  final NotionMigrationBatchStatus status;
  final DateTime createdAt;
}

class NotionMigrationItem {
  const NotionMigrationItem({
    required this.id,
    required this.sourceId,
    required this.sourceKind,
    required this.title,
    required this.sourcePath,
    required this.status,
    required this.passedChecks,
  });

  factory NotionMigrationItem.fromJson(
    Map<String, dynamic> json, {
    int passedChecks = 0,
  }) {
    return NotionMigrationItem(
      id: json['id']?.toString() ?? '',
      sourceId: json['source_id']?.toString() ?? '',
      sourceKind: json['source_kind']?.toString() ?? 'page',
      title: json['title']?.toString() ?? '',
      sourcePath: json['source_path']?.toString() ?? '',
      status: NotionMigrationItemStatus.fromStorage(json['status']?.toString()),
      passedChecks: passedChecks,
    );
  }

  final String id;
  final String sourceId;
  final String sourceKind;
  final String title;
  final String sourcePath;
  final NotionMigrationItemStatus status;
  final int passedChecks;
}

class NotionMigrationProgress {
  const NotionMigrationProgress({
    this.totalItems = 0,
    this.importedItems = 0,
    this.verifiedItems = 0,
    this.deletionReadyItems = 0,
    this.sourceDeletedItems = 0,
    this.failedItems = 0,
  });

  factory NotionMigrationProgress.fromJson(Map<String, dynamic> json) {
    int count(String key) => _notionMigrationInt(json[key]);
    return NotionMigrationProgress(
      totalItems: count('total_items'),
      importedItems: count('imported_items'),
      verifiedItems: count('verified_items'),
      deletionReadyItems: count('deletion_ready_items'),
      sourceDeletedItems: count('source_deleted_items'),
      failedItems: count('failed_items'),
    );
  }

  final int totalItems;
  final int importedItems;
  final int verifiedItems;
  final int deletionReadyItems;
  final int sourceDeletedItems;
  final int failedItems;

  double get importedRatio => totalItems == 0 ? 0 : importedItems / totalItems;
  double get verifiedRatio => totalItems == 0 ? 0 : verifiedItems / totalItems;
  double get deletedRatio =>
      totalItems == 0 ? 0 : sourceDeletedItems / totalItems;
}

class NotionMigrationSnapshot {
  const NotionMigrationSnapshot({
    this.batch,
    this.progress = const NotionMigrationProgress(),
    this.items = const <NotionMigrationItem>[],
    this.capabilities = const <NotionCapability>[],
    this.wbsReconciliation,
    this.wbsStageSummary,
    this.vaultManifestSummary,
  });

  final NotionMigrationBatch? batch;
  final NotionMigrationProgress progress;
  final List<NotionMigrationItem> items;
  final List<NotionCapability> capabilities;
  final NotionWbsReconciliation? wbsReconciliation;
  final NotionWbsStageSummary? wbsStageSummary;
  final NotionVaultManifestStageSummary? vaultManifestSummary;
}

class NotionInventoryActionResult {
  const NotionInventoryActionResult({
    required this.discovered,
    required this.remainingToExpand,
    required this.inventoryComplete,
  });

  factory NotionInventoryActionResult.fromJson(Map<String, dynamic> json) {
    return NotionInventoryActionResult(
      discovered: _notionMigrationInt(json['discovered']),
      remainingToExpand: _notionMigrationInt(json['remaining_to_expand']),
      inventoryComplete: json['inventory_complete'] == true,
    );
  }

  final int discovered;
  final int remainingToExpand;
  final bool inventoryComplete;
}

class NotionWbsReconciliation {
  const NotionWbsReconciliation({
    required this.siteRows,
    required this.notionRows,
    required this.siteDistinctIds,
    required this.notionDistinctIds,
    required this.notionDuplicateRows,
    required this.onlyInSite,
    required this.onlyInNotion,
    required this.exactMatches,
    required this.mismatchedRecords,
    required this.deletionGatePassed,
    required this.inventoryComplete,
    this.checkedAt,
  });

  factory NotionWbsReconciliation.fromJson(Map<String, dynamic> json) {
    return NotionWbsReconciliation(
      siteRows: _notionMigrationInt(json['site_rows']),
      notionRows: _notionMigrationInt(json['notion_rows']),
      siteDistinctIds: _notionMigrationInt(json['site_distinct_ids']),
      notionDistinctIds: _notionMigrationInt(json['notion_distinct_ids']),
      notionDuplicateRows: _notionMigrationInt(json['notion_duplicate_rows']),
      onlyInSite: _notionMigrationInt(json['only_in_site']),
      onlyInNotion: _notionMigrationInt(json['only_in_notion']),
      exactMatches: _notionMigrationInt(json['exact_matches']),
      mismatchedRecords: _notionMigrationInt(json['mismatched_records']),
      deletionGatePassed: json['deletion_gate_passed'] == true,
      inventoryComplete: json['inventory_complete'] == true,
      checkedAt: DateTime.tryParse(json['checked_at']?.toString() ?? ''),
    );
  }

  final int siteRows;
  final int notionRows;
  final int siteDistinctIds;
  final int notionDistinctIds;
  final int notionDuplicateRows;
  final int onlyInSite;
  final int onlyInNotion;
  final int exactMatches;
  final int mismatchedRecords;
  final bool deletionGatePassed;
  final bool inventoryComplete;
  final DateTime? checkedAt;
}

class NotionWbsStageSummary {
  const NotionWbsStageSummary({
    required this.stagedRows,
    required this.distinctTaskIds,
    required this.duplicateRows,
    required this.invalidTaskIds,
    this.stagedAt,
  });

  factory NotionWbsStageSummary.fromJson(Map<String, dynamic> json) {
    return NotionWbsStageSummary(
      stagedRows: _notionMigrationInt(json['staged_rows']),
      distinctTaskIds: _notionMigrationInt(json['distinct_task_ids']),
      duplicateRows: _notionMigrationInt(json['duplicate_rows']),
      invalidTaskIds: _notionMigrationInt(json['invalid_task_ids']),
      stagedAt: DateTime.tryParse(json['staged_at']?.toString() ?? ''),
    );
  }

  final int stagedRows;
  final int distinctTaskIds;
  final int duplicateRows;
  final int invalidTaskIds;
  final DateTime? stagedAt;
}

enum NotionParityStatus {
  inventory,
  planned,
  implemented,
  verifying,
  verified,
  gap,
  blocked;

  static NotionParityStatus fromStorage(String? value) => switch (value) {
        'planned' => planned,
        'implemented' => implemented,
        'verifying' => verifying,
        'verified' => verified,
        'gap' => gap,
        'blocked' => blocked,
        _ => inventory,
      };

  String get label => switch (this) {
        inventory => '棚卸し待ち',
        planned => '実装予定',
        implemented => '実装済み',
        verifying => '実データ検証中',
        verified => '検証済み',
        gap => '不足',
        blocked => '要対応',
      };
}

class NotionCapability {
  const NotionCapability({
    required this.key,
    required this.name,
    required this.notionScope,
    required this.siteRoutes,
    required this.status,
    this.isRequired = true,
    this.evidenceSummary = '',
  });

  factory NotionCapability.fromJson(Map<String, dynamic> json) {
    final routes = json['site_routes'];
    return NotionCapability(
      key: json['capability_key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      notionScope: json['notion_scope']?.toString() ?? '',
      siteRoutes: routes is List
          ? routes.map((route) => route.toString()).toList(growable: false)
          : const <String>[],
      status: NotionParityStatus.fromStorage(json['status']?.toString()),
      isRequired: json['is_required'] != false,
      evidenceSummary: json['evidence_summary']?.toString() ?? '',
    );
  }

  final String key;
  final String name;
  final String notionScope;
  final List<String> siteRoutes;
  final NotionParityStatus status;
  final bool isRequired;
  final String evidenceSummary;
}

int _notionMigrationInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
