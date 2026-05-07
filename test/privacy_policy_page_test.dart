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
    expect(find.text('1. 適用範囲'), findsOneWidget);
    expect(find.textContaining('対象サービス'), findsWidgets);
  });
}
