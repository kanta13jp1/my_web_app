// ignore_for_file: require_trailing_commas

import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/dpj_official_endorsements.dart';
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
      'sources': <Map<String, dynamic>>[
        <String, dynamic>{
          'label': 'Official members',
          'url': 'https://new-kokumin.jp/member',
          'category': 'official',
        },
      ],
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

  LocalElectionRealitySnapshot buildSnapshotWithLiveIntelligence() {
    final json = buildSnapshot().toJson();
    json['electionIntelligence'] = <String, dynamic>{
      'schemaVersion': 1,
      'selectedMode': 'local',
      'modes': <Map<String, dynamic>>[],
      'goals': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'local_members_700',
          'mode': 'local',
          'title': '地方議員700人',
          'metric': 'local_member_count',
          'currentValue': 333,
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
        'sourceAsOf': '2026-08-06',
        'sourceDocumentSha256': List<String>.filled(64, 'b').join(),
        'totalCount': 220,
        'incumbentCount': 103,
        'newcomerCount': 108,
        'formerCount': 9,
        'recommendationCount': 9,
        'prefectureCount': 33,
        'prefectures': <Map<String, dynamic>>[],
      },
    };
    return LocalElectionRealitySnapshot.fromJson(json);
  }

  LocalElectionPlanDashboard buildPlan() {
    return LocalElectionPlanDashboard(
      currentLocalMembers: 333,
      targetLocalMembers: 700,
      previousUnifiedElectionWins: 183,
      previousUnifiedElectionFirstHalfWins: 62,
      previousUnifiedElectionSecondHalfWins: 121,
      updatedAt: DateTime(2026, 4, 22, 10, 30),
      prefectures: const <LocalElectionPrefecturePlan>[
        LocalElectionPrefecturePlan(
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
          announcedCandidateCount: 6,
          confirmedCandidateCount: 4,
          prefectureChairName: '川合孝典',
          prefectureSecretaryGeneralName: '石黒たつお',
          prefectureOfficerSourceUrl:
              'https://www.new-kokumin.tokyo/2025/10/yakuin2025/',
          cdpLocalMembers: 83,
          ldpLocalMembers: 362,
        ),
        LocalElectionPrefecturePlan(
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
          announcedCandidateCount: 3,
          confirmedCandidateCount: 2,
          cdpLocalMembers: 20,
          ldpLocalMembers: 112,
          endorsementConfirmed: true,
        ),
      ],
    );
  }

  test('buildDraft creates full election public memo payload', () {
    final snapshot = buildSnapshot();
    final draft = service.buildDraft(
      snapshot: snapshot,
      members: snapshot.members,
    );

    expect(draft.noteId, greaterThan(0));
    expect(draft.title, contains('2026/03/28'));
    expect(draft.content, contains('国民民主党 地方議員集計'));
    expect(draft.content, contains('公式地方議員数: 333人'));
    expect(draft.content, contains('700まで残り: 367人'));
    expect(
      draft.content,
      contains('次回統一地方選(2027/04/11目安)まであと379日'),
    );
    expect(draft.content, contains('AI要約'));
    expect(draft.content, contains('アラート'));
    expect(draft.content, contains('全都道府県内訳'));
    expect(draft.content, contains('現職地方議員名簿'));
    expect(draft.content, contains('公式ソース'));
    expect(draft.content, contains('🔴 鳥取県'));
    expect(draft.content, contains('🟡 島根県'));
    expect(draft.metadata['type'], LocalElectionShareService.metadataType);
    expect(draft.metadata['officialCurrentLocalMembers'], 333);
    expect(draft.metadata['daysUntilNextUnifiedLocalElection'], 379);
    expect(draft.metadata['nextUnifiedLocalElectionTargetDate'], '2027/04/11');
    expect(draft.metadata['missingPrefectureCount'], greaterThanOrEqualTo(1));
  });

  test('generated memo source key keeps the synthetic draft identity', () {
    expect(
      LocalElectionShareService.generatedMemoSourceKey(90000007002027),
      'local-election:90000007002027',
    );
  });

  LocalElectionRealitySnapshot buildSnapshotWithCdpFallbackAlert() {
    return LocalElectionRealitySnapshot.fromJson(<String, dynamic>{
      'fetchedAt': '2026-03-28T09:00:00.000Z',
      'officialCurrentLocalMembers': 333,
      'actualNetIncreaseRequired': 367,
      'aiSummary': '地方議員数は333人です。',
      'aiAlerts': <String>[
        '議員不在県の穴埋めが必要です。',
        '立憲民主党との地方議員数の比較は今回取得していません。',
      ],
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
      ],
    });
  }

  test('buildDraft syncs CDP benchmark from plan batch values', () {
    final snapshot = buildSnapshotWithCdpFallbackAlert();
    final plan = buildPlan();
    final draft = service.buildDraft(
      snapshot: snapshot,
      members: snapshot.members,
      plan: plan,
    );

    // 注視ポイント: 立憲フォールバック行がバッチ地力差行へ差し替わる。
    expect(
      draft.content,
      contains('立憲民主党との地力差（上位）：東京都+40 / 香川県-3。'),
    );
    expect(draft.content, isNot(contains('今回取得していません')));
    // 非立憲の注視ポイントは残る。
    expect(draft.content, contains('議員不在県の穴埋めが必要です。'));
    // 全都道府県内訳: 各県の立憲参考が plan のバッチ値へ。
    expect(draft.content, contains('立憲参考 83人'));
    expect(draft.content, contains('立憲参考 20人'));
    // metadata: 解決済み立憲値の合計 (83 + 20)。
    expect(draft.metadata['cdpLocalMembers'], 103);
  });

  test('buildDraft keeps fallback alert and zero CDP when plan is absent', () {
    final snapshot = buildSnapshotWithCdpFallbackAlert();
    final draft = service.buildDraft(
      snapshot: snapshot,
      members: snapshot.members,
    );

    // plan 無し = 後方互換: 差し替えなし・立憲参考は snapshot 由来の 0。
    expect(draft.content, contains('今回取得していません'));
    expect(draft.content, isNot(contains('立憲民主党との地力差（上位）')));
    expect(draft.content, contains('立憲参考 0人'));
    expect(draft.metadata['cdpLocalMembers'], 0);
  });

  test('buildXShareText includes public note link and alert counts', () {
    final snapshot = buildSnapshot();
    final shareText = service.buildXShareText(
      snapshot: snapshot,
      publicUrl: 'https://example.com/public-memo?id=10',
    );

    expect(shareText, contains('国民民主党の地方議員数 2026/03/28'));
    expect(shareText, contains('次回統一地方選(2027/04/11目安)まであと379日'));
    expect(shareText, contains('🔴議員不在'));
    expect(shareText, contains('🟡要強化'));
    expect(shareText, contains('https://example.com/public-memo?id=10'));
  });

  test('buildXPostLongText carries the full post-A tally within the cap', () {
    // R24: API 投稿(growth-hub x.post)経路の本文。集計ノート全文=実測 3.2K
    // のポストA構造がそのまま入り、末尾に公開ノート URL が付く。
    final snapshot = buildSnapshot();
    final text = service.buildXPostLongText(
      snapshot: snapshot,
      members: snapshot.members,
      publicUrl: 'https://example.com/public-memo?id=10',
    );

    expect(text, contains('国民民主党 地方議員集計 2026/03/28'));
    expect(text, contains('取得日時:'));
    expect(text, contains('公式地方議員数: 333人'));
    expect(text, contains('700まで残り: 367人'));
    expect(text, contains('現職地方議員名簿'));
    expect(text, contains('全都道府県の内訳と現職名簿の公開ノート:'));
    expect(text, contains('https://example.com/public-memo?id=10'));
    // 上限は X 実測の加重文字数(CJK=2)で守る(code unit 数ではない)。
    expect(
      LocalElectionShareService.xWeightedLength(text),
      lessThanOrEqualTo(24000),
    );
  });

  test('xWeightedLength doubles CJK per twitter-text weighting', () {
    expect(LocalElectionShareService.xWeightedLength('abc'), 3);
    expect(LocalElectionShareService.xWeightedLength('あいう'), 6);
    expect(LocalElectionShareService.xWeightedLength('a議員1人'), 8);
  });

  test(
      'buildXPostLongText truncates at a roster section boundary when over cap',
      () {
    final snapshot = buildSnapshot();
    final full = service.buildXPostLongText(
      snapshot: snapshot,
      members: snapshot.members,
      publicUrl: '',
    );
    final fullWeighted = LocalElectionShareService.xWeightedLength(full);
    final capped = service.buildXPostLongText(
      snapshot: snapshot,
      members: snapshot.members,
      publicUrl: 'https://example.com/public-memo?id=10',
      maxWeightedChars: fullWeighted - 50,
    );

    expect(
      LocalElectionShareService.xWeightedLength(capped),
      lessThanOrEqualTo(fullWeighted - 50),
    );
    expect(capped, contains('(文字数上限のため名簿の続きは公開ノートへ)'));
    expect(capped, contains('https://example.com/public-memo?id=10'));
    // 冒頭のデータレポート骨格は必ず残る。
    expect(capped, contains('公式地方議員数: 333人'));
  });

  test('buildXPostLongText omits the note-link cue when no public URL exists',
      () {
    final snapshot = buildSnapshot();
    final full = service.buildXPostLongText(
      snapshot: snapshot,
      members: snapshot.members,
      publicUrl: '',
    );
    final capped = service.buildXPostLongText(
      snapshot: snapshot,
      members: snapshot.members,
      publicUrl: '',
      maxWeightedChars: LocalElectionShareService.xWeightedLength(full) - 50,
    );

    // URL の無い投稿に「続きは公開ノートへ」というリンク無し誘導を残さない。
    expect(capped, isNot(contains('公開ノートへ')));
    expect(capped, contains('(文字数上限のため名簿は途中まで)'));
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

  test('公開ノートに自民参考値と公認予定候補が載る (共有面の欠落防止)', () {
    final plan = buildPlan();
    final draft = service.buildPlanDashboardDraft(
      plan: plan,
      snapshot: buildSnapshot(),
      publicDashboardUrl: 'https://example.com/public/local-election-700',
    );

    // 全国サマリー: 立憲だけでなく自民と公認予定候補も出す。
    expect(draft.content, contains('自民地方議員参考合計: 474人'));
    expect(
      draft.content,
      contains('公認予定候補: $dpjOfficialEndorsementTotal件'),
    );
    expect(
      draft.content,
      contains('$dpjOfficialEndorsementPrefectureCount/47都道府県に掲載'),
    );
    // 県別行: 自民参考と地力差 (ラベルは自民であって立憲ではない)。
    expect(draft.content, contains('自民参考362人'));
    expect(draft.content, contains('自民+319'));
    // metadata にも機械可読で載る。
    expect(draft.metadata['totalLdpLocalMembers'], 474);
    expect(
      draft.metadata['officialEndorsementTotal'],
      dpjOfficialEndorsementTotal,
    );
    expect(
      draft.metadata['officialEndorsementAsOf'],
      dpjOfficialEndorsementSourceAsOf,
    );
    expect(
      draft.metadata['firstEndorsementTotal'],
      dpjOfficialEndorsementTotal,
    );
    final prefectures = draft.metadata['prefectures'] as List<dynamic>;
    final tokyo =
        Map<String, dynamic>.from(prefectures.first as Map<dynamic, dynamic>);
    expect(tokyo['ldpLocalMembers'], 362);
    expect(tokyo['ldpMemberGap'], 319);
  });

  test('共有ノートは静的値より最新の選挙インテリジェンスを優先する', () {
    final snapshot = buildSnapshotWithLiveIntelligence();
    final draft = service.buildPlanDashboardDraft(
      plan: buildPlan(),
      snapshot: snapshot,
      publicDashboardUrl: 'https://example.com/public/local-election-700',
    );
    final snapshotDraft = service.buildDraft(
      snapshot: snapshot,
      members: snapshot.members,
      plan: buildPlan(),
    );

    expect(draft.content, contains('公認予定候補: 220件'));
    expect(draft.content, contains('33/47都道府県に掲載'));
    expect(draft.metadata['officialEndorsementTotal'], 220);
    expect(draft.metadata['officialEndorsementAsOf'], '2026-08-06');
    expect(snapshotDraft.metadata['electionMode'], 'local');
    expect(snapshotDraft.metadata['partyGoals'], hasLength(1));
    expect(
      (snapshotDraft.metadata['officialEndorsements']
          as Map<String, dynamic>)['totalCount'],
      220,
    );
  });

  test('地力差ラベルは比較相手の党名を取り違えない', () {
    final plan = buildPlan();
    final draft = service.buildPlanDashboardDraft(
      plan: plan,
      snapshot: buildSnapshot(),
      publicDashboardUrl: 'https://example.com/public/local-election-700',
    );
    // 自民の差分行に立憲ラベルが混入しない (汎用ヘルパの党名直書き対策)。
    expect(draft.content, isNot(contains('自民参考362人(立憲')));
  });

  test('buildPlanDashboardDraft creates a public note for all prefecture KPIs',
      () {
    final plan = buildPlan();
    final snapshot = buildSnapshot();
    final draft = service.buildPlanDashboardDraft(
      plan: plan,
      snapshot: snapshot,
      publicDashboardUrl: 'https://example.com/public/local-election-700',
    );

    expect(draft.noteId, greaterThan(0));
    expect(draft.title, contains('統一地方選700 県連KPI一覧'));
    expect(draft.content, contains('公開ダッシュボード:'));
    expect(draft.content, contains('全県連KPI'));
    expect(draft.content, contains('東京都(関東)'));
    expect(draft.content, contains('KGI55人'));
    expect(draft.content, contains('CSF/KPI'));
    expect(draft.content, contains('確認済み候補者6人'));
    expect(draft.content, contains('県連代表川合孝典'));
    expect(draft.content, contains('幹事長石黒たつお'));
    expect(draft.content, contains('純増12人'));
    expect(draft.content, contains('立憲参考83人'));
    expect(draft.content, contains('月次KPI'));
    expect(
      draft.metadata['type'],
      LocalElectionShareService.planDashboardMetadataType,
    );
    expect(draft.metadata['prefectures'], isA<List<dynamic>>());
    final prefectures = draft.metadata['prefectures'] as List<dynamic>;
    final tokyoMetadata =
        Map<String, dynamic>.from(prefectures.first as Map<dynamic, dynamic>);
    expect(tokyoMetadata['kgiTargetLocalMembers'], 55);
    expect(tokyoMetadata['csfKpis'], isA<List<dynamic>>());
    expect(tokyoMetadata['prefectureChairName'], '川合孝典');
  });

  test('buildPlanDashboardXShareIntentUri shares one public note link', () {
    final plan = buildPlan();
    final uri = service.buildPlanDashboardXShareIntentUri(
      plan: plan,
      publicUrl: 'https://example.com/public-memo?id=700',
    );

    expect(
      '${uri.scheme}://${uri.host}${uri.path}',
      'https://x.com/intent/tweet',
    );
    expect(
        uri.queryParameters['url'], 'https://example.com/public-memo?id=700');
    expect(uri.queryParameters['text'], contains('全2県連'));
    expect(uri.queryParameters['text'], contains('KGI'));
    expect(uri.queryParameters['text'], contains('CSF'));
    expect(uri.queryParameters['text'], contains('現職 333人'));
    expect(
      uri.queryParameters['text'],
      contains('次回統一地方選(2027/04/11目安)まであと354日'),
    );
    expect(
      uri.queryParameters['text'],
      isNot(contains('https://example.com/public-memo?id=700')),
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
    expect(
      tweets.last,
      contains('次回統一地方選(2027/04/11目安)まであと368日'),
    );
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

  test('unified election 2027 provisional dates stay statute-consistent', () {
    final firstVote =
        LocalElectionShareService.nextUnifiedLocalElectionFirstHalfTargetDate;
    final firstAnnouncement = LocalElectionShareService
        .nextUnifiedLocalElectionFirstHalfAnnouncementDate;
    final secondVote =
        LocalElectionShareService.nextUnifiedLocalElectionSecondHalfTargetDate;
    final secondAnnouncement = LocalElectionShareService
        .nextUnifiedLocalElectionSecondHalfAnnouncementDate;

    // 投票日は日曜、第二次は第一次の2週間後。
    expect(firstVote.weekday, DateTime.sunday);
    expect(secondVote.weekday, DateTime.sunday);
    expect(secondVote.difference(firstVote).inDays, 14);
    // 告示日数ルール: 前半=知事選17日前 / 後半=市区議・市区長7日前 (2023実績と同じ)。
    expect(firstVote.difference(firstAnnouncement).inDays, 17);
    expect(secondVote.difference(secondAnnouncement).inDays, 7);
  });
}
