import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/route_document_title.dart';

void main() {
  test('public SEO routes keep their canonical document titles', () {
    expect(documentTitleForRoute('/'), landingDocumentTitle);
    expect(documentTitleForRoute('/philosophy'), philosophyDocumentTitle);
    expect(documentTitleForRoute('/philosophy/'), philosophyDocumentTitle);
    expect(
      documentTitleForRoute('/philosophy/?ref=seo'),
      philosophyDocumentTitle,
    );
    expect(documentTitleForRoute('/settings'), '自分株式会社');
  });

  test('route paths remove trailing slashes without changing root', () {
    expect(normalizeRoutePath('/'), '/');
    expect(normalizeRoutePath('/philosophy/'), '/philosophy');
    expect(normalizeRoutePath('/philosophy///?ref=seo'), '/philosophy');
  });
}
