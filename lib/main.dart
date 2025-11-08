import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'pages/auth_page.dart';
import 'pages/home_page.dart';
import 'pages/landing_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/shared_note_page.dart';
import 'pages/enhanced_statistics_page.dart';
import 'pages/referral_page.dart';
import 'pages/daily_challenges_page.dart';
import 'pages/memo_gallery_page.dart';
import 'pages/documents_page.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://smmkxxavexumewbfaqpy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtbWt4eGF2ZXh1bWV3YmZhcXB5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2OTExNzYsImV4cCI6MjA3NjI2NzE3Nn0.U2OsYRYFvbpu2QjTwXulJ67v9wouMMpn0y9B9K5-WHw',
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const MyApp(),
    ),
  );
}

final supabase = Supabase.instance.client;

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
      themeMode: themeService.getFlutterThemeMode(),  // 更新
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // 共有リンク用のルーティング（認証不要）
        if (settings.name != null && settings.name!.startsWith('/shared/')) {
          final token = settings.name!.replaceFirst('/shared/', '');
          return MaterialPageRoute(
            builder: (_) => SharedNotePage(shareToken: token),
          );
        }

        // Parse query parameters for referral code
        final uri = Uri.parse(settings.name ?? '/');
        final queryParams = uri.queryParameters;

        // 通常のルーティング
        switch (uri.path) {
          case '/':
            // ルートは認証状態で分岐
            return MaterialPageRoute(
              builder: (_) => supabase.auth.currentSession != null
                  ? const HomePage()
                  : const LandingPage(),
            );
          case '/landing':
            // ランディングページ（認証不要）
            return MaterialPageRoute(
              builder: (_) => const LandingPage(),
            );
          case '/leaderboard':
            // リーダーボード（認証不要）
            return MaterialPageRoute(
              builder: (_) => const LeaderboardPage(),
            );
          case '/home':
            // ホームページ（認証必要）
            return MaterialPageRoute(
              builder: (_) => const HomePage(),
            );
          case '/auth':
            // 認証ページ（紹介コードサポート）
            return MaterialPageRoute(
              builder: (_) => AuthPage(
                referralCode: queryParams['ref'],
              ),
            );
          case '/signup':
            // サインアップページ（紹介コードサポート）
            return MaterialPageRoute(
              builder: (_) => AuthPage(
                initialMode: AuthMode.signUp,
                referralCode: queryParams['ref'],
              ),
            );
          case '/statistics':
            // サイト統計ページ（認証必要）
            return MaterialPageRoute(
              builder: (_) => const EnhancedStatisticsPage(),
            );
          case '/referral':
            // 紹介プログラムページ（認証必要）
            return MaterialPageRoute(
              builder: (_) => const ReferralPage(),
            );
          case '/challenges':
            // デイリーチャレンジページ（認証必要）
            return MaterialPageRoute(
              builder: (_) => const DailyChallengesPage(),
            );
          case '/gallery':
            // メモギャラリーページ（認証不要）
            return MaterialPageRoute(
              builder: (_) => const MemoGalleryPage(),
            );
          case '/documents':
            // ドキュメントページ（認証不要）
            return MaterialPageRoute(
              builder: (_) => const DocumentsPage(),
            );
          default:
            // デフォルトはランディングページ
            return MaterialPageRoute(
              builder: (_) => const LandingPage(),
            );
        }
      },
    );
  }
}