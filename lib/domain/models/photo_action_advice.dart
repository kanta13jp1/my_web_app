enum PhotoActionPriority {
  urgent(1, '最優先'),
  high(2, '優先'),
  normal(3, 'できれば');

  const PhotoActionPriority(this.rank, this.label);

  final int rank;
  final String label;

  static PhotoActionPriority fromJson(Object? value) {
    final rank = switch (value) {
      final num value => value.toInt(),
      final String value => int.tryParse(value),
      _ => null,
    };
    return switch (rank) {
      1 => PhotoActionPriority.urgent,
      2 => PhotoActionPriority.high,
      _ => PhotoActionPriority.normal,
    };
  }
}

class PhotoRecommendedAction {
  const PhotoRecommendedAction({
    required this.priority,
    required this.title,
    required this.reason,
    required this.estimatedMinutes,
    this.caution,
  });

  final PhotoActionPriority priority;
  final String title;
  final String reason;
  final int estimatedMinutes;
  final String? caution;

  factory PhotoRecommendedAction.fromJson(Map<String, dynamic> json) {
    final title = _requiredString(json['title'], 'title');
    final reason = _requiredString(json['reason'], 'reason');
    final rawMinutes = switch (json['estimated_minutes']) {
      final num value => value.toInt(),
      final String value => int.tryParse(value),
      _ => null,
    };
    return PhotoRecommendedAction(
      priority: PhotoActionPriority.fromJson(json['priority']),
      title: title,
      reason: reason,
      estimatedMinutes: (rawMinutes ?? 5).clamp(1, 180),
      caution: _optionalString(json['caution']),
    );
  }
}

class PhotoActionAdvice {
  const PhotoActionAdvice({
    required this.sceneSummary,
    required this.observations,
    required this.actions,
    required this.confidenceNote,
    this.safetyNote,
  });

  final String sceneSummary;
  final List<String> observations;
  final List<PhotoRecommendedAction> actions;
  final String confidenceNote;
  final String? safetyNote;

  factory PhotoActionAdvice.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    if (rawActions is! List) {
      throw const FormatException('AIの行動提案を読み取れませんでした。');
    }
    final actions = <PhotoRecommendedAction>[];
    for (final rawAction in rawActions.take(6)) {
      if (rawAction is! Map) continue;
      try {
        actions.add(
          PhotoRecommendedAction.fromJson(
            Map<String, dynamic>.from(rawAction),
          ),
        );
      } on FormatException {
        // One malformed suggestion must not hide the remaining useful actions.
      }
    }
    if (actions.isEmpty) {
      throw const FormatException('具体的な行動提案を生成できませんでした。');
    }
    actions.sort((a, b) => a.priority.rank.compareTo(b.priority.rank));

    final rawObservations = json['observations'];
    final observations = rawObservations is List
        ? rawObservations
            .map(_optionalString)
            .whereType<String>()
            .take(5)
            .toList(growable: false)
        : const <String>[];

    return PhotoActionAdvice(
      sceneSummary: _requiredString(json['scene_summary'], 'scene_summary'),
      observations: observations,
      actions: List<PhotoRecommendedAction>.unmodifiable(actions),
      confidenceNote:
          _optionalString(json['confidence_note']) ?? '写真に写っている範囲だけをもとにした提案です。',
      safetyNote: _optionalString(json['safety_note']),
    );
  }
}

String _requiredString(Object? value, String fieldName) {
  final normalized = _optionalString(value);
  if (normalized == null) {
    throw FormatException('$fieldName is required');
  }
  return normalized;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
