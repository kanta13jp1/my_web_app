import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/auth_page.dart';
import 'pages/home_page.dart';
import 'pages/shared_note_page.dart';  // 追加

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://smmkxxavexumewbfaqpy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtbWt4eGF2ZXh1bWV3YmZhcXB5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2OTExNzYsImV4cCI6MjA3NjI2NzE3Nn0.U2OsYRYFvbpu2QjTwXulJ67v9wouMMpn0y9B9K5-WHw',
  );
  
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'マイメモ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // 共有リンク用のルーティング（認証不要）
        if (settings.name != null && settings.name!.startsWith('/shared/')) {
          final token = settings.name!.replaceFirst('/shared/', '');
          return MaterialPageRoute(
            builder: (_) => SharedNotePage(shareToken: token),
          );
        }

        // 通常のルーティング（認証チェック）
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => supabase.auth.currentSession != null
                  ? const HomePage()
                  : const AuthPage(),
            );
          case '/home':
            return MaterialPageRoute(
              builder: (_) => const HomePage(),
            );
          case '/auth':
            return MaterialPageRoute(
              builder: (_) => const AuthPage(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const AuthPage(),
            );
        }
      },
    );
  }
}