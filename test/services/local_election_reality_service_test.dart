import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_reality.dart';
import 'package:my_web_app/services/local_election_reality_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('caches and reloads local election reality snapshot', () async {
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
      'aiSummary': '公式サイト集計では352人です。',
      'aiAlerts': ['700まで残り348人'],
      'aiStrategicNotes': ['東京・愛知・福岡が厚い'],
      'sources': [
        {
          'label': '議員ページ',
          'url': 'https://new-kokumin.jp/member',
          'category': 'official_members',
        },
      ],
      'prefectures': [
        {
          'prefecture': '東京都',
          'sourceUrl': 'https://new-kokumin.jp/member_tag/tokyo',
          'currentMembers': 45,
          'prefecturalAssemblyMembers': 4,
          'municipalAssemblyMembers': 41,
        },
      ],
    });

    await service.cacheSnapshot(snapshot, prefs: prefs);
    final loaded = await service.loadCachedSnapshot(prefs: prefs);

    expect(loaded, isNotNull);
    expect(loaded!.officialCurrentLocalMembers, 352);
    expect(loaded.deltaFromBaseline, 12);
    expect(loaded.topPrefectures().first.prefecture, '東京都');
    expect(loaded.sources.first.category, 'official_members');
  });
}
