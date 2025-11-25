import 'package:flutter/foundation.dart';

// Web以外（テストやスマホ）では何もしない、またはログを出す
void downloadImageFile(List<int> bytes, String fileName) {
  debugPrint('Web以外でのダウンロード機能はサポートされていません');
}

// URLを開く機能（スタブ）
void openWebUrl(String url) {
  debugPrint('Web以外: $url を開こうとしました');
}

// シェア機能（スタブ）
Future<void> shareWebContent(String title, String text, String url) async {
  debugPrint('Web以外: シェア機能はサポートされていません');
}
