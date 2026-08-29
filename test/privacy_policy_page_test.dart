import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/privacy_policy_page.dart';

void main() {
  testWidgets('privacy policy page renders the public policy asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrivacyPolicyPage(showBackButton: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.text('AIデータ取扱い早見表'), findsOneWidget);
    expect(find.textContaining('AIチャット・文章生成'), findsWidgets);
    expect(find.textContaining('AI分析・提案'), findsWidgets);
    expect(find.textContaining('AI動画生成'), findsWidgets);

    for (
      var attempt = 0;
      attempt < 10 && find.text('1. 適用範囲').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(Scrollable), const Offset(0, -400));
      await tester.pump();
    }

    expect(find.text('1. 適用範囲'), findsOneWidget);
    expect(find.textContaining('対象サービス'), findsWidgets);
  });
}
