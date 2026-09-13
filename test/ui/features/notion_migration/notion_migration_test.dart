import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/notion_migration/data/notion_migration_gateway.dart';
import 'package:my_web_app/ui/features/notion_migration/data/notion_vault_manifest_service.dart';
import 'package:my_web_app/ui/features/notion_migration/domain/notion_migration_models.dart';
import 'package:my_web_app/ui/features/notion_migration/notion_migration_feature.dart';
import 'package:my_web_app/ui/features/notion_migration/view_models/notion_migration_view_model.dart';

void main() {
  group('Notion migration models', () {
    test('progress ratios stay finite for an empty inventory', () {
      const progress = NotionMigrationProgress();

      expect(progress.importedRatio, 0);
      expect(progress.verifiedRatio, 0);
      expect(progress.deletedRatio, 0);
    });

    test('storage statuses map to deletion-safe states', () {
      expect(
        NotionMigrationItemStatus.fromStorage('ready_for_source_deletion'),
        NotionMigrationItemStatus.readyForSourceDeletion,
      );
      expect(
        NotionMigrationBatchStatus.fromStorage('awaiting_source_deletion'),
        NotionMigrationBatchStatus.awaitingSourceDeletion,
      );
    });

    test('WBS reconciliation remains deletion-blocked for any difference', () {
      final result = NotionWbsReconciliation.fromJson(const {
        'site_rows': 10,
        'notion_rows': 11,
        'site_distinct_ids': 10,
        'notion_distinct_ids': 10,
        'notion_duplicate_rows': 1,
        'only_in_site': 0,
        'only_in_notion': 0,
        'exact_matches': 9,
        'mismatched_records': 1,
        'inventory_complete': true,
        'deletion_gate_passed': false,
      });

      expect(result.notionDuplicateRows, 1);
      expect(result.deletionGatePassed, isFalse);
    });

    test('capability rows preserve persisted verification state', () {
      final capability = NotionCapability.fromJson(const {
        'capability_key': 'page_tree_blocks',
        'name': 'ページ階層・ブロック',
        'notion_scope': '階層ページとブロック',
        'site_routes': ['/notes'],
        'status': 'verified',
        'is_required': true,
        'evidence_summary': '実データ3件で往復照合済み',
      });

      expect(capability.status, NotionParityStatus.verified);
      expect(capability.siteRoutes, ['/notes']);
      expect(capability.evidenceSummary, contains('往復照合'));
    });

    test('WBS staging summary reports retained duplicates', () {
      final summary = NotionWbsStageSummary.fromJson(const {
        'staged_rows': 12,
        'distinct_task_ids': 10,
        'duplicate_rows': 2,
        'invalid_task_ids': 0,
        'staged_at': '2026-08-23T00:00:00Z',
      });

      expect(summary.stagedRows, 12);
      expect(summary.duplicateRows, 2);
      expect(summary.stagedAt, DateTime.utc(2026, 8, 23));
    });
  });

  group('NotionMigrationViewModel', () {
    test('loads the current migration snapshot', () async {
      final gateway = _FakeGateway(snapshot: _sampleSnapshot());
      final viewModel = NotionMigrationViewModel(gateway: gateway);

      await viewModel.load();

      expect(viewModel.loadStatus, NotionMigrationLoadStatus.ready);
      expect(viewModel.snapshot.progress.totalItems, 2);
      expect(viewModel.snapshot.items.single.passedChecks, 7);
      expect(viewModel.snapshot.capabilities, hasLength(2));
    });

    test('recognizes authentication failure', () async {
      final viewModel = NotionMigrationViewModel(
        gateway: _AuthenticationRequiredGateway(),
      );

      await viewModel.load();

      expect(viewModel.loadStatus, NotionMigrationLoadStatus.failure);
      expect(viewModel.authenticationRequired, isTrue);
    });
  });

  testWidgets('compact empty state exposes ledger and safety gate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_FakeGateway()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notion-migration-compact')), findsOneWidget);
    expect(
      find.byKey(const Key('notion-migration-create-batch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notion-migration-safety-gate')),
      findsOneWidget,
    );
    expect(find.textContaining('7項目'), findsWidgets);
  });

  testWidgets('wide state shows counts and feature parity matrix', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_FakeGateway(snapshot: _sampleSnapshot())));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notion-migration-wide')), findsOneWidget);
    expect(find.text('Notion全件移行'), findsOneWidget);
    expect(find.textContaining('照合 7/7'), findsOneWidget);
    expect(
      find.byKey(const Key('notion-migration-inventory-start')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notion-migration-inventory-expand')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notion-migration-reconcile-wbs')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('notion-migration-stage-wbs')), findsOneWidget);
    expect(
      find.byKey(const Key('notion-migration-wbs-reconciliation')),
      findsOneWidget,
    );
    expect(find.text('削除不可'), findsOneWidget);
    expect(
      find.byKey(const Key('notion-migration-feature-matrix')),
      findsOneWidget,
    );
    expect(find.text('必須 1/2 検証済み'), findsOneWidget);
    expect(find.text('検証済み'), findsWidgets);
    expect(find.text('不足'), findsOneWidget);
    expect(
      find.byKey(const Key('notion-migration-wbs-stage-summary')),
      findsOneWidget,
    );
    expect(find.text('本番未反映'), findsOneWidget);
  });

  testWidgets('authentication failure offers login route', (tester) async {
    await tester.pumpWidget(_app(_AuthenticationRequiredGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notion-migration-login')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-page')), findsOneWidget);
  });

  testWidgets('vault manifest previews and stages allowlisted structure only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeGateway(snapshot: _sampleSnapshot());

    await tester.pumpWidget(
      _app(
        gateway,
        vaultManifestPicker: _FakeVaultManifestPicker(_pickedManifest()),
      ),
    );
    await tester.pumpAndSettle();

    final pickButton = find.byKey(
      const Key('notion-migration-vault-manifest-pick'),
    );
    await tester.ensureVisible(pickButton);
    await tester.tap(pickButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('notion-migration-vault-manifest-preview')),
      findsOneWidget,
    );
    expect(find.text('自動保存'), findsOneWidget);
    expect(find.text('認証候補'), findsOneWidget);

    final stageButton = find.byKey(
      const Key('notion-migration-vault-manifest-stage'),
    );
    await tester.ensureVisible(stageButton);
    await tester.tap(stageButton);
    await tester.pumpAndSettle();
    expect(find.text('構造情報だけを保存しますか？'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('notion-migration-vault-manifest-confirm')),
    );
    await tester.pumpAndSettle();

    expect(gateway.stagedManifest, isNotNull);
    expect(gateway.stagedManifest!.entries, hasLength(1));
    expect(gateway.stagedManifest!.entries.single.relativePath, 'HOME.md');
    expect(
      find.byKey(const Key('notion-migration-vault-manifest-summary')),
      findsOneWidget,
    );
    expect(find.textContaining('除外パスと本文は保持していません'), findsOneWidget);
  });
}

