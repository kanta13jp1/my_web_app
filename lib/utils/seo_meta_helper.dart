import 'package:web/web.dart' as web;

/// Flutter Web 上で動的に OG/meta タグとページタイトルを更新するヘルパー。
///
/// 公開メモの詳細ページなど、ページごとに固有の title / description /
/// og:image を設定する際に使用する。
class SeoMetaHelper {
  SeoMetaHelper._();

  /// ページの <title> を更新する。
  static void setTitle(String title) {
    web.document.title = title;
  }

  /// <meta name="[name]"> の content を更新する。存在しなければ作成する。
  static void setMeta(String name, String content) {
    final existing = web.document.querySelector('meta[name="$name"]');
    if (existing != null) {
      existing.setAttribute('content', content);
    } else {
      final meta =
          web.document.createElement('meta') as web.HTMLMetaElement;
      meta.name = name;
      meta.content = content;
      web.document.head?.appendChild(meta);
    }
  }

  /// <meta property="[property]"> (OG タグ) の content を更新する。
  static void setOgTag(String property, String content) {
    final existing =
        web.document.querySelector('meta[property="$property"]');
    if (existing != null) {
      existing.setAttribute('content', content);
    } else {
      final meta =
          web.document.createElement('meta') as web.HTMLMetaElement;
      meta.setAttribute('property', property);
      meta.content = content;
      web.document.head?.appendChild(meta);
    }
  }

  /// 公開メモ用の SEO タグを一括設定する。
  static void setPublicMemoSeo({
    required String title,
    required String description,
    required String url,
    String? imageUrl,
  }) {
    setTitle('$title | 自分株式会社');
    setMeta('description', description);

    setOgTag('og:title', title);
    setOgTag('og:description', description);
    setOgTag('og:url', url);
    setOgTag('og:type', 'article');
    setOgTag('og:site_name', '自分株式会社');
    if (imageUrl != null && imageUrl.isNotEmpty) {
      setOgTag('og:image', imageUrl);
    }

    // Twitter Card
    setMeta('twitter:card', 'summary_large_image');
    setMeta('twitter:title', title);
    setMeta('twitter:description', description);
    if (imageUrl != null && imageUrl.isNotEmpty) {
      setMeta('twitter:image', imageUrl);
    }
  }

  /// デフォルトの SEO タグにリセットする。
  static void resetToDefault() {
    setTitle('自分株式会社 — AI統合ライフマネジメント');
    setMeta(
      'description',
      '自分株式会社は、AI が伴走する知的生産プラットフォームです。'
          'メモ、資産管理、タスク管理、SNS を一つに統合。',
    );
    setOgTag('og:title', '自分株式会社');
    setOgTag(
      'og:description',
      'AI統合ライフマネジメントプラットフォーム',
    );
    setOgTag('og:url', 'https://my-web-app-b67f4.web.app/');
    setOgTag('og:type', 'website');
  }
}
