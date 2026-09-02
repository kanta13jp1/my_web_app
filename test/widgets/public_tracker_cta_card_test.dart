import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/public_tracker_cta_card.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders the explanation and the low-friction action', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PublicTrackerCtaCard(
          headline: 'この集計は「自分株式会社」が毎日自動更新しています',
          description: '公式ページを定期取得して差分を計算しています。',
          onActionPressed: () {},
        ),
      ),
    );

    expect(find.text('この集計は「自分株式会社」が毎日自動更新しています'), findsOneWidget);
    expect(find.text('公式ページを定期取得して差分を計算しています。'), findsOneWidget);
    // X から来た訪問者が最初に必要とするのは「何のサイトか」と次の一手。
    expect(find.text('5分だけ試す'), findsOneWidget);
    expect(find.text('登録なしで中身を見られます'), findsOneWidget);
  });

  testWidgets('fires the action callback exactly once per tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        PublicTrackerCtaCard(
          headline: 'headline',
          description: 'description',
          onActionPressed: () => taps += 1,
        ),
      ),
    );

    await tester.tap(find.text('5分だけ試す'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('allows a tracker-specific action label', (tester) async {
    await tester.pumpWidget(
      host(
        PublicTrackerCtaCard(
          headline: 'headline',
          description: 'description',
          actionLabel: '家計トラッカーを見る',
          onActionPressed: () {},
        ),
      ),
    );

    expect(find.text('家計トラッカーを見る'), findsOneWidget);
    expect(find.text('5分だけ試す'), findsNothing);
  });
}
