import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SEO entities use one canonical publisher identity', () {
    final html = File('web/index.html').readAsStringSync();
    final blocks = RegExp(
      r'<script type="application/ld\+json"[^>]*>(.*?)</script>',
      dotAll: true,
    ).allMatches(html).map((match) => jsonDecode(match.group(1)!)).toList();
    final softwareApplication = blocks.cast<dynamic>().firstWhere(
          (block) => block is Map && block['@type'] == 'SoftwareApplication',
        ) as Map<String, dynamic>;
    final entityGraph = blocks.cast<dynamic>().firstWhere(
          (block) => block is Map && block['@graph'] is List,
        ) as Map<String, dynamic>;
    const organizationId = 'https://my-web-app-b67f4.web.app/#organization';
    final organizationNodes = (entityGraph['@graph'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .where(
          (node) =>
              node['@type'] == 'Organization' && node['@id'] == organizationId,
        )
        .toList();

    expect(softwareApplication['publisher'], <String, dynamic>{
      '@id': organizationId,
    });
    expect(organizationNodes, hasLength(1));
  });

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
    expect(html, contains('trialCta.setAttribute(\'aria-busy\', \'true\')'));
  });

  test('SEO shell hands off without showing two landing pages at once', () {
    final html = File('web/index.html').readAsStringSync();
    final normalizedHtml = html.replaceAll('\r\n', '\n');

    expect(
      normalizedHtml,
      contains(
        '<link rel="preload" '
        'href="assets/web/assets/fonts/NotoSansJP-Regular.ttf" '
        'as="font" type="font/ttf" crossorigin>',
      ),
    );
    expect(html, contains('position: fixed;'));
    expect(html, contains('inset: 0;'));
    expect(html, contains('transition: opacity 120ms ease-out;'));
    expect(
      normalizedHtml,
      contains(
        '#seo-shell[data-flutter-prewarm="true"] {\n'
        '      opacity: 1;\n'
        '    }',
      ),
    );
    expect(html, isNot(contains('opacity: 0.9;')));
    expect(html, contains('#seo-shell[data-flutter-ready="true"]'));
    expect(html, contains('transition-duration: 120ms;'));
    expect(html, contains('requestAnimationFrame(function ()'));
    expect(html, contains('var stableFramesRemaining = 12;'));
    expect(
      html,
      contains("seoShell.setAttribute('data-flutter-ready', 'true')"),
    );
    expect(html, contains('}, 150);'));
    expect(html, contains("seoShell.setAttribute('aria-hidden', 'true')"));
    expect(html, contains('seoShell.remove();'));
  });

  test('SEO shell describes the trial without unsupported promises', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('登録なしで1件試す'));
    expect(html, contains('AIは提案、決めるのは本人'));
    expect(html, contains('登録時にカード入力なし'));
    expect(html, isNot(contains('5分だけ無料で試す')));
    expect(html, isNot(contains('データは本人だけに表示')));
    expect(html, isNot(contains('基本機能は無料。いつでも停止できます。')));
  });
}
