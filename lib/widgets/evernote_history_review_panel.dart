import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/evernote_cloud_stage_service.dart';
import '../services/evernote_migration_ledger_service.dart';
import 'evernote_cloud_migration_controls.dart';

typedef EvernoteHistoryReviewCallback = Future<void> Function(
  EvernoteMigrationItem item,
  int sourceVersionCount,
);

typedef EvernoteHistoryImportCallback = Future<void> Function(
  EvernoteMigrationItem item,
);

class EvernoteHistoryReviewPanel extends StatefulWidget {
  const EvernoteHistoryReviewPanel({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onRefresh,
    required this.onReviewInventory,
    required this.onImportRevision,
    this.busyItemId,
    this.error,
    this.stageProgress,
  });

  final List<EvernoteMigrationItem> items;
  final bool isLoading;
  final int? busyItemId;
  final String? error;
  final EvernoteCloudStageProgress? stageProgress;
  final Future<void> Function() onRefresh;
  final EvernoteHistoryReviewCallback onReviewInventory;
  final EvernoteHistoryImportCallback onImportRevision;

  @override
  State<EvernoteHistoryReviewPanel> createState() =>
      _EvernoteHistoryReviewPanelState();
}

class _EvernoteHistoryReviewPanelState
    extends State<EvernoteHistoryReviewPanel> {
  final Map<int, TextEditingController> _countControllers =
      <int, TextEditingController>{};
  final Map<int, String?> _countErrors = <int, String?>{};

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant EvernoteHistoryReviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  @override
  void dispose() {
    for (final controller in _countControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    final activeIds = widget.items.map((item) => item.id).toSet();
    final removedIds = _countControllers.keys
        .where((id) => !activeIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      _countControllers.remove(id)?.dispose();
      _countErrors.remove(id);
    }
    for (final item in widget.items) {
      _countControllers.putIfAbsent(
        item.id,
        () => TextEditingController(
          text: item.historyStatus == 'pending'
              ? ''
              : item.sourceHistoryVersionCount.toString(),
        ),
      );
    }
  }

  Future<void> _review(EvernoteMigrationItem item) async {
    final text = _countControllers[item.id]!.text.trim();
    final count = int.tryParse(text);
    if (count == null || count < 0) {
      setState(() {
        _countErrors[item.id] = '0以上の履歴件数を入力してください。';
      });
      return;
    }
    setState(() => _countErrors[item.id] = null);
    await widget.onReviewInventory(item, count);
  }

  @override
  Widget build(BuildContext context) {
    final importedItems =
        widget.items.where((item) => item.isImported).toList(growable: false);
    return Card(
      key: const Key('evernote-history-review-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Evernoteノート履歴の保全',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
                if (widget.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: '履歴状況を更新',
                    onPressed: widget.onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Evernoteで各ノートの履歴を確認し、履歴数を登録してください。'
              '履歴がある場合は、各版を1件ずつENEXで書き出して取り込みます。'
              '確認が完了するまでEvernote側の削除はデータベースが拒否します。',
              style: TextStyle(height: 1.5),
            ),
            if (widget.stageProgress != null) ...[
              const SizedBox(height: 12),
              EvernoteCloudStageStatus(progress: widget.stageProgress!),
            ],
            if (widget.error != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (importedItems.isEmpty)
              const Text(
                '履歴確認の対象はまだありません。先に通常のENEXノートを取り込んでください。',
                key: Key('evernote-history-empty'),
              )
            else
              ListView.builder(
                key: const Key('evernote-history-item-list'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: importedItems.length,
                itemBuilder: (context, index) {
                  final item = importedItems[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == importedItems.length - 1 ? 0 : 12,
                    ),
                    child: _buildItem(context, item),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    EvernoteMigrationItem item,
  ) {
    final busy = widget.busyItemId == item.id;
    final canImport = item.sourceHistoryVersionCount > 0 &&
        item.verifiedHistoryVersionCount < item.sourceHistoryVersionCount &&
        !busy;
    final statusColor = item.historyDeletionGatePassed
        ? Colors.green
        : Theme.of(context).colorScheme.secondary;
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.displayTitle,
          key: ValueKey('evernote-history-title-${item.id}'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '履歴: ${item.verifiedHistoryVersionCount}/'
          '${item.sourceHistoryVersionCount} 検証済み',
        ),
        const SizedBox(height: 4),
        Chip(
          avatar: Icon(
            item.historyDeletionGatePassed ? Icons.verified : Icons.lock_clock,
            size: 18,
            color: statusColor,
          ),
          label: Text(_historyStatusLabel(item.historyStatus)),
        ),
      ],
    );
    final countField = SizedBox(
      width: 180,
      child: TextField(
        key: ValueKey('evernote-history-count-${item.id}'),
        controller: _countControllers[item.id],
        enabled: !busy,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: 'Evernote上の履歴件数',
          errorText: _countErrors[item.id],
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: ValueKey('evernote-history-review-${item.id}'),
          onPressed: busy ? null : () => _review(item),
          icon: const Icon(Icons.fact_check),
          label: const Text('件数を確認'),
        ),
        FilledButton.icon(
          key: ValueKey('evernote-history-import-${item.id}'),
          onPressed: canImport ? () => widget.onImportRevision(item) : null,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.history),
          label: const Text('履歴ENEXを1件取り込む'),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < evernoteContextWideBreakpoint) {
              return Column(
                key: ValueKey('evernote-history-item-narrow-${item.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  summary,
                  const SizedBox(height: 12),
                  countField,
                  const SizedBox(height: 12),
                  actions,
                ],
              );
            }
            return Row(
              key: ValueKey('evernote-history-item-wide-${item.id}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: summary),
                const SizedBox(width: 16),
                countField,
                const SizedBox(width: 16),
                Flexible(child: actions),
              ],
            );
          },
        ),
      ),
    );
  }

  String _historyStatusLabel(String status) {
    switch (status) {
      case 'reviewed_no_versions':
        return '履歴なし確認済み';
      case 'importing':
        return '履歴取込中';
      case 'imported':
        return '検証待ち';
      case 'verified':
        return '履歴検証済み';
      default:
        return '履歴未確認・削除不可';
    }
  }
}
