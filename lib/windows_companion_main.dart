import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/local_smart_cleanup_page.dart';
import 'pages/windows_app_install_page.dart';

void main() {
  runApp(const WindowsCompanionApp());
}

class WindowsCompanionApp extends StatelessWidget {
  const WindowsCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jibun Windows Companion',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const <Locale>[
        Locale('ja', 'JP'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00897B),
      ),
      initialRoute: '/local-smart-cleanup',
      routes: <String, WidgetBuilder>{
        '/windows-app': (_) => const WindowsAppInstallPage(),
        '/local-smart-cleanup': (_) => const LocalSmartCleanupPage(),
      },
    );
  }
}
