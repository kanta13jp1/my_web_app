import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/video_studio_models.dart';

class VideoStudioException implements Exception {
  const VideoStudioException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => message ?? code;
}

abstract class VideoStudioGateway {
  Future<VideoStudioCatalog> loadCatalog();

  Future<VideoCreditBalance> loadBalance();

  Future<List<VideoGenerationJob>> listJobs();

  Future<VideoCreateResult> createJob({
    required String idempotencyKey,
    required String modelKey,
    required String prompt,
    required int durationSeconds,
    required String aspectRatio,
    required String resolution,
  });

  Future<VideoGenerationJob> refreshJob(String jobId);

  Future<Uri> createCreditCheckout({
    required String packKey,
    required String returnUrl,
  });
}

class SupabaseVideoStudioGateway implements VideoStudioGateway {
  SupabaseVideoStudioGateway({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<VideoStudioCatalog> loadCatalog() async {
    final data = await _invokeVideo({'action': 'catalog'});
    return VideoStudioCatalog.fromJson(data);
  }

  @override
  Future<VideoCreditBalance> loadBalance() async {
    final data = await _invokeVideo({'action': 'balance'});
    return VideoCreditBalance.fromJson(videoStudioMap(data['balance']));
  }

  @override
  Future<List<VideoGenerationJob>> listJobs() async {
    final data = await _invokeVideo({'action': 'list'});
    return videoStudioList(data['jobs'])
        .map((value) => VideoGenerationJob.fromJson(videoStudioMap(value)))
        .toList(growable: false);
  }

  @override
  Future<VideoCreateResult> createJob({
    required String idempotencyKey,
    required String modelKey,
    required String prompt,
    required int durationSeconds,
    required String aspectRatio,
    required String resolution,
  }) async {
    final data = await _invokeVideo({
      'action': 'create',
      'idempotency_key': idempotencyKey,
      'model_key': modelKey,
      'prompt': prompt,
      'duration_seconds': durationSeconds,
      'aspect_ratio': aspectRatio,
      'resolution': resolution,
      'rights_confirmed': true,
      'adult_confirmed': true,
    });
    return VideoCreateResult(
      job: VideoGenerationJob.fromJson(videoStudioMap(data['job'])),
      balance: VideoCreditBalance.fromJson(videoStudioMap(data['balance'])),
    );
  }

  @override
  Future<VideoGenerationJob> refreshJob(String jobId) async {
    final data = await _invokeVideo({'action': 'status', 'job_id': jobId});
    return VideoGenerationJob.fromJson(videoStudioMap(data['job']));
  }

  @override
  Future<Uri> createCreditCheckout({
    required String packKey,
    required String returnUrl,
  }) async {
    final response = await _client.functions.invoke(
      'schedule-hub',
      body: {
        'action': 'billing.create_video_credit_checkout_session',
        'pack_key': packKey,
        'return_url': returnUrl,
      },
    );
    final data = videoStudioMap(response.data);
    _throwForResponse(response.status, data);
    final uri = Uri.tryParse(data['checkout_url']?.toString() ?? '');
    if (uri == null || !uri.hasScheme) {
      throw const VideoStudioException('checkout_url_missing');
    }
    return uri;
  }

  Future<Map<String, dynamic>> _invokeVideo(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke(
      'video-generation-hub',
      body: body,
    );
    final data = videoStudioMap(response.data);
    _throwForResponse(response.status, data);
    return data;
  }

  void _throwForResponse(int status, Map<String, dynamic> data) {
    if (status >= 200 && status < 300 && data['error'] == null) return;
    throw VideoStudioException(
      data['error']?.toString() ?? 'http_$status',
      data['message']?.toString(),
    );
  }
}
