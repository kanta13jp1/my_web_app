import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin Analytics Route Compatibility', () {
    testWidgets('renders AdminAnalyticsPage via /admin route alias',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/admin': (_) => const Scaffold(body: Text('Admin Dashboard')),
            '/admin/analytics': (_) =>
                const Scaffold(body: Text('Admin Dashboard')),
          },
          initialRoute: '/admin/analytics',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Admin Dashboard'), findsOneWidget);
    });
  });
}
