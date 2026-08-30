import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('landing page keeps the analyzer entry point small', () {
    final entryPoint = File('lib/pages/landing_page.dart');
    final content = File('lib/widgets/landing_page_content.dart');
    final comparison = File(
      'lib/widgets/landing_comparison_links_section.dart',
    );
    final faq = File('lib/widgets/landing_faq_section.dart');

    expect(entryPoint.readAsLinesSync().length, lessThanOrEqualTo(1000));
    expect(
      entryPoint.readAsStringSync(),
      contains(
        "export '../widgets/landing_page_content.dart' show LandingPage;",
      ),
    );
    expect(
      content.readAsStringSync(),
      allOf(
        contains("import 'landing_comparison_links_section.dart';"),
        contains("import 'landing_faq_section.dart';"),
        contains('const LandingComparisonLinksSection()'),
        contains('LandingFaqSection('),
      ),
    );
    expect(comparison.readAsStringSync(), contains('class _CompetitorRow'));
    expect(faq.readAsStringSync(), contains('class _FaqItem'));
  });
}
