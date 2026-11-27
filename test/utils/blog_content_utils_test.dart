import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/blog_content_utils.dart';

void main() {
  group('stripBlogFrontmatter', () {
    test('removes leading YAML frontmatter while keeping mid-article hr', () {
      const raw = '---\ntitle: "Sample"\npublished: false\n---\n\n'
          '# 見出し\n\n---\n\n本文です。';
      expect(
        stripBlogFrontmatter(raw),
        '# 見出し\n\n---\n\n本文です。',
      );
    });

    test('supports CRLF frontmatter and null/empty inputs', () {
      const crlf = '---\r\ntitle: "CRLF"\r\n---\r\n本文';
      expect(stripBlogFrontmatter(crlf), '本文');
      expect(stripBlogFrontmatter(null), '');
      expect(stripBlogFrontmatter('   '), '');
    });
  });

  group('extractBlogExcerpt', () {
    test('strips frontmatter and markdown when explicit excerpt is empty', () {
      final excerpt = extractBlogExcerpt({
        'excerpt': '',
        'content': '---\ntitle: "YAML"\npublished: false\n---\n\n'
            '# タイトル\n\nこれは**実用**ガイドです。[詳細](https://example.com)',
      });
      expect(excerpt, 'これは実用ガイドです。詳細');
      expect(excerpt, isNot(contains('published: false')));
    });

    test('prefers explicit excerpt after stripping leading frontmatter', () {
      final excerpt = extractBlogExcerpt({
        'excerpt': '明示サマリ',
        'content': '本文',
      });
      expect(excerpt, '明示サマリ');
    });

    test('truncates long text to maxLength with ellipsis', () {
      final excerpt = extractBlogExcerpt(
        {'content': 'あ' * 200},
        maxLength: 10,
      );
      expect(excerpt, '${'あ' * 10}…');
    });
  });

  group('formatBlogPlatformLabel', () {
    test('maps known and fallback platform codes safely', () {
      expect(formatBlogPlatformLabel('app'), '公式ブログ');
      expect(formatBlogPlatformLabel('qiita'), 'Qiita');
      expect(formatBlogPlatformLabel('devto'), 'dev.to');
      expect(formatBlogPlatformLabel('zenn'), 'Zenn');
      expect(formatBlogPlatformLabel('medium'), 'Medium');
      expect(formatBlogPlatformLabel(''), '');
    });
  });

  group('kBlogPageSelectColumns', () {
    test('aliases missing columns cleanly', () {
      expect(kBlogPageSelectColumns, contains('excerpt:content_preview'));
      expect(kBlogPageSelectColumns, contains('published_at:posted_at'));
      expect(kBlogPageSelectColumns, isNot(contains(', excerpt,')));
      expect(kBlogPageSelectColumns, isNot(contains(', published_at,')));
    });
  });
}
