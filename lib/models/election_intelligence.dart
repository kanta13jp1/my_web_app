enum ElectionModeId {
  local('local', '地方選', '地方'),
  houseOfRepresentatives('house_of_representatives', '衆院選', '衆院'),
  houseOfCouncillors('house_of_councillors', '参院選', '参院');

  final String wireName;
  final String label;
  final String shortLabel;

  const ElectionModeId(this.wireName, this.label, this.shortLabel);

  static ElectionModeId fromWireName(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return ElectionModeId.values.firstWhere(
      (mode) => mode.wireName == normalized,
      orElse: () => ElectionModeId.local,
    );
  }
}

enum ElectionModeAvailability {
  active,
  registered;

  static ElectionModeAvailability fromJson(Object? value) {
    return value == 'active'
        ? ElectionModeAvailability.active
        : ElectionModeAvailability.registered;
  }
}

class ElectionModeOption {
  final ElectionModeId id;
  final String label;
  final String shortLabel;
  final ElectionModeAvailability availability;
  final String description;
  final List<String> collectors;

  const ElectionModeOption({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.availability,
    required this.description,
    this.collectors = const <String>[],
  });

  const ElectionModeOption.localFallback()
      : id = ElectionModeId.local,
        label = '地方選',
        shortLabel = '地方',
        availability = ElectionModeAvailability.active,
        description = '地方議員数、公認予定候補、地方選実績を追跡します。',
        collectors = const <String>[
          'local_members',
          'official_endorsements',
          'local_results',
        ];

  bool get isActive => availability == ElectionModeAvailability.active;

