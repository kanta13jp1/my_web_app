import 'package:flutter/material.dart';
import 'package:my_web_app/pages/echo_pump_game_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansJP'),
      initialRoute: '/game',
      routes: {
        '/': (context) => const Scaffold(
              body: Center(child: Text('音声確認ホーム')),
            ),
        '/game': (context) => const EchoPumpGamePage(),
      },
    ),
  );
}
