import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/election_intelligence.dart';

void main() {
  test('parses all registered modes without enabling future collectors', () {
    final snapshot = ElectionIntelligenceSnapshot.fromJson(
      <String, dynamic>{
        'schemaVersion': 1,
        'selectedMode': 'local',
        'modes': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'local',
            'label': '地方選',
            'shortLabel': '地方',
            'availability': 'active',
            'description': '地方選を追跡',
            'collectors': <String>['local_members'],
          },
          <String, dynamic>{
            'id': 'house_of_representatives',
            'label': '衆院選',
            'shortLabel': '衆院',
            'availability': 'registered',
            'description': '準備中',
            'collectors': <String>[],
          },
          <String, dynamic>{
            'id': 'house_of_councillors',
            'label': '参院選',
            'shortLabel': '参院',
            'availability': 'registered',
            'description': '準備中',
            'collectors': <String>[],
          },
        ],
        'goals': <Map<String, dynamic>>[],
        'achievements': <Map<String, dynamic>>[],
        'officialEndorsements': <String, dynamic>{},
      },
    );

    expect(snapshot.selectedMode, ElectionModeId.local);
    expect(snapshot.modes, hasLength(3));
    expect(snapshot.modes.first.isActive, isTrue);
    expect(snapshot.modes[1].isActive, isFalse);
    expect(snapshot.modes[2].id, ElectionModeId.houseOfCouncillors);
  });

  test('parses verified goal, achievement, and official endorsements', () {
    final snapshot = ElectionIntelligenceSnapshot.fromJson(
      <String, dynamic>{
        'schemaVersion': 1,
        'selectedMode': 'local',
        'modes': <Map<String, dynamic>>[],
        'goals': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'local_members_700',
            'mode': 'local',
            'title': '地方議員700人',
            'metric': 'local_member_count',
            'currentValue': 360,
            'targetValue': 700,
            'unit': '人',
            'deadlineLabel': '次期統一地方選終了時',
            'sourceUrl': 'https://example.com/goal',
            'sourcePublishedAt': '2026-07-14',
            'verificationStatus': 'verified',
          },
        ],
        'achievements': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'unified_local_election_wins_2023',
            'mode': 'local',
            'title': '2023年統一地方選 当選者',
            'metric': 'unified_local_election_wins_2023',
            'value': 183,
            'unit': '人',
            'periodLabel': '2023年統一地方選',
            'sourceUrls': <String>['https://example.com/result'],
          },
        ],
        'officialEndorsements': <String, dynamic>{
          'sourceUrl': 'https://new-kokumin.jp/local-election-list',
          'sourceAsOf': '2026-08-05',
          'sourceDocumentSha256': List<String>.filled(64, 'a').join(),
          'totalCount': 217,
          'incumbentCount': 102,
          'newcomerCount': 106,
          'formerCount': 9,
          'recommendationCount': 9,
          'prefectureCount': 1,
          'prefectures': <Map<String, dynamic>>[
            <String, dynamic>{
              'prefecture': '神奈川',
              'totalCount': 39,
              'incumbentCount': 11,
              'newcomerCount': 28,
              'formerCount': 0,
            },
          ],
        },
      },
    );

    expect(snapshot.goals.single.isVerified, isTrue);
    expect(snapshot.goals.single.remaining, 340);
    expect(snapshot.achievements.single.value, 183);
    expect(snapshot.officialEndorsements.totalCount, 217);
    expect(
      snapshot.officialEndorsements.forPrefecture('神奈川県')?.totalCount,
      39,
    );

    final roundTrip = ElectionIntelligenceSnapshot.fromJson(snapshot.toJson());
    expect(roundTrip.goals.single.targetValue, 700);
    expect(roundTrip.officialEndorsements.recommendationCount, 9);
  });
}
