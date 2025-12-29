import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/landing_page.dart';
import 'pages/gemini_university_page.dart';
import 'pages/danshari_page.dart';

import 'services/theme_service.dart';

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
              body: Center(child: CircularProgressIndicator()));
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en')],
      locale: const Locale('ja'),
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
          case '/gemini-university':
            return MaterialPageRoute(
                builder: (_) => const GeminiUniversityPage());
          case '/danshari':
            return MaterialPageRoute(builder: (_) => const DanshariPage());
          default:
            return MaterialPageRoute(builder: (_) => const LandingPage());
        }
      },
    );
  }
}
