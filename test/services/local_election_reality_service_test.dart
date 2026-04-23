import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_reality.dart';
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
}
