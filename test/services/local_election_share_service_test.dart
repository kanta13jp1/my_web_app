// ignore_for_file: require_trailing_commas

import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_plan.dart';
import 'package:my_web_app/models/local_election_reality.dart';
import 'package:my_web_app/services/local_election_share_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late LocalElectionShareService service;

  setUpAll(() async {
    await initializeDateFormatting('ja_JP');
    service = LocalElectionShareService(
      SupabaseClient('https://example.supabase.co', 'test-anon-key'),
    );
  });

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

  LocalElectionRealitySnapshot buildWeekendSnapshot() {
    return LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': '2026-04-08T09:00:00.000Z',
      'officialCurrentLocalMembers': 333,
      'actualNetIncreaseRequired': 367,
      'upcomingSchedules': <Map<String, dynamic>>[
        <String, dynamic>{
          'electionName': 'This Weekend Mayor Race',
          'prefecture': 'Tokyo',
          'municipality': 'Chiyoda',
          'electionCategory': 'chief',
          'voteDate': '2026-04-12',
          'announcementDate': '2026-04-05',
          'detailUrl': 'https://example.com/this-weekend',
          'officialCandidateSourceUrl': 'https://example.com/source',
          'seatCount': 1,
          'totalCandidateCount': 2,
          'kokuminCandidateCount': 0,
          'kokuminCandidateNames': <String>[],
          'kokuminCandidateStatuses': <String>[],
          'kokuminCandidateXHandles': <String>[],
        },
        <String, dynamic>{
          'electionName': 'Second Weekend Assembly Race',
          'prefecture': 'Osaka',
          'municipality': 'Sakai',
          'electionCategory': 'assembly',
          'voteDate': '2026-04-19',
          'announcementDate': '2026-04-12',
          'detailUrl': 'https://example.com/second-weekend',
          'officialCandidateSourceUrl': 'https://example.com/source',
          'seatCount': 20,
          'totalCandidateCount': 24,
          'kokuminCandidateCount': 0,
          'kokuminCandidateNames': <String>[],
          'kokuminCandidateStatuses': <String>[],
          'kokuminCandidateXHandles': <String>[],
        },
        <String, dynamic>{
          'electionName': 'Third Weekend Safe Race',
          'prefecture': 'Kyoto',
          'municipality': 'Uji',
          'electionCategory': 'assembly',
          'voteDate': '2026-04-26',
          'announcementDate': '2026-04-19',
          'detailUrl': 'https://example.com/third-weekend',
          'officialCandidateSourceUrl': 'https://example.com/source',
          'seatCount': 18,
          'totalCandidateCount': 18,
          'kokuminCandidateCount': 1,
          'kokuminCandidateNames': <String>['Sample Candidate'],
          'kokuminCandidateStatuses': <String>['公認'],
          'kokuminCandidateXHandles': <String>['sample_candidate'],
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

  test('buildXShareIntentUri separates the body text and shared URL', () {
    final snapshot = buildSnapshot();
    final uri = service.buildXShareIntentUri(
      snapshot: snapshot,
      publicUrl: 'https://example.com/public-memo?id=10',
    );

    expect(
        '${uri.scheme}://${uri.host}${uri.path}', 'https://x.com/intent/tweet');
    expect(uri.queryParameters['url'], 'https://example.com/public-memo?id=10');
    expect(
      uri.queryParameters['text'],
      isNot(contains('https://example.com/public-memo?id=10')),
    );
    expect(
      uri.queryParameters['text'],
      contains('国民民主党の地方議員数'),
    );
  });

  test('buildPrefectureKpiXShareText summarizes prefecture KPI and CDP gap',
      () {
    const plan = LocalElectionPrefecturePlan(
      prefecture: '東京都',
      region: '関東',
      additionalSeatTarget: 12,
      incumbentRetentionTarget: 43,
      focusMunicipalityCount: 20,
      newCandidateTarget: 15,
      endorsementDeadlineMonth: '2026-09',
      closeRaceSupportRounds: 8,
      currentMembers: 43,
      scheduledElectionCount: 3,
      cdpLocalMembers: 83,
    );
    const reality = LocalElectionPrefectureReality(
      prefecture: '東京都',
      sourceUrl: 'https://example.com/tokyo',
      currentMembers: 45,
      prefecturalAssemblyMembers: 9,
      municipalAssemblyMembers: 36,
      cdpLocalMembers: 83,
    );

    final shareText = service.buildPrefectureKpiXShareText(
      plan: plan,
      reality: reality,
      publicUrl:
          'https://example.com/public/local-election-700?prefecture=tokyo',
    );

    expect(shareText, contains('東京都 県連KPI'));
    expect(shareText, contains('現職 45人'));
    expect(shareText, contains('純増目標 12人'));
    expect(shareText, contains('予定選挙 3件'));
    expect(shareText, contains('公認内定期限 2026/09'));
    expect(shareText, contains('立憲参考 83人'));
    expect(shareText, contains('地力差 立憲+38'));
    expect(shareText, contains('都道府県議 9 / 市区町村議 36'));
    expect(
        shareText, contains('https://example.com/public/local-election-700'));
  });

  test('buildPrefectureKpiXShareIntentUri separates prefecture body and URL',
      () {
    const plan = LocalElectionPrefecturePlan(
      prefecture: '香川県',
      region: '四国',
      additionalSeatTarget: 5,
      incumbentRetentionTarget: 23,
      focusMunicipalityCount: 9,
      newCandidateTarget: 7,
      endorsementDeadlineMonth: '2026-08',
      closeRaceSupportRounds: 4,
      currentMembers: 23,
      scheduledElectionCount: 2,
      cdpLocalMembers: 20,
      endorsementConfirmed: true,
    );

    final uri = service.buildPrefectureKpiXShareIntentUri(
      plan: plan,
      publicUrl:
          'https://example.com/public/local-election-700?prefecture=kagawa',
    );

    expect(
      '${uri.scheme}://${uri.host}${uri.path}',
      'https://x.com/intent/tweet',
    );
    expect(
      uri.queryParameters['url'],
      'https://example.com/public/local-election-700?prefecture=kagawa',
    );
    expect(uri.queryParameters['text'], contains('香川県 県連KPI'));
    expect(uri.queryParameters['text'], contains('公認内定済み'));
    expect(
      uri.queryParameters['text'],
      isNot(contains('https://example.com/public/local-election-700')),
    );
  });

  test('buildUpcomingElectionsThread scopes results to the selected weekend',
      () {
    final snapshot = buildWeekendSnapshot();

    final tweets = service.buildUpcomingElectionsThread(
      snapshot: snapshot,
      weekendSaturday: DateTime(2026, 4, 18),
    );

    expect(tweets, isNotEmpty);
    expect(tweets.first, contains('4/18(土)〜4/19(日)'));
    expect(tweets.first, contains('Second Weekend Assembly Race'));
    expect(tweets.first, isNot(contains('This Weekend Mayor Race')));
    expect(tweets.first, isNot(contains('Third Weekend Safe Race')));
  });

  test(
      'buildUpcomingElectionsThread includes staffed races with candidate names',
      () {
    final snapshot = buildWeekendSnapshot();

    final tweets = service.buildUpcomingElectionsThread(
      snapshot: snapshot,
      weekendSaturday: DateTime(2026, 4, 25),
    );

    expect(tweets, isNotEmpty);
    expect(tweets.first, contains('Third Weekend Safe Race'));
    expect(tweets.first, contains('Sample Candidate'));
  });

  test('nextWeekends includes the current weekend on Sunday', () {
    final weekends = LocalElectionRealitySnapshot.nextWeekends(
      count: 3,
      now: DateTime(2026, 4, 12),
    );

    expect(weekends, hasLength(3));
    expect(weekends[0], DateTime(2026, 4, 11));
    expect(weekends[1], DateTime(2026, 4, 18));
    expect(weekends[2], DateTime(2026, 4, 25));
  });
}
