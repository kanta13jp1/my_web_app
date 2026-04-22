import 'dart:math' as math;

class LocalElectionPrefecturePlan {
  final String prefecture;
  final String region;
  final int additionalSeatTarget;
  final int incumbentRetentionTarget;
  final int focusMunicipalityCount;
  final int newCandidateTarget;
  final String endorsementDeadlineMonth;
  final int closeRaceSupportRounds;
  final int currentMembers;
  final int scheduledElectionCount;
  final int announcedCandidateCount;
  final int confirmedCandidateCount;
  final int cdpLocalMembers;
  final String cdpSourceUrl;
  final String prefectureChairName;
  final String prefectureSecretaryGeneralName;
  final String prefectureOfficerSourceUrl;
  final String autoUpdatedAt;
  final bool endorsementConfirmed;
  final String notes;

  const LocalElectionPrefecturePlan({
    required this.prefecture,
    required this.region,
    required this.additionalSeatTarget,
    required this.incumbentRetentionTarget,
    required this.focusMunicipalityCount,
    required this.newCandidateTarget,
    required this.endorsementDeadlineMonth,
    required this.closeRaceSupportRounds,
    this.currentMembers = 0,
    this.scheduledElectionCount = 0,
    this.announcedCandidateCount = 0,
    this.confirmedCandidateCount = 0,
    this.cdpLocalMembers = 0,
    this.cdpSourceUrl = '',
    this.prefectureChairName = '',
    this.prefectureSecretaryGeneralName = '',
    this.prefectureOfficerSourceUrl = '',
    this.autoUpdatedAt = '',
    this.endorsementConfirmed = false,
    this.notes = '',
  });

