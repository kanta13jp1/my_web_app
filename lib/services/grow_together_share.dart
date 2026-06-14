import 'package:url_launcher/url_launcher.dart';

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
  static const String shareText = 'ユーザーが機能追加要望や改善要望、不具合報告をすると、'
      'AIが勝手にそれに対応してくれるアプリを作りました。\n\n'
      '使ってみてください。みんなでアプリを育てられます。\n\n'
      '自分株式会社';

  /// クリップボードへコピーする用の、URL を含む完全な共有文。
  static String get fullShareMessage => '$shareText\n$appUrl';

  /// X の投稿 intent URL を生成する純関数。
  ///
  /// `text`（本文）と `url`（リンク）を分けて渡すことで、X が URL を自動で
  /// t.co 短縮し、本文の文字数超過を避ける。副作用を持たないためテスト容易。
  static Uri buildXIntentUrl() {
    return Uri.https('x.com', '/intent/tweet', <String, String>{
      'text': shareText,
      'url': appUrl,
    });
  }

  /// X の投稿画面を開く。Web では別タブ、その他では外部アプリで開く。
  ///
  /// 成功可否を返す（ポップアップブロック等で開けなかった場合は false）。
  static Future<bool> launchXShare() async {
    final uri = buildXIntentUrl();
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }
}
