import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/asset_month_end_snapshot_service.dart';

/// Inject below the existing manual history. Does not alter manual snapshots.
class AssetMonthEndSnapshotCard extends StatefulWidget {
  final AssetMonthEndSnapshotService service;
  final List<String> monthKeys;
  const AssetMonthEndSnapshotCard({
    super.key,
    required this.service,
    required this.monthKeys,
  });

  @override
  State<AssetMonthEndSnapshotCard> createState() =>
      _AssetMonthEndSnapshotCardState();
}

class _AssetMonthEndSnapshotCardState extends State<AssetMonthEndSnapshotCard> {
  bool _loading = true;
  bool _enabled = false;
  String? _error;
  List<AssetMonthEndSnapshot> _snapshots = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final enabled = await widget.service.isEnabled();
      final snapshots = await widget.service.load();
      if (!mounted) return;
      setState(() { _enabled = enabled; _snapshots = snapshots; });
    } catch (_) {
      if (mounted) setState(() => _error = '月末記録を取得できませんでした。再試行してください。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool enabled) async {
    setState(() { _loading = true; _error = null; });
    try {
      await widget.service.setEnabled(enabled);
      if (!mounted) return;
      await _refresh();
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = '設定を保存できませんでした。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final yen = NumberFormat.currency(locale: 'ja_JP', symbol: '¥', decimalDigits: 0);
    final snapshots = monthEndComparison(
      monthKeys: widget.monthKeys, snapshots: _snapshots,
    );
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('月末の記録残高', style: Theme.of(context).textTheme.titleMedium),
          IconButton(onPressed: _loading ? null : _refresh,
            tooltip: '月末記録だけ更新', icon: const Icon(Icons.refresh)),
        ]),
        SwitchListTile(contentPadding: EdgeInsets.zero,
          title: const Text('月末に自動保存する'),
          subtitle: const Text('日本時間の月替わりに、サイトを閉じていても保存します。'),
          value: _enabled, onChanged: _loading ? null : _toggle),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const Text('銀行との照合済み残高ではありません。未更新・廃止口座の有無は確認が必要です。手動の記録とは分けて表示します。'),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columns: const [DataColumn(label: Text('月')), DataColumn(label: Text('総資産')),
            DataColumn(label: Text('負債')), DataColumn(label: Text('純資産')),
            DataColumn(label: Text('観測状況'))],
          rows: List.generate(widget.monthKeys.length, (index) {
            final snapshot = snapshots[index];
            return DataRow(cells: [
              DataCell(Text(widget.monthKeys[index])),
              DataCell(Text(snapshot == null ? '未取得' : yen.format(snapshot.totalAssets))),
              DataCell(Text(snapshot == null ? '—' : yen.format(snapshot.totalLiabilities))),
              DataCell(Text(snapshot == null ? '—' : yen.format(snapshot.netWorth))),
              DataCell(snapshot == null ? const Text('月末前・過去の未取得分は補完しません') :
                Tooltip(message: snapshot.accounts.map((account) =>
                  '${account['title']}: ${account['observed_at']}').join('\n'),
                  child: Text('前月以前の残高 ${snapshot.staleAccountCount}口座'))),
            ]);
          }),
        )),
      ]),
    ));
  }
}