  factory LocalElectionPrefecturePlan.fromJson(Map<String, dynamic> json) {
    return LocalElectionPrefecturePlan(
      prefecture: (json['prefecture'] as String? ?? '').trim(),
      region: (json['region'] as String? ?? '').trim(),
      additionalSeatTarget: _readInt(json['additionalSeatTarget']),
      incumbentRetentionTarget: _readInt(json['incumbentRetentionTarget']),
      focusMunicipalityCount: _readInt(json['focusMunicipalityCount']),
      newCandidateTarget: _readInt(json['newCandidateTarget']),
      endorsementDeadlineMonth:
          (json['endorsementDeadlineMonth'] as String? ?? '2026-10').trim(),
      closeRaceSupportRounds: _readInt(json['closeRaceSupportRounds']),
      currentMembers: _readInt(json['currentMembers']),
      scheduledElectionCount: _readInt(json['scheduledElectionCount']),
      announcedCandidateCount: _readInt(json['announcedCandidateCount']),
      confirmedCandidateCount: _readInt(json['confirmedCandidateCount']),
      cdpLocalMembers: _readInt(json['cdpLocalMembers']),
      cdpSourceUrl: (json['cdpSourceUrl'] as String? ?? '').trim(),
      prefectureChairName:
          (json['prefectureChairName'] as String? ?? '').trim(),
      prefectureSecretaryGeneralName:
          (json['prefectureSecretaryGeneralName'] as String? ?? '').trim(),
      prefectureOfficerSourceUrl:
          (json['prefectureOfficerSourceUrl'] as String? ?? '').trim(),
      autoUpdatedAt: (json['autoUpdatedAt'] as String? ?? '').trim(),
      endorsementConfirmed: json['endorsementConfirmed'] == true,
      notes: (json['notes'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'prefecture': prefecture,
      'region': region,
      'additionalSeatTarget': additionalSeatTarget,
      'incumbentRetentionTarget': incumbentRetentionTarget,
      'focusMunicipalityCount': focusMunicipalityCount,
      'newCandidateTarget': newCandidateTarget,
      'endorsementDeadlineMonth': endorsementDeadlineMonth,
      'closeRaceSupportRounds': closeRaceSupportRounds,
      'currentMembers': currentMembers,
      'scheduledElectionCount': scheduledElectionCount,
      'announcedCandidateCount': announcedCandidateCount,
      'confirmedCandidateCount': confirmedCandidateCount,
      'cdpLocalMembers': cdpLocalMembers,
      'cdpSourceUrl': cdpSourceUrl,
      'prefectureChairName': prefectureChairName,
      'prefectureSecretaryGeneralName': prefectureSecretaryGeneralName,
      'prefectureOfficerSourceUrl': prefectureOfficerSourceUrl,
      'autoUpdatedAt': autoUpdatedAt,
      'endorsementConfirmed': endorsementConfirmed,
      'notes': notes,
    };
  }

  LocalElectionPrefecturePlan copyWith({
    String? prefecture,
    String? region,
    int? additionalSeatTarget,
    int? incumbentRetentionTarget,
    int? focusMunicipalityCount,
    int? newCandidateTarget,
    String? endorsementDeadlineMonth,
    int? closeRaceSupportRounds,
    int? currentMembers,
    int? scheduledElectionCount,
    int? announcedCandidateCount,
    int? confirmedCandidateCount,
    int? cdpLocalMembers,
    String? cdpSourceUrl,
    String? prefectureChairName,
    String? prefectureSecretaryGeneralName,
    String? prefectureOfficerSourceUrl,
    String? autoUpdatedAt,
    bool? endorsementConfirmed,
    String? notes,
  }) {
    return LocalElectionPrefecturePlan(
      prefecture: prefecture ?? this.prefecture,
      region: region ?? this.region,
      additionalSeatTarget: additionalSeatTarget ?? this.additionalSeatTarget,
      incumbentRetentionTarget:
          incumbentRetentionTarget ?? this.incumbentRetentionTarget,
      focusMunicipalityCount:
          focusMunicipalityCount ?? this.focusMunicipalityCount,
      newCandidateTarget: newCandidateTarget ?? this.newCandidateTarget,
      endorsementDeadlineMonth:
          endorsementDeadlineMonth ?? this.endorsementDeadlineMonth,
      closeRaceSupportRounds:
          closeRaceSupportRounds ?? this.closeRaceSupportRounds,
      currentMembers: currentMembers ?? this.currentMembers,
      scheduledElectionCount:
          scheduledElectionCount ?? this.scheduledElectionCount,
      announcedCandidateCount:
          announcedCandidateCount ?? this.announcedCandidateCount,
      confirmedCandidateCount:
          confirmedCandidateCount ?? this.confirmedCandidateCount,
      cdpLocalMembers: cdpLocalMembers ?? this.cdpLocalMembers,
      cdpSourceUrl: cdpSourceUrl ?? this.cdpSourceUrl,
      prefectureChairName: prefectureChairName ?? this.prefectureChairName,
      prefectureSecretaryGeneralName:
          prefectureSecretaryGeneralName ?? this.prefectureSecretaryGeneralName,
      prefectureOfficerSourceUrl:
          prefectureOfficerSourceUrl ?? this.prefectureOfficerSourceUrl,
      autoUpdatedAt: autoUpdatedAt ?? this.autoUpdatedAt,
      endorsementConfirmed: endorsementConfirmed ?? this.endorsementConfirmed,
      notes: notes ?? this.notes,
    );
  }

  DateTime get endorsementDeadlineDate =>
      _monthKeyToDate(endorsementDeadlineMonth);

  bool isEndorsementOverdue(DateTime now) {
    if (endorsementConfirmed) {
      return false;
    }
    final deadline = _monthEnd(endorsementDeadlineDate);
    return now.isAfter(deadline);
  }

  bool isEndorsementDueSoon(DateTime now) {
    if (endorsementConfirmed) {
      return false;
    }
    final deadline = _monthEnd(endorsementDeadlineDate);
    final days = deadline.difference(now).inDays;
    return days >= 0 && days <= 60;
  }

  int get executionLoad =>
      additionalSeatTarget +
      incumbentRetentionTarget +
      newCandidateTarget +
      closeRaceSupportRounds;

  int get cdpMemberGap => cdpLocalMembers - currentMembers;

  bool get hasCdpComparison => cdpLocalMembers > 0;

  bool get hasPrefectureOfficerNames =>
      prefectureChairName.isNotEmpty ||
      prefectureSecretaryGeneralName.isNotEmpty;

  int get kgiTargetLocalMembers =>
      incumbentRetentionTarget + additionalSeatTarget;

  int get kgiGapMembers => math.max(0, kgiTargetLocalMembers - currentMembers);

  double get kgiProgressRatio => kgiTargetLocalMembers <= 0
      ? 0
      : (currentMembers / kgiTargetLocalMembers).clamp(0, 1).toDouble();

  String get kgiStatement => '2027統一地方選後に地方議員$kgiTargetLocalMembers人を達成';

  List<LocalElectionCsfKpi> get csfKpis => <LocalElectionCsfKpi>[
        LocalElectionCsfKpi(
          csf: '現職基盤の維持',
          kpiLabel: '現職維持対象',
          target: incumbentRetentionTarget,
          actual: math.min(currentMembers, incumbentRetentionTarget),
          unit: '人',
        ),
        LocalElectionCsfKpi(
          csf: '候補者パイプライン',
          kpiLabel: '確認済み候補者',
          target: newCandidateTarget,
          actual: announcedCandidateCount,
          unit: '人',
        ),
        LocalElectionCsfKpi(
          csf: '重点自治体攻略',
          kpiLabel: '予定選挙の捕捉',
          target: focusMunicipalityCount,
          actual: scheduledElectionCount,
          unit: '件',
        ),
        LocalElectionCsfKpi(
          csf: '公認決定の前倒し',
          kpiLabel: '公認/予定候補',
          target: newCandidateTarget,
          actual: confirmedCandidateCount,
          unit: '人',
        ),
        LocalElectionCsfKpi(
          csf: '接戦区支援の実行',
          kpiLabel: '支援ラウンド',
          target: closeRaceSupportRounds,
          actual: math.min(
            closeRaceSupportRounds,
            scheduledElectionCount + confirmedCandidateCount,
          ),
          unit: '回',
        ),
      ];

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }
}

class LocalElectionCsfKpi {
  final String csf;
  final String kpiLabel;
  final int target;
  final int actual;
  final String unit;

