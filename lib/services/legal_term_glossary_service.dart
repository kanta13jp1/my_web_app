class LegalTermDefinition {
  const LegalTermDefinition({
    required this.term,
    required this.definition,
    required this.background,
    required this.lawReferences,
    this.aliases = const <String>[],
  });

  final String term;
  final String definition;
  final String background;
  final List<String> lawReferences;
  final List<String> aliases;

  Iterable<String> get matchWords sync* {
    yield term;
    yield* aliases;
  }

  String get tooltipText {
    final references =
        lawReferences.isEmpty ? '' : '\n関連: ${lawReferences.join(' / ')}';
    return '$term\n$definition\n$background$references';
  }
}

class LegalTermMatch {
  const LegalTermMatch({
    required this.start,
    required this.end,
    required this.matchedText,
    required this.definition,
  });

  final int start;
  final int end;
  final String matchedText;
  final LegalTermDefinition definition;
}

class LegalTermGlossaryService {
  const LegalTermGlossaryService({
    this.definitions = defaultDefinitions,
  });

  final List<LegalTermDefinition> definitions;

  static const List<LegalTermDefinition> defaultDefinitions =
      <LegalTermDefinition>[
    LegalTermDefinition(
      term: '広範性要件',
      definition: '憲法改正や緊急権の制度設計で、対象範囲が広すぎないかを確認する観点です。',
      background: '権限の濫用や通常時への拡張を防ぐため、発動条件・期間・対象を明確にします。',
      lawReferences: ['憲法改正論点', '緊急事態条項'],
      aliases: ['広範性'],
    ),
    LegalTermDefinition(
      term: '参議院の緊急集会',
      definition: '衆議院解散中に国会の議決が必要な緊急事態で、参議院が暫定的に開く会議です。',
      background: '日本国憲法54条2項・3項に規定され、後に衆議院の同意が必要になります。',
      lawReferences: ['憲法54条'],
      aliases: ['緊急集会'],
    ),
    LegalTermDefinition(
      term: '緊急政令',
      definition: '緊急時に行政が法律に準じる内容を定める命令を指す議論上の概念です。',
      background: '国会中心主義との緊張があるため、事後承認や期限設定が重要になります。',
      lawReferences: ['内閣法制', '緊急事態条項'],
    ),
    LegalTermDefinition(
      term: '繰延投票',
      definition: '災害などで予定日に投票できない地域の投票日を後ろへずらす制度です。',
      background: '選挙の公平性と実施可能性を両立するため、対象地域や期間を限定して運用されます。',
      lawReferences: ['公職選挙法57条'],
    ),
    LegalTermDefinition(
      term: '国民投票法附則4条',
      definition: '憲法改正国民投票制度の宿題として、関連制度の検討を求めた附則規定です。',
      background: '投票環境、広告規制、運動の公平性などの継続論点と結びつきます。',
      lawReferences: ['日本国憲法の改正手続に関する法律'],
      aliases: ['附則4条'],
    ),
    LegalTermDefinition(
      term: '国家緊急権',
      definition: '戦争・大災害などで国家機能を維持するために例外的権限を認める考え方です。',
      background: '人権制約や権力集中の危険があるため、厳格な発動要件と統制が不可欠です。',
      lawReferences: ['比較憲法', '緊急事態条項'],
    ),
    LegalTermDefinition(
      term: '緊急事態条項',
      definition: '緊急時の権限・国会機能・選挙期日などを憲法に明記する提案群です。',
      background: '災害対応の実効性と、権力濫用を防ぐ統制設計の両方が論点になります。',
      lawReferences: ['憲法改正論点'],
    ),
    LegalTermDefinition(
      term: '憲法審査会',
      definition: '憲法や憲法改正原案を調査・審査する衆参両院の機関です。',
      background: '各会派の意見表明、参考人質疑、論点整理の場として機能します。',
      lawReferences: ['国会法102条の6'],
    ),
  ];

  List<LegalTermMatch> matchTerms(String text) {
    if (text.isEmpty) return const <LegalTermMatch>[];

    final occupied = List<bool>.filled(text.length, false);
    final matches = <LegalTermMatch>[];
    final entries = <_GlossaryEntry>[
      for (final definition in definitions)
        for (final word in definition.matchWords)
          if (word.isNotEmpty) _GlossaryEntry(word, definition),
    ]..sort((a, b) => b.word.length.compareTo(a.word.length));

    for (final entry in entries) {
      var start = text.indexOf(entry.word);
      while (start >= 0) {
        final end = start + entry.word.length;
        final overlaps =
            occupied.sublist(start, end).any((alreadyUsed) => alreadyUsed);
        if (!overlaps) {
          for (var i = start; i < end; i++) {
            occupied[i] = true;
          }
          matches.add(
            LegalTermMatch(
              start: start,
              end: end,
              matchedText: text.substring(start, end),
              definition: entry.definition,
            ),
          );
        }
        start = text.indexOf(entry.word, end);
      }
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    return matches;
  }
}

class _GlossaryEntry {
  const _GlossaryEntry(this.word, this.definition);

  final String word;
  final LegalTermDefinition definition;
}
