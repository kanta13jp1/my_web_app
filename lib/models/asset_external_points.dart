/// 外部ポイント（京王ポイント・Vポイント等）の記録モデルと純関数群。
///
/// 純資産・手元現金・月次支出には合算せず、残高・増減・失効予定の控えとして扱う。
/// 会員番号・取引番号・POS番号などの個人・決済識別子は保持しない。
class AssetExternalPointPresets {
  static const String keio = '京王ポイント';

  static const List<String> all = <String>[
    '京王ポイント',
    'Vポイント',
    '楽天ポイント',
    'dポイント',
    'Pontaポイント',
    'PayPayポイント',
    'ファミマポイント',
    'JRE POINT',
  ];
}

/// 外部ポイントの有効期限ステータス。
enum AssetExternalPointExpiryStatus {
  none,
  active,
  expiringSoon,
  expired,
}

/// 外部ポイントの 1 観測レコード。
class AssetExternalPointRecord {
  const AssetExternalPointRecord({
    required this.id,
    required this.programName,
    required this.observedAt,
    required this.balanceAfter,
    this.deltaPoints = 0,
    this.balanceBefore,
    this.expiringPoints,
    this.expiresOn,
    this.merchant = '',
    this.pointTargetAmountYen,
    this.memo = '',
  });

  final String id;
  final String programName;
  final DateTime observedAt;
  final int balanceAfter;
  final int deltaPoints;
  final int? balanceBefore;
  final int? expiringPoints;
  final DateTime? expiresOn;
  final String merchant;

  /// レシート等のポイント対象金額（参考値のみで支出計上外）。
  final int? pointTargetAmountYen;
  final String memo;

  Map<String, dynamic> toJson() {
    final expires = expiresOn;
    return <String, dynamic>{
      'id': id,
      'programName': programName,
      'observedAt': observedAt.toIso8601String(),
      'balanceAfter': balanceAfter,
      'deltaPoints': deltaPoints,
      if (balanceBefore != null) 'balanceBefore': balanceBefore,
      if (expiringPoints != null) 'expiringPoints': expiringPoints,
      if (expires != null) 'expiresOn': _formatIsoDate(expires),
      if (merchant.isNotEmpty) 'merchant': merchant,
      if (pointTargetAmountYen != null)
        'pointTargetAmountYen': pointTargetAmountYen,
      if (memo.isNotEmpty) 'memo': memo,
    };
  }

  /// 寛容パース。必須項目欠損・空文字・パース不可・負の残高は null を返す。
  static AssetExternalPointRecord? fromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final rawId = raw['id'];
    if (rawId is! String) {
      return null;
    }
    final id = rawId.trim();
    if (id.isEmpty) {
      return null;
    }

    final rawProgram = raw['programName'];
    if (rawProgram is! String) {
      return null;
    }
    final programName = rawProgram.trim();
    if (programName.isEmpty) {
      return null;
    }

    final observedAt = _parseJsonDateTime(raw['observedAt']);
    if (observedAt == null) {
      return null;
    }

    final balanceAfter = _parseJsonInt(raw['balanceAfter']);
    if (balanceAfter == null || balanceAfter < 0) {
      return null;
    }

    final deltaPoints = _parseJsonInt(raw['deltaPoints']) ?? 0;

    final parsedBalanceBefore = _parseJsonInt(raw['balanceBefore']);
    final balanceBefore =
        parsedBalanceBefore != null && parsedBalanceBefore >= 0
            ? parsedBalanceBefore
            : null;

    final parsedExpiringPoints = _parseJsonInt(raw['expiringPoints']);
    final expiringPoints =
        parsedExpiringPoints != null && parsedExpiringPoints > 0
            ? parsedExpiringPoints
            : null;

    final expiresOn = _parseDateOnly(raw['expiresOn']);

    final rawMerchant = raw['merchant'];
    final merchant = rawMerchant is String ? rawMerchant.trim() : '';

    final parsedTargetAmount = _parseJsonInt(raw['pointTargetAmountYen']);
    final pointTargetAmountYen =
        parsedTargetAmount != null && parsedTargetAmount > 0
            ? parsedTargetAmount
            : null;

    final rawMemo = raw['memo'];
    final memo = rawMemo is String ? rawMemo.trim() : '';

