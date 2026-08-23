import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/notion_migration_models.dart';

class NotionMigrationException implements Exception {
  const NotionMigrationException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => message ?? code;
}

abstract class NotionMigrationGateway {
  Future<NotionMigrationSnapshot> loadLatest();

  Future<NotionMigrationBatch> createBatch({
    required String workspaceId,
    required String workspaceName,
    required String name,
  });

  Future<NotionInventoryActionResult> startInventory(String batchId);

  Future<NotionInventoryActionResult> expandInventory(String batchId);

  Future<NotionWbsReconciliation> reconcileWbs(String batchId);

  Future<NotionWbsStageSummary> stageWbs(String batchId);
}

class SupabaseNotionMigrationGateway implements NotionMigrationGateway {
  SupabaseNotionMigrationGateway({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const NotionMigrationException('authentication_required');
    }
    return id;
  }

  @override
  Future<NotionMigrationSnapshot> loadLatest() async {
    final userId = _userId;
    final rows = await _client
        .from('notion_migration_batches')
        .select()
        .eq('user_id', userId)
        .isFilter('archived_at', null)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return const NotionMigrationSnapshot();

    final batch = NotionMigrationBatch.fromJson(
      Map<String, dynamic>.from(rows.first),
    );
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _client
          .from('notion_migration_batch_progress')
          .select()
          .eq('batch_id', batch.id)
          .limit(1),
      _client
          .from('notion_migration_items')
          .select()
          .eq('batch_id', batch.id)
          .order('source_path')
          .limit(500),
      _client
          .from('notion_migration_checks')
          .select('item_id,status')
          .eq('user_id', userId)
          .eq('status', 'passed'),
      _client
          .from('notion_migration_items')
          .select('metadata')
          .eq('batch_id', batch.id)
          .eq('source_kind', 'data_source')
          .order('updated_at', ascending: false)
          .limit(100),
      _client
          .from('notion_migration_capabilities')
          .select()
          .eq('batch_id', batch.id)
          .order('capability_key'),
      _client
          .from('notion_migration_wbs_stage_progress')
          .select()
          .eq('batch_id', batch.id)
          .limit(1),
    ]);

    final progressRows = results[0];
    final itemRows = results[1];
    final checkRows = results[2];
    final dataSourceRows = results[3];
    final capabilityRows = results[4];
    final stageRows = results[5];
    final checksByItem = <String, int>{};
    for (final check in checkRows) {
      final itemId = check['item_id']?.toString();
      if (itemId != null) {
        checksByItem.update(itemId, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    NotionWbsReconciliation? reconciliation;
    for (final row in dataSourceRows) {
      final metadata = row['metadata'];
      if (metadata is! Map) continue;
      final value = metadata['wbs_reconciliation'];
      if (value is Map) {
        reconciliation = NotionWbsReconciliation.fromJson(
          Map<String, dynamic>.from(value),
        );
        break;
      }
    }

    return NotionMigrationSnapshot(
      batch: batch,
      progress: progressRows.isEmpty
          ? const NotionMigrationProgress()
          : NotionMigrationProgress.fromJson(progressRows.first),
      items: itemRows
          .map(
            (row) => NotionMigrationItem.fromJson(
              row,
              passedChecks: checksByItem[row['id']?.toString()] ?? 0,
            ),
          )
          .toList(growable: false),
      capabilities:
          capabilityRows.map(NotionCapability.fromJson).toList(growable: false),
      wbsReconciliation: reconciliation,
      wbsStageSummary: stageRows.isEmpty
          ? null
          : NotionWbsStageSummary.fromJson(stageRows.first),
    );
  }

  @override
  Future<NotionMigrationBatch> createBatch({
    required String workspaceId,
    required String workspaceName,
    required String name,
  }) async {
    final row = await _client
        .from('notion_migration_batches')
        .insert({
          'user_id': _userId,
          'workspace_id': workspaceId.trim(),
          'workspace_name': workspaceName.trim(),
          'name': name.trim(),
        })
        .select()
        .single();
    return NotionMigrationBatch.fromJson(row);
  }

  @override
  Future<NotionInventoryActionResult> startInventory(String batchId) {
    return _runInventoryAction('inventory.start', batchId);
  }

  @override
  Future<NotionInventoryActionResult> expandInventory(String batchId) {
    return _runInventoryAction('inventory.expand', batchId);
  }

  @override
  Future<NotionWbsReconciliation> reconcileWbs(String batchId) async {
    final data = await _runAction('reconcile.wbs', batchId);
    return NotionWbsReconciliation.fromJson(data);
  }

  @override
  Future<NotionWbsStageSummary> stageWbs(String batchId) async {
    final data = await _runAction('stage.wbs', batchId);
    return NotionWbsStageSummary.fromJson(data);
  }

  Future<NotionInventoryActionResult> _runInventoryAction(
    String action,
    String batchId,
  ) async {
    final data = await _runAction(action, batchId);
    return NotionInventoryActionResult.fromJson(data);
  }

  Future<Map<String, dynamic>> _runAction(
    String action,
    String batchId,
  ) async {
    _userId;
    try {
      final response = await _client.functions.invoke(
        'notion-migration-hub',
        body: <String, dynamic>{
          'action': action,
          'batch_id': batchId,
          if (action == 'inventory.expand') 'limit': 2,
        },
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      if (response.status < 200 ||
          response.status >= 300 ||
          data['success'] != true) {
        throw NotionMigrationException(
          data['error']?.toString() ?? 'inventory_failed',
        );
      }
      return data;
    } on FunctionException catch (error) {
      final details = error.details is Map
          ? Map<String, dynamic>.from(error.details as Map)
          : const <String, dynamic>{};
      throw NotionMigrationException(
        details['error']?.toString() ?? 'http_${error.status}',
        error.reasonPhrase,
      );
    }
  }
}
