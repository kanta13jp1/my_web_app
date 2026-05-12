import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/legal_term_glossary_service.dart';

void main() {
  test('matches predefined legal terms in reading order', () {
    const service = LegalTermGlossaryService();

    final matches = service.matchTerms(
      '憲法審査会では参議院の緊急集会、緊急政令、国家緊急権を議論した。',
    );

    expect(
      matches.map((match) => match.definition.term),
      <String>['憲法審査会', '参議院の緊急集会', '緊急政令', '国家緊急権'],
    );
  });

  test('prefers the longest match and avoids overlapping aliases', () {
    const service = LegalTermGlossaryService();

    final matches = service.matchTerms('参議院の緊急集会は緊急集会とも呼ばれる。');

    expect(matches, hasLength(2));
    expect(matches.first.matchedText, '参議院の緊急集会');
    expect(matches.last.matchedText, '緊急集会');
  });

  test('returns an empty list for plain text', () {
    const service = LegalTermGlossaryService();

    expect(service.matchTerms('今日は通常の契約レビューを行う。'), isEmpty);
  });
}
