import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_background_job.dart';

class ChatBackgroundJobCenter extends ChangeNotifier {
  static const int maxRetainedJobs = 30;

  final List<ChatBackgroundJob> _jobs = <ChatBackgroundJob>[];
  StreamSubscription<ChatBackgroundJob>? _subscription;
  int _counter = 0;

  List<ChatBackgroundJob> get jobs =>
      List<ChatBackgroundJob>.unmodifiable(_jobs);

  ChatBackgroundJob startJob({
    required String title,
    String source = 'ai-hub',
    String summary = 'バックグラウンドで処理を実行中です',
    String? id,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now().toUtc();
    _counter += 1;
    final jobId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : 'bg_job_${timestamp.microsecondsSinceEpoch}_$_counter';
    final job = ChatBackgroundJob(
      id: jobId,
      title: title,
      source: source,
      status: ChatBackgroundJobStatus.running,
      summary: summary,
      startedAt: timestamp,
      updatedAt: timestamp,
    );
    _upsertJob(job);
    return job;
  }

  void updateJobStatus(
    String jobId, {
    required ChatBackgroundJobStatus status,
    double? progress,
    String? summary,
    String? resultDetail,
    String? errorMessage,
    DateTime? now,
  }) {
    final index = _jobs.indexWhere((item) => item.id == jobId);
    if (index < 0) {
      return;
    }
    final current = _jobs[index];
    _jobs[index] = current.copyWith(
      status: status,
      progress: progress,
      summary: summary,
      resultDetail: resultDetail,
      errorMessage: errorMessage,
      updatedAt: now ?? DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  void completeJob(
    String jobId, {
    required String summary,
    String? resultDetail,
    DateTime? now,
  }) {
    updateJobStatus(
      jobId,
      status: ChatBackgroundJobStatus.completed,
      progress: 1.0,
      summary: summary,
      resultDetail: resultDetail,
      now: now,
    );
  }

  void failJob(
    String jobId, {
    required String summary,
    required String errorMessage,
    DateTime? now,
  }) {
    updateJobStatus(
      jobId,
      status: ChatBackgroundJobStatus.failed,
      summary: summary,
      errorMessage: errorMessage,
      now: now,
    );
  }

  void dismissJob(String jobId) {
    final before = _jobs.length;
    _jobs.removeWhere((item) => item.id == jobId);
    if (_jobs.length != before) {
      notifyListeners();
    }
  }

  void bindStatusStream(Stream<ChatBackgroundJob> stream) {
    _subscription?.cancel();
    _subscription = stream.listen(
      _upsertJob,
      onError: (_) {
        // Fail-open: realtime subscription errors must not disrupt active UI.
      },
    );
  }

  void _upsertJob(ChatBackgroundJob job) {
    final index = _jobs.indexWhere((item) => item.id == job.id);
    if (index >= 0) {
      _jobs[index] = job;
    } else {
      _jobs.insert(0, job);
      if (_jobs.length > maxRetainedJobs) {
        _jobs.removeRange(maxRetainedJobs, _jobs.length);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
