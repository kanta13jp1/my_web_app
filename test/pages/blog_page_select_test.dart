import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/blog_page.dart';

void main() {
  test('BlogPage select columns alias excerpt and published_at safely', () {
    const cols = BlogPage.blogPostsSelectColumns;
    expect(cols, contains('excerpt:content_preview'));
    expect(cols, contains('published_at:posted_at'));

    final tokens = cols.split(',').map((t) => t.trim()).toList();
    expect(tokens.contains('excerpt'), isFalse);
    expect(tokens.contains('published_at'), isFalse);
  });
}
