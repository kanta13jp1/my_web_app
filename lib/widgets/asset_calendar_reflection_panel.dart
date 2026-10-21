import 'asset_reflection_day_badge.dart';
import '../services/asset_calendar_reflection_import_parser.dart';
import 'package:flutter/material.dart';
import '../models/asset_calendar_reflection.dart';
import '../services/asset_calendar_reflection_repository.dart';

class AssetCalendarReflectionPanel extends StatefulWidget {
  const AssetCalendarReflectionPanel({
    super.key,
    required this.repository,
    required this.start,
    required this.end,
    required this.selectedDate,
    required this.onLoaded,
    this.flowEvents = const [],
  });
  final List<AssetCalendarReflection> flowEvents;
  final AssetCalendarReflectionStore repository;
  final DateTime start;
  final DateTime end;
  final DateTime? selectedDate;
  final ValueChanged<List<AssetCalendarReflection>> onLoaded;
  @override
  State<AssetCalendarReflectionPanel> createState() =>
      _AssetCalendarReflectionPanelState();
}

class _AssetCalendarReflectionPanelState
    extends State<AssetCalendarReflectionPanel> {
  List<AssetCalendarReflection> _events = const [];
  bool _loading = true;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AssetCalendarReflectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start || oldWidget.end != widget.end) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.repository.load(widget.start, widget.end);
      if (!mounted || request != _request) return;
      setState(() {
        _events = events;
      });
      widget.onLoaded(events);
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _error = '振り返りを取得できませんでした。通信状態を確認して再試行してください。';
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final input = TextEditingController();
    List<AssetCalendarReflection>? preview;
    String? error;
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('日記・読書の振り返りを取り込む'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '確認済みの日付と内容だけを JSON 配列で取り込みます。口座番号や個人名など不要な情報は含めないでください。支出・残高には加算しません。同じ出典キーは重複登録しません。',
                  ),
                  TextField(
                    controller: input,
                    maxLines: 6,
                    enabled: !saving,
                    decoration: const InputDecoration(
                      labelText: '振り返りデータ（JSON）',
                      hintText: '日付・種類・タイトル・出典キー・出典名',
                    ),
                    onChanged: (_) => update(() {
                      preview = null;
                      error = null;
                    }),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (preview != null) ...[
                    Text('確認: ${preview!.length}件。金額不明は不明のまま保存します。'),
                    for (final event in preview!)
                      Text(
                        '${event.date.month}/${event.date.day} ${event.kinds.map((k) => k.label).join('・')} ${event.title}（出典: ${event.sourceLabel}）\n'
                        '金額: ${event.verifiedAmount?.toStringAsFixed(0) ?? '不明'}・酒代内訳: ${event.alcoholAmount?.toStringAsFixed(0) ?? '不明'}\n'
                        '${event.memo} ${event.pages == null ? '' : '${event.pages}ページ'} ${event.minutes == null ? '' : '${event.minutes}分'}',
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () {
                      try {
                        final parsed =
                            parseAssetCalendarReflectionImport(input.text);
                        update(() {
                          preview = parsed;
                          error = null;
                        });
                      } on FormatException catch (exception) {
                        update(() {
                          error = exception.message;
                          preview = null;
                        });
                      } catch (_) {
                        update(() {
                          error = '入力を確認できませんでした。内容を保持したまま再試行してください。';
                          preview = null;
                        });
                      }
                    },
              child: const Text('内容を確認'),
            ),
            FilledButton(
              onPressed: saving || preview == null
                  ? null
                  : () async {
                      update(() => saving = true);
                      try {
                        await widget.repository.import(preview!);
                        if (context.mounted) Navigator.pop(context);
                        await _load();
                      } catch (_) {
                        if (context.mounted) {
                          update(() {
                            saving = false;
                            error =
                                '保存を確認できませんでした。閉じて再取得し、保存済みの内容を確認してください。同じ出典キーで再試行しても重複しません。';
                          });
                        }
                      }
                    },
              child: Text(saving ? '保存中…' : '確認した内容を保存'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events =
        AssetCalendarReflection.mergeSources(_events, widget.flowEvents)
            .where(
              (e) =>
                  !e.date.isBefore(widget.start) && e.date.isBefore(widget.end),
            )
            .toList();
    final summary = AssetReflectionSummary(events);
    final selected = widget.selectedDate;
    final dayEvents = selected == null
        ? <AssetCalendarReflection>[]
        : events
            .where(
              (e) =>
                  e.date.year == selected.year &&
                  e.date.month == selected.month &&
                  e.date.day == selected.day,
            )
            .toList();
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFB45309)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '外食・飲酒・たばこ購入・読書の振り返り',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in AssetReflectionKind.values)
                Chip(
                  backgroundColor: AssetReflectionDayBadge.backgroundFor({
                    kind,
                  }),
                  label: Text('${kind.label} ${summary.days(kind)}日'),
                ),
            ],
          ),
          Text(
            '表示期間の確認済み金額 ${summary.knownAmount.toStringAsFixed(0)}円・金額不明${summary.unknownAmounts}件',
          ),
          Text(
            '酒代の確認済み内訳 ${summary.knownAlcoholAmount.toStringAsFixed(0)}円・酒代不明${summary.unknownAlcoholAmounts}件（合計の内訳）',
          ),
          const Text(
            '記録のある日だけを集計しています。印のない日は未記録の場合があります。振り返りの金額は参考内訳で、支出合計には加算しません。',
          ),
          const Text(
            'たばこ購入は記録済み支出の品目から表示します。喫煙した日や本数は判定しません。混合購入の金額はレシート全体で、たばこ代だけの金額ではありません。',
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('振り返りを再取得'),
              ),
              TextButton.icon(
                onPressed: _loading ? null : _import,
                icon: const Icon(Icons.note_add),
                label: const Text('日記・読書データを取り込む'),
              ),
            ],
          ),
          if (selected != null)
            Text(
              '${selected.month}/${selected.day} の振り返り',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          for (final event in dayEvents)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${event.kinds.map((k) => k.label).join('・')}: ${event.title}\n'
                '${event.memo}\n出典: ${event.sourceLabel}・金額: ${event.verifiedAmount?.toStringAsFixed(0) ?? '不明'}'
                '${event.alcoholAmount == null ? '' : '（うち酒代 ${event.alcoholAmount}円）'}'
                '${event.pages == null ? '' : '・${event.pages}ページ'}${event.minutes == null ? '' : '・${event.minutes}分'}',
              ),
            ),
        ],
      ),
    );
  }
}
