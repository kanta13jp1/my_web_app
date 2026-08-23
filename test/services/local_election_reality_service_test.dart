import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_reality.dart';
import 'package:my_web_app/models/election_intelligence.dart';
import 'package:my_web_app/services/local_election_reality_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('caches and reloads local election reality snapshot with member roster',
      () async {
    const service = LocalElectionRealityService();
    final prefs = await SharedPreferences.getInstance();
    final snapshot = LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': '2026-03-28T14:30:00.000Z',
      'baselineCurrentLocalMembers': 340,
      'officialCurrentLocalMembers': 352,
      'targetLocalMembers': 700,
      'baselineNetIncreaseRequired': 360,
      'actualNetIncreaseRequired': 348,
      'official2023FirstHalfWins': 62,
      'official2023SecondHalfWins': 121,
      'official2023TotalWins': 183,
      'aiSummary': 'Official tally shows 352 local legislators.',
      'aiAlerts': <String>['348 more are needed to reach 700.'],
      'aiStrategicNotes': <String>[
        'Track every prefecture monthly and avoid incumbent losses.',
      ],
      'scheduleAiSummary':
          'Monitor upcoming local elections and prioritize unstaffed races.',
      'scheduleAiAlerts': <String>[
        'Tokyo Tama mayoral race currently has no Kokumin candidate.',
      ],
      'sources': <Map<String, String>>[
        <String, String>{
          'label': 'Official member page',
          'url': 'https://new-kokumin.jp/member',
          'category': 'official_members',
        },
      ],
      'prefectures': <Map<String, dynamic>>[
        <String, dynamic>{
          'prefecture': 'Tokyo',
          'sourceUrl': 'https://new-kokumin.jp/member_tag/tokyo',
          'currentMembers': 45,
          'prefecturalAssemblyMembers': 4,
          'municipalAssemblyMembers': 41,
          'cdpLocalMembers': 83,
          'cdpSourceUrl': 'https://cdp-japan.jp/members/prefecture/Tokyo',
        },
      ],
      'members': <Map<String, dynamic>>[
        <String, dynamic>{
          'prefecture': 'Tokyo',
          'sourceUrl': 'https://new-kokumin.jp/member_tag/tokyo',
          'detailUrl': 'https://new-kokumin.jp/member/sample-member',
          'name': 'Sample Member',
          'kana': 'sample member',
          'constituency': 'Tokyo Chiyoda',
          'municipality': 'Chiyoda',
          'assemblyLabel': 'City Council',
          'assemblyCategory': 'municipal',
          'electionCountLabel': '1 term',
          'birthDate': '1984/01/02',
          'age': 42,
          'gender': '',
          'profile': 'Worked in labor policy before joining local politics.',
        },
      ],
      'upcomingSchedules': <Map<String, dynamic>>[
        <String, dynamic>{
          'electionName': 'Tama mayoral election',
          'prefecture': 'Tokyo',
          'municipality': 'Tama',
          'electionCategory': '首長選挙',
          'voteDate': '2026-04-12',
          'announcementDate': '2026-04-05',
          'detailUrl': 'https://go2senkyo.com/local/senkyo/sample',
          'officialCandidateSourceUrl':
              'https://new-kokumin.jp/?post_type=election&prefectures=Tokyo',
          'seatCount': 1,
          'totalCandidateCount': 2,
          'kokuminCandidateCount': 0,
          'kokuminCandidateNames': <String>[],
          'kokuminCandidateStatuses': <String>[],
          'kokuminCandidateXHandles': <String>[],
        },
        <String, dynamic>{
          'electionName': 'Nerima mayoral election',
          'prefecture': 'Tokyo',
          'municipality': 'Nerima',
          'electionCategory': 'chief',
          'voteDate': '2026-04-12',
          'announcementDate': '2026-04-05',
          'detailUrl': '',
          'officialCandidateSourceUrl':
              'https://new-kokumin.jp/?post_type=election&prefectures=Tokyo',
          'seatCount': 1,
          'totalCandidateCount': 3,
          'kokuminCandidateCount': 1,
          'kokuminCandidateNames': <String>['おじま紘平'],
          'kokuminCandidateStatuses': <String>['推薦'],
          'kokuminCandidateXHandles': <String>['ojimakohei'],
        },
        <String, dynamic>{
          'electionName': 'Tama city council by-election',
          'prefecture': 'Tokyo',
          'municipality': 'Tama',
          'electionCategory': 'assembly',
          'voteDate': '2026-04-12',
          'announcementDate': '2026-04-05',
          'detailUrl': '',
          'officialCandidateSourceUrl':
              'https://new-kokumin.jp/?post_type=election&prefectures=Tokyo',
          'seatCount': 1,
          'totalCandidateCount': 3,
          'kokuminCandidateCount': 0,
          'kokuminCandidateNames': <String>[],
          'kokuminCandidateStatuses': <String>[],
          'kokuminCandidateXHandles': <String>[],
        },
      ],
    });

    await service.cacheSnapshot(snapshot, prefs: prefs);
    final loaded = await service.loadCachedSnapshot(prefs: prefs);

    expect(loaded, isNotNull);
    expect(loaded!.officialCurrentLocalMembers, 352);
    expect(loaded.deltaFromBaseline, 12);
    expect(loaded.topPrefectures().first.prefecture, 'Tokyo');
    expect(loaded.prefectures.first.cdpLocalMembers, 83);
    expect(
      loaded.prefectures.first.cdpSourceUrl,
      'https://cdp-japan.jp/members/prefecture/Tokyo',
    );
    expect(loaded.sources.first.category, 'official_members');
    expect(loaded.members, hasLength(1));
    expect(loaded.members.single.name, 'Sample Member');
    expect(loaded.ageAvailableCount, 1);
    expect(loaded.scheduleAiAlerts, isNotEmpty);
    expect(loaded.upcomingSchedules, hasLength(3));
    expect(loaded.targetElectionSchedules, hasLength(1));
    expect(loaded.redAlertScheduleCount, 1);
    expect(loaded.upcomingSchedules.first.isChiefElection, isTrue);
    expect(
      loaded.upcomingSchedules[1].kokuminCandidateXHandles,
      <String>['ojimakohei'],
    );

    final history = await service.loadSnapshotHistory(prefs: prefs);
    expect(history, hasLength(1));
    expect(history.single.officialCurrentLocalMembers, 352);
    expect(history.single.actualNetIncreaseRequired, 348);
  });

  test('keeps future election mode caches isolated from the local snapshot',
      () async {
    final prefs = await SharedPreferences.getInstance();
    const service = LocalElectionRealityService(client: null);
    final snapshot = LocalElectionRealitySnapshot.fromJson(
      <String, dynamic>{
        'fetchedAt': '2026-08-07T00:00:00.000Z',
        'officialCurrentLocalMembers': 0,
        'electionIntelligence': <String, dynamic>{
          'schemaVersion': 1,
          'selectedMode': 'house_of_representatives',
          'modes': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'house_of_representatives',
              'label': '衆院選',
              'shortLabel': '衆院',
              'availability': 'active',
              'description': '衆院選を追跡',
              'collectors': <String>['official_candidates'],
            },
          ],
          'goals': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'house_goal',
              'mode': 'house_of_representatives',
              'title': '公式目標',
              'metric': 'seats',
              'currentValue': 0,
              'targetValue': 1,
              'unit': '議席',
              'deadlineLabel': '次期衆院選',
              'sourceUrl': 'https://example.com/goal',
              'sourcePublishedAt': '2026-08-07',
              'verificationStatus': 'verified',
            },
          ],
          'achievements': <Map<String, dynamic>>[],
          'officialEndorsements': <String, dynamic>{},
        },
      },
    );

    expect(snapshot.hasData, isTrue);
    await service.cacheSnapshot(snapshot, prefs: prefs);

    expect(await service.loadCachedSnapshot(prefs: prefs), isNull);
    final loaded = await service.loadCachedSnapshot(
      prefs: prefs,
      mode: ElectionModeId.houseOfRepresentatives,
    );
    expect(loaded, isNotNull);
    expect(
      loaded!.electionIntelligence.selectedMode,
      ElectionModeId.houseOfRepresentatives,
    );
  });

  test('caches and reloads member profile details', () async {
    const service = LocalElectionRealityService();
    final prefs = await SharedPreferences.getInstance();
    const profile = LocalElectionLegislatorProfile(
      prefecture: 'Oita',
      sourceUrl: 'https://new-kokumin.jp/member_tag/oita',
      detailUrl: 'https://new-kokumin.jp/member/abe-kunihiko',
      name: 'Abc Member',
      kana: 'abc member',
      constituency: 'Oita City',
      municipality: 'Oita City',
      assemblyLabel: 'City Council',
      assemblyCategory: 'municipal',
      electionCountLabel: '1 term',
      birthDate: '1971/11/03',
      age: 54,
      profile: 'Former labor union leader in Oita.',
    );

    await service.cacheMemberProfile(profile, prefs: prefs);
    final loaded = await service.loadCachedMemberProfile(
      profile.detailUrl,
      prefs: prefs,
    );

    expect(loaded, isNotNull);
    expect(loaded!.name, 'Abc Member');
    expect(loaded.age, 54);
    expect(loaded.hasDetailedProfile, isTrue);
  });

  test('target schedules keep local assemblies and exclude chiefs/national',
      () {
    final snapshot = LocalElectionRealitySnapshot(
      fetchedAt: DateTime(2026, 4, 24),
      baselineCurrentLocalMembers: 340,
      officialCurrentLocalMembers: 355,
      targetLocalMembers: 700,
      baselineNetIncreaseRequired: 360,
      actualNetIncreaseRequired: 345,
      official2023FirstHalfWins: 62,
      official2023SecondHalfWins: 121,
      official2023TotalWins: 183,
      aiSummary: '',
      aiAlerts: <String>[],
      aiStrategicNotes: <String>[],
      scheduleAiSummary: '',
      scheduleAiAlerts: <String>[],
      sources: <LocalElectionRealitySource>[],
      prefectures: <LocalElectionPrefectureReality>[],
      members: <LocalElectionLegislatorProfile>[],
      upcomingSchedules: const <LocalElectionScheduleEntry>[
        LocalElectionScheduleEntry(
          electionName: '山口市議会議員選挙',
          prefecture: '山口県',
          municipality: '山口市',
          electionCategory: 'assembly',
          voteDate: '2026-04-26',
          announcementDate: '2026-04-19',
          detailUrl: '',
          officialCandidateSourceUrl: '',
          seatCount: 34,
          totalCandidateCount: 40,
          kokuminCandidateCount: 2,
          kokuminCandidateNames: <String>[],
          kokuminCandidateStatuses: <String>[],
          kokuminCandidateXHandles: <String>[],
        ),
        LocalElectionScheduleEntry(
          electionName: '鹿島市長選挙',
          prefecture: '佐賀県',
          municipality: '鹿島市',
          electionCategory: 'chief',
          voteDate: '2026-04-26',
          announcementDate: '2026-04-19',
          detailUrl: '',
          officialCandidateSourceUrl: '',
          seatCount: 1,
          totalCandidateCount: 2,
          kokuminCandidateCount: 0,
          kokuminCandidateNames: <String>[],
          kokuminCandidateStatuses: <String>[],
          kokuminCandidateXHandles: <String>[],
        ),
        LocalElectionScheduleEntry(
          electionName: '参議院議員選挙',
          prefecture: '東京都',
          municipality: '',
          electionCategory: 'other',
          voteDate: '2026-07-12',
          announcementDate: '2026-06-25',
          detailUrl: '',
          officialCandidateSourceUrl: '',
          seatCount: 0,
          totalCandidateCount: 0,
          kokuminCandidateCount: 0,
          kokuminCandidateNames: <String>[],
          kokuminCandidateStatuses: <String>[],
          kokuminCandidateXHandles: <String>[],
        ),
      ],
    );

    expect(
      snapshot.targetElectionSchedules.map((item) => item.electionName),
      <String>['山口市議会議員選挙'],
    );
  });

  test('rejects cached snapshots with empty official prefecture pages',
      () async {
    const service = LocalElectionRealityService();
    final prefs = await SharedPreferences.getInstance();
    final snapshot = LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': DateTime(2026, 4, 23, 9).toIso8601String(),
      'officialCurrentLocalMembers': 344,
      'actualNetIncreaseRequired': 356,
      'prefectures': <Map<String, dynamic>>[
        <String, dynamic>{
          'prefecture': '京都府',
          'sourceUrl': 'https://new-kokumin.jp/member_tag/kyoto',
          'currentMembers': 0,
          'prefecturalAssemblyMembers': 0,
          'municipalAssemblyMembers': 0,
        },
      ],
      'members': <Map<String, dynamic>>[],
    });

    expect(snapshot.suspiciousEmptyOfficialPrefectures, <String>['京都府']);

    await service.cacheSnapshot(snapshot, prefs: prefs);

    expect(await service.loadCachedSnapshot(prefs: prefs), isNull);
    expect(await service.loadSnapshotHistory(prefs: prefs), isEmpty);
  });

  test('keeps roster identity when detail profile omits name and kana', () {
    const roster = LocalElectionLegislatorProfile(
      prefecture: 'Oita',
      sourceUrl: 'https://new-kokumin.jp/member_tag/oita',
      detailUrl: 'https://new-kokumin.jp/member/abe-kunihiko',
      name: 'Roster Name',
      kana: 'roster kana',
      constituency: 'Oita City',
      municipality: 'Oita City',
      assemblyLabel: 'City Council',
      assemblyCategory: 'municipal',
      electionCountLabel: '1 term',
    );
    const detail = LocalElectionLegislatorProfile(
      prefecture: 'Oita',
      sourceUrl: 'https://new-kokumin.jp/member/abe-kunihiko',
      detailUrl: 'https://new-kokumin.jp/member/abe-kunihiko',
      name: '',
      kana: '',
      constituency: 'Oita City',
      municipality: 'Oita City',
      assemblyLabel: 'City Council',
      assemblyCategory: 'municipal',
      electionCountLabel: '1 term',
      birthDate: '1971/11/03',
      age: 54,
      profile: 'Former labor union leader in Oita.',
    );

    final merged = roster.mergeWith(detail);

    expect(merged.name, 'Roster Name');
    expect(merged.kana, 'roster kana');
    expect(merged.age, 54);
    expect(merged.profile, 'Former labor union leader in Oita.');
  });

  test('keeps only the latest history point for the same day', () async {
    const service = LocalElectionRealityService();
    final prefs = await SharedPreferences.getInstance();

    final first = LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': '2026-03-28T01:00:00.000Z',
      'officialCurrentLocalMembers': 345,
      'actualNetIncreaseRequired': 355,
    });
    final second = LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': '2026-03-28T12:00:00.000Z',
      'officialCurrentLocalMembers': 347,
      'actualNetIncreaseRequired': 353,
    });

    await service.cacheSnapshot(first, prefs: prefs);
    await service.cacheSnapshot(second, prefs: prefs);

    final history = await service.loadSnapshotHistory(prefs: prefs);
    expect(history, hasLength(1));
    expect(history.single.officialCurrentLocalMembers, 347);
    expect(history.single.actualNetIncreaseRequired, 353);
  });

  test('normalizes known Kuki city council result to two Kokumin wins', () {
    final snapshot = LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': '2026-04-27T05:30:00.000Z',
      'officialCurrentLocalMembers': 361,
      'actualNetIncreaseRequired': 339,
      'upcomingSchedules': <Map<String, dynamic>>[
        <String, dynamic>{
          'electionName': '久喜市議会議員選挙',
          'prefecture': '埼玉県',
          'municipality': '久喜市',
          'electionCategory': 'assembly',
          'voteDate': '2026-04-19',
          'announcementDate': '2026-04-12',
          'detailUrl': 'https://www.city.kuki.lg.jp/',
          'officialCandidateSourceUrl': 'https://new-kokumin.jp/election',
          'seatCount': 27,
          'totalCandidateCount': 40,
          'kokuminCandidateCount': 2,
          'kokuminCandidateNames': <String>['はやま武士', '坂本和久'],
          'kokuminCandidateStatuses': <String>[],
          'kokuminCandidateXHandles': <String>[
            'hymtks0601',
            'Kazuhisa_SakaMT',
          ],
          'isPast': true,
        },
      ],
    });

    final schedule = snapshot.upcomingSchedules.single;
    expect(schedule.kokuminCandidateNames, <String>[
      'はやま 武士',
      '坂本 かずひさ',
    ]);
    expect(schedule.kokuminCandidateStatuses, <String>['当選', '当選']);
    expect(snapshot.resolvedPastElectionResults, hasLength(1));
    expect(snapshot.resolvedPastElectionResults.single.winCount, 2);
  });

  test('normalizes known Kasukabe city council result to a Kokumin win', () {
    final snapshot = LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': '2026-04-27T07:40:00.000Z',
      'officialCurrentLocalMembers': 362,
      'actualNetIncreaseRequired': 338,
      'upcomingSchedules': <Map<String, dynamic>>[
        <String, dynamic>{
          'electionName': '春日部市議会議員選挙',
          'prefecture': '埼玉県',
          'municipality': '春日部市',
          'electionCategory': 'assembly',
          'voteDate': '2026-04-19',
          'announcementDate': '2026-04-12',
          'detailUrl': 'https://www.city.kasukabe.lg.jp/',
          'officialCandidateSourceUrl': 'https://new-kokumin.jp/election',
          'seatCount': 30,
          'totalCandidateCount': 39,
          'kokuminCandidateCount': 1,
          'kokuminCandidateNames': <String>['えんどう彩生'],
          'kokuminCandidateStatuses': <String>[],
          'kokuminCandidateXHandles': <String>['Saiki_Endo'],
          'isPast': true,
        },
      ],
    });

    final schedule = snapshot.upcomingSchedules.single;
    expect(schedule.kokuminCandidateNames, <String>['えんどう 彩生']);
    expect(schedule.kokuminCandidateStatuses, <String>['当選']);
    expect(snapshot.resolvedPastElectionResults, hasLength(1));
    expect(snapshot.resolvedPastElectionResults.single.winCount, 1);
  });

  test('keeps automatically parsed past election votes on schedules', () {
    final snapshot = LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': '2026-04-27T08:10:00.000Z',
      'officialCurrentLocalMembers': 362,
      'actualNetIncreaseRequired': 338,
      'upcomingSchedules': <Map<String, dynamic>>[
        <String, dynamic>{
          'electionName': '中野市議会議員選挙',
          'prefecture': '長野県',
          'municipality': '中野市',
          'electionCategory': 'assembly',
          'voteDate': '2026-04-26',
          'announcementDate': '2026-04-19',
          'detailUrl': 'https://go2senkyo.com/local/senkyo/26072',
          'officialCandidateSourceUrl': 'https://new-kokumin.jp/election',
          'seatCount': 20,
          'totalCandidateCount': 22,
          'kokuminCandidateCount': 1,
          'kokuminCandidateNames': <String>['あべ 一真'],
          'kokuminCandidateStatuses': <String>['当選'],
          'kokuminCandidateVotes': <int>[843],
          'kokuminCandidateXHandles': <String>['N3yKOgfAqH2619'],
          'isPast': true,
        },
      ],
    });

    final schedule = snapshot.upcomingSchedules.single;
    expect(schedule.kokuminCandidateVotes, <int>[843]);
    expect(snapshot.resolvedPastElectionResults, hasLength(1));
    final candidate =
        snapshot.resolvedPastElectionResults.single.dppCandidates.single;
    expect(candidate.name, 'あべ 一真');
    expect(candidate.status, '当選');
    expect(candidate.votes, 843);
  });

  test('treats runner-up status as a resolved past election loss', () {
    final snapshot = LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': '2026-04-27T10:30:00.000Z',
      'officialCurrentLocalMembers': 362,
      'actualNetIncreaseRequired': 338,
      'upcomingSchedules': <Map<String, dynamic>>[
        <String, dynamic>{
          'electionName': '松山市議会議員選挙',
          'prefecture': '愛媛県',
          'municipality': '松山市',
          'electionCategory': 'assembly',
          'voteDate': '2026-04-26',
          'announcementDate': '2026-04-19',
          'detailUrl': 'https://go2senkyo.com/local/senkyo/23307',
          'officialCandidateSourceUrl': 'https://new-kokumin.jp/election',
          'seatCount': 41,
          'totalCandidateCount': 55,
          'kokuminCandidateCount': 2,
          'kokuminCandidateNames': <String>['十川 ゆういち', '伊藤 しゅん'],
          'kokuminCandidateStatuses': <String>['当選', '次点'],
          'kokuminCandidateVotes': <int>[2161, 2122],
          'kokuminCandidateXHandles': <String>['sogawa123', 'itoh_syun0204'],
          'isPast': true,
        },
      ],
    });

    final result = snapshot.resolvedPastElectionResults.single;
    expect(result.winCount, 1);
    expect(result.lossCount, 1);
    expect(result.dppCandidates.last.status, '次点');
    expect(result.dppCandidates.last.votes, 2122);
  });
}
