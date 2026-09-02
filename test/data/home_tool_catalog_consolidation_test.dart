import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<_CatalogEntry> entries;

  setUpAll(() {
    final source = File('lib/data/home_tool_catalog.dart').readAsStringSync();
    final starts = RegExp(r'^    HomeToolEntry\(', multiLine: true)
        .allMatches(source)
        .toList(growable: false);
    entries = <_CatalogEntry>[
      for (var index = 0; index < starts.length; index++)
        if (_CatalogEntry.tryParse(
          source.substring(
            starts[index].start,
            index + 1 < starts.length ? starts[index + 1].start : source.length,
          ),
        )
            case final entry?)
          entry,
    ];
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
      'ai-summarizer',
      'local-election-schedule',
      'mindmap',
      'referral-program',
      'stats',
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
        'ai-writing-assistant',
        'local-election-700',
        'rewards',
      ]),
    );
  });

  test('同じ具体ページを複数のホーム入口として重複掲載しない', () {
    final idsByPageClass = <String, List<String>>{};
    for (final entry in entries) {
      final pageClass = entry.pageClass;
      if (pageClass == null) continue;
      idsByPageClass.putIfAbsent(pageClass, () => <String>[]).add(entry.id);
    }
    final duplicates = idsByPageClass.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
        .toList(growable: false);

    expect(
      duplicates,
      isEmpty,
      reason: '同一実装の二重入口は統合する:\n${duplicates.join('\n')}',
    );
  });
}

class _CatalogEntry {
  const _CatalogEntry(this.id, this.title, this.pageClass);

  static _CatalogEntry? tryParse(String source) {
    final id = RegExp(r"\bid: '([^']+)',").firstMatch(source)?.group(1);
    final title = RegExp(r"\btitle: '([^']+)',").firstMatch(source)?.group(1);
    if (id == null || title == null) return null;
    final pageClass = RegExp(
      r'_pushPage\(context,\s*(?:const\s+)?([A-Za-z0-9_]+)\(',
    ).firstMatch(source)?.group(1);
    return _CatalogEntry(id, title, pageClass);
  }

  final String id;
  final String title;
  final String? pageClass;
}