  const LocalElectionCsfKpi({
    required this.csf,
    required this.kpiLabel,
    required this.target,
    required this.actual,
    required this.unit,
  });

  int get remaining => math.max(0, target - actual);

  double get progressRatio =>
      target <= 0 ? 0 : (actual / target).clamp(0, 1).toDouble();

  String get compactLabel => '$csf: $kpiLabel $actual/$target$unit';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'csf': csf,
      'kpiLabel': kpiLabel,
      'target': target,
      'actual': actual,
      'unit': unit,
      'remaining': remaining,
      'progressRatio': progressRatio,
    };
  }
}

class LocalElectionMonthlyCheckpoint {
  final String monthKey;
  final int cumulativeIncumbentRetentionTarget;
  final int cumulativeFocusMunicipalityCount;
  final int cumulativeNewCandidateTarget;
  final int endorsementsDueThisMonth;
  final int cumulativeEndorsementsDue;
  final int cumulativeCloseRaceSupportRounds;

  const LocalElectionMonthlyCheckpoint({
    required this.monthKey,
    required this.cumulativeIncumbentRetentionTarget,
    required this.cumulativeFocusMunicipalityCount,
    required this.cumulativeNewCandidateTarget,
    required this.endorsementsDueThisMonth,
    required this.cumulativeEndorsementsDue,
    required this.cumulativeCloseRaceSupportRounds,
  });

  String get label {
    final parts = monthKey.split('-');
    if (parts.length != 2) {
      return monthKey;
    }
    return '${parts[0]}/${parts[1]}';
  }
}

class LocalElectionPlanDashboard {
  final int currentLocalMembers;
  final int targetLocalMembers;
  final int previousUnifiedElectionWins;
  final int previousUnifiedElectionFirstHalfWins;
  final int previousUnifiedElectionSecondHalfWins;
  final DateTime updatedAt;
  final List<LocalElectionPrefecturePlan> prefectures;

