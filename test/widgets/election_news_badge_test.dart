// ElectionNewsBadge の一括取得経路テスト。
//
// election_victory_page.dart は package:web を推移 import するため VM テスト
// から読み込めない。ここではページ側と同じ配線 (一括 fetch → normalize key で
// 県別配布) を最小ハーネスで再現し、Supabase クエリが 1 回だけ発行されることを
// 検証する。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/prefecture_election_news_service.dart';
import 'package:my_web_app/widgets/election_news_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSupabaseClient extends Fake implements SupabaseClient {
  FakeSupabaseClient(List<Map<String, dynamic>> rows)
      : _queryBuilder = FakeSupabaseQueryBuilder(rows);

  final FakeSupabaseQueryBuilder _queryBuilder;
  int fromCallCount = 0;
  String? lastTable;

  @override
  SupabaseQueryBuilder from(String table) {
    fromCallCount++;
    lastTable = table;
    return _queryBuilder;
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  FakeSupabaseQueryBuilder(this._rows);

  final List<Map<String, dynamic>> _rows;

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String? columns = '*',
  ]) {
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(_rows);
  }
}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  FakePostgrestFilterBuilder(this._value);

  final T _value;

  // testWidgets の FakeAsync 内で await されるため、時間経過を要する
  // Future.delayed ではなく即時完了の Future で返す。
  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future<T>.value(_value).then(onValue, onError: onError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #eq ||
        invocation.memberName == #order ||
        invocation.memberName == #limit ||
        invocation.memberName == #timeout) {
      return this;
    }
    return super.noSuchMethod(invocation);
  }
}

List<Map<String, dynamic>> sampleRows() => <Map<String, dynamic>>[
      <String, dynamic>{
        'prefecture': '宮崎',
        'news_title': '宮崎県連が地方選で計25人擁立目標',
        'news_summary': '20人決定済+公募5人追加方針',
        'news_source_url': 'https://www.yomiuri.co.jp/',
        'news_source_label': '読売新聞',
        'announced_at': '2026-04-29',
        'total_candidate_target': 25,
        'confirmed_candidate_count': 20,
        'public_recruitment_count': 5,
        'representative_name': '長友慎治',
      },
      <String, dynamic>{
        'prefecture': '北海道',
        'news_title': '道連、統一地方選で20〜30人目標',
        'news_summary': '札幌中心に公募で新顔擁立',
        'news_source_url': 'https://www.asahi.com/',
        'news_source_label': '朝日新聞',
        'announced_at': '2026-04-12',
        'representative_name': '臼木秀剛',
      },
      <String, dynamic>{
        'prefecture': '大阪',
        'news_title': '大阪府連 統一選挙で30名超擁立目標',
        'news_summary': '玉木代表が定期大会で発信',
        'news_source_url': 'https://x.com/tamakiyuichiro',
        'news_source_label': 'X (@tamakiyuichiro)',
        'announced_at': '2026-04-25',
      },
    ];

/// ページ側 (_buildPrefectureCard) と同じ配布ロジックの最小再現。
Widget buildDistributionHarness(
  Map<String, List<Map<String, dynamic>>> newsByPrefecture,
  List<String> prefectures,
) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            for (final prefecture in prefectures)
              ElectionNewsBadge(
                newsItems: newsByPrefecture[
                        PrefectureElectionNewsService.normalizePrefectureKey(
                      prefecture,
                    )] ??
                    const <Map<String, dynamic>>[],
              ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('一括取得 1 クエリで全県連カードの news badge が描画される', (tester) async {
    final fakeClient = FakeSupabaseClient(sampleRows());
    final service = PrefectureElectionNewsService(client: fakeClient);

    final newsByPrefecture = await service.fetchActiveNewsByPrefecture();

    // ページ表示形式 (長形式) の県名で配布する。佐賀県は news 無し。
    await tester.pumpWidget(
      buildDistributionHarness(
        newsByPrefecture,
        const ['宮崎県', '北海道', '大阪府', '佐賀県'],
      ),
    );

    // 県数分ではなく 1 クエリのみ。
    expect(fakeClient.fromCallCount, 1);
    expect(fakeClient.lastTable, 'prefecture_election_news');

    // 各県のカードに該当 news が配布される (大阪府 → DB短形式 '大阪' も一致)。
    expect(find.text('宮崎県連が地方選で計25人擁立目標'), findsOneWidget);
    expect(find.text('道連、統一地方選で20〜30人目標'), findsOneWidget);
    expect(find.text('大阪府連 統一選挙で30名超擁立目標'), findsOneWidget);
    expect(find.text('計 25 人'), findsOneWidget);
    expect(find.text('確定 20 人'), findsOneWidget);
    expect(find.text('公募 5 人'), findsOneWidget);
    expect(find.text('代表: 長友慎治'), findsOneWidget);
  });

  testWidgets('news が無い県のバッジは何も描画しない', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ElectionNewsBadge(newsItems: <Map<String, dynamic>>[]),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(ElectionNewsBadge),
        matching: find.byType(SizedBox),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ElectionNewsBadge),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
  });
}
