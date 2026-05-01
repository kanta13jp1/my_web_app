import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

// Web以外（テストやスマホ）では何もしない、またはログを出す
void downloadImageFile(List<int> bytes, String fileName) {
  debugPrint('Web以外でのダウンロード機能はサポートされていません');
}

// URLを開く機能（スタブ）
void openWebUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    debugPrint('Invalid URL: $url');
    return;
  }
  unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
}

// シェア機能（スタブ）
Future<void> shareWebContent(String title, String text, String url) async {
  debugPrint('Web以外: シェア機能はサポートされていません');
}

void downloadCsvFile(String csvData, String fileName) {
  debugPrint('Web以外: CSVダウンロード機能はサポートされていません');
}
