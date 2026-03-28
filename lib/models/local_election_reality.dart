class LocalElectionRealitySource {
  final String label;
  final String url;
  final String category;
  final String note;

  const LocalElectionRealitySource({
    required this.label,
    required this.url,
    required this.category,
    this.note = '',
  });

  factory LocalElectionRealitySource.fromJson(Map<String, dynamic> json) {
    return LocalElectionRealitySource(
      label: (json['label'] as String? ?? '').trim(),
      url: (json['url'] as String? ?? '').trim(),
      category: (json['category'] as String? ?? '').trim(),
      note: (json['note'] as String? ?? '').trim(),
    );
  }

  Map<String, String> toJson() {
    return <String, String>{
      'label': label,
      'url': url,
      'category': category,
      'note': note,
    };
  }
}

class LocalElectionPrefectureReality {
  final String prefecture;
  final String sourceUrl;
  final int currentMembers;
  final int prefecturalAssemblyMembers;
  final int municipalAssemblyMembers;

  const LocalElectionPrefectureReality({
    required this.prefecture,
    required this.sourceUrl,
    required this.currentMembers,
    required this.prefecturalAssemblyMembers,
    required this.municipalAssemblyMembers,
  });

  factory LocalElectionPrefectureReality.fromJson(Map<String, dynamic> json) {
    return LocalElectionPrefectureReality(
      prefecture: (json['prefecture'] as String? ?? '').trim(),
      sourceUrl: (json['sourceUrl'] as String? ?? '').trim(),
      currentMembers: _readInt(json['currentMembers']),
      prefecturalAssemblyMembers: _readInt(json['prefecturalAssemblyMembers']),
      municipalAssemblyMembers: _readInt(json['municipalAssemblyMembers']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'prefecture': prefecture,
      'sourceUrl': sourceUrl,
      'currentMembers': currentMembers,
      'prefecturalAssemblyMembers': prefecturalAssemblyMembers,
      'municipalAssemblyMembers': municipalAssemblyMembers,
    };
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }
}

class LocalElectionRealitySnapshot {
  final DateTime fetchedAt;
  final int baselineCurrentLocalMembers;
  final int officialCurrentLocalMembers;
  final int targetLocalMembers;
  final int baselineNetIncreaseRequired;
  final int actualNetIncreaseRequired;
  final int official2023FirstHalfWins;
  final int official2023SecondHalfWins;
  final int official2023TotalWins;
  final String aiSummary;
  final List<String> aiAlerts;
  final List<String> aiStrategicNotes;
  final List<LocalElectionRealitySource> sources;
  final List<LocalElectionPrefectureReality> prefectures;

  const LocalElectionRealitySnapshot({
    required this.fetchedAt,
    required this.baselineCurrentLocalMembers,
    required this.officialCurrentLocalMembers,
    required this.targetLocalMembers,
    required this.baselineNetIncreaseRequired,
    required this.actualNetIncreaseRequired,
    required this.official2023FirstHalfWins,
    required this.official2023SecondHalfWins,
    required this.official2023TotalWins,
    required this.aiSummary,
    required this.aiAlerts,
    required this.aiStrategicNotes,
    required this.sources,
    required this.prefectures,
  });

  LocalElectionRealitySnapshot.empty()
      : fetchedAt = DateTime.fromMillisecondsSinceEpoch(0),
        baselineCurrentLocalMembers = 340,
        officialCurrentLocalMembers = 0,
        targetLocalMembers = 700,
        baselineNetIncreaseRequired = 360,
        actualNetIncreaseRequired = 700,
        official2023FirstHalfWins = 62,
        official2023SecondHalfWins = 121,
        official2023TotalWins = 183,
        aiSummary = '',
        aiAlerts = const <String>[],
        aiStrategicNotes = const <String>[],
        sources = const <LocalElectionRealitySource>[],
        prefectures = const <LocalElectionPrefectureReality>[];

  factory LocalElectionRealitySnapshot.fromJson(Map<String, dynamic> json) {
    return LocalElectionRealitySnapshot(
      fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      baselineCurrentLocalMembers: _readInt(
        json['baselineCurrentLocalMembers'],
        fallback: 340,
      ),
      officialCurrentLocalMembers: _readInt(
        json['officialCurrentLocalMembers'],
      ),
      targetLocalMembers: _readInt(json['targetLocalMembers'], fallback: 700),
      baselineNetIncreaseRequired: _readInt(
        json['baselineNetIncreaseRequired'],
        fallback: 360,
      ),
      actualNetIncreaseRequired: _readInt(
        json['actualNetIncreaseRequired'],
        fallback: 700,
      ),
      official2023FirstHalfWins: _readInt(
        json['official2023FirstHalfWins'],
        fallback: 62,
      ),
      official2023SecondHalfWins: _readInt(
        json['official2023SecondHalfWins'],
        fallback: 121,
      ),
      official2023TotalWins: _readInt(
        json['official2023TotalWins'],
        fallback: 183,
      ),
      aiSummary: (json['aiSummary'] as String? ?? '').trim(),
      aiAlerts: _readStringList(json['aiAlerts']),
      aiStrategicNotes: _readStringList(json['aiStrategicNotes']),
      sources: _readSources(json['sources']),
      prefectures: _readPrefectures(json['prefectures']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fetchedAt': fetchedAt.toIso8601String(),
      'baselineCurrentLocalMembers': baselineCurrentLocalMembers,
      'officialCurrentLocalMembers': officialCurrentLocalMembers,
      'targetLocalMembers': targetLocalMembers,
      'baselineNetIncreaseRequired': baselineNetIncreaseRequired,
      'actualNetIncreaseRequired': actualNetIncreaseRequired,
      'official2023FirstHalfWins': official2023FirstHalfWins,
      'official2023SecondHalfWins': official2023SecondHalfWins,
      'official2023TotalWins': official2023TotalWins,
      'aiSummary': aiSummary,
      'aiAlerts': aiAlerts,
      'aiStrategicNotes': aiStrategicNotes,
      'sources': sources.map((item) => item.toJson()).toList(),
      'prefectures': prefectures.map((item) => item.toJson()).toList(),
    };
  }

  bool get hasData => officialCurrentLocalMembers > 0;

  int get deltaFromBaseline =>
      officialCurrentLocalMembers - baselineCurrentLocalMembers;

  bool get isStale {
    if (!hasData) {
      return true;
    }
    return DateTime.now().difference(fetchedAt) > const Duration(hours: 12);
  }

  List<LocalElectionPrefectureReality> topPrefectures({int limit = 10}) {
    final sorted = List<LocalElectionPrefectureReality>.from(prefectures)
      ..sort((a, b) {
        final countCompare = b.currentMembers.compareTo(a.currentMembers);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.prefecture.compareTo(b.prefecture);
      });
    return sorted.take(limit).toList();
  }

  static int _readInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? fallback;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<LocalElectionRealitySource> _readSources(Object? value) {
    if (value is! List) {
      return const <LocalElectionRealitySource>[];
    }
    return value.whereType<Map>().map((item) {
      return LocalElectionRealitySource.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }

  static List<LocalElectionPrefectureReality> _readPrefectures(Object? value) {
    if (value is! List) {
      return const <LocalElectionPrefectureReality>[];
    }
    return value.whereType<Map>().map((item) {
      return LocalElectionPrefectureReality.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }
}
