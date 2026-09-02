import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/notion_migration_models.dart';
import '../view_models/notion_migration_view_model.dart';

class NotionMigrationPage extends StatelessWidget {
  const NotionMigrationPage({super.key});

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<NotionMigrationViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notion移行センター'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: () => unawaited(viewModel.load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => switch (viewModel.loadStatus) {
            NotionMigrationLoadStatus.initial ||
            NotionMigrationLoadStatus.loading =>
              const Center(
                child: CircularProgressIndicator(),
              ),
            NotionMigrationLoadStatus.failure => _LoadFailure(
                viewModel: viewModel,
              ),
            NotionMigrationLoadStatus.ready => LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= _wideBreakpoint;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: Column(
                          key: Key(
                            wide
                                ? 'notion-migration-wide'
                                : 'notion-migration-compact',
                          ),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _MigrationHero(),
                            const SizedBox(height: 16),
                            if (viewModel.errorMessage != null)
                              _InlineMessage(message: viewModel.errorMessage!),
                            if (viewModel.noticeMessage != null)
                              _InlineMessage(
                                message: viewModel.noticeMessage!,
                                isSuccess: true,
                              ),
                            if (viewModel.snapshot.batch == null)
                              _EmptyLedger(viewModel: viewModel)
                            else
                              _MigrationLedger(
                                snapshot: viewModel.snapshot,
                                wide: wide,
                                viewModel: viewModel,
                              ),
                            const SizedBox(height: 20),
                            _VaultManifestCard(
                              snapshot: viewModel.snapshot,
                              viewModel: viewModel,
                            ),
                            const SizedBox(height: 20),
                            const _SafetyGate(),
                            const SizedBox(height: 20),
                            _FeatureMatrix(
                              capabilities: viewModel.snapshot.capabilities,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          },
        ),
      ),
    );
  }
}

class _MigrationHero extends StatelessWidget {
  const _MigrationHero();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer, colors.tertiaryContainer],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.move_to_inbox_outlined, size: 44),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'コピーではなく、検証できる段階移行',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Notionの全件棚卸し、サイトへの取込、件数・内容・添付・権限の照合、'
                    'Notion側削除、最終解約までを1件単位で記録します。',
                    style: TextStyle(height: 1.55),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLedger extends StatefulWidget {
  const _EmptyLedger({required this.viewModel});

  final NotionMigrationViewModel viewModel;

  @override
  State<_EmptyLedger> createState() => _EmptyLedgerState();
}

class _EmptyLedgerState extends State<_EmptyLedger> {
  final _workspaceId = TextEditingController();
  final _workspaceName = TextEditingController();
  final _batchName = TextEditingController(text: 'Notion全件移行');

