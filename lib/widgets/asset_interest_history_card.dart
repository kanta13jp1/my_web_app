import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/asset_interest_history.dart';
import '../services/asset_interest_repository.dart';

class AssetInterestHistoryCard extends StatefulWidget {
  final AssetInterestRepository repository;
  final DateTime? now;
  const AssetInterestHistoryCard({super.key, required this.repository, this.now});
  @override
  State<AssetInterestHistoryCard> createState() => _AssetInterestHistoryCardState();
}

class _AssetInterestHistoryCardState extends State<AssetInterestHistoryCard> {
  List<AssetInterestMonth> _months = [];
  bool _loading = true;
  String? _error;
  DateTime get _now => widget.now ?? DateTime.now();
  String _yen(int value) => '${NumberFormat('#,##0').format(value)}円';
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final months = await widget.repository.load();
      if (mounted) setState(() => _months = months);
    } catch (_) {
      if (mounted) setState(() => _error = 'サーバ読込に失敗しました。再読み込みしてください。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(String month, AssetInterestMonth? existing) async {
    final amounts = TextEditingController(text: existing?.amounts.entries
      .map((e) => '${e.key}=${e.value}').join('\n') ?? '');
    final evidence = TextEditingController(text: existing?.evidence ?? '');
    var complete = existing?.complete ?? false;
    var saving = false;
    String? error;
    await showDialog<void>(context: context, barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(builder: (context, update) =>
        PopScope(canPop: !saving, child: AlertDialog(
          title: Text('$month 支払利息の記録'),
          content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('明細の利息・リボ手数料の支払充当額だけを入力します。元金・未払利息・年率は含めません。残高は変更しません。'),
              TextField(controller: amounts, enabled: !saving, minLines: 3, maxLines: 8,
                decoration: const InputDecoration(labelText: '口座名=利息円（1行1口座）',
                  hintText: 'カードA=3000\nローンB=0')),
              TextField(controller: evidence, enabled: !saving, maxLength: 500,
                decoration: const InputDecoration(labelText: '確認根拠（例：8月明細を照合）',
                  helperText: '口座番号・個人情報は入力しないでください')),
              CheckboxListTile(contentPadding: EdgeInsets.zero, value: complete,
                title: const Text('この月の全対象口座を照合済み'),
                subtitle: const Text('完済口座も比較期間中は0円で残してください'),
                onChanged: saving ? null : (v) => update(() => complete = v ?? false)),
              if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ]))),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
            FilledButton(onPressed: saving ? null : () async {
              update(() { saving = true; error = null; });
              try {
                final record = AssetInterestMonth(month: month,
                  amounts: AssetInterestMonth.parseAmounts(amounts.text),
                  complete: complete, evidence: evidence.text.trim(), revision: existing?.revision);
                await widget.repository.save(record);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) await _load();
              } catch (_) {
                update(() { saving = false; error = '保存できませんでした。入力形式・接続を確認してください。同じ月が別端末で更新された場合は再読込が必要です。入力は保持しています。'; });
              }
            }, child: Text(saving ? '保存中…' : 'サーバに保存')),
          ],
        ))));
    amounts.dispose(); evidence.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final byMonth = {for (final m in _months) m.month: m};
    final keys = List.generate(12, (i) => AssetInterestMonth.monthKey(
      DateTime(_now.year, _now.month - 11 + i)));
    final maximum = keys.map((k) => byMonth[k]?.total ?? 0)
      .fold<int>(1, (a, b) => a > b ? a : b);
    final closed = keys.where((k) => k != keys.last && byMonth[k] != null).toList();
    final latest = closed.isEmpty ? null : byMonth[closed.last];
    final date = latest == null ? null : DateTime.parse('${latest.month}-01');
    final previous = date == null ? null : byMonth[AssetInterestMonth.monthKey(DateTime(date.year, date.month - 1))];
    final reduction = latest?.reductionFrom(previous, _now);
    final comparison = reduction == null ? '前月比較は保留（連続する確定月・同じ対象口座が必要）'
      : reduction > 0 ? '${latest!.month}：前月より利息負担が${_yen(reduction)}減少'
      : reduction < 0 ? '${latest!.month}：前月より利息負担が${_yen(-reduction)}増加'
      : '${latest!.month}：前月と同額';
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('毎月の支払利息', style: Theme.of(context).textTheme.titleLarge),
        const Text('明細で確認した実績のみ。未登録は0円ではありません。現在の月は途中経過です。'),
        if (_loading) const LinearProgressIndicator()
        else if (_error != null) Text(_error!)
        else ...[
          const SizedBox(height: 12),
          Text(comparison, style: Theme.of(context).textTheme.titleMedium),
          if (reduction != null && previous!.total > 0)
            Text('前月比 ${((latest!.total - previous.total) / previous.total * 100).toStringAsFixed(1)}%'),
          const Text('利息の減少は負担軽減の目安です。使える現金や生活改善を保証するものではありません。'),
          const SizedBox(height: 12),
          for (final key in keys) Padding(padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(key),
                Text(byMonth[key] == null ? '未登録' : '${_yen(byMonth[key]!.total)} / ${key == keys.last ? '月途中' : byMonth[key]!.complete ? '照合済み' : '未照合'}'),
                TextButton(onPressed: () => _edit(key, byMonth[key]), child: const Text('記録・修正')),
              ]),
              if (byMonth[key] != null) Semantics(label: '$key 支払利息 ${_yen(byMonth[key]!.total)}',
                child: LinearProgressIndicator(value: byMonth[key]!.total / maximum,
                  minHeight: 12, color: byMonth[key]!.complete && key != keys.last ? Colors.teal : Colors.orange)),
              if (byMonth[key] != null) Text(byMonth[key]!.amounts.entries.map((e) => '${e.key} ${_yen(e.value)}').join(' / ')),
            ])),
        ],
        TextButton.icon(onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh), label: const Text('サーバから再読み込み')),
      ])));
  }
}
