import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/note_clipboard_helper.dart';
import 'note_native_selectable_text.dart';

/// iPhone Safari でも自由な範囲選択・抽出コピーができる専用画面を開く。
Future<TextSelection?> openNoteRangeSelectPage({
  required BuildContext context,
  required String text,
  required TextSelection initialSelection,
}) {
  return Navigator.of(context).push<TextSelection?>(
    MaterialPageRoute<TextSelection?>(
      settings: const RouteSettings(name: '/note-editor'),
      fullscreenDialog: true,
      builder: (_) => NoteRangeSelectPage(
        text: text,
        initialSelection: initialSelection,
      ),
    ),
  );
}

/// 「なぞって選択（Webネイティブ）」と「抽出・微調整」を提供する選択専用ページ。
class NoteRangeSelectPage extends StatefulWidget {
  final String text;
  final TextSelection initialSelection;

  const NoteRangeSelectPage({
    required this.text,
    required this.initialSelection,
    super.key,
  });

  @override
  State<NoteRangeSelectPage> createState() => _NoteRangeSelectPageState();
}

class _NoteRangeSelectPageState extends State<NoteRangeSelectPage> {
  int _mode = 0;
  late final List<NoteCopyableItem> _items;
  late final List<NoteCopyableItem> _primaryItems;
  late final List<NoteCopyableItem> _lineItems;
  late int _start;
  late int _end;
  String _nativeSelectedText = '';
  TextSelection? _nativeRange;

  @override
  void initState() {
    super.initState();
    _items = NoteClipboardHelper.extractCopyableItems(widget.text);
    _primaryItems =
        _items.where((item) => item.kind != NoteCopyableItemKind.line).toList();
    _lineItems =
        _items.where((item) => item.kind == NoteCopyableItemKind.line).toList();
    final len = widget.text.length;
    final sel = widget.initialSelection;
    if (len > 0 && sel.isValid && !sel.isCollapsed) {
      final s = sel.start.clamp(0, len);
      final e = sel.end.clamp(s, len);
      if (e > s) {
        _start = s;
        _end = e;
        _nativeSelectedText = widget.text.substring(s, e);
        _nativeRange = TextSelection(baseOffset: s, extentOffset: e);
        return;
      }
    }
    _start = 0;
    _end = len;
  }

  void _handleNativeSelection(String selected, TextSelection? selection) {
    TextSelection? resolved = selection;
    if (resolved == null || resolved.isCollapsed) {
      final idx = widget.text.indexOf(selected);
      if (idx >= 0) {
        resolved = TextSelection(
          baseOffset: idx,
          extentOffset: idx + selected.length,
        );
      }
    }
    setState(() {
      _nativeSelectedText = selected;
      _nativeRange = resolved;
      if (resolved != null && !resolved.isCollapsed) {
        _start = resolved.start.clamp(0, widget.text.length);
        _end = resolved.end.clamp(_start, widget.text.length);
      }
    });
  }

  void _adjustPrecision({int startDelta = 0, int endDelta = 0}) {
    final next = NoteClipboardHelper.adjustSelection(
      widget.text,
      TextSelection(baseOffset: _start, extentOffset: _end),
      startDelta: startDelta,
      endDelta: endDelta,
    );
    setState(() {
      _start = next.start;
      _end = next.end;
    });
  }

  VoidCallback? _startAdjuster(int delta) {
    if (widget.text.isEmpty) {
      return null;
    }
    return () => _adjustPrecision(startDelta: delta);
  }

  VoidCallback? _endAdjuster(int delta) {
    if (widget.text.isEmpty) {
      return null;
    }
    return () => _adjustPrecision(endDelta: delta);
  }

  void _applyRangeAndPop(int start, int end) {
    Navigator.of(context).pop(
      TextSelection(baseOffset: start, extentOffset: end),
    );
  }

  void _copySelectedRange(String selectedText) {
    final len = selectedText.length;
    unawaited(_copyText(selectedText, '選択範囲 ($len文字) をコピーしました'));
  }

  void _loadItemIntoPrecision(NoteCopyableItem item) {
    setState(() {
      _start = item.start.clamp(0, widget.text.length);
      _end = item.end.clamp(_start, widget.text.length);
    });
  }

