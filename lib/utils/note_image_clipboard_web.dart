import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

typedef NoteImagePasteHandler = Future<void> Function(
  Uint8List bytes,
  String fileName,
  String mimeType,
);

abstract class NoteImagePasteRegistration {
  void dispose();
}

NoteImagePasteRegistration registerNoteImagePasteListener({
  required bool Function() isEnabled,
  required NoteImagePasteHandler onImagePasted,
}) {
  return _WebNoteImagePasteRegistration(
    isEnabled: isEnabled,
    onImagePasted: onImagePasted,
  )..attach();
}

class _WebNoteImagePasteRegistration implements NoteImagePasteRegistration {
  _WebNoteImagePasteRegistration({
    required bool Function() isEnabled,
    required NoteImagePasteHandler onImagePasted,
  })  : _isEnabled = isEnabled,
        _onImagePasted = onImagePasted;

  final bool Function() _isEnabled;
  final NoteImagePasteHandler _onImagePasted;
  JSFunction? _pasteListener;
  bool _isProcessing = false;

  void attach() {
    _pasteListener = ((web.Event event) {
      unawaited(_handlePasteEvent(event));
    }).toJS;
    web.document.addEventListener('paste', _pasteListener);
  }

  Future<void> _handlePasteEvent(web.Event event) async {
    if (_isProcessing || !_isEnabled()) {
      return;
    }

    final clipboardEvent = event as web.ClipboardEvent;
    final items = clipboardEvent.clipboardData?.items;
    if (items == null) {
      return;
    }

    for (var index = 0; index < items.length; index++) {
      final item = items.item(index);
      if (item == null ||
          item.kind != 'file' ||
          !item.type.startsWith('image/')) {
        continue;
      }

      final file = item.getAsFile();
      if (file == null) {
        continue;
      }

      clipboardEvent.preventDefault();
      _isProcessing = true;
      try {
        final bytes = await _blobToBytes(file);
        final name = file.name.trim().isEmpty
            ? 'pasted-image.png'
            : file.name;
        await _onImagePasted(bytes, name, item.type);
      } finally {
        _isProcessing = false;
      }
      break;
    }
  }

  Future<Uint8List> _blobToBytes(web.Blob blob) {
    final completer = Completer<Uint8List>();
    final reader = web.FileReader();
    reader.onload = ((web.Event _) {
      if (completer.isCompleted) return;
      final result = reader.result;
      if (result == null) {
        completer.completeError(StateError('Clipboard image bytes are empty'));
        return;
      }
      final dataUrl = (result as JSString).toDart;
      final commaIndex = dataUrl.indexOf(',');
      if (commaIndex < 0) {
        completer.completeError(StateError('Invalid clipboard image data'));
        return;
      }
      completer.complete(base64Decode(dataUrl.substring(commaIndex + 1)));
    }).toJS;
    reader.onerror = ((web.Event _) {
      if (completer.isCompleted) return;
      completer.completeError(
        StateError(reader.error?.message ?? 'Failed to read clipboard image'),
      );
    }).toJS;
    reader.readAsDataURL(blob);
    return completer.future;
  }

  @override
  void dispose() {
    if (_pasteListener != null) {
      web.document.removeEventListener('paste', _pasteListener);
      _pasteListener = null;
    }
  }
}
