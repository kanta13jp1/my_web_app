const landingDocumentTitle = '自分株式会社とは？ | 人生を経営するAIライフマネジメントアプリ';
const philosophyDocumentTitle = '自分株式会社とは？人生を経営する9原則と実践方法';

String documentTitleForRoute(String routePath) {
  return switch (routePath) {
    '/philosophy' => philosophyDocumentTitle,
    '/' => landingDocumentTitle,
    _ => '自分株式会社',
  };
}
