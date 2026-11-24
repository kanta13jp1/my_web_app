import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_web_app/models/local_election_reality.dart';
import 'package:my_web_app/models/public_memo.dart';
import 'package:my_web_app/services/local_election_roster_diff.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ja_JP');
  });

  PublicMemo buildLegacyMemo({
    required int id,
    required int noteId,
    required String snapshotDate,
    required String content,
    Map<String, dynamic> extraMetadata = const <String, dynamic>{},
    DateTime? publishedAt,
    DateTime? updatedAt,
  }) {
    final ts = publishedAt ?? DateTime.utc(2026, 11, 16, 20, 11, 54);
    return PublicMemo(
      id: id,
      noteId: noteId,
      userId: 'user-a',
      title: '国民民主党 地方議員集計 $snapshotDate',
      content: content,
      category: '選挙ダッシュボード',
      metadata: <String, dynamic>{
        'type': 'local_election_snapshot',
        'source_key':
            'local-election:900000${snapshotDate.replaceAll('/', '')}',
        'snapshotDate': snapshotDate,
        ...extraMetadata,
      },
      likeCount: 0,
      viewCount: 0,
      isPublic: true,
      publishedAt: ts,
      createdAt: ts,
      updatedAt: updatedAt ?? ts,
    );
  }

  LocalElectionRealitySnapshot buildCurrentSnapshot({
    required DateTime fetchedAt,
    required int officialCount,
    required List<LocalElectionLegislatorProfile> members,
    List<String> zeroPrefectures = const <String>[],
  }) {
    final memberCountByPref = <String, int>{};
    for (final m in members) {
      memberCountByPref[m.prefecture] =
          (memberCountByPref[m.prefecture] ?? 0) + 1;
    }
    return LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': fetchedAt.toIso8601String(),
      'baselineCurrentLocalMembers': 340,
      'officialCurrentLocalMembers': officialCount,
      'targetLocalMembers': 700,
      'baselineNetIncreaseRequired': 360,
      'actualNetIncreaseRequired': 700 - officialCount,
      'official2023FirstHalfWins': 62,
      'official2023SecondHalfWins': 121,
      'official2023TotalWins': 183,
      'prefectures': localElectionAllPrefectures
          .map(
            (pref) => <String, dynamic>{
              'prefecture': pref,
              'sourceUrl': 'https://example.com/pref',
              'currentMembers': zeroPrefectures.contains(pref)
                  ? 0
                  : (memberCountByPref[pref] ?? 1),
              'prefecturalAssemblyMembers': 1,
              'municipalAssemblyMembers': 0,
            },
          )
          .toList(),
      'members': members.map((m) => m.toJson()).toList(),
    });
  }

  test(
    'matches 2026/11/17 legacy text memo against 2026/11/24 snapshot accurately',
    () {
      const legacyContent = '''
国民民主党 地方議員集計 2026/11/17

現職地方議員名簿

◽️ 国民民主党埼玉県現職地方議員
狭山市議会議員 / 狭山市 / 三浦 和也 / 当選4回

◽️ 国民民主党愛知県現職地方議員
名古屋市会議員 / 名古屋市 / 日比 美咲 / 当選3回
幸田町議会議員 / 幸田町 / 田境 毅 / 当選2回

◽️ 国民民主党東京都現職地方議員
杉並区議会議員 / 杉並区 / あんざい あきら / 当選5回

公式ソース
- Official: https://new-kokumin.jp/member
''';
      final prevMemo = buildLegacyMemo(
        id: 66,
        noteId: 567,
        snapshotDate: '2026/11/17',
        content: legacyContent,
        extraMetadata: const <String, dynamic>{
          'activePrefectureCount': 46,
          'missingPrefectures': <String>['鳥取県'],
          'officialCurrentLocalMembers': 420,
          'rosterCount': 4,
        },
      );

      final currentMembers = <LocalElectionLegislatorProfile>[
        const LocalElectionLegislatorProfile(
          prefecture: '埼玉県',
          sourceUrl: 'https://new-kokumin.jp/member_tag/saitama',
          detailUrl: 'https://new-kokumin.jp/member/shirane-daisuke',
          name: '白根 大輔',
          kana: 'しらね だいすけ',
          constituency: '川口市',
          municipality: '川口市',
          assemblyLabel: '埼玉県議会議員',
          assemblyCategory: 'prefectural',
          electionCountLabel: '当選2回',
        ),
        const LocalElectionLegislatorProfile(
          prefecture: '埼玉県',
          sourceUrl: 'https://new-kokumin.jp/member_tag/saitama',
          detailUrl: 'https://new-kokumin.jp/member/miura-kazuya',
          name: '三浦 和也',
          kana: 'みうら かずや',
          constituency: '狭山市',
          municipality: '狭山市',
          assemblyLabel: '狭山市議会議員',
          assemblyCategory: 'municipal',
          electionCountLabel: '当選4回',
        ),
        const LocalElectionLegislatorProfile(
          prefecture: '愛知県',
          sourceUrl: 'https://new-kokumin.jp/member_tag/aichi',
          detailUrl: 'https://new-kokumin.jp/member/hibi-misaki',
          name: '日比 美咲',
          kana: 'ひび みさき',
          constituency: '名古屋市名東区',
          municipality: '名古屋市名東区',
          assemblyLabel: '名古屋市会議員',
          assemblyCategory: 'municipal',
          electionCountLabel: '当選3回',
        ),
        const LocalElectionLegislatorProfile(
          prefecture: '東京都',
          sourceUrl: 'https://new-kokumin.jp/member_tag/tokyo',
          detailUrl: 'https://new-kokumin.jp/member/anzai-akira',
          name: '安斉 あきら',
          kana: 'あんざい あきら',
          constituency: '杉並区',
          municipality: '杉並区',
          assemblyLabel: '杉並区議会議員',
          assemblyCategory: 'municipal',
          electionCountLabel: '当選5回',
        ),
        const LocalElectionLegislatorProfile(
          prefecture: '鳥取県',
          sourceUrl: 'https://new-kokumin.jp/member_tag/tottori',
          detailUrl: 'https://new-kokumin.jp/member/murao-masahiko',
          name: '村尾 昌彦',
          kana: 'むらお まさひこ',
          constituency: '',
          municipality: '鳥取県',
          assemblyLabel: '地方自治体議員',
          assemblyCategory: 'municipal',
          electionCountLabel: '当選1回',
        ),
      ];

      final snapshot = buildCurrentSnapshot(
        fetchedAt: DateTime(2026, 11, 24, 5, 27),
        officialCount: 421,
        members: currentMembers,
      );
      final diff = computeLocalElectionRosterDiff(
        previousMemo: prevMemo,
        currentSnapshot: snapshot,
        currentMembers: currentMembers,
        currentPrefectures: snapshot.prefectures,
      );

      expect(diff, isNotNull);
      expect(diff!.netDelta, 1);
      expect(
          diff.added.map((e) => e.name).toList(), <String>['白根 大輔', '村尾 昌彦']);
      expect(diff.removed.map((e) => e.name).toList(), <String>['田境 毅']);
      expect(diff.nameChanges, hasLength(1));
      expect(diff.nameChanges.first.before.name, 'あんざい あきら');
      expect(diff.nameChanges.first.after.name, '安斉 あきら');
      expect(diff.locationChanges, hasLength(1));
      expect(diff.locationChanges.first.before.effectiveLocation, '名古屋市');
      expect(
        diff.locationChanges.first.after.effectiveLocation,
        '名古屋市名東区',
      );
      expect(diff.attributeChanges, isEmpty);
      expect(diff.newlyCoveredPrefectures, <String>['鳥取県']);

      final section = formatLocalElectionRosterDiffSection(diff);
      expect(section, contains('最新の増加履歴（2026年11月24日）'));
      expect(section, contains('4 → 5：+1（追加2人・名簿掲載なし1人）'));
      expect(section, contains('【追加：2人】'));
      expect(section, contains('・白根 大輔（埼玉県・川口市・埼玉県議会議員・当選2回）'));
      expect(section, contains('・村尾 昌彦（鳥取県・地方自治体議員・当選1回）'));
      expect(section, contains('【名簿掲載なし：1人】'));
      expect(section, contains('・田境 毅（愛知県・幸田町・幸田町議会議員・当選2回）'));
      expect(section, contains('【氏名表記の変更：人数の増減なし】'));
      expect(section, contains('・あんざい あきら → 安斉 あきら（東京都・杉並区・杉並区議会議員・当選5回）'));
      expect(section, contains('【所在地表記の変更：人数の増減なし】'));
      expect(section, contains('名古屋市 → 名古屋市名東区'));
      expect(section, contains('※村尾 昌彦氏は自治体名が名簿に記載されていません。'));
      expect(section, contains('※氏名・所在地等の表記変更は人数の増減に含めていません。'));
      expect(section,
          contains('鳥取県に初めて地方議員が掲載され、議員在籍県数は46県から47県になり、議員不在県がなくなりました。'));
    },
  );

  test(
    'uses detailUrl for 1-to-1 matching and prevents false merges across different people',
    () {
      final prevMemo = buildLegacyMemo(
        id: 70,
        noteId: 700,
        snapshotDate: '2026/11/17',
        content: '',
        extraMetadata: <String, dynamic>{
          'rosterSnapshot': <Map<String, dynamic>>[
            // Same detailUrl, completely different name -> nameChanges
            const LocalElectionRosterEntry(
              prefecture: '東京都',
              detailUrl: 'https://new-kokumin.jp/member/same-url/',
              assemblyLabel: '東京都議会議員',
              constituency: '新宿区',
              name: '旧姓 太郎',
              electionCountLabel: '当選2回',
            ).toJson(),
            // Distinct non-empty detailUrls, identical seat tuple -> must NOT merge
            const LocalElectionRosterEntry(
              prefecture: '神奈川県',
              detailUrl: 'https://new-kokumin.jp/member/person-old',
              assemblyLabel: '横浜市会議員',
              constituency: '青葉区',
              name: '神奈川 一郎',
              electionCountLabel: '当選1回',
            ).toJson(),
            // Legacy entry without detailUrl, unrelated name -> must NOT merge
            const LocalElectionRosterEntry(
              prefecture: '大阪府',
              assemblyLabel: '大阪市会議員',
              constituency: '北区',
              name: '山田 太郎',
              electionCountLabel: '当選1回',
            ).toJson(),
          ],
        },
      );

      final currentMembers = <LocalElectionLegislatorProfile>[
        const LocalElectionLegislatorProfile(
          prefecture: '東京都',
          sourceUrl: 'https://example.com',
          detailUrl: 'https://new-kokumin.jp/member/same-url',
          name: '新姓 太郎',
          kana: 'しんせい たろう',
          constituency: '新宿区',
          municipality: '新宿区',
          assemblyLabel: '東京都議会議員',
          assemblyCategory: 'prefectural',
          electionCountLabel: '当選2回',
        ),
        const LocalElectionLegislatorProfile(
          prefecture: '神奈川県',
          sourceUrl: 'https://example.com',
          detailUrl: 'https://new-kokumin.jp/member/person-new',
          name: '神奈川 一郎',
          kana: 'かながわ いちろう',
          constituency: '青葉区',
          municipality: '青葉区',
          assemblyLabel: '横浜市会議員',
          assemblyCategory: 'municipal',
          electionCountLabel: '当選1回',
        ),
        const LocalElectionLegislatorProfile(
          prefecture: '大阪府',
          sourceUrl: 'https://example.com',
          detailUrl: 'https://new-kokumin.jp/member/sato-hanako',
          name: '佐藤 花子',
          kana: 'さとう はなこ',
          constituency: '北区',
          municipality: '北区',
          assemblyLabel: '大阪市会議員',
          assemblyCategory: 'municipal',
          electionCountLabel: '当選1回',
        ),
      ];

      final snapshot = buildCurrentSnapshot(
        fetchedAt: DateTime(2026, 11, 24, 9),
        officialCount: 3,
        members: currentMembers,
      );
      final diff = computeLocalElectionRosterDiff(
        previousMemo: prevMemo,
        currentSnapshot: snapshot,
        currentMembers: currentMembers,
        currentPrefectures: snapshot.prefectures,
      );

      expect(diff, isNotNull);
      expect(diff!.nameChanges.map((c) => c.after.name), <String>['新姓 太郎']);
      expect(
        diff.added.map((e) => e.name).toList(),
        <String>['神奈川 一郎', '佐藤 花子'],
      );
      expect(
        diff.removed.map((e) => e.name).toList(),
        <String>['神奈川 一郎', '山田 太郎'],
      );
    },
  );

  test(
    'handles zero changes, negative deltas, and fails closed on corrupt legacy memos',
    () {
      const members = <LocalElectionLegislatorProfile>[
        LocalElectionLegislatorProfile(
          prefecture: '東京都',
          sourceUrl: 'https://example.com',
          detailUrl: 'https://example.com/a',
          name: '東京 太郎',
          kana: 'とうきょう たろう',
          constituency: '港区',
          municipality: '港区',
          assemblyLabel: '港区議会議員',
          assemblyCategory: 'municipal',
          electionCountLabel: '当選1回',
        ),
      ];
      final unchangedPrev = buildLegacyMemo(
        id: 1,
        noteId: 10,
        snapshotDate: '2026/11/17',
        content: '',
        extraMetadata: <String, dynamic>{
          'rosterSnapshot': <Map<String, dynamic>>[
            LocalElectionRosterEntry.fromProfile(members.first).toJson(),
          ],
        },
      );
      final snapSame = buildCurrentSnapshot(
        fetchedAt: DateTime(2026, 11, 24, 9),
        officialCount: 1,
        members: members,
      );
      final noChangeDiff = computeLocalElectionRosterDiff(
        previousMemo: unchangedPrev,
        currentSnapshot: snapSame,
        currentMembers: members,
        currentPrefectures: snapSame.prefectures,
      );
      expect(noChangeDiff, isNotNull);
      expect(noChangeDiff!.hasAnyChange, isFalse);
      expect(
        formatLocalElectionRosterDiffSection(noChangeDiff),
        contains('1 → 1：±0（前回 2026/11/17 から名簿の変更なし）'),
      );

      final prevWithTwo = buildLegacyMemo(
        id: 2,
        noteId: 20,
        snapshotDate: '2026/11/17',
        content: '',
        extraMetadata: <String, dynamic>{
          'rosterSnapshot': <Map<String, dynamic>>[
            LocalElectionRosterEntry.fromProfile(members.first).toJson(),
            const LocalElectionRosterEntry(
              prefecture: '愛知県',
              assemblyLabel: '名古屋市会議員',
              constituency: '中区',
              name: '愛知 二郎',
              electionCountLabel: '当選2回',
            ).toJson(),
          ],
        },
      );
      final negDiff = computeLocalElectionRosterDiff(
        previousMemo: prevWithTwo,
        currentSnapshot: snapSame,
        currentMembers: members,
        currentPrefectures: snapSame.prefectures,
      );
      expect(negDiff, isNotNull);
      expect(negDiff!.netDelta, -1);
      final negText = formatLocalElectionRosterDiffSection(negDiff);
      expect(negText, contains('最新の増減履歴（2026年11月24日）'));
      expect(negText, contains('2 → 1：-1（追加0人・名簿掲載なし1人）'));
      expect(negText, contains('【名簿掲載なし：1人】'));

      final corruptPrev = buildLegacyMemo(
        id: 3,
        noteId: 30,
        snapshotDate: '2026/11/17',
        content: '現職地方議員名簿\n\n◽️ 国民民主党東京都現職地方議員\n区議 / 新宿区 / テスト / 1期',
        extraMetadata: const <String, dynamic>{'rosterCount': 400},
      );
      final corruptDiff = computeLocalElectionRosterDiff(
        previousMemo: corruptPrev,
        currentSnapshot: snapSame,
        currentMembers: members,
        currentPrefectures: snapSame.prefectures,
      );
      expect(corruptDiff, isNull);
    },
  );

  test(
    'selectPreviousSnapshotMemo picks strictly earlier snapshotDate over newer updatedAt',
    () {
      final oct11EditedLater = buildLegacyMemo(
        id: 65,
        noteId: 564,
        snapshotDate: '2026/10/11',
        content: '',
        publishedAt: DateTime.utc(2026, 10, 10),
        updatedAt: DateTime.utc(2026, 11, 20),
      );
      final nov17 = buildLegacyMemo(
        id: 66,
        noteId: 567,
        snapshotDate: '2026/11/17',
        content: '',
        publishedAt: DateTime.utc(2026, 11, 16),
        updatedAt: DateTime.utc(2026, 11, 16),
      );
      final nov24SameDay = buildLegacyMemo(
        id: 67,
        noteId: 2730,
        snapshotDate: '2026/11/24',
        content: '',
        publishedAt: DateTime.utc(2026, 11, 23),
        updatedAt: DateTime.utc(2026, 11, 24),
      );

      final selected = selectPreviousSnapshotMemo(
        candidates: <PublicMemo>[nov24SameDay, oct11EditedLater, nov17],
        metadataType: 'local_election_snapshot',
        excludeSourceKey: 'local-election:90000020261124',
        beforeSnapshotDate: '2026/11/24',
      );
      expect(selected?.id, 66);
    },
  );
}