  Future<void> _copyText(String value, String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('コピーに失敗しました')));
    }
  }

  Widget _buildModeSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          selected: <int>{_mode},
          showSelectedIcon: false,
          onSelectionChanged: (values) {
            if (values.isNotEmpty) {
              setState(() => _mode = values.first);
            }
          },
          segments: const [
            ButtonSegment<int>(
              value: 0,
              label: Text(
                'なぞって選択',
                key: Key('note_range_mode_native'),
              ),
            ),
            ButtonSegment<int>(
              value: 1,
              label: Text(
                '抽出・微調整',
                key: Key('note_range_mode_precision'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNativeMode(ThemeData theme) {
    final selectedLen = _nativeSelectedText.length;
    final copyLabel = selectedLen > 0 ? 'コピー ($selectedLen文字)' : '範囲を選択してコピー';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '文字を長押しすると iPhone 標準のハンドルで範囲選択できます',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: NoteNativeSelectableText(
              text: widget.text,
              backgroundColor: theme.colorScheme.surfaceContainerLowest,
              textColor: theme.colorScheme.onSurface,
              onSelectionChanged: _handleNativeSelection,
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('note_range_copy_button'),
                    onPressed: _nativeSelectedText.isEmpty
                        ? null
                        : () => _copySelectedRange(_nativeSelectedText),
                    icon: const Icon(Icons.content_copy_outlined, size: 18),
                    label: Text(copyLabel),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const Key('note_range_apply_button'),
                  onPressed: _nativeRange == null
                      ? null
                      : () => Navigator.of(context).pop(_nativeRange),
                  child: const Text('エディタへ反映'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeltaButton({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(42, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildItemTile({
    required ThemeData theme,
    required NoteCopyableItem item,
    Key? copyButtonKey,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: () => _loadItemIntoPrecision(item),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('微調整'),
            ),
            FilledButton.tonal(
              key: copyButtonKey,
              onPressed: () => unawaited(
                _copyText(item.value, '「${item.label}」をコピーしました'),
              ),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('コピー'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrecisionCard(ThemeData theme) {
    final len = widget.text.length;
    final safeStart = _start.clamp(0, len);
    final safeEnd = _end.clamp(safeStart, len);
    final selectedText = widget.text.substring(safeStart, safeEnd);
    final prefix = widget.text.substring(0, safeStart);
    final suffix = widget.text.substring(safeEnd);

    return Card(
      key: const Key('note_range_precision_card'),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '文字単位で微調整',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '$safeStart〜$safeEnd（${selectedText.length}文字）',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    children: [
                      if (prefix.isNotEmpty) TextSpan(text: prefix),
                      if (selectedText.isNotEmpty)
                        TextSpan(
                          text: selectedText,
                          style: TextStyle(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (suffix.isNotEmpty) TextSpan(text: suffix),
                    ],
                  ),
                ),
              ),
            ),
            if (len > 1)
              RangeSlider(
                key: const Key('note_range_slider'),
                min: 0,
                max: len.toDouble(),
                divisions: len,
                values: RangeValues(safeStart.toDouble(), safeEnd.toDouble()),
                onChanged: (values) {
                  final s = values.start.round().clamp(0, len - 1);
                  final e = values.end.round().clamp(s + 1, len);
                  setState(() {
                    _start = s;
                    _end = e;
                  });
                },
              ),
            Wrap(
              spacing: 4,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('始点:', style: theme.textTheme.labelMedium),
                _buildDeltaButton(
                  label: '-5',
                  onPressed: _startAdjuster(-5),
                ),
                _buildDeltaButton(
                  key: const Key('note_range_start_minus_1'),
                  label: '-1',
                  onPressed: _startAdjuster(-1),
                ),
                _buildDeltaButton(
                  key: const Key('note_range_start_plus_1'),
                  label: '+1',
                  onPressed: _startAdjuster(1),
                ),
                _buildDeltaButton(
                  label: '+5',
                  onPressed: _startAdjuster(5),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('終点:', style: theme.textTheme.labelMedium),
                _buildDeltaButton(
                  label: '-5',
                  onPressed: _endAdjuster(-5),
                ),
                _buildDeltaButton(
                  key: const Key('note_range_end_minus_1'),
                  label: '-1',
                  onPressed: _endAdjuster(-1),
                ),
                _buildDeltaButton(
                  key: const Key('note_range_end_plus_1'),
                  label: '+1',
                  onPressed: _endAdjuster(1),
                ),
                _buildDeltaButton(
                  label: '+5',
                  onPressed: _endAdjuster(5),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('note_range_precision_copy_button'),
                    onPressed: selectedText.isEmpty
                        ? null
                        : () => _copySelectedRange(selectedText),
                    icon: const Icon(Icons.content_copy_outlined, size: 18),
                    label: const Text('この範囲をコピー'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const Key('note_range_precision_apply_button'),
                  onPressed: safeEnd <= safeStart
                      ? null
                      : () => _applyRangeAndPop(safeStart, safeEnd),
                  child: const Text('エディタへ反映'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrecisionMode(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        if (_primaryItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('ワンタップ抽出', style: theme.textTheme.titleSmall),
          ),
          for (var i = 0; i < _primaryItems.length; i++)
            _buildItemTile(
              theme: theme,
              item: _primaryItems[i],
              copyButtonKey: Key('note_range_quick_copy_$i'),
            ),
          const SizedBox(height: 4),
        ],
        _buildPrecisionCard(theme),
        if (_lineItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('各行からコピー', style: theme.textTheme.titleSmall),
          ),
          for (final item in _lineItems)
            _buildItemTile(theme: theme, item: item),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('note_range_select_page'),
      appBar: AppBar(
        title: const Text('範囲を選択してコピー'),
      ),
      body: Column(
        children: [
          _buildModeSwitcher(),
          Expanded(
            child: _mode == 0
                ? _buildNativeMode(theme)
                : _buildPrecisionMode(theme),
          ),
        ],
      ),
    );
  }
}
