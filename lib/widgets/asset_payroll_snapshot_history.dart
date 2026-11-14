import 'package:flutter/material.dart';
import '../services/asset_payroll_snapshot_history.dart';
import '../services/asset_payroll_snapshot_store.dart';

class AssetPayrollSnapshotHistory extends StatefulWidget {
  const AssetPayrollSnapshotHistory({
    super.key,
    required this.reader,
    required this.accountId,
    required this.month,
  });
  final PayrollSnapshotHistoryReader reader;
  final String accountId;
  final DateTime month;

  @override
  State<AssetPayrollSnapshotHistory> createState() =>
      _AssetPayrollSnapshotHistoryState();
}

class _AssetPayrollSnapshotHistoryState
    extends State<AssetPayrollSnapshotHistory> {
  int _epoch = 0;
  bool _loading = false;
  PayrollSnapshotHistoryPage? _page;
  String? _error;

  @override
  void didUpdateWidget(AssetPayrollSnapshotHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reader.ownerId != widget.reader.ownerId ||
        oldWidget.accountId != widget.accountId ||
        oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      ++_epoch;
      _loading = false;
      _page = null;
      _error = null;
    }
  }

  Future<void> _read() async {
    final epoch = ++_epoch;
    final owner = widget.reader.ownerId;
    setState(() {
      _loading = true;
      _page = null;
      _error = null;
    });
    try {
      final page = await widget.reader.read(widget.accountId, widget.month);
      if (!mounted || epoch != _epoch || owner != widget.reader.ownerId) return;
      if (page.entries.any(
        (entry) =>
            entry.record.ownerId != owner ||
            entry.record.accountId != widget.accountId ||
            entry.record.month.year != widget.month.year ||
            entry.record.month.month != widget.month.month,
      )) {
        throw StateError('履歴の対象が一致しません。');
      }
      setState(() => _page = page);
    } catch (_) {
      if (!mounted || epoch != _epoch || owner != widget.reader.ownerId) return;
      setState(() => _error = '訂正履歴を読み込めませんでした。再読込してください。');
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: _loading ? null : _read,
            child: Text(_loading ? '訂正履歴を読込中' : '訂正履歴を読み込む'),
          ),
          if (_error != null) Text(_error!),
          if (_page != null) ...[
            const Text('本人確認の記録・訂正履歴（新しい順）。銀行検証済みではありません。'
                '現在採用中の残高は上の表示を再読込して確認してください。'),
            if (_page!.entries.isEmpty) const Text('この口座・対象月の履歴はありません。'),
            if (_page!.hasMore) const Text('最新50件を表示しています。さらに古い履歴があります。'),
            for (final entry in _page!.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${entry.previousId == null ? '初回記録' : '訂正'}・'
                  '${entry.record.balanceYen}円\n'
                  '入金日 ${payrollDate(entry.record.depositDate)}\n'
                  '記録変更日時 ${entry.changedAt.toLocal()}\n'
                  '理由：${entry.reason}\n資料メモ：${entry.record.note}',
                ),
              ),
          ],
        ],
      );
}
