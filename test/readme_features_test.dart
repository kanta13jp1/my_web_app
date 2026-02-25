import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_list_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:my_web_app/pages/home_page.dart';
import 'package:my_web_app/pages/emergency_meeting_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // 1. テスト実行前にFlutterの機能をバインドする（プラグインエラー防止の鍵）
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 2. Supabaseが動く前に、保存機能のモック（偽物）を用意する
    SharedPreferences.setMockInitialValues({});

    // 3. その後でSupabaseを初期化する
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'dummy',
      debug: false,
    );
  });

  setUp(() {
    // 各テストの前に設定をリセット
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

      expect(find.text('CEO OFFICE'), findsOneWidget);
      expect(find.text('CSO OFFICE'), findsOneWidget);
    });

    testWidgets('Feature: EmergencyMeetingPage renders correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: EmergencyMeetingPage()));
      await tester.pumpAndSettle();

      // UIの確認
      expect(find.text('緊急役員会議 (継続・禁欲)'), findsOneWidget);
      // ボタンがあるか確認
      expect(find.text('継続・禁欲プランを作成'), findsOneWidget);
    });

    testWidgets('Feature: NoteListPage renders correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: NoteListPage()));
      // データの読み込み待ち（エラーになってもUIが出ればOK）
      await tester.pumpAndSettle();

      expect(find.text('CKO OFFICE (知識)'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