  @override
  void dispose() {
    _workspaceId.dispose();
    _workspaceName.dispose();
    _batchName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '移行台帳を作成',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('台帳には機密データそのものではなく、所有者、移行状態、照合証跡、移行先IDを記録します。'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('notion-migration-workspace-name'),
              controller: _workspaceName,
              decoration: const InputDecoration(
                labelText: 'Notionワークスペース名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('notion-migration-workspace-id'),
              controller: _workspaceId,
              decoration: const InputDecoration(
                labelText: 'NotionワークスペースID',
                helperText: 'コードやテストデータには埋め込みません。',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('notion-migration-batch-name'),
              controller: _batchName,
              decoration: const InputDecoration(
                labelText: '移行名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('notion-migration-create-batch'),
              onPressed: widget.viewModel.isCreating
                  ? null
                  : () => unawaited(_create()),
              icon: widget.viewModel.isCreating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add_check_circle_outlined),
              label: Text(widget.viewModel.isCreating ? '作成中…' : '移行台帳を開始'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final created = await widget.viewModel.createBatch(
      workspaceId: _workspaceId.text,
      workspaceName: _workspaceName.text,
      name: _batchName.text,
    );
    if (!created && mounted && widget.viewModel.errorMessage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('3項目をすべて入力してください。')));
    }
  }
}

class _MigrationLedger extends StatelessWidget {
  const _MigrationLedger({
    required this.snapshot,
    required this.wide,
    required this.viewModel,
  });

  final NotionMigrationSnapshot snapshot;
  final bool wide;
  final NotionMigrationViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final batch = snapshot.batch!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      batch.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Chip(label: Text(batch.status.label)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('対象: ${batch.workspaceName}'),
                const SizedBox(height: 16),
                _ProgressStrip(progress: snapshot.progress),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: const Key('notion-migration-inventory-start'),
                      onPressed: viewModel.isInventoryRunning
                          ? null
                          : () => unawaited(viewModel.startInventory()),
                      icon: const Icon(Icons.manage_search),
                      label: Text(
                        snapshot.progress.totalItems == 0
                            ? 'Notion接続を棚卸し'
                            : '接続範囲を再確認',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('notion-migration-inventory-expand'),
                      onPressed: viewModel.isInventoryRunning ||
                              snapshot.progress.totalItems == 0
                          ? null
                          : () => unawaited(viewModel.expandInventory()),
                      icon: viewModel.isInventoryRunning
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.account_tree_outlined),
                      label: const Text('再帰棚卸しを続ける'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('notion-migration-reconcile-wbs'),
                      onPressed: viewModel.isReconciliationRunning ||
                              viewModel.isInventoryRunning ||
                              snapshot.progress.totalItems == 0
                          ? null
                          : () => unawaited(viewModel.reconcileWbs()),
                      icon: viewModel.isReconciliationRunning
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.rule_folder_outlined),
                      label: const Text('WBSを全件照合'),
                    ),
                    FilledButton.tonalIcon(
                      key: const Key('notion-migration-stage-wbs'),
                      onPressed: viewModel.isWbsStaging ||
                              viewModel.isReconciliationRunning ||
                              viewModel.isInventoryRunning ||
                              snapshot.wbsReconciliation == null
                          ? null
                          : () => unawaited(viewModel.stageWbs()),
                      icon: viewModel.isWbsStaging
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.inventory_2_outlined),
                      label: const Text('WBSを安全領域へ取込'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '接続APIで見える範囲だけでは全件保証になりません。ワークスペース書き出し・ブラウザ棚卸しとの照合が終わるまで削除不可です。',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (snapshot.wbsReconciliation case final reconciliation?) ...[
          const SizedBox(height: 16),
          _WbsReconciliationCard(reconciliation: reconciliation),
        ],
        if (snapshot.wbsStageSummary case final stage?)
          if (stage.stagedRows > 0) ...[
            const SizedBox(height: 16),
            _WbsStageCard(summary: stage),
          ],
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _StageTimeline(progress: snapshot.progress)),
              const SizedBox(width: 16),
              Expanded(child: _ItemPanel(items: snapshot.items)),
            ],
          )
        else ...[
          _StageTimeline(progress: snapshot.progress),
          const SizedBox(height: 16),
          _ItemPanel(items: snapshot.items),
        ],
      ],
    );
  }
}

class _WbsStageCard extends StatelessWidget {
  const _WbsStageCard({required this.summary});

