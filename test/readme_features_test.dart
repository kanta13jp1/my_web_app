import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/services/theme_service.dart';

// テスト対象のページ
import 'package:my_web_app/pages/home_page.dart';
import 'package:my_web_app/pages/emergency_meeting_page.dart';

void main() {
  setUp(() {
    // SharedPreferencesのモック初期化
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

      // 経営コックピットの主要セクションが表示されているか確認
      expect(find.text('CEO OFFICE (最高執行責任者)'), findsOneWidget);
      expect(find.text('CSO OFFICE (最高戦略責任者)'), findsOneWidget);
    });

    testWidgets('Feature: EmergencyMeetingPage renders correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const EmergencyMeetingPage()));
      await tester.pumpAndSettle();

      // 緊急役員会議のUI要素が表示されているか確認
      expect(find.text('緊急役員会議 (Emergency Board)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('招集'), findsOneWidget);
    });
  });
}
