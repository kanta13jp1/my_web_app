// ここにWeb専用のインポートを書く
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:convert';

void downloadImage(List<int> bytes, String fileName) {
  // ここに元の share_note_card_dialog.dart にあったWeb用のダウンロード処理を移動
  // 例: アンカータグを作ってクリックするなど
  final base64 = base64Encode(bytes);
  final href = 'data:image/png;base64,$base64';
  
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = href;
  anchor.download = fileName;
  anchor.click();
}