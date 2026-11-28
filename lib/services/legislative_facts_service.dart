/// Neutral classification for a registered legislative fact (#2806).
enum FactStance {
  supporting('supporting', '裏付け'),
  contextual('contextual', '背景'),
  disputed('disputed', '見解差');

  const FactStance(this.wireName, this.label);

  final String wireName;
  final String label;
}

/// Legislative fact entry anchored to a mandatory public source URL.
class LegislativeFactEntry {
  const LegislativeFactEntry({
    required this.id,
    required this.topicKey,
    required this.factionName,
    required this.summary,
    required this.sourceUrl,
    required this.sourceTitle,
    required this.stance,
  });

  final String id;
  final String topicKey;
  final String factionName;
  final String summary;
  final String sourceUrl;
  final String sourceTitle;
  final FactStance stance;
}

/// Facts grouped for one faction within a topic comparison matrix.
class FactionFactColumn {
  const FactionFactColumn({
    required this.factionName,
    required this.facts,
  });

  final String factionName;
  final List<LegislativeFactEntry> facts;
}

/// Side-by-side comparison matrix across factions for a single topic.
class LegislativeFactComparisonMatrix {
  const LegislativeFactComparisonMatrix({
    required this.topicKey,
    required this.totalFacts,
    required this.columns,
  });

  final String topicKey;
  final int totalFacts;
  final List<FactionFactColumn> columns;
}

/// Service managing neutral legislative facts and mandatory source validation.
class LegislativeFactsService {
  final List<LegislativeFactEntry> _entries = <LegislativeFactEntry>[];

  /// Validates that [rawUrl] is a non-empty http:// or https:// URL.
  String validateSourceUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('sourceUrl must not be empty.');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw ArgumentError('sourceUrl must be a valid http/https URL.');
    }
    return uri.toString();
  }

  /// Registers a legislative fact after validating mandatory fields & URL.
  LegislativeFactEntry registerFact(LegislativeFactEntry entry) {
    final id = entry.id.trim();
    final topicKey = entry.topicKey.trim();
    final factionName = entry.factionName.trim();
    final summary = entry.summary.trim();
    final sourceTitle = entry.sourceTitle.trim();

    if (id.isEmpty ||
        topicKey.isEmpty ||
        factionName.isEmpty ||
        summary.isEmpty ||
        sourceTitle.isEmpty) {
      throw ArgumentError('All legislative fact fields must be non-empty.');
    }

    final normalizedUrl = validateSourceUrl(entry.sourceUrl);
    final sanitized = LegislativeFactEntry(
      id: id,
      topicKey: topicKey,
      factionName: factionName,
      summary: summary,
      sourceUrl: normalizedUrl,
      sourceTitle: sourceTitle,
      stance: entry.stance,
    );
    _entries.add(sanitized);
    return sanitized;
  }

  /// Builds a side-by-side faction comparison matrix for [topicKey].
  LegislativeFactComparisonMatrix buildComparisonMatrix(String topicKey) {
    final target = topicKey.trim();
    final byFaction = <String, List<LegislativeFactEntry>>{};

    for (final entry in _entries) {
      if (entry.topicKey != target) {
        continue;
      }
      byFaction
          .putIfAbsent(entry.factionName, () => <LegislativeFactEntry>[])
          .add(entry);
    }

    final sortedFactions = byFaction.keys.toList()..sort();
    final columns = <FactionFactColumn>[
      for (final faction in sortedFactions)
        FactionFactColumn(
          factionName: faction,
          facts: List<LegislativeFactEntry>.unmodifiable(
            byFaction[faction]!,
          ),
        ),
    ];

    var totalFacts = 0;
    for (final col in columns) {
      totalFacts += col.facts.length;
    }

    return LegislativeFactComparisonMatrix(
      topicKey: target,
      totalFacts: totalFacts,
      columns: List<FactionFactColumn>.unmodifiable(columns),
    );
  }
}
