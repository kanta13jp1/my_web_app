import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_web_app/services/home_tool_usage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('records recent tools with newest first and no duplicates', () async {
    final prefs = await SharedPreferences.getInstance();

    await HomeToolUsageService.recordToolUse('alpha', prefs: prefs);
    await HomeToolUsageService.recordToolUse('beta', prefs: prefs);
    await HomeToolUsageService.recordToolUse('alpha', prefs: prefs);

    expect(
      await HomeToolUsageService.loadRecentToolIds(prefs: prefs),
      <String>['alpha', 'beta'],
    );
  });

  test('keeps only the latest six tools', () async {
    final prefs = await SharedPreferences.getInstance();

    for (final id in <String>[
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
    ]) {
      await HomeToolUsageService.recordToolUse(id, prefs: prefs);
    }

    expect(
      await HomeToolUsageService.loadRecentToolIds(prefs: prefs),
      <String>['seven', 'six', 'five', 'four', 'three', 'two'],
    );
  });
}
