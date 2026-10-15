import 'package:flutter/material.dart';
import 'package:my_web_app/widgets/browser_reminder_settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(const MaterialApp(home: Scaffold(
    body: SafeArea(child: BrowserReminderSettingsTile()),
  )));
}