Widget _app(
  NotionMigrationGateway gateway, {
  NotionVaultManifestPicker? vaultManifestPicker,
}) {
  return MaterialApp(
    routes: {
      '/login': (_) =>
          const Scaffold(body: Text('Login', key: Key('login-page'))),
    },
    home: NotionMigrationFeature(
      gateway: gateway,
      vaultManifestPicker: vaultManifestPicker,
    ),
  );
}

NotionMigrationSnapshot _sampleSnapshot() {
  return NotionMigrationSnapshot(
    batch: NotionMigrationBatch(
      id: '11111111-1111-4111-8111-111111111111',
      workspaceId: 'workspace-test',
      workspaceName: 'テスト用ワークスペース',
      name: 'Notion全件移行',
      status: NotionMigrationBatchStatus.verifying,
      createdAt: DateTime.utc(2026, 8, 23),
    ),
    progress: const NotionMigrationProgress(
      totalItems: 2,
      importedItems: 2,
      verifiedItems: 1,
      deletionReadyItems: 1,
    ),
    items: const [
      NotionMigrationItem(
        id: '22222222-2222-4222-8222-222222222222',
        sourceId: 'source-test',
        sourceKind: 'page',
        title: 'テストページ',
        sourcePath: '/テストページ',
        status: NotionMigrationItemStatus.readyForSourceDeletion,
        passedChecks: 7,
      ),
    ],
    capabilities: const [
      NotionCapability(
        key: 'page_tree_blocks',
        name: 'ページ階層・ブロック',
        notionScope: '階層ページとブロック',
        siteRoutes: ['/notes', '/wiki-database'],
        status: NotionParityStatus.verified,
        evidenceSummary: '実データ3件で往復照合済み',
      ),
      NotionCapability(
        key: 'database_data_sources',
        name: 'データベース・データソース',
        notionScope: '複数データソースと保存済みビュー',
        siteRoutes: ['/table-data'],
        status: NotionParityStatus.gap,
      ),
    ],
    wbsReconciliation: const NotionWbsReconciliation(
      siteRows: 9,
      notionRows: 10,
      siteDistinctIds: 9,
      notionDistinctIds: 9,
      notionDuplicateRows: 1,
      onlyInSite: 0,
      onlyInNotion: 0,
      exactMatches: 8,
      mismatchedRecords: 1,
      deletionGatePassed: false,
      inventoryComplete: true,
    ),
    wbsStageSummary: const NotionWbsStageSummary(
      stagedRows: 10,
      distinctTaskIds: 9,
      duplicateRows: 1,
      invalidTaskIds: 0,
      stagedAt: null,
    ),
  );
}

class _FakeGateway implements NotionMigrationGateway {
  _FakeGateway({NotionMigrationSnapshot? snapshot})
      : _snapshot = snapshot ?? const NotionMigrationSnapshot();

