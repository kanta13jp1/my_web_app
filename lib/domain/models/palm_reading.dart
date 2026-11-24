enum PalmHandSide { left, right }

extension PalmHandSideDisplay on PalmHandSide {
  String get wireValue => name;
  String get label => this == PalmHandSide.left ? '左手' : '右手';
  String get meaning => this == PalmHandSide.left ? '生来の資質・内面' : '現在の傾向・後天的な変化';

  static PalmHandSide fromWireValue(Object? value) =>
      value?.toString() == PalmHandSide.right.name
          ? PalmHandSide.right
          : PalmHandSide.left;
}

enum PalmLineKey { life, head, heart, fate }

extension PalmLineKeyDisplay on PalmLineKey {
  String get label => switch (this) {
        PalmLineKey.life => '生命線',
        PalmLineKey.head => '知能線',
        PalmLineKey.heart => '感情線',
        PalmLineKey.fate => '運命線',
      };

  static PalmLineKey? tryParse(Object? value) {
    final raw = value?.toString();
    for (final key in PalmLineKey.values) {
      if (key.name == raw) return key;
    }
    return null;
  }
}

class PalmPhotoQuality {
  const PalmPhotoQuality({
    required this.score,
    required this.isUsable,
    required this.feedback,
  });

  final int score;
  final bool isUsable;
  final String feedback;

  factory PalmPhotoQuality.fromJson(Map<String, dynamic> json) {
    return PalmPhotoQuality(
      score: _boundedInt(json['score']),
      isUsable: json['is_usable'] == true,
      feedback: json['feedback']?.toString().trim() ?? '',
    );
  }
}

class PalmLineReading {
  const PalmLineReading({
    required this.key,
    required this.label,
    required this.visibility,
    required this.strength,
    required this.continuity,
    required this.shape,
    required this.interpretation,
  });

  final PalmLineKey key;
  final String label;
  final int visibility;
  final int strength;
  final int continuity;
  final String shape;
  final String interpretation;

  factory PalmLineReading.fromJson(Map<String, dynamic> json) {
    final key = PalmLineKeyDisplay.tryParse(json['key']) ?? PalmLineKey.life;
    return PalmLineReading(
      key: key,
      label: key.label,
      visibility: _boundedInt(json['visibility']),
      strength: _boundedInt(json['strength']),
      continuity: _boundedInt(json['continuity']),
      shape: json['shape']?.toString().trim() ?? '',
      interpretation: json['interpretation']?.toString().trim() ?? '',
    );
  }
}

enum PalmChangeDirection { stronger, stable, weaker, uncertain }

extension PalmChangeDirectionDisplay on PalmChangeDirection {
  String get label => switch (this) {
        PalmChangeDirection.stronger => '強く見える',
        PalmChangeDirection.stable => '安定',
        PalmChangeDirection.weaker => '弱く見える',
        PalmChangeDirection.uncertain => '判定保留',
      };

  static PalmChangeDirection fromWireValue(Object? value) {
    final raw = value?.toString();
    for (final direction in PalmChangeDirection.values) {
      if (direction.name == raw) return direction;
    }
    return PalmChangeDirection.uncertain;
  }
}

class PalmLineChange {
  const PalmLineChange({
    required this.key,
    required this.label,
    required this.direction,
    required this.detail,
  });

  final PalmLineKey key;
  final String label;
  final PalmChangeDirection direction;
  final String detail;

  factory PalmLineChange.fromJson(Map<String, dynamic> json) {
    final key = PalmLineKeyDisplay.tryParse(json['key']) ?? PalmLineKey.life;
    return PalmLineChange(
      key: key,
      label: key.label,
      direction: PalmChangeDirectionDisplay.fromWireValue(json['direction']),
      detail: json['detail']?.toString().trim() ?? '',
    );
  }
}

class PalmReadingComparison {
  const PalmReadingComparison({
    required this.hasPrevious,
    required this.confidence,
    required this.summary,
    required this.caution,
    required this.changes,
  });

