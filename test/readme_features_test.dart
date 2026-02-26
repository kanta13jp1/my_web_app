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

      expect(find.text('次に実施すべきアクション'), findsOneWidget);
      expect(find.textContaining('AI推奨:'), findsOneWidget);
      expect(find.text('やらないことガード'), findsOneWidget);
      expect(find.text('CEO OFFICE'), findsOneWidget);
      expect(find.text('CSO OFFICE'), findsOneWidget);
    });

    testWidgets('Feature: HomePage prioritizes morning briefing before noon',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        createTestWidget(
          HomePage(nowProvider: () => DateTime(2026, 2, 26, 9, 0)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('モーニング・ブリーフィングを先に実施'), findsOneWidget);
      expect(find.text('モーニング・ブリーフィング（最優先）'), findsOneWidget);
    });

    testWidgets('Feature: HomePage prioritizes balance check after briefing',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'home_morning_briefing_done_2026-02-26': true,
      });
      await tester.pumpWidget(
        createTestWidget(
          HomePage(nowProvider: () => DateTime(2026, 2, 26, 10, 0)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日の口座残高を確認'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
    });

    testWidgets('Feature: HomePage shows normal mode when core flow is done',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'home_morning_briefing_done_2026-02-26': true,
        'home_balance_check_done_2026-02-26': true,
      });
      await tester.pumpWidget(
        createTestWidget(
          HomePage(nowProvider: () => DateTime(2026, 2, 26, 13, 0)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日の必須導線は完了済み'), findsOneWidget);
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
