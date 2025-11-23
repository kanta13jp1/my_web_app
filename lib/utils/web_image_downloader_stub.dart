// Web以外（テストやスマホ）では何もしない、またはログを出す
void downloadImageFile(List<int> bytes, String fileName) {
  print('Web以外でのダウンロード機能はサポートされていません');
}

// ✅ 追加: URLを開く機能（スタブ）
void openWebUrl(String url) {
  print('Web以外: $url を開こうとしました');
}

// ✅ 追加: シェア機能（スタブ）
Future<void> shareWebContent(String title, String text, String url) async {
  print('Web以外: シェア機能はサポートされていません');
}