  final bool hasPrevious;
  final String confidence;
  final String summary;
  final String caution;
  final List<PalmLineChange> changes;

  factory PalmReadingComparison.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'];
    return PalmReadingComparison(
      hasPrevious: json['has_previous'] == true,
      confidence: json['confidence']?.toString() == 'medium' ? 'medium' : 'low',
      summary: json['summary']?.toString().trim() ?? '',
      caution: json['caution']?.toString().trim() ?? '',
      changes: rawChanges is List
          ? rawChanges
              .map(_mapFrom)
              .where((item) => item.isNotEmpty)
              .map(PalmLineChange.fromJson)
              .toList(growable: false)
          : const <PalmLineChange>[],
    );
  }
}

class PalmReading {
  const PalmReading({
    required this.id,
    required this.requestId,
    required this.handSide,
    required this.imagePath,
    required this.imageMimeType,
    required this.createdAt,
    required this.provider,
    required this.model,
    required this.schemaVersion,
    required this.quality,
    required this.overall,
    required this.traits,
    required this.love,
    required this.work,
    required this.advice,
    required this.lines,
    required this.comparison,
    this.imageUrl,
  });

  final String id;
  final String requestId;
  final PalmHandSide handSide;
  final String imagePath;
  final String imageMimeType;
  final DateTime createdAt;
  final String provider;
  final String model;
  final int schemaVersion;
  final PalmPhotoQuality quality;
  final String overall;
  final String traits;
  final String love;
  final String work;
  final List<String> advice;
  final List<PalmLineReading> lines;
  final PalmReadingComparison comparison;
  final String? imageUrl;

  factory PalmReading.fromJson(Map<String, dynamic> json) {
    final analysis = _mapFrom(json['analysis']);
    final quality = _mapFrom(analysis['photo_quality']);
    final rawLines = analysis['lines'];
    final rawAdvice = analysis['advice'];
    return PalmReading(
      id: json['id']?.toString() ?? '',
      requestId: json['request_id']?.toString() ?? '',
      handSide: PalmHandSideDisplay.fromWireValue(json['hand_side']),
      imagePath: json['image_path']?.toString() ?? '',
      imageMimeType: json['image_mime_type']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      provider: json['provider']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      schemaVersion: _positiveInt(json['schema_version'], fallback: 1),
      quality: PalmPhotoQuality.fromJson(quality),
      overall: analysis['overall']?.toString().trim() ?? '',
      traits: analysis['traits']?.toString().trim() ?? '',
      love: analysis['love']?.toString().trim() ?? '',
      work: analysis['work']?.toString().trim() ?? '',
      advice: rawAdvice is List
          ? rawAdvice
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      lines: rawLines is List
          ? rawLines
              .map(_mapFrom)
              .where((item) => item.isNotEmpty)
              .map(PalmLineReading.fromJson)
              .toList(growable: false)
          : const <PalmLineReading>[],
      comparison: PalmReadingComparison.fromJson(_mapFrom(json['comparison'])),
      imageUrl: json['image_url']?.toString(),
    );
  }

  PalmReading copyWith({String? imageUrl}) {
    return PalmReading(
      id: id,
      requestId: requestId,
      handSide: handSide,
      imagePath: imagePath,
      imageMimeType: imageMimeType,
      createdAt: createdAt,
      provider: provider,
      model: model,
      schemaVersion: schemaVersion,
      quality: quality,
      overall: overall,
      traits: traits,
      love: love,
      work: work,
      advice: advice,
      lines: lines,
      comparison: comparison,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

Map<String, dynamic> _mapFrom(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

int _boundedInt(Object? value) {
  final parsed = value is num ? value.round() : int.tryParse('$value') ?? 0;
  return parsed.clamp(0, 100);
}

int _positiveInt(Object? value, {required int fallback}) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : fallback;
}
