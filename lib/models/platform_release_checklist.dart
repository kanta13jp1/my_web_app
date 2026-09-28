enum PlatformCheckStatus { untested, passed, failed, notApplicable }

extension PlatformCheckStatusLabel on PlatformCheckStatus {
  String get label => switch (this) {
        PlatformCheckStatus.untested => '未確認',
        PlatformCheckStatus.passed => '確認済み',
        PlatformCheckStatus.failed => '要修正',
        PlatformCheckStatus.notApplicable => '対象外',
      };
}

class PlatformReleaseChecklist {
  const PlatformReleaseChecklist({
    this.sharedScope = '',
    this.notes = const <String, String>{},
    this.statuses = const <String, PlatformCheckStatus>{},
  });

  static const platforms = <String>['Web', 'iOS', 'Android'];

  final String sharedScope;
  final Map<String, String> notes;
  final Map<String, PlatformCheckStatus> statuses;

  PlatformCheckStatus statusFor(String platform) =>
      statuses[platform] ?? PlatformCheckStatus.untested;

  PlatformReleaseChecklist copyWith({
    String? sharedScope,
    Map<String, String>? notes,
    Map<String, PlatformCheckStatus>? statuses,
  }) =>
      PlatformReleaseChecklist(
        sharedScope: sharedScope ?? this.sharedScope,
        notes: notes ?? this.notes,
        statuses: statuses ?? this.statuses,
      );

  Map<String, Object> toJson() => <String, Object>{
        'sharedScope': sharedScope,
        'notes': notes,
        'statuses': statuses.map(
          (platform, status) => MapEntry(platform, status.name),
        ),
      };

  factory PlatformReleaseChecklist.fromJson(Map<String, Object?> json) {
    final rawNotes = json['notes'];
    final rawStatuses = json['statuses'];
    final rawScope = json['sharedScope'];
    if (rawScope != null && rawScope is! String) {
      throw const FormatException('sharedScope must be a string');
    }
    if (rawNotes != null && rawNotes is! Map) {
      throw const FormatException('notes must be a map');
    }
    if (rawStatuses != null && rawStatuses is! Map) {
      throw const FormatException('statuses must be a map');
    }
    final notes = <String, String>{};
    if (rawNotes is Map) {
      for (final entry in rawNotes.entries) {
        if (entry.key is! String || entry.value is! String) {
          throw const FormatException('notes must contain strings');
        }
        notes[entry.key as String] = entry.value as String;
      }
    }
    final statuses = <String, PlatformCheckStatus>{};
    if (rawStatuses is Map) {
      for (final entry in rawStatuses.entries) {
        if (entry.key is! String || entry.value is! String) {
          throw const FormatException('statuses must contain strings');
        }
        final matches = PlatformCheckStatus.values.where(
          (candidate) => candidate.name == entry.value,
        );
        if (matches.isEmpty) {
          throw const FormatException('statuses contains an unknown state');
        }
        statuses[entry.key as String] = matches.first;
      }
    }
    return PlatformReleaseChecklist(
      sharedScope: rawScope as String? ?? '',
      notes: notes,
      statuses: statuses,
    );
  }

  String toShareText() {
    final lines = <String>[
      'クロスプラットフォーム リリース確認',
      '共通の確認範囲: ${sharedScope.isEmpty ? '未入力' : sharedScope}',
    ];
    for (final platform in platforms) {
      final note = notes[platform] ?? '';
      lines.add(
        '$platform: ${statusFor(platform).label}${note.isEmpty ? '' : ' — $note'}',
      );
    }
    lines.add('注: 確認済みは、この一覧に記録した確認に限ります。端末・ストア・OS固有の確認は別々に行います。');
    return lines.join('\n');
  }
}
