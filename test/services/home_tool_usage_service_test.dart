import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_web_app/services/home_tool_usage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('records recent tools with newest first and no duplicates', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.utc(2026, 5, 5, 1);

    await HomeToolUsageService.recordToolUse('alpha', prefs: prefs, now: now);
    await HomeToolUsageService.recordToolUse(
      'beta',
      prefs: prefs,
      now: now.add(const Duration(minutes: 1)),
    );
    await HomeToolUsageService.recordToolUse(
      'alpha',
      prefs: prefs,
      now: now.add(const Duration(minutes: 2)),
    );

    expect(
      await HomeToolUsageService.loadRecentToolIds(prefs: prefs),
      <String>['alpha', 'beta'],
    );

    final signals = await HomeToolUsageService.loadUsageSignals(
      prefs: prefs,
      candidates: const [
        HomeToolUsageCandidate(
          id: 'alpha',
          title: 'Alpha',
          sectionId: 'personal',
        ),
        HomeToolUsageCandidate(
          id: 'beta',
          title: 'Beta',
          sectionId: 'personal',
        ),
      ],
    );

    expect(signals.first.id, 'alpha');
    expect(signals.first.openCount, 2);
    expect(signals.first.lastUsedAt, isNotNull);
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

  test('clear removes recency and usage signals', () async {
    final prefs = await SharedPreferences.getInstance();

    await HomeToolUsageService.recordToolUse(
      'alpha',
      prefs: prefs,
      now: DateTime.utc(2026, 5, 5),
    );
    await HomeToolUsageService.clear(prefs: prefs);

    expect(await HomeToolUsageService.loadRecentToolIds(prefs: prefs), isEmpty);
    final signals = await HomeToolUsageService.loadUsageSignals(
      prefs: prefs,
      candidates: const [
        HomeToolUsageCandidate(
          id: 'alpha',
          title: 'Alpha',
          sectionId: 'personal',
        ),
      ],
    );
    expect(signals.single.openCount, 0);
    expect(signals.single.lastUsedAt, isNull);
  });
}