  final NotionWbsStageSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('notion-migration-wbs-stage-summary'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'WBS安全領域',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(label: Text('本番未反映')),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Notionの元ページIDと元JSONを保持しています。重複の採用行と属性競合を確定するまで、'
              '本番WBSへの反映やNotion側削除は行いません。',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(label: '保存行', value: summary.stagedRows),
                _Metric(label: '一意ID', value: summary.distinctTaskIds),
                _Metric(
                  label: '重複行',
                  value: summary.duplicateRows,
                  isWarning: summary.duplicateRows > 0,
                ),
                _Metric(
                  label: 'ID不正',
                  value: summary.invalidTaskIds,
                  isWarning: summary.invalidTaskIds > 0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WbsReconciliationCard extends StatelessWidget {
  const _WbsReconciliationCard({required this.reconciliation});

  final NotionWbsReconciliation reconciliation;

  @override
  Widget build(BuildContext context) {
    final passed = reconciliation.deletionGatePassed;
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('notion-migration-wbs-reconciliation'),
      color: passed ? colors.primaryContainer : colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(passed ? Icons.verified_outlined : Icons.block_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'WBS全件照合',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(label: Text(passed ? '属性照合 合格' : '削除不可')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              passed
                  ? '全IDとミラー属性は一致しています。バックアップ・添付・権限など残りの安全確認後に削除候補になります。'
                  : '差分が残っています。値は上書きせず、原因を確定してから同期または移行します。',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(label: 'サイト行', value: reconciliation.siteRows),
                _Metric(label: 'Notion行', value: reconciliation.notionRows),
                _Metric(label: '完全一致', value: reconciliation.exactMatches),
                _Metric(
                  label: 'Notion重複',
                  value: reconciliation.notionDuplicateRows,
                  isWarning: reconciliation.notionDuplicateRows > 0,
                ),
                _Metric(
                  label: 'サイトのみ',
                  value: reconciliation.onlyInSite,
                  isWarning: reconciliation.onlyInSite > 0,
                ),
                _Metric(
                  label: 'Notionのみ',
                  value: reconciliation.onlyInNotion,
                  isWarning: reconciliation.onlyInNotion > 0,
                ),
                _Metric(
                  label: '属性不一致',
                  value: reconciliation.mismatchedRecords,
                  isWarning: reconciliation.mismatchedRecords > 0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.progress});

  final NotionMigrationProgress progress;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Metric(label: '棚卸し', value: progress.totalItems),
        _Metric(label: '取込済み', value: progress.importedItems),
        _Metric(label: '照合済み', value: progress.verifiedItems),
        _Metric(label: '削除可能', value: progress.deletionReadyItems),
        _Metric(label: 'Notion削除済み', value: progress.sourceDeletedItems),
        if (progress.failedItems > 0)
          _Metric(label: '要対応', value: progress.failedItems, isWarning: true),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final int value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 142,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning ? colors.errorContainer : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StageTimeline extends StatelessWidget {
  const _StageTimeline({required this.progress});

  final NotionMigrationProgress progress;

  @override
  Widget build(BuildContext context) {
    final stages = <(String, int, double)>[
      ('1. 棚卸し', progress.totalItems, progress.totalItems == 0 ? 0 : 1),
      ('2. サイトへ取込', progress.importedItems, progress.importedRatio),
      ('3. 7項目照合', progress.verifiedItems, progress.verifiedRatio),
      ('4. Notion側削除', progress.sourceDeletedItems, progress.deletedRatio),
      ('5. サブスク解約', 0, 0),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '段階進捗',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            for (final stage in stages) ...[
              Row(
                children: [
                  Expanded(child: Text(stage.$1)),
                  Text('${stage.$2}件'),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: stage.$3.clamp(0, 1)),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemPanel extends StatelessWidget {
  const _ItemPanel({required this.items});

  final List<NotionMigrationItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '移行項目',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('再帰棚卸しの取込待ちです。Notion側のデータはまだ削除しません。')
            else
              for (final item in items.take(30))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconFor(item.sourceKind)),
                  title: Text(item.title.isEmpty ? '名称なし' : item.title),
                  subtitle: Text(
                    '${item.status.label} • 照合 ${item.passedChecks}/7',
                  ),
                  trailing: item.status ==
                          NotionMigrationItemStatus.readyForSourceDeletion
                      ? const Icon(Icons.verified, color: Colors.green)
                      : null,
                ),
            if (items.length > 30) Text('ほか ${items.length - 30} 件'),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String kind) => switch (kind) {
        'database' || 'data_source' => Icons.table_chart_outlined,
        'attachment' => Icons.attach_file,
        'comment' => Icons.comment_outlined,
        'teamspace' => Icons.groups_outlined,
        _ => Icons.description_outlined,
      };
}

class _VaultManifestCard extends StatelessWidget {
  const _VaultManifestCard({required this.snapshot, required this.viewModel});

  final NotionMigrationSnapshot snapshot;
  final NotionMigrationViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final preview = viewModel.vaultManifestPreview;
    final staged = snapshot.vaultManifestSummary;
    return Card(
      key: const Key('notion-migration-vault-manifest-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.hub_outlined),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Obsidian保管庫を安全な中継地点にする',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(label: Text('ローカル先行')),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'ローカル生成したmanifestだけをブラウザ内で検証します。ノート本文・プロパティ値・'
              '認証情報・除外ファイルのパスは送信せず、許可されたノートと添付の構造情報だけを'
              '本番データとは分離した安全領域へ保存します。',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  key: const Key('notion-migration-vault-manifest-pick'),
                  onPressed: viewModel.isVaultManifestSelecting ||
                          viewModel.isVaultManifestStaging
                      ? null
                      : () => unawaited(viewModel.selectVaultManifest()),
                  icon: viewModel.isVaultManifestSelecting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_open_outlined),
                  label: const Text('manifest JSONを選択'),
                ),
                FilledButton.tonalIcon(
                  key: const Key('notion-migration-vault-manifest-stage'),
                  onPressed: snapshot.batch == null ||
                          preview == null ||
                          viewModel.isVaultManifestSelecting ||
                          viewModel.isVaultManifestStaging
                      ? null
                      : () => unawaited(_confirmAndStage(context)),
                  icon: viewModel.isVaultManifestStaging
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.inventory_2_outlined),
                  label: const Text('構造情報を安全領域へ保存'),
                ),
              ],
            ),
            if (snapshot.batch == null) ...[
              const SizedBox(height: 8),
              const Text('保存するには先に移行台帳を作成してください。'),
            ],
            if (preview != null) ...[
              const SizedBox(height: 16),
              Container(
                key: const Key('notion-migration-vault-manifest-preview'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${preview.vaultName} / ${preview.sourceFileName}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Metric(label: '全件', value: preview.fileCount),
                        _Metric(label: '自動保存', value: preview.autoStageCount),
                        _Metric(
                          label: '要確認',
                          value: preview.reviewRequiredCount,
                          isWarning: preview.reviewRequiredCount > 0,
                        ),
                        _Metric(
                          label: '除外',
                          value: preview.excludedCount,
                          isWarning: preview.excludedCount > 0,
                        ),
                        _Metric(
                          label: '認証候補',
                          value: preview.credentialCandidateCount,
                          isWarning: preview.credentialCandidateCount > 0,
                        ),
                        _Metric(
                          label: '未解決リンク',
                          value: preview.unresolvedWikilinkOccurrences,
                          isWarning: preview.unresolvedWikilinkOccurrences > 0,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (staged != null) ...[
              const SizedBox(height: 16),
              Container(
                key: const Key('notion-migration-vault-manifest-summary'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '最新: ${staged.stagedEntryCount}件を${staged.status == 'staged' ? '保存済み' : '処理中'}。'
                  '要確認${staged.reviewRequiredCount}件、除外${staged.excludedCount}件。'
                  '除外パスと本文は保持していません。',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndStage(BuildContext context) async {
    final preview = viewModel.vaultManifestPreview;
    if (preview == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('構造情報だけを保存しますか？'),
        content: Text(
          '${preview.stageableCount}件の相対パス、ハッシュ、リンク・タスク等の構造情報を保存します。'
          'ノート本文、プロパティ値、認証情報、除外${preview.excludedCount}件のパスは送信しません。'
          'Notionの元データと本番コンテンツは変更しません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('notion-migration-vault-manifest-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('安全領域へ保存'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await viewModel.stageVaultManifest();
    }
  }
}

class _SafetyGate extends StatelessWidget {
  const _SafetyGate();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('notion-migration-safety-gate'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined),
              SizedBox(width: 8),
              Text(
                '削除安全ゲート',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'バックアップ・本文・階層・プロパティ・添付・コメント・権限の7項目がすべて合格し、'
            '対象を明示した実行直前の承認が記録されるまで、Notion側削除には進めません。'
            'サブスク解約は全件削除後の最終検収とは別の承認です。',
            style: TextStyle(height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _FeatureMatrix extends StatelessWidget {
  const _FeatureMatrix({required this.capabilities});

  final List<NotionCapability> capabilities;

  @override
  Widget build(BuildContext context) {
    final required = capabilities
        .where((capability) => capability.isRequired)
        .toList(growable: false);
    final verified = required
        .where((capability) => capability.status == NotionParityStatus.verified)
        .length;
    return Column(
      key: const Key('notion-migration-feature-matrix'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Notion機能同等性の検証台帳',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text('ルートが存在するだけでは完了扱いにせず、実データで互換性を確認します。'),
        if (capabilities.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '必須 $verified/${required.length} 検証済み',
            key: const Key('notion-migration-capability-progress'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
        const SizedBox(height: 12),
        if (capabilities.isEmpty)
          const Text('移行台帳を作成すると、Notion機能の必須検証項目が登録されます。')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final capability in capabilities)
                    SizedBox(
                      width: width,
                      child: _CapabilityCard(capability: capability),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capability});

  final NotionCapability capability;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    capability.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  avatar: Icon(_statusIcon(capability.status), size: 18),
                  label: Text(capability.status.label),
                  backgroundColor: _statusColor(context, capability.status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(capability.notionScope),
            const SizedBox(height: 10),
            Text(
              capability.siteRoutes.isEmpty
                  ? '対応ルート未割当'
                  : capability.siteRoutes.join('  '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (capability.evidenceSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '証跡: ${capability.evidenceSummary}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, NotionParityStatus status) {
    final colors = Theme.of(context).colorScheme;
    return switch (status) {
      NotionParityStatus.verified => colors.primaryContainer,
      NotionParityStatus.gap ||
      NotionParityStatus.blocked =>
        colors.errorContainer,
      NotionParityStatus.verifying => colors.tertiaryContainer,
      _ => colors.surfaceContainerHighest,
    };
  }

  IconData _statusIcon(NotionParityStatus status) => switch (status) {
        NotionParityStatus.verified => Icons.verified_outlined,
        NotionParityStatus.gap => Icons.warning_amber_outlined,
        NotionParityStatus.blocked => Icons.block_outlined,
        NotionParityStatus.verifying => Icons.fact_check_outlined,
        NotionParityStatus.implemented => Icons.code_outlined,
        NotionParityStatus.planned => Icons.event_note_outlined,
        NotionParityStatus.inventory => Icons.inventory_2_outlined,
      };
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.viewModel});

  final NotionMigrationViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(viewModel.errorMessage ?? '読み込みに失敗しました。'),
            const SizedBox(height: 16),
            if (viewModel.authenticationRequired)
              FilledButton(
                key: const Key('notion-migration-login'),
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                child: const Text('ログイン'),
              )
            else
              FilledButton.icon(
                onPressed: () => unawaited(viewModel.load()),
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, this.isSuccess = false});

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: MaterialBanner(
        backgroundColor: isSuccess
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.errorContainer,
        content: Text(message),
        actions: const [SizedBox.shrink()],
      ),
    );
  }
}
