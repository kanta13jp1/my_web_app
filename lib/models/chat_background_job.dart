enum ChatBackgroundJobStatus {
  queued(label: '待機中'),
  running(label: '実行中'),
  completed(label: '完了'),
  failed(label: '失敗');

  const ChatBackgroundJobStatus({required this.label});

  final String label;

  bool get isTerminal =>
      this == ChatBackgroundJobStatus.completed ||
      this == ChatBackgroundJobStatus.failed;

  static ChatBackgroundJobStatus parseWire(Object? raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'queued':
        return ChatBackgroundJobStatus.queued;
      case 'completed':
      case 'success':
        return ChatBackgroundJobStatus.completed;
      case 'failed':
      case 'error':
        return ChatBackgroundJobStatus.failed;
      case 'running':
      default:
        return ChatBackgroundJobStatus.running;
    }
  }
}

class ChatBackgroundJob {
  const ChatBackgroundJob({
    required this.id,
    required this.title,
    required this.source,
    required this.status,
    required this.summary,
    required this.startedAt,
    required this.updatedAt,
    this.progress,
    this.resultDetail,
    this.errorMessage,
  });

  final String id;
  final String title;
  final String source;
  final ChatBackgroundJobStatus status;
  final double? progress;
  final String summary;
  final String? resultDetail;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime updatedAt;

  ChatBackgroundJob copyWith({
    String? title,
    String? source,
    ChatBackgroundJobStatus? status,
    double? progress,
    String? summary,
    String? resultDetail,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return ChatBackgroundJob(
      id: id,
      title: title ?? this.title,
      source: source ?? this.source,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      summary: summary ?? this.summary,
      resultDetail: resultDetail ?? this.resultDetail,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ChatBackgroundJob.fromJson(Map<String, dynamic> json) {
    final startedRaw = json['started_at']?.toString() ?? '';
    final updatedRaw = json['updated_at']?.toString() ?? '';
    final started =
        DateTime.tryParse(startedRaw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final updated = DateTime.tryParse(updatedRaw) ?? started;
    final rawProgress = json['progress'];
    final progress = rawProgress is num ? rawProgress.toDouble() : null;

    return ChatBackgroundJob(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'バックグラウンド処理').toString(),
      source: (json['source'] ?? 'ai-hub').toString(),
      status: ChatBackgroundJobStatus.parseWire(json['status']),
      progress: progress,
      summary: (json['summary'] ?? '').toString(),
      resultDetail: json['result_detail']?.toString(),
      errorMessage: json['error_message']?.toString(),
      startedAt: started,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'source': source,
      'status': status.name,
      if (progress != null) 'progress': progress,
      'summary': summary,
      if (resultDetail != null) 'result_detail': resultDetail,
      if (errorMessage != null) 'error_message': errorMessage,
      'started_at': startedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
