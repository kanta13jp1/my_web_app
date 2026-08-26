import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings menu and app router expose the AI form assistant', () {
    final settingsSource =
        File('lib/pages/settings_page.dart').readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(settingsSource, contains("name: '/settings/ai-form-assistant'"));
    expect(
      settingsSource,
      contains('builder: (_) => const AiFormAssistantPage()'),
    );
    expect(mainSource, contains("case '/settings/ai-form-assistant':"));
    expect(mainSource, contains('supabase.auth.currentSession == null'));
    expect(mainSource, contains('LandingPage('));
    expect(mainSource, contains('const AiFormAssistantPage()'));
  });
}
