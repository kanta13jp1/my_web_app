import 'package:flutter/material.dart';

enum AsyncJobStatus {
  queued(wireValue: 'queued', label: '待機中', icon: Icons.schedule),
  running(wireValue: 'running', label: '実行中', icon: Icons.sync),
  completed(
    wireValue: 'completed',
    label: '完了',
    icon: Icons.check_circle_outline,
  ),
  failed(wireValue: 'failed', label: '失敗', icon: Icons.error_outline),
  cancelled(
    wireValue: 'cancelled',
    label: 'キャンセル',
    icon: Icons.cancel_outlined,
  );

  const AsyncJobStatus({
    required this.wireValue,
    required this.label,
    required this.icon,
  });

  final String wireValue;
  final String label;
  final IconData icon;

  bool get isTerminal =>
      this == AsyncJobStatus.completed ||
      this == AsyncJobStatus.failed ||
      this == AsyncJobStatus.cancelled;

  bool get isActive =>
      this == AsyncJobStatus.queued || this == AsyncJobStatus.running;

  static AsyncJobStatus parse(Object? raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'queued':
        return AsyncJobStatus.queued;
      case 'running':
        return AsyncJobStatus.running;
      case 'completed':
      case 'success':
        return AsyncJobStatus.completed;
      case 'failed':
      case 'error':
        return AsyncJobStatus.failed;
      case 'cancelled':
      case 'canceled':
        return AsyncJobStatus.cancelled;
      default:
        return AsyncJobStatus.queued;
    }
  }
}

class AsyncJob {
  const AsyncJob({
    required this.id,
    required this.userId,
    required this.jobType,
    required this.title,
    required this.status,
    required this.progressPercent,
    required this.requestPayload,
    required this.createdAt,
    required this.updatedAt,
    this.resultPayload,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String userId;
  final String jobType;
  final String title;
  final AsyncJobStatus status;
  final int progressPercent;
  final Map<String, dynamic> requestPayload;
  final Map<String, dynamic>? resultPayload;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  static DateTime _parseDate(Object? value, {DateTime? fallback}) {
    if (value is DateTime) return value.toUtc();
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed.toUtc();
    }
    return (fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
  }

  static DateTime? _parseNullableDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toUtc();
    }
    return null;
  }

  static Map<String, dynamic>? _asNullableMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  factory AsyncJob.fromJson(Map<String, dynamic> json) {
    final created = _parseDate(json['created_at']);
    final progressRaw = json['progress_percent'];
    final progress = progressRaw is num
        ? progressRaw.toInt().clamp(0, 100)
        : int.tryParse(progressRaw?.toString() ?? '0')?.clamp(0, 100) ?? 0;
    final rawTitle = (json['title']?.toString() ?? '').trim();
    final jobType = (json['job_type']?.toString() ?? 'unknown').trim();
    return AsyncJob(
      id: (json['id']?.toString() ?? '').trim(),
      userId: (json['user_id']?.toString() ?? '').trim(),
      jobType: jobType,
      title: rawTitle.isNotEmpty ? rawTitle : jobType,
      status: AsyncJobStatus.parse(json['status']),
      progressPercent: progress,
      requestPayload:
          _asNullableMap(json['request_payload']) ?? const <String, dynamic>{},
      resultPayload: _asNullableMap(json['result_payload']),
      errorMessage: json['error_message']?.toString(),
      createdAt: created,
      updatedAt: _parseDate(json['updated_at'], fallback: created),
      startedAt: _parseNullableDate(json['started_at']),
      completedAt: _parseNullableDate(json['completed_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'job_type': jobType,
        'title': title,
        'status': status.wireValue,
        'progress_percent': progressPercent,
        'request_payload': requestPayload,
        'result_payload': resultPayload,
        'error_message': errorMessage,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'started_at': startedAt?.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
      };
}
