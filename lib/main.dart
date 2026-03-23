import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_web_app/services/gamification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_web_app/services/notification_service.dart';
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/landing_page.dart';
import 'pages/agent_org_page.dart';
import 'pages/gemini_university_v2_page.dart';
import 'pages/danshari_page.dart';
import 'pages/memory_drill_page.dart';
import 'pages/behavior_review_page.dart';
import 'pages/digest_queue_page.dart';
import 'pages/growth_mission_page.dart';
import 'pages/reality_check_page.dart';
import 'pages/thought_anchor_page.dart';

import 'services/growth_mission_service.dart';
import 'services/theme_service.dart';
import 'widgets/global_header_clock_bar.dart';

SupabaseClient? _testSupabaseClient;
final GrowthPresenceNavigatorObserver _growthPresenceObserver =
    GrowthPresenceNavigatorObserver();

@visibleForTesting
set supabaseClientForTesting(SupabaseClient client) =>
    _testSupabaseClient = client;

SupabaseClient get supabase => _testSupabaseClient ?? Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final NotificationService notificationService = NotificationService();
  await notificationService.init();
  final prefs = await SharedPreferences.getInstance();
  final saturdayReminderEnabled =
      prefs.getBool('stock_tasks_saturday_reminder_enabled') ?? true;
  if (saturdayReminderEnabled) {
    await notificationService.scheduleSaturdayReminder();
  } else {
    await notificationService.cancelSaturdayReminder();
  }

  await Supabase.initialize(
    url: 'https://smmkxxavexumewbfaqpy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtbWt4eGF2ZXh1bWV3YmZhcXB5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2OTExNzYsImV4cCI6MjA3NjI2NzE3Nn0.U2OsYRYFvbpu2QjTwXulJ67v9wouMMpn0y9B9K5-WHw',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => GamificationService()),
        Provider<NotificationService>(create: (_) => notificationService),
      ],
      child: const MyApp(),
    ),
  );
}

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
      if (response == null) return true;
      final metadata = response['metadata'] as Map<String, dynamic>?;
      return metadata?['onboarding_completed'] != true;
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
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return (snapshot.data ?? false)
            ? const OnboardingPage()
            : const HomePage();
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
      title: '自分株式会社', //  旧: マイメモ -> 新: 自分株式会社
      debugShowCheckedModeBanner: false,
      theme: themeService.getLightTheme(),
      darkTheme: themeService.getDarkTheme(),
      themeMode: themeService.getFlutterThemeMode(),
      builder: (context, child) {
        return GlobalHeaderClockShell(
          child: child ?? const SizedBox.shrink(),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en')],
      locale: const Locale('ja'),
      navigatorObservers: <NavigatorObserver>[_growthPresenceObserver],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');

        switch (uri.path) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => supabase.auth.currentSession != null
                  ? const _AuthenticatedHomePage()
                  : const LandingPage(),
            );
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomePage());
          case '/agents':
            return MaterialPageRoute(builder: (_) => AgentOrgPage());
          case '/gemini-university':
            return MaterialPageRoute(
              builder: (_) => const GeminiUniversityV2Page(),
            );
          case '/danshari':
            return MaterialPageRoute(builder: (_) => const DanshariPage());
          case '/memory-drill':
            return MaterialPageRoute(builder: (_) => const MemoryDrillPage());
          case '/digest-queue':
            return MaterialPageRoute(builder: (_) => const DigestQueuePage());
          case '/growth-mission':
            return MaterialPageRoute(
              builder: (_) => const GrowthMissionPage(),
              settings: const RouteSettings(name: '/growth-mission'),
            );
          case '/behavior-review':
            return MaterialPageRoute(builder: (_) => BehaviorReviewPage());
          case '/reality-check':
            return MaterialPageRoute(builder: (_) => const RealityCheckPage());
          case '/thought-anchor':
            return MaterialPageRoute(builder: (_) => const ThoughtAnchorPage());
          default:
            return MaterialPageRoute(builder: (_) => const LandingPage());
        }
      },
    );
  }
}
