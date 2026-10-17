import 'package:flutter/material.dart';
import 'package:my_web_app/pages/echo_pump_game_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(const MaterialApp(home: EchoPumpGamePage()));
}
