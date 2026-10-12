import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_balance_observation.dart';

typedef AssetBalanceHistoryLoader = Future<List<AssetBalanceObservation>>
    Function(int offset);

/// Read-only timestamp and paged history for one account.
class AssetBalanceHistoryControl extends StatelessWidget {
  const AssetBalanceHistoryControl({
    super.key,
    required this.accountName,
    required this.latest,
    required this.loadPage,
  });

  final String accountName;
  final AssetBalanceObservation? latest;
  final AssetBalanceHistoryLoader loadPage;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (latest != null)
          Text(
            '残高日時 ${latest!.timestampLabel}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
        TextButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _AssetBalanceHistoryDialog(
              accountName: accountName,
              loadPage: loadPage,
            ),
          ),
          icon: const Icon(Icons.history, size: 18),
          label: const Text('残高履歴'),
        ),
      ],
    );
  }
}

class _AssetBalanceHistoryDialog extends StatefulWidget {
  const _AssetBalanceHistoryDialog({
    required this.accountName,
    required this.loadPage,
  });

  final String accountName;
  final AssetBalanceHistoryLoader loadPage;

  @override
  State<_AssetBalanceHistoryDialog> createState() =>
      _AssetBalanceHistoryDialogState();
}

class _AssetBalanceHistoryDialogState extends State<_AssetBalanceHistoryDialog> {
  final List<AssetBalanceObservation> _rows = [];
  bool _loading = false;
  bool _hasMore = true;
  bool _failed = false;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  Future<void> _loadNext() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.loadPage(_offset);
      if (!mounted) return;
      setState(() {
        final ids = _rows.map((row) => row.id).whereType<int>().toSet();
        for (final row in page) {
          if (row.accountName == widget.accountName &&
              (row.id == null || ids.add(row.id!))) {
            _rows.add(row);
          }
        }
        _rows.sort(AssetBalanceObservation.newestFirst);
        _offset += page.length;
        _hasMore = page.length == 50;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.##');
    return AlertDialog(
      title: Text('${widget.accountName}の残高履歴'),
      content: SizedBox(
        width: 560,
        height: MediaQuery.sizeOf(context).height * 0.60,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '保存済みの残高を新しい順に表示します。日時は日本時間です。'
              '金融機関の取得時刻とは異なる場合があります。',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  if (_rows.isEmpty && !_loading && !_failed)
                    const Text('残高履歴はありません。'),
                  for (final row in _rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.timestampLabel),
                          Text(
                            '¥${currency.format(row.amount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                        ],
                      ),
                    ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (_failed) ...[
                    const Text('履歴を読み込めませんでした。'),
                    TextButton(
                      onPressed: _loadNext,
                      child: const Text('再試行'),
                    ),
                  ] else if (_hasMore && !_loading)
                    TextButton(
                      onPressed: _loadNext,
                      child: const Text('さらに読み込む'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
