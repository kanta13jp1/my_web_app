import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/route_document_title.dart';

void main() {
  test('public SEO routes keep their canonical document titles', () {
    expect(documentTitleForRoute('/'), landingDocumentTitle);
    expect(documentTitleForRoute('/philosophy'), philosophyDocumentTitle);
    expect(documentTitleForRoute('/settings'), '自分株式会社');
  });
}