    return AssetExternalPointRecord(
      id: id,
      programName: programName,
      observedAt: observedAt,
      balanceAfter: balanceAfter,
      deltaPoints: deltaPoints,
      balanceBefore: balanceBefore,
      expiringPoints: expiringPoints,
      expiresOn: expiresOn,
      merchant: merchant,
      pointTargetAmountYen: pointTargetAmountYen,
      memo: memo,
    );
  }

  AssetExternalPointRecord copyWith({
    String? id,
    String? programName,
    DateTime? observedAt,
    int? balanceAfter,
    int? deltaPoints,
    int? balanceBefore,
    bool clearBalanceBefore = false,
    int? expiringPoints,
    bool clearExpiringPoints = false,
    DateTime? expiresOn,
    bool clearExpiresOn = false,
    String? merchant,
    int? pointTargetAmountYen,
    bool clearPointTargetAmountYen = false,
    String? memo,
  }) {
    return AssetExternalPointRecord(
      id: id ?? this.id,
      programName: programName ?? this.programName,
      observedAt: observedAt ?? this.observedAt,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      deltaPoints: deltaPoints ?? this.deltaPoints,
      balanceBefore:
          clearBalanceBefore ? null : balanceBefore ?? this.balanceBefore,
      expiringPoints:
          clearExpiringPoints ? null : expiringPoints ?? this.expiringPoints,
      expiresOn: clearExpiresOn
          ? null
          : _normalizeDateOnly(expiresOn ?? this.expiresOn),
      merchant: merchant ?? this.merchant,
      pointTargetAmountYen: clearPointTargetAmountYen
          ? null
          : pointTargetAmountYen ?? this.pointTargetAmountYen,
      memo: memo ?? this.memo,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AssetExternalPointRecord &&
        other.id == id &&
        other.programName == programName &&
        other.observedAt.isAtSameMomentAs(observedAt) &&
        other.balanceAfter == balanceAfter &&
        other.deltaPoints == deltaPoints &&
        other.balanceBefore == balanceBefore &&
        other.expiringPoints == expiringPoints &&
        _sameDateOnly(other.expiresOn, expiresOn) &&
        other.merchant == merchant &&
        other.pointTargetAmountYen == pointTargetAmountYen &&
        other.memo == memo;
  }

  @override
  int get hashCode {
    final normalizedExpiry = _normalizeDateOnly(expiresOn);
    return Object.hash(
      id,
      programName,
      observedAt.microsecondsSinceEpoch,
      balanceAfter,
      deltaPoints,
      balanceBefore,
      expiringPoints,
      normalizedExpiry,
      merchant,
      pointTargetAmountYen,
      memo,
    );
  }
}

/// プログラム別の最新残高と期限ステータスをまとめたサマリ。
class AssetExternalPointProgramSummary {
  const AssetExternalPointProgramSummary({
    required this.programName,
    required this.latestRecord,
    required this.recordCount,
    required this.expiryStatus,
  });

  final String programName;
  final AssetExternalPointRecord latestRecord;
  final int recordCount;
  final AssetExternalPointExpiryStatus expiryStatus;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AssetExternalPointProgramSummary &&
        other.programName == programName &&
        other.latestRecord == latestRecord &&
        other.recordCount == recordCount &&
        other.expiryStatus == expiryStatus;
  }

  @override
  int get hashCode => Object.hash(
        programName,
        latestRecord,
        recordCount,
        expiryStatus,
      );
}

/// 観測日時の降順（同時刻は `id` 昇順）でレコードを並べ替える。
List<AssetExternalPointRecord> sortExternalPointRecords(
  Iterable<AssetExternalPointRecord> records,
) {
  final sorted = records.toList()
    ..sort((a, b) {
      final timeOrder = b.observedAt.compareTo(a.observedAt);
      if (timeOrder != 0) {
        return timeOrder;
      }
      return a.id.compareTo(b.id);
    });
  return sorted;
}

/// プログラム別に最新観測レコード・件数・期限ステータスを集計する（最新観測が新しい順）。
List<AssetExternalPointProgramSummary> summarizeExternalPointPrograms(
  Iterable<AssetExternalPointRecord> records, {
  DateTime? now,
}) {
  final referenceNow = now ?? DateTime.now();
  final sorted = sortExternalPointRecords(records);
  final latestByProgram = <String, AssetExternalPointRecord>{};
  final countsByProgram = <String, int>{};

  for (final record in sorted) {
    latestByProgram.putIfAbsent(record.programName, () => record);
    countsByProgram[record.programName] =
        (countsByProgram[record.programName] ?? 0) + 1;
  }

  return <AssetExternalPointProgramSummary>[
    for (final entry in latestByProgram.entries)
      AssetExternalPointProgramSummary(
        programName: entry.key,
        latestRecord: entry.value,
        recordCount: countsByProgram[entry.key] ?? 1,
        expiryStatus: _classifyExpiryStatus(entry.value, referenceNow),
      ),
  ];
}

