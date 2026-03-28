import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_reality.dart';
import 'package:my_web_app/services/local_election_share_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final service = LocalElectionShareService(
    SupabaseClient('https://example.supabase.co', 'test-anon-key'),
  );

  LocalElectionRealitySnapshot buildSnapshot() {
    return LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': '2026-03-28T09:00:00.000Z',
      'baselineCurrentLocalMembers': 340,
      'officialCurrentLocalMembers': 333,
      'targetLocalMembers': 700,
      'baselineNetIncreaseRequired': 360,
      'actualNetIncreaseRequired': 367,
      'official2023FirstHalfWins': 62,
      'official2023SecondHalfWins': 121,
      'official2023TotalWins': 183,
      'aiSummary': '地方議員数は333人で、700まで残り367人です。',
      'aiAlerts': <String>['議員不在県の穴埋めが必要です。'],
      'aiStrategicNotes': <String>['全県連に月次KPIを割り振る必要があります。'],
      'prefectures': <Map<String, dynamic>>[
        <String, dynamic>{
          'prefecture': '東京都',
          'sourceUrl': 'https://example.com/tokyo',
          'currentMembers': 43,
          'prefecturalAssemblyMembers': 9,
          'municipalAssemblyMembers': 34,
        },
        <String, dynamic>{
          'prefecture': '香川県',
          'sourceUrl': 'https://example.com/kagawa',
          'currentMembers': 23,
          'prefecturalAssemblyMembers': 5,
          'municipalAssemblyMembers': 18,
        },
        <String, dynamic>{
          'prefecture': '鳥取県',
          'sourceUrl': 'https://example.com/tottori',
          'currentMembers': 0,
          'prefecturalAssemblyMembers': 0,
          'municipalAssemblyMembers': 0,
        },
        <String, dynamic>{
          'prefecture': '島根県',
          'sourceUrl': 'https://example.com/shimane',
          'currentMembers': 3,
          'prefecturalAssemblyMembers': 1,
          'municipalAssemblyMembers': 2,
        },
      ],
      'members': <Map<String, dynamic>>[
        <String, dynamic>{
          'prefecture': '東京都',
          'sourceUrl': 'https://example.com/tokyo',
          'detailUrl': 'https://example.com/member/a',
          'name': '東京サンプル',
          'kana': 'とうきょうさんぷる',
          'constituency': '千代田区',
          'municipality': '千代田区',
          'assemblyLabel': '区議会',
          'assemblyCategory': 'municipal',
          'electionCountLabel': '2期',
          'age': 45,
          'profile': '市民活動と政策提言に取り組んできた。',
        },
        <String, dynamic>{
          'prefecture': '香川県',
          'sourceUrl': 'https://example.com/kagawa',
          'detailUrl': 'https://example.com/member/b',
          'name': '香川サンプル',
          'kana': 'かがわさんぷる',
          'constituency': '高松市',
          'municipality': '高松市',
          'assemblyLabel': '市議会',
          'assemblyCategory': 'municipal',
          'electionCountLabel': '1期',
        },
      ],
    });
  }

  test('buildDraft creates full election public memo payload', () {
    final snapshot = buildSnapshot();
    final draft = service.buildDraft(
      snapshot: snapshot,
      members: snapshot.members,
    );

    expect(draft.noteId, greaterThan(0));
    expect(draft.title, contains('2026/03/28'));
    expect(draft.content, contains('全都道府県内訳'));
    expect(draft.content, contains('現職地方議員名簿'));
    expect(draft.content, contains('🔴 鳥取県'));
    expect(draft.content, contains('🟡 島根県'));
    expect(draft.metadata['type'], LocalElectionShareService.metadataType);
    expect(draft.metadata['officialCurrentLocalMembers'], 333);
    expect(draft.metadata['missingPrefectureCount'], greaterThanOrEqualTo(1));
  });

  test('buildXShareText includes public note link and alert counts', () {
    final snapshot = buildSnapshot();
    final shareText = service.buildXShareText(
      snapshot: snapshot,
      publicUrl: 'https://example.com/public-memo?id=10',
    );

    expect(shareText, contains('国民民主党の地方議員数 2026/03/28'));
    expect(shareText, contains('🔴議員不在'));
    expect(shareText, contains('🟡要強化'));
    expect(shareText, contains('https://example.com/public-memo?id=10'));
  });
}
