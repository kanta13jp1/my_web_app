const landingDocumentTitle = '自分株式会社とは？ | 人生を経営するAIライフマネジメントアプリ';
const philosophyDocumentTitle = '自分株式会社とは？人生を経営する9原則と実践方法';

String normalizeRoutePath(String routePath) {
  final path = Uri.tryParse(routePath)?.path ?? routePath;
  if (path.length <= 1) return path.isEmpty ? '/' : path;
  return path.replaceFirst(RegExp(r'/+$'), '');
}

String documentTitleForRoute(String routePath) {
  return switch (normalizeRoutePath(routePath)) {
    '/philosophy' => philosophyDocumentTitle,
    '/' => landingDocumentTitle,
    _ => '自分株式会社',
  };
}
