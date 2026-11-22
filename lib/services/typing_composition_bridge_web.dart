import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Restores composition metadata omitted by Flutter 3.38's semantic editor.
/// Listeners read only the focused game's labelled input. No data leaves it.
class TypingCompositionBridge {
  TypingCompositionBridge({
    required bool Function() ownsInput,
    required void Function() onCommitted,
  })  : _ownsInput = ownsInput,
        _onCommitted = onCommitted {
    _start = _handleStart.toJS;
    _end = _handleEnd.toJS;
    web.document.addEventListener('compositionstart', _start, true.toJS);
    web.document.addEventListener('compositionend', _end, true.toJS);
  }

  final bool Function() _ownsInput;
  final void Function() _onCommitted;
  late final JSFunction _start;
  late final JSFunction _end;
  bool _composing = false;
  String? _pending;

  bool get isComposing => _composing;

  web.Element? _inputTarget(web.Event event) {
    if (!_ownsInput()) return null;
    // composedPath also reaches the labelled input through Flutter's shadow DOM.
    for (final target in event.composedPath().toDart) {
      if (!target.isA<web.HTMLInputElement>() &&
          !target.isA<web.HTMLTextAreaElement>()) {
        continue;
      }
      final element = target as web.Element;
      final label = element.getAttribute('aria-label') ?? '';
      if (label.startsWith('ローマ字入力') || label.startsWith('Romaji input')) {
        return element;
      }
    }
    return null;
  }

  void _handleStart(web.Event event) {
    if (_inputTarget(event) == null) return;
    _composing = true;
    _pending = null;
  }

  void _handleEnd(web.Event event) {
    final target = _inputTarget(event);
    if (target == null) {
      reset();
      return;
    }
    _pending = target.isA<web.HTMLInputElement>()
        ? (target as web.HTMLInputElement).value
        : (target as web.HTMLTextAreaElement).value;
    _composing = false;
    _onCommitted();
  }

  String? consume(String value) {
    final pending = _pending;
    if (_composing || pending == null) return null;
    final candidate = pending.endsWith(' ')
        ? pending.substring(0, pending.length - 1)
        : pending;
    if (value != candidate && value != '$candidate ') return null;
    _pending = null;
    return candidate;
  }

  String? takePending() {
    if (_composing) return null;
    final result = _pending;
    _pending = null;
    return result;
  }

  void reset() {
    _composing = false;
    _pending = null;
  }

  void dispose() {
    web.document.removeEventListener('compositionstart', _start, true.toJS);
    web.document.removeEventListener('compositionend', _end, true.toJS);
    reset();
  }
}
