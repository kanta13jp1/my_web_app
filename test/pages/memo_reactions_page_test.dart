import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/memo_reactions_page.dart';
import 'package:my_web_app/services/public_memo_service.dart';

class FakeMemoReactionService implements MemoReactionService {
  final List<int> loadedMemoIds = <int>[];
  final List<({int memoId, String reaction})> toggles =
      <({int memoId, String reaction})>[];

  @override
  Future<Map<String, dynamic>> loadReactions(int memoId) async {
    loadedMemoIds.add(memoId);
    return <String, dynamic>{
      'reactions': <String, int>{'👍': 2},
      'userReactions': <String>[],
    };
  }

  @override
  Future<Map<String, dynamic>> toggleReaction({
    required int memoId,
    required String reaction,
  }) async {
    toggles.add((memoId: memoId, reaction: reaction));
    return <String, dynamic>{
      'reactions': <String, int>{'👍': 3},
      'userReactions': <String>['👍'],
    };
  }
}

void main() {
  testWidgets('loads and toggles anonymous reactions through the service', (
    tester,
  ) async {
    final service = FakeMemoReactionService();
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(home: MemoReactionsPage(publicMemoService: service)),
      );

      await tester.enterText(find.byType(TextField), '42');
      await tester.tap(find.text('取得'));
      await tester.pumpAndSettle();

      expect(service.loadedMemoIds, <int>[42]);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('いいね 2件'));
      await tester.pumpAndSettle();

      expect(service.toggles, <({int memoId, String reaction})>[
        (memoId: 42, reaction: '👍'),
      ]);
      expect(find.text('3'), findsOneWidget);
      expect(find.bySemanticsLabel('いいね 3件 選択中'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
