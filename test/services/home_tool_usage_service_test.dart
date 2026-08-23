import 'dart:convert';

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

    expect(await HomeToolUsageService.loadRecentToolIds(prefs: prefs), <String>[
      'alpha',
      'beta',
    ]);

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

    expect(await HomeToolUsageService.loadRecentToolIds(prefs: prefs), <String>[
      'seven',
      'six',
      'five',
      'four',
      'three',
      'two',
    ]);
  });

  test('legacy tool usage is merged into the canonical tool id', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'home_recent_tool_ids_v1': <String>[
        'local-election-schedule',
        'alpha',
        'local-election-700',
      ],
      'home_tool_usage_counts_v1': jsonEncode(<String, int>{
        'local-election-schedule': 2,
        'local-election-700': 3,
      }),
      'home_tool_last_used_at_v1': jsonEncode(<String, String>{
        'local-election-schedule': '2026-08-22T09:00:00.000Z',
        'local-election-700': '2026-08-22T08:00:00.000Z',
      }),
    });
    final prefs = await SharedPreferences.getInstance();

    expect(await HomeToolUsageService.loadRecentToolIds(prefs: prefs), <String>[
      'local-election-700',
      'alpha',
    ]);

    final signals = await HomeToolUsageService.loadUsageSignals(
      prefs: prefs,
      candidates: const <HomeToolUsageCandidate>[
        HomeToolUsageCandidate(
          id: 'local-election-700',
          title: 'Local elections',
          sectionId: 'special',
        ),
      ],
    );
    expect(signals.single.openCount, 5);
    expect(signals.single.lastUsedAt?.toUtc(), DateTime.utc(2026, 8, 22, 9));

    await HomeToolUsageService.recordToolUse(
      'local-election-schedule',
      prefs: prefs,
      now: DateTime.utc(2026, 8, 22, 10),
    );
    final storedCounts =
        jsonDecode(prefs.getString('home_tool_usage_counts_v1')!)
            as Map<String, dynamic>;
    expect(storedCounts['local-election-700'], 6);
    expect(storedCounts.containsKey('local-election-schedule'), isFalse);
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