  factory ElectionModeOption.fromJson(Map<String, dynamic> json) {
    final id = ElectionModeId.fromWireName(json['id']);
    return ElectionModeOption(
      id: id,
      label: _readString(json['label'], fallback: id.label),
      shortLabel: _readString(json['shortLabel'], fallback: id.shortLabel),
      availability: ElectionModeAvailability.fromJson(json['availability']),
      description: _readString(json['description']),
      collectors: _readStringList(json['collectors']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.wireName,
        'label': label,
        'shortLabel': shortLabel,
        'availability': availability.name,
        'description': description,
        'collectors': collectors,
      };
}

enum ElectionGoalVerificationStatus {
  verified,
  sourceUnverified,
  awaitingOfficialTarget;

  static ElectionGoalVerificationStatus fromJson(Object? value) {
    switch (value) {
      case 'verified':
        return ElectionGoalVerificationStatus.verified;
      case 'awaiting_official_target':
        return ElectionGoalVerificationStatus.awaitingOfficialTarget;
      default:
        return ElectionGoalVerificationStatus.sourceUnverified;
    }
  }

  String get wireName {
    switch (this) {
      case ElectionGoalVerificationStatus.verified:
        return 'verified';
      case ElectionGoalVerificationStatus.sourceUnverified:
        return 'source_unverified';
      case ElectionGoalVerificationStatus.awaitingOfficialTarget:
        return 'awaiting_official_target';
    }
  }
}

class ElectionGoalProgress {
  final String id;
  final ElectionModeId mode;
  final String title;
  final String metric;
  final int? currentValue;
  final int? targetValue;
  final String unit;
  final String deadlineLabel;
  final String sourceUrl;
  final String sourcePublishedAt;
  final ElectionGoalVerificationStatus verificationStatus;

  const ElectionGoalProgress({
    required this.id,
    required this.mode,
    required this.title,
    required this.metric,
    required this.currentValue,
    required this.targetValue,
    required this.unit,
    required this.deadlineLabel,
    required this.sourceUrl,
    required this.sourcePublishedAt,
    required this.verificationStatus,
  });

  factory ElectionGoalProgress.fromJson(Map<String, dynamic> json) {
    return ElectionGoalProgress(
      id: _readString(json['id']),
      mode: ElectionModeId.fromWireName(json['mode']),
      title: _readString(json['title']),
      metric: _readString(json['metric']),
      currentValue: _readNullableInt(json['currentValue']),
      targetValue: _readNullableInt(json['targetValue']),
      unit: _readString(json['unit']),
      deadlineLabel: _readString(json['deadlineLabel']),
      sourceUrl: _readString(json['sourceUrl']),
      sourcePublishedAt: _readString(json['sourcePublishedAt']),
      verificationStatus:
          ElectionGoalVerificationStatus.fromJson(json['verificationStatus']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'mode': mode.wireName,
        'title': title,
        'metric': metric,
        'currentValue': currentValue,
        'targetValue': targetValue,
        'unit': unit,
        'deadlineLabel': deadlineLabel,
        'sourceUrl': sourceUrl,
        'sourcePublishedAt': sourcePublishedAt,
        'verificationStatus': verificationStatus.wireName,
      };

  bool get isVerified =>
      verificationStatus == ElectionGoalVerificationStatus.verified;

  int? get remaining {
    final current = currentValue;
    final target = targetValue;
    if (current == null || target == null) {
      return null;
    }
    final value = target - current;
    return value < 0 ? 0 : value;
  }
}

class ElectionAchievement {
  final String id;
  final ElectionModeId mode;
  final String title;
  final String metric;
  final int? value;
  final String unit;
  final String periodLabel;
  final List<String> sourceUrls;

  const ElectionAchievement({
    required this.id,
    required this.mode,
    required this.title,
    required this.metric,
    required this.value,
    required this.unit,
    required this.periodLabel,
    this.sourceUrls = const <String>[],
  });

  factory ElectionAchievement.fromJson(Map<String, dynamic> json) {
    return ElectionAchievement(
      id: _readString(json['id']),
      mode: ElectionModeId.fromWireName(json['mode']),
      title: _readString(json['title']),
      metric: _readString(json['metric']),
      value: _readNullableInt(json['value']),
      unit: _readString(json['unit']),
      periodLabel: _readString(json['periodLabel']),
      sourceUrls: _readStringList(json['sourceUrls']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'mode': mode.wireName,
        'title': title,
        'metric': metric,
        'value': value,
        'unit': unit,
        'periodLabel': periodLabel,
        'sourceUrls': sourceUrls,
      };
}

class OfficialEndorsementPrefecture {
  final String prefecture;
  final int totalCount;
  final int incumbentCount;
  final int newcomerCount;
  final int formerCount;

  const OfficialEndorsementPrefecture({
    required this.prefecture,
    required this.totalCount,
    required this.incumbentCount,
    required this.newcomerCount,
    required this.formerCount,
  });

  factory OfficialEndorsementPrefecture.fromJson(Map<String, dynamic> json) {
    return OfficialEndorsementPrefecture(
      prefecture: _readString(json['prefecture']),
      totalCount: _readInt(json['totalCount']),
      incumbentCount: _readInt(json['incumbentCount']),
      newcomerCount: _readInt(json['newcomerCount']),
      formerCount: _readInt(json['formerCount']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'prefecture': prefecture,
        'totalCount': totalCount,
        'incumbentCount': incumbentCount,
        'newcomerCount': newcomerCount,
        'formerCount': formerCount,
      };

  bool get hasBreakdown =>
      incumbentCount > 0 || newcomerCount > 0 || formerCount > 0;

  String get breakdownLabel => <String>[
        if (incumbentCount > 0) '現職$incumbentCount',
        if (newcomerCount > 0) '新人$newcomerCount',
        if (formerCount > 0) '元職$formerCount',
      ].join(' / ');
}

class OfficialEndorsementSnapshot {
  final String sourceUrl;
  final String sourceAsOf;
  final String sourceDocumentSha256;
  final int totalCount;
  final int incumbentCount;
  final int newcomerCount;
  final int formerCount;
  final int recommendationCount;
  final int prefectureCount;
  final List<OfficialEndorsementPrefecture> prefectures;

  const OfficialEndorsementSnapshot({
    required this.sourceUrl,
    required this.sourceAsOf,
    required this.sourceDocumentSha256,
    required this.totalCount,
    required this.incumbentCount,
    required this.newcomerCount,
    required this.formerCount,
    required this.recommendationCount,
    required this.prefectureCount,
    this.prefectures = const <OfficialEndorsementPrefecture>[],
  });

  const OfficialEndorsementSnapshot.empty()
      : sourceUrl = '',
        sourceAsOf = '',
        sourceDocumentSha256 = '',
        totalCount = 0,
        incumbentCount = 0,
        newcomerCount = 0,
        formerCount = 0,
        recommendationCount = 0,
        prefectureCount = 0,
        prefectures = const <OfficialEndorsementPrefecture>[];

  factory OfficialEndorsementSnapshot.fromJson(Map<String, dynamic> json) {
    return OfficialEndorsementSnapshot(
      sourceUrl: _readString(json['sourceUrl']),
      sourceAsOf: _readString(json['sourceAsOf']),
      sourceDocumentSha256: _readString(json['sourceDocumentSha256']),
      totalCount: _readInt(json['totalCount']),
      incumbentCount: _readInt(json['incumbentCount']),
      newcomerCount: _readInt(json['newcomerCount']),
      formerCount: _readInt(json['formerCount']),
      recommendationCount: _readInt(json['recommendationCount']),
      prefectureCount: _readInt(json['prefectureCount']),
      prefectures: _readMapList(json['prefectures'])
          .map(OfficialEndorsementPrefecture.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sourceUrl': sourceUrl,
        'sourceAsOf': sourceAsOf,
        'sourceDocumentSha256': sourceDocumentSha256,
        'totalCount': totalCount,
        'incumbentCount': incumbentCount,
        'newcomerCount': newcomerCount,
        'formerCount': formerCount,
        'recommendationCount': recommendationCount,
        'prefectureCount': prefectureCount,
        'prefectures': prefectures.map((item) => item.toJson()).toList(),
      };

  bool get hasData => totalCount > 0;

  OfficialEndorsementPrefecture? forPrefecture(String prefecture) {
    final normalized = prefecture.replaceFirst(RegExp(r'[都府県]$'), '');
    for (final item in prefectures) {
      if (item.prefecture == normalized) {
        return item;
      }
    }
    return null;
  }
}

class ElectionIntelligenceSnapshot {
  final int schemaVersion;
  final ElectionModeId selectedMode;
  final List<ElectionModeOption> modes;
  final List<ElectionGoalProgress> goals;
  final List<ElectionAchievement> achievements;
  final OfficialEndorsementSnapshot officialEndorsements;

  const ElectionIntelligenceSnapshot({
    required this.schemaVersion,
    required this.selectedMode,
    required this.modes,
    required this.goals,
    required this.achievements,
    required this.officialEndorsements,
  });

  const ElectionIntelligenceSnapshot.localFallback()
      : schemaVersion = 1,
        selectedMode = ElectionModeId.local,
        modes = const <ElectionModeOption>[
          ElectionModeOption.localFallback(),
          ElectionModeOption(
            id: ElectionModeId.houseOfRepresentatives,
            label: '衆院選',
            shortLabel: '衆院',
            availability: ElectionModeAvailability.registered,
            description: '公式目標と候補者ソースの確定後に有効化します。',
          ),
          ElectionModeOption(
            id: ElectionModeId.houseOfCouncillors,
            label: '参院選',
            shortLabel: '参院',
            availability: ElectionModeAvailability.registered,
            description: '公式目標と候補者ソースの確定後に有効化します。',
          ),
        ],
        goals = const <ElectionGoalProgress>[],
        achievements = const <ElectionAchievement>[],
        officialEndorsements = const OfficialEndorsementSnapshot.empty();

  factory ElectionIntelligenceSnapshot.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return const ElectionIntelligenceSnapshot.localFallback();
    }
    return ElectionIntelligenceSnapshot(
      schemaVersion: _readInt(json['schemaVersion'], fallback: 1),
      selectedMode: ElectionModeId.fromWireName(json['selectedMode']),
      modes: _readMapList(json['modes'])
          .map(ElectionModeOption.fromJson)
          .toList(growable: false),
      goals: _readMapList(json['goals'])
          .map(ElectionGoalProgress.fromJson)
          .toList(growable: false),
      achievements: _readMapList(json['achievements'])
          .map(ElectionAchievement.fromJson)
          .toList(growable: false),
      officialEndorsements: OfficialEndorsementSnapshot.fromJson(
        _readMap(json['officialEndorsements']),
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'selectedMode': selectedMode.wireName,
        'modes': modes.map((item) => item.toJson()).toList(),
        'goals': goals.map((item) => item.toJson()).toList(),
        'achievements': achievements.map((item) => item.toJson()).toList(),
        'officialEndorsements': officialEndorsements.toJson(),
      };

  ElectionModeOption? get selectedModeOption {
    for (final mode in modes) {
      if (mode.id == selectedMode) {
        return mode;
      }
    }
    return null;
  }
}

String _readString(Object? value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _readNullableInt(Object? value) {
  if (value == null || value == '') {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic> _readMap(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

List<Map<String, dynamic>> _readMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
