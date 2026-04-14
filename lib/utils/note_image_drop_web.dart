import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Wraps [child] with an HTML drop-zone that accepts image files.
/// On drop, [onImageDropped] is called with the raw bytes.
class NoteImageDropZone extends StatefulWidget {
  final Widget child;
  final Future<void> Function(List<int> bytes, String fileName, String mimeType)
      onImageDropped;

  const NoteImageDropZone({
    super.key,
    required this.child,
    required this.onImageDropped,
  });

  @override
  State<NoteImageDropZone> createState() => _NoteImageDropZoneState();
}

class _NoteImageDropZoneState extends State<NoteImageDropZone> {
  bool _isDragOver = false;
  JSFunction? _dragoverListener;
  JSFunction? _dragleaveListener;
  JSFunction? _dropListener;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _dragoverListener = ((web.Event e) {
      final drag = e as web.DragEvent;
      if (_dragHasImage(drag)) {
        drag.preventDefault();
        if (mounted && !_isDragOver) {
          setState(() => _isDragOver = true);
        }
      }
    }).toJS;

    _dragleaveListener = ((web.Event e) {
      final drag = e as web.DragEvent;
      // relatedTarget is null only when leaving the browser window
      if (drag.relatedTarget == null && mounted && _isDragOver) {
        setState(() => _isDragOver = false);
      }
    }).toJS;

    _dropListener = ((web.Event e) {
      final drag = e as web.DragEvent;
      drag.preventDefault();
      if (mounted && _isDragOver) setState(() => _isDragOver = false);
      if (_isProcessing) return;
      _isProcessing = true;
      unawaited(_handleDrop(drag).whenComplete(() => _isProcessing = false));
    }).toJS;

    web.document.addEventListener('dragover', _dragoverListener);
    web.document.addEventListener('dragleave', _dragleaveListener);
    web.document.addEventListener('drop', _dropListener);
  }

  /// Check via files list (avoids DataTransferItemList.item() binding issue).
  bool _dragHasImage(web.DragEvent drag) {
    final files = drag.dataTransfer?.files;
    if (files == null) return false;
    for (var i = 0; i < files.length; i++) {
      final f = files.item(i);
      if (f != null && f.type.startsWith('image/')) return true;
    }
    return false;
  }

  Future<void> _handleDrop(web.DragEvent drag) async {
    final files = drag.dataTransfer?.files;
    if (files == null) return;
    for (var i = 0; i < files.length; i++) {
      final file = files.item(i);
      if (file == null || !file.type.startsWith('image/')) continue;
      try {
        final bytes = await _blobToBytes(file);
        final name = file.name.trim().isEmpty ? 'dropped-image.png' : file.name;
        await widget.onImageDropped(bytes, name, file.type);
      } catch (_) {
        // ignore individual file errors
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
        completer.completeError(StateError('Drop image bytes are empty'));
        return;
      }
      final dataUrl = (result as JSString).toDart;
      final idx = dataUrl.indexOf(',');
      if (idx < 0) {
        completer.completeError(StateError('Invalid drop image data'));
        return;
      }
      completer.complete(base64Decode(dataUrl.substring(idx + 1)));
    }).toJS;
    reader.onerror = ((web.Event _) {
      if (completer.isCompleted) return;
      completer.completeError(
        StateError(reader.error?.message ?? 'Failed to read drop image'),
      );
    }).toJS;
    reader.readAsDataURL(blob);
    return completer.future;
  }

  @override
  void dispose() {
    web.document.removeEventListener('dragover', _dragoverListener);
    web.document.removeEventListener('dragleave', _dragleaveListener);
    web.document.removeEventListener('drop', _dropListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isDragOver)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0x226366F1),
                  border: Border.all(
                    color: const Color(0xFF6366F1),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        IconData(0xe3f3, fontFamily: 'MaterialIcons'),
                        size: 48,
                        color: Color(0xFF6366F1),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '画像をここにドロップ',
                        style: TextStyle(
                          color: Color(0xFF6366F1),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
