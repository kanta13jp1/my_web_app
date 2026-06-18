import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

// Web のみ package:web を使ってサイズ付きポップアップを開く。VM(flutter test)では
// dart:js_interop が無いため、条件付き import で非Web用スタブに切り替える。
import 'grow_together_share_opener_io.dart'
    if (dart.library.js_interop) 'grow_together_share_opener_web.dart'
    as share_opener;

/// 「みんなでアプリを育てる」X (旧 Twitter) シェア用の正本テキストとリンク生成。
///
/// 自分株式会社は、ユーザーが機能追加要望・改善要望・不具合報告を送ると、
/// それを自動で GitHub Issue 化し、`github-issue-fix` レーン (draft PR 自動起票)
/// と Claude / Codex の AI 開発フリートが対応に着手する仕組みを備えている。
/// この文言はその「みんなで育てるアプリ」という体験を共有するためのもの。
///
/// 副作用を持たない純関数 ([buildXIntentUrl] / [fullShareMessage]) を中心に置き、
/// 文字列・URL 生成を単体テストできるようにしている。
class GrowTogetherShare {
  const GrowTogetherShare._();

  /// 本番サイト URL（X intent の `url` パラメータにも使用）。
  static const String appUrl = 'https://my-web-app-b67f4.web.app/';

  /// X 投稿の本文。URL は intent の `url` パラメータで別途付与するため含めない
  /// （X 側が t.co 短縮し、本文の文字数を圧迫しないようにするため）。
  ///
  /// 文言は実態に合わせている: 送信内容を AI が自動で開発タスク(Issue)化して
  /// 「対応に着手」するところまでが自動。完全自律でコード修正を完了させると
  /// は約束しない（誇大広告を避け、共有文言が嘘にならないようにする）。
  static const String shareText = 'ユーザーが機能追加要望や改善要望、不具合報告を送ると、'
      'AIが自動で受け取り、開発タスク化して対応に着手してくれるアプリを作りました。\n\n'
      '使ってみてください。みんなでアプリを育てられます。\n\n'
      '自分株式会社';

  /// クリップボードへコピーする用の、URL を含む完全な共有文。
  /// `shareText` と `appUrl` がともに const のため、これ自体も const にできる
  /// （const ClipboardData などの const コンテキストで利用するため）。
  static const String fullShareMessage = '$shareText\n$appUrl';

  /// X の投稿 intent URL を生成する純関数。
  ///
  /// host は `twitter.com`（ログイン済みなら x.com の作成画面へリダイレクト）。
  /// `x.com/intent/tweet` を直接開くと作成画面が真っ白になる事象がある。
  ///
  /// URL は **`text` パラメータ内に本文と一緒に含める**（別の `url` パラメータは
  /// 使わない）。`text`+`url` の2パラメータ構成だと、X が full app の作成画面へ
  /// リダイレクトする際に本文が反映されず空欄になる事象が実機で確認された。
  /// 本リポジトリの他の共有導線(app_share_service / viral_ad_generator)と同じく
  /// 単一 `text` 構成にすることで本文が確実に prefill される。
  static Uri buildXIntentUrl() {
    return Uri.https('twitter.com', '/intent/tweet', <String, String>{
      'text': fullShareMessage,
    });
  }

  /// X の投稿画面を開く。Web では**サイズ付きポップアップ**で開く。
  ///
  /// 🔴 Web で `window.open(url, '_blank')`（フルタブ）だと、X が full app の
  /// 作成画面へリダイレクトする過程で本文が脱落し空欄になる（実機確認済み）。
  /// サイズ指定付きの `window.open(url, name, 'width=...,height=...')` で開くと
  /// X の専用 intent 作成画面が表示され、本文が確実に prefill される
  /// （一般的な「Xでシェア」ボタンと同じ定石）。
  ///
  /// 同期的に `window.open` を呼ぶことでユーザー操作のジェスチャを維持し、
  /// ポップアップブロックを避ける。
  static Future<bool> launchXShare() async {
    final uri = buildXIntentUrl();
    if (kIsWeb) {
      return share_opener.openXSharePopup(uri.toString());
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
