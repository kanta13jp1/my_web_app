import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<_CatalogEntry> entries;

  setUpAll(() {
    final source = File('lib/data/home_tool_catalog.dart').readAsStringSync();
    entries = RegExp(
      r"HomeToolEntry\(\s+id: '([^']+)',[\s\S]*?title: '([^']+)',",
      multiLine: true,
    )
        .allMatches(source)
        .map((match) => _CatalogEntry(match.group(1)!, match.group(2)!))
        .toList(growable: false);
  });

  test('ホームに同じ表示名の機能を重複掲載しない', () {
    final idsByTitle = <String, List<String>>{};
    for (final entry in entries) {
      idsByTitle.putIfAbsent(entry.title, () => <String>[]).add(entry.id);
    }
    final duplicates = idsByTitle.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
        .toList(growable: false);

    expect(
      duplicates,
      isEmpty,
      reason: '同じ目的の入口は統合ハブへ寄せる:\n${duplicates.join('\n')}',
    );
  });

  test('統合済みの旧入口をホームへ再追加しない', () {
    final ids = entries.map((entry) => entry.id).toSet();
    const retiredHomeEntries = <String>{
      'asset-management',
      'budget-financial-planner',
      'expense-tracker',
      'habit-gamification',
      'goal-tracker',
      'mindmap',
      'referral-program',
      'video-ad-generator',
      'viral-video-generator',
      'wip-limit',
    };

    expect(ids.intersection(retiredHomeEntries), isEmpty);
    expect(
      ids,
      containsAll(<String>[
        'cfo-office',
        'mind-map',
        'referral',
        'viral-ad-generator',
        'video-studio',
        'digest-queue',
        'daily-habits',
        'life-goals',
      ]),
    );
  });
}

class _CatalogEntry {
  const _CatalogEntry(this.id, this.title);

  final String id;
  final String title;
}
