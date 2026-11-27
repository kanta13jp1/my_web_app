import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

typedef NoteNativeSelectionCallback = void Function(
  String selectedText,
  TextSelection? selection,
);

/// Web（特に iOS Safari PWA）でブラウザ標準の選択ハンドルを使う表示ビュー。
class NoteNativeSelectableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Color backgroundColor;
  final Color textColor;
  final NoteNativeSelectionCallback onSelectionChanged;

  const NoteNativeSelectableText({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.onSelectionChanged,
    this.style,
    super.key,
  });

  @override
  State<NoteNativeSelectableText> createState() =>
      _NoteNativeSelectableTextState();
}

class _NoteNativeSelectableTextState extends State<NoteNativeSelectableText> {
  web.HTMLDivElement? _container;
  JSFunction? _selectionListener;

  @override
  void initState() {
    super.initState();
    _selectionListener = ((web.Event _) {
      _handleSelectionChange();
    }).toJS;
    web.document.addEventListener('selectionchange', _selectionListener);
  }

  @override
  void didUpdateWidget(covariant NoteNativeSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final container = _container;
    if (container == null) {
      return;
    }
    if (oldWidget.text != widget.text) {
      container.textContent = widget.text;
    }
    if (oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.textColor != widget.textColor ||
        oldWidget.style?.fontSize != widget.style?.fontSize) {
      _applyStyles(container);
    }
  }

  @override
  void dispose() {
    if (_selectionListener != null) {
      web.document.removeEventListener('selectionchange', _selectionListener);
      _selectionListener = null;
    }
    _container = null;
    super.dispose();
  }

  void _applyStyles(web.HTMLDivElement div) {
    final fontSizePx = (widget.style?.fontSize ?? 16).round().clamp(12, 28);
    div.style
      ..width = '100%'
      ..height = '100%'
      ..boxSizing = 'border-box'
      ..padding = '16px'
      ..overflowY = 'auto'
      ..whiteSpace = 'pre-wrap'
      ..fontSize = '${fontSizePx}px'
      ..lineHeight = '1.75'
      ..cursor = 'text'
      ..pointerEvents = 'auto'
      ..borderRadius = '12px'
      ..backgroundColor = _toCssColor(widget.backgroundColor)
      ..color = _toCssColor(widget.textColor)
      ..border = '1px solid rgba(128, 128, 128, 0.25)'
      ..setProperty('-webkit-overflow-scrolling', 'touch')
      ..setProperty('word-break', 'break-word')
      ..setProperty('touch-action', 'pan-y')
      ..setProperty(
        'font-family',
        '-apple-system, BlinkMacSystemFont, "Hiragino Sans", '
            '"Noto Sans JP", sans-serif',
      )
      ..setProperty('-webkit-user-select', 'text', 'important')
      ..setProperty('user-select', 'text', 'important')
      ..setProperty('-webkit-touch-callout', 'default', 'important');
  }

  void _handleSelectionChange() {
    final container = _container;
    if (container == null || !mounted) {
      return;
    }
    final selection = web.window.getSelection();
    if (selection == null ||
        selection.rangeCount == 0 ||
        selection.isCollapsed) {
      return;
    }
    final range = selection.getRangeAt(0);
    if (!container.contains(range.startContainer) ||
        !container.contains(range.endContainer)) {
      return;
    }
    final selected = range.cloneContents().textContent ?? '';
    if (selected.isEmpty) {
      return;
    }
    TextSelection? offsets;
    final firstChild = container.firstChild;
    if (firstChild != null &&
        firstChild.isSameNode(range.startContainer) &&
        firstChild.isSameNode(range.endContainer)) {
      final start = range.startOffset.clamp(0, widget.text.length);
      final end = range.endOffset.clamp(start, widget.text.length);
      if (end > start) {
        offsets = TextSelection(baseOffset: start, extentOffset: end);
      }
    }
    widget.onSelectionChanged(selected, offsets);
  }

  String _toCssColor(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    final a = color.a.clamp(0.0, 1.0).toStringAsFixed(3);
    return 'rgba($r, $g, $b, $a)';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'div',
      onElementCreated: (element) {
        final div = element as web.HTMLDivElement;
        _container = div;
        div.textContent = widget.text;
        _applyStyles(div);
      },
    );
  }
}