  NotionMigrationSnapshot _snapshot;
  NotionVaultManifestPreview? stagedManifest;

  @override
  Future<NotionMigrationSnapshot> loadLatest() async => _snapshot;

  @override
  Future<NotionMigrationBatch> createBatch({
    required String workspaceId,
    required String workspaceName,
    required String name,
  }) async {
    final batch = NotionMigrationBatch(
      id: '33333333-3333-4333-8333-333333333333',
      workspaceId: workspaceId,
      workspaceName: workspaceName,
      name: name,
      status: NotionMigrationBatchStatus.inventory,
      createdAt: DateTime.utc(2026, 8, 23),
    );
    _snapshot = NotionMigrationSnapshot(batch: batch);
    return batch;
  }

  @override
  Future<NotionInventoryActionResult> startInventory(String batchId) async {
    return const NotionInventoryActionResult(
      discovered: 3,
      remainingToExpand: 2,
      inventoryComplete: false,
    );
  }

  @override
  Future<NotionInventoryActionResult> expandInventory(String batchId) async {
    return const NotionInventoryActionResult(
      discovered: 2,
      remainingToExpand: 0,
      inventoryComplete: true,
    );
  }

  @override
  Future<NotionWbsReconciliation> reconcileWbs(String batchId) async {
    return const NotionWbsReconciliation(
      siteRows: 9,
      notionRows: 10,
      siteDistinctIds: 9,
      notionDistinctIds: 9,
      notionDuplicateRows: 1,
      onlyInSite: 0,
      onlyInNotion: 0,
      exactMatches: 8,
      mismatchedRecords: 1,
      deletionGatePassed: false,
      inventoryComplete: true,
    );
  }

  @override
  Future<NotionWbsStageSummary> stageWbs(String batchId) async {
    return const NotionWbsStageSummary(
      stagedRows: 10,
      distinctTaskIds: 9,
      duplicateRows: 1,
      invalidTaskIds: 0,
    );
  }

  @override
  Future<NotionVaultManifestStageSummary> stageVaultManifest({
    required String batchId,
    required NotionVaultManifestPreview manifest,
  }) async {
    stagedManifest = manifest;
    return NotionVaultManifestStageSummary(
      id: '44444444-4444-4444-8444-444444444444',
      vaultName: manifest.vaultName,
      sourceManifestSha256: manifest.sourceManifestSha256,
      fileCount: manifest.fileCount,
      stagedEntryCount: manifest.entries.length,
      reviewRequiredCount: manifest.reviewRequiredCount,
      excludedCount: manifest.excludedCount,
      credentialCandidateCount: manifest.credentialCandidateCount,
      unresolvedWikilinkOccurrences: manifest.unresolvedWikilinkOccurrences,
      status: 'staged',
      stagedAt: DateTime.utc(2026, 8, 27),
    );
  }
}

class _AuthenticationRequiredGateway extends _FakeGateway {
  @override
  Future<NotionMigrationSnapshot> loadLatest() =>
      Future.error(const NotionMigrationException('authentication_required'));
}

class _FakeVaultManifestPicker implements NotionVaultManifestPicker {
  const _FakeVaultManifestPicker(this.value);

  final PickedNotionVaultManifest value;

  @override
  Future<PickedNotionVaultManifest?> pick() async => value;
}

PickedNotionVaultManifest _pickedManifest() {
  const noteHash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final manifest = <String, dynamic>{
    'schema_version': 1,
    'local_only': true,
    'vault_name': 'company',
    'source_absolute_path_included': false,
    'policy': <String, dynamic>{
      'network_requests': false,
      'vault_files_copied': false,
      'note_body_or_property_values_included': false,
      'excluded_files_opened_or_hashed': false,
    },
    'entries': <Map<String, dynamic>>[
      <String, dynamic>{
        'relative_path': 'HOME.md',
        'category': 'note',
        'migration_action': 'auto_stage',
        'size_bytes': 120,
        'content_inspected': true,
        'sha256': noteHash,
        'markdown': <String, dynamic>{
          'frontmatter_present': false,
          'property_keys': <String>[],
          'wikilinks': <Map<String, dynamic>>[],
          'external_link_count': 0,
          'callout_types': <String, int>{},
          'task_count': 2,
          'completed_task_count': 1,
        },
      },
      <String, dynamic>{
        'relative_path': 'private/service-account.json',
        'category': 'credential_candidate',
        'migration_action': 'exclude',
        'size_bytes': 2048,
        'content_inspected': false,
        'sha256': null,
      },
    ],
    'summary': <String, dynamic>{
      'file_count': 2,
      'action_counts': <String, int>{
        'auto_stage': 1,
        'review_required': 0,
        'exclude': 1,
      },
      'credential_candidate_count': 1,
      'unresolved_wikilink_occurrences': 0,
    },
  };
  return PickedNotionVaultManifest(
    name: 'company-manifest.json',
    bytes: Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
  );
}
