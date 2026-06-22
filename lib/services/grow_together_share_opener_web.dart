import 'package:web/web.dart' as web;

/// X の投稿 intent を**サイズ付きポップアップ**で開く（Web 専用）。
///
/// `window.open(url, '_blank')`（フルタブ）だと X が full app の作成画面へ
/// リダイレクトする過程で本文が脱落し空欄になる。サイズ指定付きで開くと X の
/// 専用 intent 作成画面が表示され、本文＋URL が確実に prefill される
/// （一般的な「Xでシェア」ボタンと同じ定石）。
///
/// ユーザー操作と同一イベントループで同期的に呼ぶことでポップアップブロックを
/// 避ける（呼び出し側は await を挟まない）。
bool openXSharePopup(String url) {
  web.window.open(
    url,
    'jibun-x-share',
    'width=600,height=680,menubar=no,toolbar=no,location=no,status=no',
  );
  return true;
}
