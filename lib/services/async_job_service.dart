import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/async_job.dart';

abstract class AsyncJobRepository {
  Future<AsyncJob> enqueueJob({
    required String jobType,
    String? title,
    Map<String, dynamic>? requestPayload,
  });

  Future<AsyncJob?> fetchJobStatus(String jobId);

  Future<List<AsyncJob>> listJobs({
    AsyncJobStatus? statusFilter,
    int limit = 30,
  });

  Stream<List<AsyncJob>> watchJobs({int limit = 30});

  Future<AsyncJob> cancelJob(String jobId);
}

class SupabaseAsyncJobRepository implements AsyncJobRepository {
  SupabaseAsyncJobRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  @override
  Future<AsyncJob> enqueueJob({
    required String jobType,
    String? title,
    Map<String, dynamic>? requestPayload,
  }) async {
    final res = await _client.functions.invoke(
      'core-hub',
      body: <String, dynamic>{
        'action': 'async_job.enqueue',
        'job_type': jobType,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (requestPayload != null) 'request_payload': requestPayload,
      },
    );
    final map = _asMap(res.data);
    final rawJob = map['job'];
    if (rawJob is Map) {
      return AsyncJob.fromJson(Map<String, dynamic>.from(rawJob));
    }
    throw StateError('非同期ジョブの受付レスポンスが不正です');
  }

  @override
  Future<AsyncJob?> fetchJobStatus(String jobId) async {
    final trimmed = jobId.trim();
    if (trimmed.isEmpty) return null;
    final res = await _client.functions.invoke(
      'core-hub',
      body: <String, dynamic>{
        'action': 'async_job.status',
        'job_id': trimmed,
      },
    );
    final map = _asMap(res.data);
    final rawJob = map['job'];
    if (rawJob is Map) {
      return AsyncJob.fromJson(Map<String, dynamic>.from(rawJob));
    }
    return null;
  }

  @override
  Future<List<AsyncJob>> listJobs({
    AsyncJobStatus? statusFilter,
    int limit = 30,
  }) async {
    final res = await _client.functions.invoke(
      'core-hub',
      body: <String, dynamic>{
        'action': 'async_job.list',
        if (statusFilter != null) 'status': statusFilter.wireValue,
        'limit': limit,
      },
    );
    final map = _asMap(res.data);
    final rawList = map['jobs'];
    if (rawList is! List) return const <AsyncJob>[];
    return rawList
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => AsyncJob.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Stream<List<AsyncJob>> watchJobs({int limit = 30}) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return Stream<List<AsyncJob>>.value(const <AsyncJob>[]);
    }
    return _client
        .from('async_jobs')
        .stream(primaryKey: const <String>['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map(
                (row) => AsyncJob.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<AsyncJob> cancelJob(String jobId) async {
    final res = await _client.functions.invoke(
      'core-hub',
      body: <String, dynamic>{
        'action': 'async_job.update_status',
        'job_id': jobId.trim(),
        'status': 'cancelled',
      },
    );
    final map = _asMap(res.data);
    final rawJob = map['job'];
    if (rawJob is Map) {
      return AsyncJob.fromJson(Map<String, dynamic>.from(rawJob));
    }
    throw StateError('非同期ジョブのキャンセル結果を取得できませんでした');
  }
}