  const LocalElectionPlanDashboard({
    required this.currentLocalMembers,
    required this.targetLocalMembers,
    required this.previousUnifiedElectionWins,
    required this.previousUnifiedElectionFirstHalfWins,
    required this.previousUnifiedElectionSecondHalfWins,
    required this.updatedAt,
    required this.prefectures,
  });

  factory LocalElectionPlanDashboard.fromJson(Map<String, dynamic> json) {
    final rawPrefectures = json['prefectures'];
    final prefectures = <LocalElectionPrefecturePlan>[];
    if (rawPrefectures is List) {
      for (final item in rawPrefectures) {
        if (item is! Map) {
          continue;
        }
        prefectures.add(
          LocalElectionPrefecturePlan.fromJson(
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }

    return LocalElectionPlanDashboard(
      currentLocalMembers: _readInt(json['currentLocalMembers'], fallback: 340),
      targetLocalMembers: _readInt(json['targetLocalMembers'], fallback: 700),
      previousUnifiedElectionWins:
          _readInt(json['previousUnifiedElectionWins'], fallback: 183),
      previousUnifiedElectionFirstHalfWins: _readInt(
        json['previousUnifiedElectionFirstHalfWins'],
        fallback: 62,
      ),
      previousUnifiedElectionSecondHalfWins: _readInt(
        json['previousUnifiedElectionSecondHalfWins'],
        fallback: 121,
      ),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      prefectures: prefectures,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'currentLocalMembers': currentLocalMembers,
      'targetLocalMembers': targetLocalMembers,
      'previousUnifiedElectionWins': previousUnifiedElectionWins,
      'previousUnifiedElectionFirstHalfWins':
          previousUnifiedElectionFirstHalfWins,
      'previousUnifiedElectionSecondHalfWins':
          previousUnifiedElectionSecondHalfWins,
      'updatedAt': updatedAt.toIso8601String(),
      'prefectures': prefectures.map((item) => item.toJson()).toList(),
    };
  }

  LocalElectionPlanDashboard copyWith({
    int? currentLocalMembers,
    int? targetLocalMembers,
    int? previousUnifiedElectionWins,
    int? previousUnifiedElectionFirstHalfWins,
    int? previousUnifiedElectionSecondHalfWins,
    DateTime? updatedAt,
    List<LocalElectionPrefecturePlan>? prefectures,
  }) {
    return LocalElectionPlanDashboard(
      currentLocalMembers: currentLocalMembers ?? this.currentLocalMembers,
      targetLocalMembers: targetLocalMembers ?? this.targetLocalMembers,
      previousUnifiedElectionWins:
          previousUnifiedElectionWins ?? this.previousUnifiedElectionWins,
      previousUnifiedElectionFirstHalfWins:
          previousUnifiedElectionFirstHalfWins ??
              this.previousUnifiedElectionFirstHalfWins,
      previousUnifiedElectionSecondHalfWins:
          previousUnifiedElectionSecondHalfWins ??
              this.previousUnifiedElectionSecondHalfWins,
      updatedAt: updatedAt ?? this.updatedAt,
      prefectures: prefectures ?? this.prefectures,
    );
  }

  int get requiredNetIncrease => targetLocalMembers - currentLocalMembers;

  int get allocatedNetIncrease => prefectures.fold<int>(
        0,
        (sum, item) => sum + item.additionalSeatTarget,
      );

  int get allocationGap => requiredNetIncrease - allocatedNetIncrease;

  int get totalIncumbentRetentionTarget => prefectures.fold<int>(
        0,
        (sum, item) => sum + item.incumbentRetentionTarget,
      );

  int get totalFocusMunicipalityCount => prefectures.fold<int>(
        0,
        (sum, item) => sum + item.focusMunicipalityCount,
      );

  int get totalNewCandidateTarget => prefectures.fold<int>(
        0,
        (sum, item) => sum + item.newCandidateTarget,
      );

  int get totalCloseRaceSupportRounds => prefectures.fold<int>(
        0,
        (sum, item) => sum + item.closeRaceSupportRounds,
      );

  int get totalCdpLocalMembers => prefectures.fold<int>(
        0,
        (sum, item) => sum + item.cdpLocalMembers,
      );

  int get cdpComparisonPrefectureCount =>
      prefectures.where((item) => item.hasCdpComparison).length;

  int get cdpLeadPrefectureCount => prefectures.where((item) {
        return item.hasCdpComparison &&
            item.cdpLocalMembers > item.currentMembers;
      }).length;

  int get kokuminLeadPrefectureCount => prefectures.where((item) {
        return item.hasCdpComparison &&
            item.currentMembers >= item.cdpLocalMembers;
      }).length;

  List<LocalElectionPrefecturePlan> topCdpGapPrefectures({int limit = 8}) {
    final sorted = prefectures.where((item) => item.hasCdpComparison).toList()
      ..sort((a, b) {
        final gapCompare = b.cdpMemberGap.compareTo(a.cdpMemberGap);
        if (gapCompare != 0) {
          return gapCompare;
        }
        return b.cdpLocalMembers.compareTo(a.cdpLocalMembers);
      });
    return sorted.take(limit).toList();
  }

  int get confirmedEndorsementCount => prefectures.where((item) {
        return item.endorsementConfirmed;
      }).length;

  int overdueEndorsementCount([DateTime? now]) => prefectures.where((item) {
        return item.isEndorsementOverdue(now ?? DateTime.now());
      }).length;

  int dueSoonEndorsementCount([DateTime? now]) => prefectures.where((item) {
        return item.isEndorsementDueSoon(now ?? DateTime.now());
      }).length;

  List<String> get regionLabels {
    final labels = prefectures.map((item) => item.region).toSet().toList()
      ..sort();
    return <String>['すべて', ...labels];
  }

  List<LocalElectionPrefecturePlan> prefecturesForRegion(String region) {
    if (region == 'すべて') {
      return _sortedPrefectures(prefectures);
    }
    return _sortedPrefectures(
      prefectures.where((item) => item.region == region).toList(),
    );
  }

  List<LocalElectionPrefecturePlan> topPriorityPrefectures({int limit = 8}) {
    final sorted = _sortedPrefectures(prefectures);
    return sorted.take(limit).toList();
  }

  List<LocalElectionMonthlyCheckpoint> get monthlyCheckpoints {
    const retentionRatios = <double>[
      0.12,
      0.20,
      0.28,
      0.36,
      0.48,
      0.60,
      0.70,
      0.78,
      0.85,
      0.92,
      0.97,
      1.00,
    ];
    const focusRatios = <double>[
      0.18,
      0.30,
      0.45,
      0.60,
      0.72,
      0.84,
      0.92,
      1.00,
      1.00,
      1.00,
      1.00,
      1.00,
    ];
    const candidateRatios = <double>[
      0.10,
      0.18,
      0.28,
      0.42,
      0.58,
      0.74,
      0.86,
      0.94,
      1.00,
      1.00,
      1.00,
      1.00,
    ];
    const supportRatios = <double>[
      0.04,
      0.08,
      0.12,
      0.18,
      0.28,
      0.40,
      0.54,
      0.66,
      0.78,
      0.88,
      0.96,
      1.00,
    ];

    final checkpoints = <LocalElectionMonthlyCheckpoint>[];
    for (var index = 0; index < planningMonthKeys.length; index++) {
      final monthKey = planningMonthKeys[index];
      final endorsementsDueThisMonth = prefectures.where((item) {
        return item.endorsementDeadlineMonth == monthKey;
      }).length;
      final cumulativeEndorsementsDue = prefectures.where((item) {
        return item.endorsementDeadlineDate
            .isBefore(_monthKeyToDate(_nextMonthKey(monthKey)));
      }).length;

      checkpoints.add(
        LocalElectionMonthlyCheckpoint(
          monthKey: monthKey,
          cumulativeIncumbentRetentionTarget:
              (totalIncumbentRetentionTarget * retentionRatios[index]).round(),
          cumulativeFocusMunicipalityCount:
              (totalFocusMunicipalityCount * focusRatios[index]).round(),
          cumulativeNewCandidateTarget:
              (totalNewCandidateTarget * candidateRatios[index]).round(),
          endorsementsDueThisMonth: endorsementsDueThisMonth,
          cumulativeEndorsementsDue: cumulativeEndorsementsDue,
          cumulativeCloseRaceSupportRounds:
              (totalCloseRaceSupportRounds * supportRatios[index]).round(),
        ),
      );
    }
    return checkpoints;
  }

  String buildClipboardSummary() {
    final lines = <String>[
      '統一地方選700 必達管理サマリー',
      '対象期間: 2026年4月 - 2027年3月',
      '現在議員数: $currentLocalMembers',
      '目標議員数: $targetLocalMembers',
      '必要純増: $requiredNetIncrease',
      '県連配分済み純増: $allocatedNetIncrease',
      '未配分ギャップ: $allocationGap',
      '現職維持目標合計: $totalIncumbentRetentionTarget',
      '重点自治体合計: $totalFocusMunicipalityCount',
      '新人擁立合計: $totalNewCandidateTarget',
      '接戦区支援回数合計: $totalCloseRaceSupportRounds',
      '公認内定済み県連: $confirmedEndorsementCount / ${prefectures.length}',
      '期限超過県連: ${overdueEndorsementCount()}',
      '直近60日で期限到来: ${dueSoonEndorsementCount()}',
      '2023統一地方選実績: '
          '$previousUnifiedElectionFirstHalfWins + '
          '$previousUnifiedElectionSecondHalfWins = '
          '$previousUnifiedElectionWins',
      '',
      '重点県連:',
      for (final item in topPriorityPrefectures())
        '- ${item.prefecture}: KGI${item.kgiTargetLocalMembers}, '
            '残${item.kgiGapMembers}, '
            '純増${item.additionalSeatTarget}, '
            '現職維持${item.incumbentRetentionTarget}, '
            '重点自治体${item.focusMunicipalityCount}, '
            '新人${item.newCandidateTarget}, '
            '内定期限${item.endorsementDeadlineMonth}, '
            '支援${item.closeRaceSupportRounds}回',
    ];
    return lines.join('\n');
  }

  static int _readInt(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? fallback;
  }

  static List<LocalElectionPrefecturePlan> _sortedPrefectures(
    List<LocalElectionPrefecturePlan> items,
  ) {
    final sorted = List<LocalElectionPrefecturePlan>.from(items);
    sorted.sort((a, b) {
      final targetCompare =
          b.additionalSeatTarget.compareTo(a.additionalSeatTarget);
      if (targetCompare != 0) {
        return targetCompare;
      }
      final deadlineCompare =
          a.endorsementDeadlineDate.compareTo(b.endorsementDeadlineDate);
      if (deadlineCompare != 0) {
        return deadlineCompare;
      }
      return a.prefecture.compareTo(b.prefecture);
    });
    return sorted;
  }
}

const List<String> planningMonthKeys = <String>[
  '2026-04',
  '2026-05',
  '2026-06',
  '2026-07',
  '2026-08',
  '2026-09',
  '2026-10',
  '2026-11',
  '2026-12',
  '2027-01',
  '2027-02',
  '2027-03',
];

DateTime monthKeyToDate(String monthKey) => _monthKeyToDate(monthKey);

String formatMonthKey(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) {
    return monthKey;
  }
  return '${parts[0]}/${parts[1]}';
}

DateTime _monthKeyToDate(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) {
    return DateTime(2026, 10);
  }
  return DateTime(
    int.tryParse(parts[0]) ?? 2026,
    int.tryParse(parts[1]) ?? 10,
  );
}

DateTime _monthEnd(DateTime month) => DateTime(month.year, month.month + 1, 0);

String _nextMonthKey(String monthKey) {
  final date = _monthKeyToDate(monthKey);
  final next = DateTime(date.year, date.month + 1);
  return '${next.year.toString().padLeft(4, '0')}-'
      '${next.month.toString().padLeft(2, '0')}';
}

int clampPositiveInt(int value, {int minimum = 0}) {
  return math.max(value, minimum);
}
