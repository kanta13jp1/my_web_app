// 条件によって読み込むファイルを切り替えるスイッチ
import 'web_image_downloader_stub.dart'
    if (dart.library.js_interop) 'web_image_downloader_web.dart';

// ダウンロード機能を呼び出す共通関数
void downloadImageFile(List<int> bytes, String fileName) {
  downloadImage(bytes, fileName);
}