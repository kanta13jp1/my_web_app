// ignore_for_file: argument_type_not_assignable
@TestOn('browser')

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/main.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:my_web_app/services/landing_signup_completion_service.dart';
import 'package:my_web_app/pages/home_page.dart';
import 'package:my_web_app/pages/landing_page.dart';
import 'package:my_web_app/pages/onboarding_page.dart';
import 'package:my_web_app/pages/gemini_university_v2_page.dart';
import 'package:my_web_app/pages/danshari_page.dart';

// モック生成
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  SupabaseQueryBuilder,
  PostgrestFilterBuilder,
  PostgrestTransformBuilder,
  ThemeService,
  User,
  Session,
])
import 'main_test.mocks.dart';

// PostgrestTransformBuilder は Future を実装しているため、
// await できるように Fake クラスを作成して then メソッドをオーバーライドします。
class FakePostgrestTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  final T _value;
  FakePostgrestTransformBuilder(this._value);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) async {
    return onValue(_value);
  }
}

class _SignupCompletionRecorder extends LandingSignupCompletionService {
  _SignupCompletionRecorder();

  final List<(String?, String?, DateTime?)> calls =
      <(String?, String?, DateTime?)>[];

  @override
  Future<bool> completeIfPending({
    required String? signupUserId,
    String? signupEmail,
    DateTime? accountCreatedAt,
    SharedPreferences? preferences,
  }) async {
    calls.add((signupUserId, signupEmail, accountCreatedAt));
    return true;
  }
}

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockThemeService mockThemeService;

  setUp(() {
    // SharedPreferences のモック初期化
    SharedPreferences.setMockInitialValues({});

    // Supabase 関連のモック初期化
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockThemeService = MockThemeService();

    // main.dart の supabase ゲッターがモックを返すように設定
    supabaseClientForTesting = mockSupabaseClient;

    // 基本的なスタブ設定
    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);

    // ThemeService のスタブ設定
    when(mockThemeService.getLightTheme()).thenReturn(ThemeData.light());
    when(mockThemeService.getDarkTheme()).thenReturn(ThemeData.dark());
    when(mockThemeService.getFlutterThemeMode()).thenReturn(ThemeMode.system);
    when(mockThemeService.isDarkMode).thenReturn(false);
    when(mockThemeService.primaryColor).thenReturn(Colors.blue);
    // ChangeNotifier のリスナー登録をスタブ化
    when(mockThemeService.addListener(any)).thenReturn(null);
    when(mockThemeService.removeListener(any)).thenReturn(null);
  });

  group('MyApp Widget Tests', () {
    testWidgets('未ログイン時は LandingPage が表示されること', (WidgetTester tester) async {
      // Arrange: セッションがない状態をシミュレート
      when(mockGoTrueClient.currentSession).thenReturn(null);

      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: mockThemeService,
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(LandingPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(find.byKey(const Key('global_header_clock_bar')), findsNothing);
    });

    testWidgets('ログイン済みでオンボーディング未完了時は OnboardingPage が表示されること',
        (WidgetTester tester) async {
      // Arrange: セッションがある状態をシミュレート
      final mockSession = MockSession();
      final mockUser = MockUser();
      when(mockGoTrueClient.currentSession).thenReturn(mockSession);
      when(mockGoTrueClient.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn('test-user-id');
      when(mockUser.email).thenReturn('new-user@example.com');
      when(mockUser.createdAt).thenReturn('2026-07-23T01:00:02Z');
      final signupCompletion = _SignupCompletionRecorder();

      // DB呼び出しのモック: user_stats が存在しない (null) -> オンボーディング表示
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      // select() は List<Map<String, dynamic>> を扱う FilterBuilder を返すため型を指定
      final mockFilterBuilder =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

      when(mockSupabaseClient.from('user_stats'))
          .thenAnswer((_) => mockQueryBuilder);
      when(mockQueryBuilder.select('metadata'))
          .thenAnswer((_) => mockFilterBuilder);
      when(mockFilterBuilder.eq('user_id', 'test-user-id'))
          .thenAnswer((_) => mockFilterBuilder);
      // maybeSingle が null を持つ FakeBuilder を返すように設定
      when(mockFilterBuilder.maybeSingle())
          .thenAnswer((_) => FakePostgrestTransformBuilder(null));

      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: mockThemeService,
          child: MyApp(signupCompletionService: signupCompletion),
        ),
      );
      // FutureBuilder の完了を待つ
      await tester.pump(); // 読み込み開始
      await tester.pump(const Duration(milliseconds: 100)); // 非同期処理待ち
      await tester.pumpAndSettle(); // アニメーション完了待ち

      // Assert
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(signupCompletion.calls, <(String?, String?, DateTime?)>[
        (
          'test-user-id',
          'new-user@example.com',
          DateTime.utc(2026, 7, 23, 1, 0, 2),
        ),
      ]);
    });

    testWidgets('ログイン済みでオンボーディング完了時は HomePage が表示されること',
        (WidgetTester tester) async {
      // Arrange
      final mockSession = MockSession();
      final mockUser = MockUser();
      when(mockGoTrueClient.currentSession).thenReturn(mockSession);
      when(mockGoTrueClient.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn('test-user-id');

      // DB呼び出しのモック: user_stats があり、onboarding_completed が true
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

      when(mockSupabaseClient.from('user_stats'))
          .thenAnswer((_) => mockQueryBuilder);
      when(mockQueryBuilder.select('metadata'))
          .thenAnswer((_) => mockFilterBuilder);
      when(mockFilterBuilder.eq('user_id', 'test-user-id'))
          .thenAnswer((_) => mockFilterBuilder);
      // maybeSingle がデータを持つ FakeBuilder を返すように設定
      when(mockFilterBuilder.maybeSingle()).thenAnswer(
        (_) => FakePostgrestTransformBuilder({
          'metadata': {'onboarding_completed': true},
        }),
      );

      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: mockThemeService,
          child: const MyApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byKey(const Key('global_header_clock_bar')), findsOneWidget);
    });

    testWidgets('オンボーディングは保存済みページから再開できること', (WidgetTester tester) async {
      // Arrange
      final mockUser = MockUser();
      when(mockGoTrueClient.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn('test-user-id');
      SharedPreferences.setMockInitialValues({
        'activation_onboarding_draft_v1_test-user-id_stage': 1,
        'activation_onboarding_draft_v1_test-user-id_intent': 'work',
        'activation_onboarding_draft_v1_test-user-id_first_action':
            '今日終える仕事を1つだけ選び、完了条件を書く',
        'activation_onboarding_draft_v1_test-user-id_reason':
            '優先順位を増やすより、完了条件を1つ固定します。',
        'activation_onboarding_draft_v1_test-user-id_ten_minute_step':
            '最初の10分だけ着手する',
      });

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingPage(),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('あなた向けの最初の一手'), findsOneWidget);
      expect(find.text('入力を直す'), findsOneWidget);
    });

    testWidgets('テーマ設定が反映されていること', (WidgetTester tester) async {
      // Arrange: ダークモードを強制
      when(mockThemeService.getFlutterThemeMode()).thenReturn(ThemeMode.dark);
      when(mockGoTrueClient.currentSession).thenReturn(null); // LandingPageで確認

      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: mockThemeService,
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.dark);
    });

    testWidgets('ルーティング: /gemini-university へ遷移できること',
        (WidgetTester tester) async {
      // Arrange
      when(mockGoTrueClient.currentSession).thenReturn(null);

      // GeminiUniversityPage 用のモック
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

      when(mockSupabaseClient.from('gemini_lectures'))
          .thenAnswer((_) => mockQueryBuilder);
      when(mockQueryBuilder.select(any)).thenAnswer((_) => mockFilterBuilder);
      when(mockFilterBuilder.order(any, ascending: anyNamed('ascending')))
          .thenAnswer((_) => FakePostgrestTransformBuilder([]));

      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: mockThemeService,
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(LandingPage));
      Navigator.of(context).pushNamed('/gemini-university');
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AiUniversityPage), findsOneWidget);
    });

    testWidgets('ルーティング: /digital-danshari へ遷移できること',
        (WidgetTester tester) async {
      // Arrange
      when(mockGoTrueClient.currentSession).thenReturn(null);

      // DanshariPage 用のモック
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
      final mockUser = MockUser();

      // DanshariPage は currentUser.id を参照するためモック化
      when(mockGoTrueClient.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn('test-user-id');

      when(mockSupabaseClient.from('danshari_items'))
          .thenAnswer((_) => mockQueryBuilder);
      when(mockQueryBuilder.select(any)).thenAnswer((_) => mockFilterBuilder);
      when(mockFilterBuilder.eq(any, any)).thenAnswer((_) => mockFilterBuilder);
      when(mockFilterBuilder.order(any, ascending: anyNamed('ascending')))
          .thenAnswer((_) => FakePostgrestTransformBuilder([]));

      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: mockThemeService,
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(LandingPage));
      Navigator.of(context).pushNamed('/digital-danshari');
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(DanshariPage), findsOneWidget);
    });

    testWidgets('ルーティング: 不明なパスは LandingPage へ遷移すること',
        (WidgetTester tester) async {
      // Arrange
      when(mockGoTrueClient.currentSession).thenReturn(null);

      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: mockThemeService,
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(LandingPage));
      Navigator.of(context).pushNamed('/unknown-route-xyz');
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(LandingPage), findsAtLeastNWidgets(1));
    });

    testWidgets('オンボーディング判定: DBエラー時も初回価値導線を表示すること',
        (WidgetTester tester) async {
      // Arrange
      final mockSession = MockSession();
      final mockUser = MockUser();
      when(mockGoTrueClient.currentSession).thenReturn(mockSession);
      when(mockGoTrueClient.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn('test-user-id');

      // DB呼び出しで例外
      when(mockSupabaseClient.from('user_stats'))
          .thenThrow(Exception('DB Error'));

      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: mockThemeService,
          child: const MyApp(),
        ),
      );
      // FutureBuilder の完了を待つ
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });
  });
}
