import 'package:flutter/material.dart';
// ✅ 追加: ローカリゼーション用のパッケージ
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
// ❌ 削除: import 'pages/auth_page.dart';
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/landing_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/shared_note_page.dart';
import 'pages/enhanced_statistics_page.dart';
import 'pages/referral_page.dart';
import 'pages/daily_challenges_page.dart';
import 'pages/memo_gallery_page.dart';
import 'pages/documents_page.dart';
import 'pages/personality_test_landing_page.dart';
import 'pages/compatibility_landing_page.dart';
import 'services/theme_service.dart';
import 'services/timer_service.dart';

// Supabaseクライアントのゲッター
SupabaseClient get supabase => Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://smmkxxavexumewbfaqpy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtbWt4eGF2ZXh1bWV3YmZhcXB5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2OTExNzYsImV4cCI6MjA3NjI2NzE3Nn0.U2OsYRYFvbpu2QjTwXulJ67v9wouMMpn0y9B9K5-WHw',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => TimerService()),
      ],
      child: const MyApp(),
    ),
  );
}

// Helper widget to check onboarding status
class _AuthenticatedHomePage extends StatelessWidget {
  const _AuthenticatedHomePage();

  Future<bool> _shouldShowOnboarding() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await supabase
          .from('user_stats')
          .select('metadata')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return true;
      }

      final metadata = response['metadata'] as Map<String, dynamic>?;
      final onboardingCompleted = metadata?['onboarding_completed'] as bool?;

      return onboardingCompleted != true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _shouldShowOnboarding(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final shouldShowOnboarding = snapshot.data ?? false;
        return shouldShowOnboarding ? const OnboardingPage() : const HomePage();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      title: 'マイメモ',
      debugShowCheckedModeBanner: false,
      theme: themeService.getLightTheme(),
      darkTheme: themeService.getDarkTheme(),
      themeMode: themeService.getFlutterThemeMode(),

      // ✅ 追加: 日本語ローカリゼーションの設定
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja'), // 日本語
        Locale('en'), // 英語
      ],
      locale: const Locale('ja'), // デフォルトを日本語に固定

      initialRoute: '/',
      onGenerateRoute: (settings) {
        // 共有リンク用のルーティング（認証不要）
        if (settings.name != null && settings.name!.startsWith('/shared/')) {
          final token = settings.name!.replaceFirst('/shared/', '');
          return MaterialPageRoute(
            builder: (_) => SharedNotePage(shareToken: token),
          );
        }

        final uri = Uri.parse(settings.name ?? '/');
        // final queryParams = uri.queryParameters; // ※必要に応じてLandingPageに渡す

        // 通常のルーティング
        switch (uri.path) {
          case '/':
            // ルートは認証状態で分岐
            return MaterialPageRoute(
              builder: (_) => supabase.auth.currentSession != null
                  ? const _AuthenticatedHomePage()
                  : const LandingPage(),
            );
          case '/landing':
            // ランディングページ
            return MaterialPageRoute(
              builder: (_) => const LandingPage(),
            );
          case '/leaderboard':
            // リーダーボード
            return MaterialPageRoute(
              builder: (_) => const LeaderboardPage(),
            );
          case '/home':
            // ホームページ（認証必要）
            return MaterialPageRoute(
              builder: (_) => const HomePage(),
            );

          // ✅ 変更: 認証系ルートはすべてLandingPageへ統合
          case '/auth':
          case '/signup':
            return MaterialPageRoute(
              builder: (_) => const LandingPage(),
            );

          case '/statistics':
            // サイト統計ページ
            return MaterialPageRoute(
              builder: (_) => const EnhancedStatisticsPage(),
            );
          case '/referral':
            // 紹介プログラムページ
            return MaterialPageRoute(
              builder: (_) => const ReferralPage(),
            );
          case '/challenges':
            // デイリーチャレンジページ
            return MaterialPageRoute(
              builder: (_) => const DailyChallengesPage(),
            );
          case '/gallery':
            // メモギャラリーページ
            return MaterialPageRoute(
              builder: (_) => const MemoGalleryPage(),
            );
          case '/documents':
            // ドキュメントページ
            return MaterialPageRoute(
              builder: (_) => const DocumentsPage(),
            );
          case '/personality-test':
            // 性格診断ページ
            return MaterialPageRoute(
              builder: (_) => const PersonalityTestLandingPage(),
            );
          case '/compatibility':
            // 恋愛相性診断ページ
            return MaterialPageRoute(
              builder: (_) => const CompatibilityLandingPage(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const LandingPage(),
            );
        }
      },
    );
  }
}
