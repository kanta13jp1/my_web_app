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

class LocalElectionLegislatorProfile {
  final String prefecture;
  final String sourceUrl;
  final String detailUrl;
  final String name;
  final String kana;
  final String constituency;
  final String municipality;
  final String assemblyLabel;
  final String assemblyCategory;
  final String electionCountLabel;
  final String birthDate;
  final int? age;
  final String gender;
  final String profile;

  const LocalElectionLegislatorProfile({
    required this.prefecture,
    required this.sourceUrl,
    required this.detailUrl,
    required this.name,
    required this.kana,
    required this.constituency,
    required this.municipality,
    required this.assemblyLabel,
    required this.assemblyCategory,
    required this.electionCountLabel,
    this.birthDate = '',
    this.age,
    this.gender = '',
    this.profile = '',
  });

  factory LocalElectionLegislatorProfile.fromJson(Map<String, dynamic> json) {
    return LocalElectionLegislatorProfile(
      prefecture: (json['prefecture'] as String? ?? '').trim(),
      sourceUrl: (json['sourceUrl'] as String? ?? '').trim(),
      detailUrl: (json['detailUrl'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      kana: (json['kana'] as String? ?? '').trim(),
      constituency: (json['constituency'] as String? ?? '').trim(),
      municipality: (json['municipality'] as String? ?? '').trim(),
      assemblyLabel: (json['assemblyLabel'] as String? ?? '').trim(),
      assemblyCategory: (json['assemblyCategory'] as String? ?? '').trim(),
      electionCountLabel: (json['electionCountLabel'] as String? ?? '').trim(),
      birthDate: (json['birthDate'] as String? ?? '').trim(),
      age: _readNullableInt(json['age']),
      gender: (json['gender'] as String? ?? '').trim(),
      profile: (json['profile'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'prefecture': prefecture,
      'sourceUrl': sourceUrl,
      'detailUrl': detailUrl,
      'name': name,
      'kana': kana,
      'constituency': constituency,
      'municipality': municipality,
      'assemblyLabel': assemblyLabel,
      'assemblyCategory': assemblyCategory,
      'electionCountLabel': electionCountLabel,
      'birthDate': birthDate,
      'age': age,
      'gender': gender,
      'profile': profile,
    };
  }

  bool get hasDetailedProfile =>
      birthDate.isNotEmpty ||
      age != null ||
      gender.isNotEmpty ||
      profile.isNotEmpty;

  LocalElectionLegislatorProfile copyWith({
    String? prefecture,
    String? sourceUrl,
    String? detailUrl,
    String? name,
    String? kana,
    String? constituency,
    String? municipality,
    String? assemblyLabel,
    String? assemblyCategory,
    String? electionCountLabel,
    String? birthDate,
    int? age,
    bool clearAge = false,
    String? gender,
    String? profile,
  }) {
    return LocalElectionLegislatorProfile(
      prefecture: prefecture ?? this.prefecture,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      detailUrl: detailUrl ?? this.detailUrl,
      name: name ?? this.name,
      kana: kana ?? this.kana,
      constituency: constituency ?? this.constituency,
      municipality: municipality ?? this.municipality,
      assemblyLabel: assemblyLabel ?? this.assemblyLabel,
      assemblyCategory: assemblyCategory ?? this.assemblyCategory,
      electionCountLabel: electionCountLabel ?? this.electionCountLabel,
      birthDate: birthDate ?? this.birthDate,
      age: clearAge ? null : (age ?? this.age),
      gender: gender ?? this.gender,
      profile: profile ?? this.profile,
    );
  }

  LocalElectionLegislatorProfile mergeWith(
    LocalElectionLegislatorProfile? override,
  ) {
    if (override == null) {
      return this;
    }
    return LocalElectionLegislatorProfile(
      prefecture:
          override.prefecture.isNotEmpty ? override.prefecture : prefecture,
      sourceUrl: override.sourceUrl.isNotEmpty ? override.sourceUrl : sourceUrl,
      detailUrl: override.detailUrl.isNotEmpty ? override.detailUrl : detailUrl,
      name: override.name.isNotEmpty ? override.name : name,
      kana: override.kana.isNotEmpty ? override.kana : kana,
      constituency: override.constituency.isNotEmpty
          ? override.constituency
          : constituency,
      municipality: override.municipality.isNotEmpty
          ? override.municipality
          : municipality,
      assemblyLabel: override.assemblyLabel.isNotEmpty
          ? override.assemblyLabel
          : assemblyLabel,
      assemblyCategory: override.assemblyCategory.isNotEmpty
          ? override.assemblyCategory
          : assemblyCategory,
      electionCountLabel: override.electionCountLabel.isNotEmpty
          ? override.electionCountLabel
          : electionCountLabel,
      birthDate: override.birthDate.isNotEmpty ? override.birthDate : birthDate,
      age: override.age ?? age,
      gender: override.gender.isNotEmpty ? override.gender : gender,
      profile: override.profile.isNotEmpty ? override.profile : profile,
    );
  }

  bool matchesQuery(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    final haystack = <String>[
      prefecture,
      name,
      kana,
      constituency,
      municipality,
      assemblyLabel,
      electionCountLabel,
      gender,
      profile,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  static int? _readNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value');
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

class LocalElectionScheduleEntry {
  final String electionName;
  final String prefecture;
  final String municipality;
  final String electionCategory;
  final String voteDate;
  final String announcementDate;
  final String detailUrl;
  final String officialCandidateSourceUrl;
  final int seatCount;
  final int totalCandidateCount;
  final int kokuminCandidateCount;
  final List<String> kokuminCandidateNames;
  final List<String> kokuminCandidateStatuses;
  final List<String> kokuminCandidateXHandles;
  final bool isPast;

  const LocalElectionScheduleEntry({
    required this.electionName,
    required this.prefecture,
    required this.municipality,
    required this.electionCategory,
    required this.voteDate,
    required this.announcementDate,
    required this.detailUrl,
    required this.officialCandidateSourceUrl,
    required this.seatCount,
    required this.totalCandidateCount,
    required this.kokuminCandidateCount,
    required this.kokuminCandidateNames,
    required this.kokuminCandidateStatuses,
    required this.kokuminCandidateXHandles,
    this.isPast = false,
  });

  factory LocalElectionScheduleEntry.fromJson(Map<String, dynamic> json) {
    return LocalElectionScheduleEntry(
      electionName: (json['electionName'] as String? ?? '').trim(),
      prefecture: (json['prefecture'] as String? ?? '').trim(),
      municipality: (json['municipality'] as String? ?? '').trim(),
      electionCategory: (json['electionCategory'] as String? ?? '').trim(),
      voteDate: (json['voteDate'] as String? ?? '').trim(),
      announcementDate: (json['announcementDate'] as String? ?? '').trim(),
      detailUrl: (json['detailUrl'] as String? ?? '').trim(),
      officialCandidateSourceUrl:
          (json['officialCandidateSourceUrl'] as String? ?? '').trim(),
      seatCount: _readInt(json['seatCount']),
      totalCandidateCount: _readInt(json['totalCandidateCount']),
      kokuminCandidateCount: _readInt(json['kokuminCandidateCount']),
      kokuminCandidateNames: _readStringList(json['kokuminCandidateNames']),
      kokuminCandidateStatuses:
          _readStringList(json['kokuminCandidateStatuses']),
      kokuminCandidateXHandles:
          _readStringList(json['kokuminCandidateXHandles']),
      isPast: (json['isPast'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'electionName': electionName,
      'prefecture': prefecture,
      'municipality': municipality,
      'electionCategory': electionCategory,
      'voteDate': voteDate,
      'announcementDate': announcementDate,
      'detailUrl': detailUrl,
      'officialCandidateSourceUrl': officialCandidateSourceUrl,
      'seatCount': seatCount,
      'totalCandidateCount': totalCandidateCount,
      'kokuminCandidateCount': kokuminCandidateCount,
      'kokuminCandidateNames': kokuminCandidateNames,
      'kokuminCandidateStatuses': kokuminCandidateStatuses,
      'kokuminCandidateXHandles': kokuminCandidateXHandles,
      'isPast': isPast,
    };
  }

  bool get isAlertRed => kokuminCandidateCount == 0;

  bool get isAlertYellow => kokuminCandidateCount == 1;

  DateTime? get parsedVoteDate => _parseDate(voteDate);

  bool isWithinDays(int days) {
    if (isPast) return false;
    final date = parsedVoteDate;
    if (date == null) {
      return false;
    }
    final today = DateTime.now();
    final localDate = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    return !localDate.isBefore(todayDate) &&
        localDate.difference(todayDate).inDays <= days;
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

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static DateTime? _parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value) ??
        DateTime.tryParse(value.replaceAll('/', '-'));
  }
}

class PastElectionCandidate {
  final String name;
  final String status;
  final int votes;

  const PastElectionCandidate({
    required this.name,
    required this.status,
    this.votes = 0,
  });

  factory PastElectionCandidate.fromJson(Map<String, dynamic> json) {
    return PastElectionCandidate(
      name: (json['name'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      votes: _readInt(json['votes']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'status': status,
      'votes': votes,
    };
  }

  bool get isWin => status.contains('当選');

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

class PastElectionResult {
  final int id;
  final String electionName;
  final String date;
  final String location;
  final List<PastElectionCandidate> dppCandidates;

  const PastElectionResult({
    required this.id,
    required this.electionName,
    required this.date,
    required this.location,
    required this.dppCandidates,
  });

  factory PastElectionResult.fromJson(Map<String, dynamic> json) {
    final candidates = json['dppCandidates'];
    return PastElectionResult(
      id: _readInt(json['id']),
      electionName: (json['electionName'] as String? ?? '').trim(),
      date: (json['date'] as String? ?? '').trim(),
      location: (json['location'] as String? ?? '').trim(),
      dppCandidates: (candidates is List)
          ? candidates.whereType<Map>().map((item) {
              return PastElectionCandidate.fromJson(
                Map<String, dynamic>.from(item),
              );
            }).toList()
          : const <PastElectionCandidate>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'electionName': electionName,
      'date': date,
      'location': location,
      'dppCandidates': dppCandidates.map((c) => c.toJson()).toList(),
    };
  }

  int get winCount => dppCandidates.where((c) => c.isWin).length;
  int get totalCount => dppCandidates.length;

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

class LocalElectionRealityHistoryPoint {
  final DateTime fetchedAt;
  final int officialCurrentLocalMembers;
  final int actualNetIncreaseRequired;

  const LocalElectionRealityHistoryPoint({
    required this.fetchedAt,
    required this.officialCurrentLocalMembers,
    required this.actualNetIncreaseRequired,
  });

  factory LocalElectionRealityHistoryPoint.fromJson(
    Map<String, dynamic> json,
  ) {
    return LocalElectionRealityHistoryPoint(
      fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      officialCurrentLocalMembers:
          _readHistoryInt(json['officialCurrentLocalMembers']),
      actualNetIncreaseRequired:
          _readHistoryInt(json['actualNetIncreaseRequired']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fetchedAt': fetchedAt.toIso8601String(),
      'officialCurrentLocalMembers': officialCurrentLocalMembers,
      'actualNetIncreaseRequired': actualNetIncreaseRequired,
    };
  }

  static int _readHistoryInt(Object? value) {
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
  final String scheduleAiSummary;
  final List<String> scheduleAiAlerts;
  final List<LocalElectionRealitySource> sources;
  final List<LocalElectionPrefectureReality> prefectures;
  final List<LocalElectionLegislatorProfile> members;
  final List<LocalElectionScheduleEntry> upcomingSchedules;
  final List<PastElectionResult> pastElectionResults;

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
    required this.scheduleAiSummary,
    required this.scheduleAiAlerts,
    required this.sources,
    required this.prefectures,
    required this.members,
    required this.upcomingSchedules,
    this.pastElectionResults = const <PastElectionResult>[],
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
        scheduleAiSummary = '',
        scheduleAiAlerts = const <String>[],
        sources = const <LocalElectionRealitySource>[],
        prefectures = const <LocalElectionPrefectureReality>[],
        members = const <LocalElectionLegislatorProfile>[],
        upcomingSchedules = const <LocalElectionScheduleEntry>[],
        pastElectionResults = const <PastElectionResult>[];

  factory LocalElectionRealitySnapshot.fromJson(Map<String, dynamic> json) {
    return LocalElectionRealitySnapshot(
      fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      baselineCurrentLocalMembers: _readInt(
        json['baselineCurrentLocalMembers'],
        fallback: 340,
      ),
      officialCurrentLocalMembers:
          _readInt(json['officialCurrentLocalMembers']),
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
      scheduleAiSummary: (json['scheduleAiSummary'] as String? ?? '').trim(),
      scheduleAiAlerts: _readStringList(json['scheduleAiAlerts']),
      sources: _readSources(json['sources']),
      prefectures: _readPrefectures(json['prefectures']),
      members: _readMembers(json['members']),
      upcomingSchedules: _readSchedules(json['upcomingSchedules']),
      pastElectionResults: _readPastResults(json['pastElectionResults']),
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
      'scheduleAiSummary': scheduleAiSummary,
      'scheduleAiAlerts': scheduleAiAlerts,
      'sources': sources.map((item) => item.toJson()).toList(),
      'prefectures': prefectures.map((item) => item.toJson()).toList(),
      'members': members.map((item) => item.toJson()).toList(),
      'upcomingSchedules':
          upcomingSchedules.map((item) => item.toJson()).toList(),
      'pastElectionResults':
          pastElectionResults.map((item) => item.toJson()).toList(),
    };
  }

  bool get hasData => officialCurrentLocalMembers > 0;

  int get deltaFromBaseline =>
      officialCurrentLocalMembers - baselineCurrentLocalMembers;

  int get rosterCount => members.length;

  int get detailedProfileCount =>
      members.where((item) => item.hasDetailedProfile).length;

  int get ageAvailableCount => members.where((item) => item.age != null).length;

  bool get hasScheduleData => upcomingSchedules.isNotEmpty;

  int get redAlertScheduleCount => upcomingSchedules
      .where((item) => !item.isPast && item.isAlertRed)
      .length;

  int get yellowAlertScheduleCount => upcomingSchedules
      .where((item) => !item.isPast && item.isAlertYellow)
      .length;

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

  List<LocalElectionLegislatorProfile> membersForPrefecture(String prefecture) {
    final normalized = prefecture.trim();
    if (normalized.isEmpty || normalized == 'すべて') {
      return List<LocalElectionLegislatorProfile>.from(members);
    }
    return members
        .where((item) => item.prefecture.trim() == normalized)
        .toList();
  }

  List<LocalElectionScheduleEntry> schedulesWithinDays(int days) {
    return upcomingSchedules.where((item) => item.isWithinDays(days)).toList();
  }

  List<LocalElectionScheduleEntry> topScheduleAlerts({int limit = 8}) {
    final sorted = List<LocalElectionScheduleEntry>.from(upcomingSchedules)
      ..sort((left, right) {
        final severityCompare = _scheduleSeverity(left).compareTo(
          _scheduleSeverity(right),
        );
        if (severityCompare != 0) {
          return severityCompare;
        }
        final leftDate = left.parsedVoteDate;
        final rightDate = right.parsedVoteDate;
        if (leftDate != null && rightDate != null) {
          final dateCompare = leftDate.compareTo(rightDate);
          if (dateCompare != 0) {
            return dateCompare;
          }
        }
        return left.electionName.compareTo(right.electionName);
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

  static List<LocalElectionLegislatorProfile> _readMembers(Object? value) {
    if (value is! List) {
      return const <LocalElectionLegislatorProfile>[];
    }
    return value.whereType<Map>().map((item) {
      return LocalElectionLegislatorProfile.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }

  static List<LocalElectionScheduleEntry> _readSchedules(Object? value) {
    if (value is! List) {
      return const <LocalElectionScheduleEntry>[];
    }
    return value.whereType<Map>().map((item) {
      return LocalElectionScheduleEntry.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }

  static List<PastElectionResult> _readPastResults(Object? value) {
    if (value is! List) {
      return const <PastElectionResult>[];
    }
    return value.whereType<Map>().map((item) {
      return PastElectionResult.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  static int _scheduleSeverity(LocalElectionScheduleEntry entry) {
    if (entry.isAlertRed) {
      return 0;
    }
    if (entry.isAlertYellow) {
      return 1;
    }
    return 2;
  }
}
