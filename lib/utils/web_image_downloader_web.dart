import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadImageFile(List<int> bytes, String fileName) {
  final imageBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = web.Blob([imageBytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..click();
  web.URL.revokeObjectURL(url);
}

void downloadCsvFile(String csvData, String fileName) {
  final bytes = Uint8List.fromList(utf8.encode('﻿$csvData'));
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..click();
  web.URL.revokeObjectURL(url);
}

// ✅ 追加: URLを開く機能
void openWebUrl(String url) {
  web.window.open(url, '_blank');
}

// ✅ 追加: シェア機能
Future<void> shareWebContent(String title, String text, String url) async {
  final shareData = web.ShareData(
    title: title,
    text: text,
    url: url,
  );
  await web.window.navigator.share(shareData).toDart;
}
