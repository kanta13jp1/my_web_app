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
  }) => PlatformReleaseChecklist(
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
    return PlatformReleaseChecklist(
      sharedScope: json['sharedScope'] as String? ?? '',
      notes: rawNotes is Map
          ? rawNotes.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
      statuses: rawStatuses is Map
          ? rawStatuses.map((key, value) {
              final status = PlatformCheckStatus.values.where(
                (candidate) => candidate.name == value,
              );
              return MapEntry(
                key.toString(),
                status.isEmpty ? PlatformCheckStatus.untested : status.first,
              );
            })
          : const <String, PlatformCheckStatus>{},
    );
  }

  String toShareText() {
    final lines = <String>[
      'クロスプラットフォーム リリース確認',
      '共通の確認範囲: ${sharedScope.isEmpty ? '未入力' : sharedScope}',
    ];
    for (final platform in platforms) {
      final note = notes[platform] ?? '';
      lines.add('$platform: ${statusFor(platform).label}${note.isEmpty ? '' : ' — $note'}');
    }
    lines.add('注: 確認済みは、この一覧に記録した確認に限ります。端末・ストア・OS固有の確認は別々に行います。');
    return lines.join('\n');
  }
}
