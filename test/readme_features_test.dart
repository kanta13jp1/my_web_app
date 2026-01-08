import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:my_web_app/pages/home_page.dart';
import 'package:my_web_app/pages/emergency_meeting_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('README Features Smoke Test', () {
    testWidgets('Feature: HomePage (Cockpit) renders correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const HomePage()));
      await tester.pumpAndSettle();

      // UI確認
      expect(find.text('CEO OFFICE'), findsOneWidget);
      expect(find.text('CSO OFFICE'), findsOneWidget);
    });

    testWidgets('Feature: EmergencyMeetingPage renders correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const EmergencyMeetingPage()));
      await tester.pumpAndSettle();

      // UI要素の確認: テキスト入力欄があること
      expect(find.byType(TextField), findsOneWidget);

      // '招集'ボタンの確認 (アイコンボタンではなくテキストで探す)
      // ボタン内のテキスト、あるいはツールチップなどを探す
      expect(find.text('招集'), findsOneWidget);
    });
  });
}
