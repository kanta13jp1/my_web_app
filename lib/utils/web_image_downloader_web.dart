import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:typed_data';

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