/// 全角数字・全角符号・カンマ・空白・単位 (`P`/`pt`/`円`) を許容して整数をパースする。
int? parseFlexiblePointInt(String raw, {bool allowNegative = false}) {
  final normalized = _normalizePointInput(raw);
  if (normalized.isEmpty) {
    return null;
  }
  final withoutUnit = normalized.replaceFirst(
    RegExp(r'(?:pt|p|円)$', caseSensitive: false),
    '',
  );
  if (!RegExp(r'^[+-]?\d+$').hasMatch(withoutUnit)) {
    return null;
  }
  final parsed = int.tryParse(withoutUnit);
  if (parsed == null) {
    return null;
  }
  if (!allowNegative && parsed < 0) {
    return null;
  }
  return parsed;
}

/// `yyyy/MM/dd HH:mm` 形式に整形する。
String formatExternalPointDateTime(DateTime dt) {
  return '${formatExternalPointDate(dt)} ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
}

/// `yyyy/MM/dd` 形式に整形する。
String formatExternalPointDate(DateTime dt) {
  final year = dt.year.toString().padLeft(4, '0');
  return '$year/${_twoDigits(dt.month)}/${_twoDigits(dt.day)}';
}

/// 桁区切りでポイント数を整形する（例: `1,250`）。
String formatExternalPointsCount(int value) {
  final isNegative = value < 0;
  final digits = value.toString().replaceFirst('-', '');
  final buffer = StringBuffer();
  if (isNegative) {
    buffer.write('-');
  }
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

AssetExternalPointExpiryStatus _classifyExpiryStatus(
  AssetExternalPointRecord record,
  DateTime now,
) {
  final expiresOn = record.expiresOn;
  final expiringPoints = record.expiringPoints;
  if (expiresOn == null || expiringPoints == null || expiringPoints <= 0) {
    return AssetExternalPointExpiryStatus.none;
  }
  final today = DateTime.utc(now.year, now.month, now.day);
  final expiryDay = DateTime.utc(
    expiresOn.year,
    expiresOn.month,
    expiresOn.day,
  );
  final diffDays = expiryDay.difference(today).inDays;
  if (diffDays < 0) {
    return AssetExternalPointExpiryStatus.expired;
  }
  if (diffDays <= 30) {
    return AssetExternalPointExpiryStatus.expiringSoon;
  }
  return AssetExternalPointExpiryStatus.active;
}

String _normalizePointInput(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    if (rune >= 0xFF10 && rune <= 0xFF19) {
      buffer.writeCharCode(rune - 0xFF10 + 0x30);
      continue;
    }
    switch (rune) {
      case 0xFF0B: // ＋
        buffer.write('+');
        break;
      case 0x2212: // −
      case 0xFF0D: // －
      case 0x30FC: // ー
        buffer.write('-');
        break;
      case 0xFF0C: // ，
      case 0x002C: // ,
      case 0x3000: // 全角スペース
      case 0x0020: // 半角スペース
      case 0x0009: // \t
      case 0x000A: // \n
      case 0x000D: // \r
        break;
      case 0xFF30: // Ｐ
        buffer.write('P');
        break;
      case 0xFF50: // ｐ
        buffer.write('p');
        break;
      case 0xFF34: // Ｔ
        buffer.write('T');
        break;
      case 0xFF54: // ｔ
        buffer.write('t');
        break;
      default:
        buffer.writeCharCode(rune);
        break;
    }
  }
  return buffer.toString();
}

int? _parseJsonInt(dynamic raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is double) {
    if (!raw.isFinite || raw != raw.truncateToDouble()) {
      return null;
    }
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw.trim());
  }
  return null;
}

DateTime? _parseJsonDateTime(dynamic raw) {
  if (raw is DateTime) {
    return raw;
  }
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return DateTime.tryParse(trimmed);
}

DateTime? _parseDateOnly(dynamic raw) {
  if (raw is DateTime) {
    return DateTime(raw.year, raw.month, raw.day);
  }
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final ymdMatch = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$').firstMatch(
    trimmed,
  );
  if (ymdMatch != null) {
    final yearStr = ymdMatch.group(1);
    final monthStr = ymdMatch.group(2);
    final dayStr = ymdMatch.group(3);
    if (yearStr == null || monthStr == null || dayStr == null) {
      return null;
    }
    final year = int.tryParse(yearStr);
    final month = int.tryParse(monthStr);
    final day = int.tryParse(dayStr);
    if (year == null || month == null || day == null) {
      return null;
    }
    final candidate = DateTime(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      return null;
    }
    return candidate;
  }
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) {
    return null;
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _normalizeDateOnly(DateTime? dt) {
  if (dt == null) {
    return null;
  }
  return DateTime(dt.year, dt.month, dt.day);
}

bool _sameDateOnly(DateTime? a, DateTime? b) {
  if (a == null || b == null) {
    return a == null && b == null;
  }
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatIsoDate(DateTime dt) {
  final year = dt.year.toString().padLeft(4, '0');
  return '$year-${_twoDigits(dt.month)}-${_twoDigits(dt.day)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
