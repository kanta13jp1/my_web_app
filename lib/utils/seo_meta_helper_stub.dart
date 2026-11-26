/// VM (単体 / widget テスト) 用の SeoMetaHelper スタブ。
class SeoMetaHelper {
  SeoMetaHelper._();

  static void setTitle(String title) {}

  static void setMeta(String name, String content) {}

  static void setOgTag(String property, String content) {}

  static void setPublicMemoSeo({
    required String title,
    required String description,
    required String url,
    String? imageUrl,
  }) {}

  static void resetToDefault() {}
}
