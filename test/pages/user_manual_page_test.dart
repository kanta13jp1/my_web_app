import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/user_manual_page.dart';

void main() {
  testWidgets(
    'discloses paid plans instead of claiming every feature is free',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserManualPage()));

      expect(find.textContaining('主要機能は無料で始められます'), findsOneWidget);
      expect(find.textContaining('Pro・Teamなどの有料プラン'), findsOneWidget);
      expect(find.textContaining('料金・対象機能・解約条件'), findsOneWidget);
      expect(find.textContaining('完全無料'), findsNothing);
    },
  );
}
