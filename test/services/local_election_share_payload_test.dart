import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/local_election_share_service.dart';

void main() {
  group('R24 buildElectionXPostPayload (x.post経由化)', () {
    test('lead + replies + variant/archetype tagging', () {
      final p = LocalElectionShareService.buildElectionXPostPayload([
        '国民民主党 地方議員集計 2026/07/12 公式地方議員数: 378人',
        '都道府県内訳(上位): 東京49 / 香川26 / 茨城22',
        'アラート: 議員不在 1県',
      ]);
      expect(p['action'], 'x.post');
      expect(p['text'], contains('地方議員集計'));
      expect((p['replyTexts'] as List).length, 2);
      expect(p['variant'], 'local_election_tracker');
      expect(p['contentArchetype'], 'data_report');
      expect(p['source'], 'local_election_tracker');
    });

    test('single tweet → no replyTexts; empty/blank → empty payload', () {
      final single =
          LocalElectionShareService.buildElectionXPostPayload(['only']);
      expect(single.containsKey('replyTexts'), isFalse);
      expect(
        LocalElectionShareService.buildElectionXPostPayload(['  ', '']),
        isEmpty,
      );
    });
  });
}
