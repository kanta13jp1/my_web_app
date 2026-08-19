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

  test('SEO shell covers the incomplete Flutter font handoff', () {
    final html = File('web/index.html').readAsStringSync();

    expect(
      html,
      contains(
        '<link rel="preload" '
        'href="assets/web/assets/fonts/NotoSansJP-Regular.ttf" '
        'as="font" type="font/ttf" crossorigin>',
      ),
    );
    expect(html, contains('position: fixed;'));
    expect(html, contains('inset: 0;'));
    expect(html, contains('transition: opacity 600ms ease-out;'));
    expect(html, contains('#seo-shell[data-flutter-prewarm="true"]'));
    expect(html, contains('opacity: 0.9;'));
    expect(html, contains('#seo-shell[data-flutter-ready="true"]'));
    expect(html, contains('requestAnimationFrame(function ()'));
    expect(html, contains('var stableFramesRemaining = 12;'));
    expect(
      html,
      contains("seoShell.setAttribute('data-flutter-ready', 'true')"),
    );
    expect(html, contains('}, 650);'));
    expect(html, contains("seoShell.setAttribute('aria-hidden', 'true')"));
    expect(html, contains('seoShell.remove();'));
  });
}
