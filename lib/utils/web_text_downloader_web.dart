import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadTextFile(
  String textData,
  String fileName, {
  String mimeType = 'text/plain;charset=utf-8',
}) {
  final bytes = Uint8List.fromList(utf8.encode(textData));
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..click();
  web.URL.revokeObjectURL(url);
}
