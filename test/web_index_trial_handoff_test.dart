import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SEO trial CTA preserves the in-flight Flutter boot on the root LP', () {
    final html = File('web/index.html').readAsStringSync();

    expect(
      html,
      contains(
        '<link rel="preload" href="main.dart.js" as="script" '
        'fetchpriority="high">',
      ),
    );
    expect(html, contains('id="seo-trial-cta"'));
    expect(
      html,
      contains(
        'href="/?lp_intent=trial&amp;utm_source=seo_shell&amp;utm_medium=landing&amp;utm_campaign=first_user_growth"',
      ),
    );
    expect(html, contains('id="seo-loading-status"'));
    expect(html, contains('window.location.pathname === \'/\''));
    expect(html, contains('event.preventDefault();'));
    expect(html, contains('window.history.replaceState('));
    expect(html, contains('target.pathname + target.search + target.hash'));
    expect(
      html,
      contains('trialCta.setAttribute(\'aria-busy\', \'true\')'),
    );
  });
}
