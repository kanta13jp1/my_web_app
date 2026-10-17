import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/wiki_page_response.dart';

void main() {
  test('hub title and exact multiline body become display fields', () {
    final result = normalizeWikiPageResponse({
      'id': 'row-1',
      'created_at': '2026-09-22T00:00:00Z',
      'metadata': <String, dynamic>{
        'title': 'Page title',
        'content': 'line one\n\n  line two',
        'category': 'parent-1',
      },
    });
    expect(result['title'], 'Page title');
    expect(result['content'], 'line one\n\n  line two');
    expect(result['category'], 'parent-1');
    expect(result['createdAt'], '2026-09-22T00:00:00Z');
  });

  test('hub row identity wins over obsolete metadata IDs without mutation', () {
    final metadata = <String, dynamic>{'id': 'wrong', 'page_id': 'wrong'};
    final row = <String, dynamic>{'id': 'actual', 'metadata': metadata};
    final result = normalizeWikiPageResponse(row);
    expect(result['id'], 'actual');
    expect(result['page_id'], 'actual');
    expect(metadata['id'], 'wrong');
    expect(row.containsKey('page_id'), isFalse);
  });

  test('legacy flat response retains empty content and identity', () {
    final result = normalizeWikiPageResponse({
      'page_id': 'legacy',
      'title': 'Legacy',
      'content': '',
      'createdAt': '2026-09-21',
      'metadata': null,
    });
    expect(result['id'], 'legacy');
    expect(result['title'], 'Legacy');
    expect(result['content'], '');
    expect(result['createdAt'], '2026-09-21');
  });
}
