import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_calendar_reflection.dart';
import 'package:my_web_app/services/asset_calendar_reflection_repository.dart';
import 'package:my_web_app/widgets/asset_calendar_reflection_panel.dart';

class EmptyRepository implements AssetCalendarReflectionStore {
  EmptyRepository([this.recorded = const []]);
  final List<AssetCalendarReflection> recorded;
  @override
  Future<void> import(List<AssetCalendarReflection> events) async {}
  @override
  Future<List<AssetCalendarReflection>> load(
    DateTime start,
    DateTime end,
  ) async =>
      recorded;
}

class DeferredRepository implements AssetCalendarReflectionStore {
  final pending = Completer<List<AssetCalendarReflection>>();
  @override
  Future<void> import(List<AssetCalendarReflection> events) async {}
  @override
  Future<List<AssetCalendarReflection>> load(DateTime start, DateTime end) =>
      pending.future;
}

Map<String, dynamic> flow(
  String description, {
  String type = 'expense',
  int id = 100,
}) =>
    {
      'id': id,
      'occurred_at': '2026-09-20T12:00:00',
      'action_type': type,
      'description': description,
      'amount': 1200,
    };

void main() {
  test('ambiguous meal is a candidate, not a projected or counted event', () {
    final input = flow('餃子の王将 ラーメンセット（食費）');
    expect(AssetCalendarReflection.fromFlows([input]), isEmpty);
    final candidates = AssetDiningReviewCandidate.fromFlows([input, input]);
    expect(candidates, hasLength(1));
    expect(candidates.single.flowId, '100');
    expect(
      AssetReflectionSummary(AssetCalendarReflection.fromFlows([input]))
          .days(AssetReflectionKind.dining),
      0,
    );
  });

  test(
      'explicit dining stays confirmed and unrelated or negated rows do not become candidates',
      () {
    expect(
      AssetDiningReviewCandidate.fromFlows([flow('外食 餃子の王将 ラーメンセット')]),
      isEmpty,
    );
    expect(
      AssetDiningReviewCandidate.fromFlows([flow('餃子の王将 ラーメンセット 返金')]),
      isEmpty,
    );
    expect(
      AssetDiningReviewCandidate.fromFlows(
        [flow('餃子の王将 ラーメンセット', type: 'transfer')],
      ),
      isEmpty,
    );
    expect(
      AssetDiningReviewCandidate.fromFlows([flow('コンビニ ラーメンセット')]),
      isEmpty,
    );
    expect(
      AssetDiningReviewCandidate.fromFlows([flow('スーパー 餃子の王将 冷凍ラーメンセット')]),
      isEmpty,
    );
    expect(
      AssetDiningReviewCandidate.fromFlows([flow('餃子の王将 ラーメンセット 持ち帰り')]),
      isEmpty,
    );
    expect(
      AssetDiningReviewCandidate.fromFlows([flow('餃子の王将 ラーメンセット 出前')]),
      isEmpty,
    );
    expect(
      AssetDiningReviewCandidate.fromFlows([flow('餃子の王将 ラーメンセットへ行かなかった')]),
      isEmpty,
    );
    expect(
      AssetDiningReviewCandidate.fromFlows([flow('吉野家 外食していない')]),
      isEmpty,
    );
    expect(AssetDiningReviewCandidate.fromFlows([flow('吉野家 株価')]), isEmpty);
    expect(
      AssetDiningReviewCandidate.fromFlows([flow('餃子の王子 ラーメンセット')]),
      isEmpty,
    );
    expect(AssetDiningReviewCandidate.fromFlows([flow('餃子の王将 食事券')]), isEmpty);
    expect(
      AssetDiningReviewCandidate.fromFlows([flow('マクドナルド 食事')]),
      hasLength(1),
    );
    expect(
      AssetDiningReviewCandidate.fromFlows([flow('吉野家 食事')]),
      hasLength(1),
    );
    expect(
      AssetDiningReviewCandidate.fromFlows([
        {...flow('吉野家'), 'id': '101'},
      ]),
      hasLength(1),
    );
    expect(
      AssetDiningReviewCandidate.fromFlows([
        {...flow('吉野家'), 'id': 'non-numeric'},
      ]),
      isEmpty,
    );
  });

  test(
      'owner mismatch, unknown owner, loading and failed reads hide candidates',
      () {
    final rows = [flow('餃子の王将 ラーメンセット')];
    List<AssetDiningReviewCandidate> evaluate(
      String? current,
      String? source, {
      bool reading = false,
      bool failed = false,
    }) =>
        AssetDiningReviewCandidate.fromOwnedFlows(
          currentOwner: current,
          flowsOwner: source,
          reading: reading,
          failed: failed,
          flows: rows,
        );
    expect(evaluate('a', 'a'), hasLength(1));
    expect(evaluate('a', 'b'), isEmpty);
    expect(evaluate(null, null), isEmpty);
    expect(evaluate('a', 'a', reading: true), isEmpty);
    expect(evaluate('a', 'a', failed: true), isEmpty);
  });

  testWidgets('candidate appears only on its day and does not affect counts',
      (tester) async {
    final candidates = AssetDiningReviewCandidate.fromFlows([
      flow('餃子の王将 ラーメンセット（食費）'),
    ]);
    Widget app(DateTime selected, AssetCalendarReflectionStore repository) =>
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssetCalendarReflectionPanel(
                repository: repository,
                start: DateTime(2026, 9),
                end: DateTime(2026, 10),
                selectedDate: selected,
                onLoaded: (_) {},
                diningReviewCandidates: candidates,
              ),
            ),
          ),
        );
    final repository = EmptyRepository();
    await tester.pumpWidget(app(DateTime(2026, 9, 20), repository));
    await tester.pumpAndSettle();
    expect(find.textContaining('外食かは要確認'), findsOneWidget);
    expect(find.textContaining('出典: 記録済み支出'), findsOneWidget);
    expect(
      find.textContaining('ラーメンセット'),
      findsNothing,
      reason: 'the hint shows only the matched store name',
    );
    expect(find.text('外食 0日'), findsOneWidget);
    expect(find.text('外飲み 0日'), findsOneWidget);
    expect(find.text('酒購入 0日'), findsOneWidget);
    expect(find.textContaining('表示期間の確認済み金額 0円'), findsOneWidget);
    await tester.pumpWidget(app(DateTime(2026, 9, 21), repository));
    await tester.pumpAndSettle();
    expect(find.textContaining('外食かは要確認'), findsNothing);
    expect(find.textContaining('当月を含む24か月分'), findsOneWidget);
  });

  testWidgets('same-day store candidates disclose the matching limitation',
      (tester) async {
    final candidates = AssetDiningReviewCandidate.fromFlows([
      flow('餃子の王将 ラーメンセット（食費）'),
      flow('餃子の王将 定食（食費）', id: 101),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssetCalendarReflectionPanel(
              repository: EmptyRepository(),
              start: DateTime(2026, 9),
              end: DateTime(2026, 10),
              selectedDate: DateTime(2026, 9, 20),
              onLoaded: (_) {},
              diningReviewCandidates: candidates,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('支出の内容に「餃子の王将」'), findsNWidgets(2));
    expect(find.textContaining('当月を含む24か月分'), findsOneWidget);
    expect(find.textContaining('2000件を超える場合'), findsOneWidget);
    expect(find.textContaining('この画面では支出明細を個別に照合できません'), findsOneWidget);
    expect(find.textContaining('ラーメンセット'), findsNothing);
    expect(find.textContaining('定食'), findsNothing);
    expect(find.text('外食 0日'), findsOneWidget);
  });

  testWidgets('confirmed linked dining suppresses the review candidate',
      (tester) async {
    final candidates = AssetDiningReviewCandidate.fromFlows([
      flow('餃子の王将 ラーメンセット（食費）'),
    ]);
    final confirmed = AssetCalendarReflection(
      sourceKey: 'confirmed:one',
      date: DateTime(2026, 9, 20),
      kinds: const {AssetReflectionKind.dining},
      title: '確認済み外食',
      sourceLabel: '本人確認',
      linkedFlowId: '100',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssetCalendarReflectionPanel(
              repository: EmptyRepository([confirmed]),
              start: DateTime(2026, 9),
              end: DateTime(2026, 10),
              selectedDate: DateTime(2026, 9, 20),
              onLoaded: (_) {},
              diningReviewCandidates: candidates,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('外食かは要確認'), findsNothing);
    expect(find.text('外食 1日'), findsOneWidget);
  });

  testWidgets('linked dining on a different day does not suppress review',
      (tester) async {
    final candidates = AssetDiningReviewCandidate.fromFlows([
      flow('餃子の王将 ラーメンセット（食費）'),
    ]);
    final confirmedElsewhere = AssetCalendarReflection(
      sourceKey: 'confirmed:other-day',
      date: DateTime(2026, 9, 19),
      kinds: const {AssetReflectionKind.dining},
      title: '別日の確定記録',
      sourceLabel: '本人確認',
      linkedFlowId: '100',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssetCalendarReflectionPanel(
              repository: EmptyRepository([confirmedElsewhere]),
              start: DateTime(2026, 9),
              end: DateTime(2026, 10),
              selectedDate: DateTime(2026, 9, 20),
              onLoaded: (_) {},
              diningReviewCandidates: candidates,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('外食かは要確認'), findsOneWidget);
  });

  testWidgets('candidate waits for successful confirmed-record lookup',
      (tester) async {
    final repository = DeferredRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssetCalendarReflectionPanel(
              repository: repository,
              start: DateTime(2026, 9),
              end: DateTime(2026, 10),
              selectedDate: DateTime(2026, 9, 20),
              onLoaded: (_) {},
              diningReviewCandidates: AssetDiningReviewCandidate.fromFlows(
                [flow('吉野家')],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('外食かは要確認'), findsNothing);
    repository.pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.textContaining('外食かは要確認'), findsOneWidget);
  });

  testWidgets('failed confirmed-record lookup hides the candidate',
      (tester) async {
    final repository = DeferredRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssetCalendarReflectionPanel(
              repository: repository,
              start: DateTime(2026, 9),
              end: DateTime(2026, 10),
              selectedDate: DateTime(2026, 9, 20),
              onLoaded: (_) {},
              diningReviewCandidates: AssetDiningReviewCandidate.fromFlows(
                [flow('吉野家')],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    repository.pending.completeError(StateError('synthetic read error'));
    await tester.pumpAndSettle();
    expect(find.textContaining('外食かは要確認'), findsNothing);
    expect(find.textContaining('振り返りを取得できませんでした'), findsOneWidget);
  });

  testWidgets(
      'candidate does not change existing nonzero meal and alcohol summary',
      (tester) async {
    final recorded = AssetCalendarReflection(
      sourceKey: 'existing',
      date: DateTime(2026, 9, 18),
      kinds: const {
        AssetReflectionKind.dining,
        AssetReflectionKind.drinkingOut,
      },
      title: '確定済み',
      sourceLabel: '本人確認',
      verifiedAmount: 2500,
      alcoholAmount: 500,
    );
    final repo = EmptyRepository([recorded]);
    final reported = <List<AssetCalendarReflection>>[];
    Widget app(List<AssetDiningReviewCandidate> candidates) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssetCalendarReflectionPanel(
                repository: repo,
                start: DateTime(2026, 9),
                end: DateTime(2026, 10),
                selectedDate: DateTime(2026, 9, 20),
                onLoaded: (events) => reported.add(events),
                diningReviewCandidates: candidates,
              ),
            ),
          ),
        );
    await tester.pumpWidget(app([]));
    await tester.pumpAndSettle();
    expect(find.text('外食 1日'), findsOneWidget);
    expect(find.text('外飲み 1日'), findsOneWidget);
    expect(find.textContaining('表示期間の確認済み金額 2500円'), findsOneWidget);
    expect(find.textContaining('酒代の確認済み内訳 500円'), findsOneWidget);
    expect(reported.single, [recorded]);
    await tester
        .pumpWidget(app(AssetDiningReviewCandidate.fromFlows([flow('吉野家')])));
    await tester.pumpAndSettle();
    expect(find.text('外食 1日'), findsOneWidget);
    expect(find.text('外飲み 1日'), findsOneWidget);
    expect(find.textContaining('表示期間の確認済み金額 2500円'), findsOneWidget);
    expect(find.textContaining('酒代の確認済み内訳 500円'), findsOneWidget);
    expect(find.textContaining('外食かは要確認'), findsOneWidget);
    expect(reported.single, [recorded]);
  });
}
