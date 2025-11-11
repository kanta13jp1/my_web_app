/// タイマーのステータス
enum TimerStatus {
  running,   // 実行中
  paused,    // 一時停止
  completed, // 完了
  stopped,   // 停止
}

/// タイマーモデル
class AppTimer {
  final int id;
  final String userId;
  final int? noteId;          // 関連するメモID（nullの場合は汎用タイマー）
  final String name;          // タイマー名（例: "ポモドーロ"）
  final int durationSeconds;  // 設定時間（秒）
  final DateTime startedAt;   // 開始時刻
  final DateTime? completedAt; // 完了時刻
  final TimerStatus status;   // 実行中、一時停止、完了、停止
  final bool soundNotification;   // サウンド通知ON/OFF
  final bool browserNotification; // ブラウザ通知ON/OFF
  final bool autoSave;            // 終了時に自動保存
  final DateTime createdAt;
  final DateTime updatedAt;

  AppTimer({
    required this.id,
    required this.userId,
    this.noteId,
    required this.name,
    required this.durationSeconds,
    required this.startedAt,
    this.completedAt,
    required this.status,
    this.soundNotification = true,
    this.browserNotification = true,
    this.autoSave = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// JSONからAppTimerを作成
  factory AppTimer.fromJson(Map<String, dynamic> json) {
    return AppTimer(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      noteId: json['note_id'] as int?,
      name: json['name'] as String,
      durationSeconds: json['duration_seconds'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      status: _statusFromString(json['status'] as String),
      soundNotification: json['sound_notification'] as bool? ?? true,
      browserNotification: json['browser_notification'] as bool? ?? true,
      autoSave: json['auto_save'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// AppTimerをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'note_id': noteId,
      'name': name,
      'duration_seconds': durationSeconds,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'status': _statusToString(status),
      'sound_notification': soundNotification,
      'browser_notification': browserNotification,
      'auto_save': autoSave,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// コピーを作成
  AppTimer copyWith({
    int? id,
    String? userId,
    int? noteId,
    String? name,
    int? durationSeconds,
    DateTime? startedAt,
    DateTime? completedAt,
    TimerStatus? status,
    bool? soundNotification,
    bool? browserNotification,
    bool? autoSave,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppTimer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      noteId: noteId ?? this.noteId,
      name: name ?? this.name,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      soundNotification: soundNotification ?? this.soundNotification,
      browserNotification: browserNotification ?? this.browserNotification,
      autoSave: autoSave ?? this.autoSave,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 文字列からTimerStatusに変換
  static TimerStatus _statusFromString(String status) {
    switch (status) {
      case 'running':
        return TimerStatus.running;
      case 'paused':
        return TimerStatus.paused;
      case 'completed':
        return TimerStatus.completed;
      case 'stopped':
        return TimerStatus.stopped;
      default:
        return TimerStatus.stopped;
    }
  }

  /// TimerStatusを文字列に変換
  static String _statusToString(TimerStatus status) {
    switch (status) {
      case TimerStatus.running:
        return 'running';
      case TimerStatus.paused:
        return 'paused';
      case TimerStatus.completed:
        return 'completed';
      case TimerStatus.stopped:
        return 'stopped';
    }
  }
}
