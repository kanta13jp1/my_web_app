import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/video_studio/domain/video_studio_models.dart';

void main() {
  test('catalog parses only the public first-party product contract', () {
    final catalog = VideoStudioCatalog.fromJson({
      'models': [
        {
          'key': 'studio-video-v1',
          'name': 'Studio Video 1',
          'description': 'text to video',
          'durations': [5],
          'aspect_ratios': ['16:9', '9:16'],
          'resolutions': ['720p'],
          'credits_per_second': 60,
          'provider': 'must-not-be-consumed',
        },
      ],
      'credit_packs': [
        {
          'key': 'starter',
          'name': 'Starter',
          'credits': 500,
          'amount_jpy': 500,
        },
      ],
    });

    expect(catalog.models.single.key, 'studio-video-v1');
    expect(catalog.models.single.durations, [5]);
    expect(catalog.models.single.creditsPerSecond, 60);
    expect(catalog.creditPacks.single.amountJpy, 500);
  });

  test('job recognizes terminal states and signed output', () {
    final job = VideoGenerationJob.fromJson({
      'id': 'job-1',
      'model_key': 'studio-video-v1',
      'prompt': 'paper city',
      'duration_seconds': 5,
      'aspect_ratio': '16:9',
      'resolution': '720p',
      'status': 'succeeded',
      'quoted_credits': 300,
      'charged_credits': 300,
      'output_url': 'https://example.test/signed.mp4',
      'output_expires_at': '2026-08-20T12:00:00Z',
      'started_at': '2026-08-20T10:03:00Z',
      'created_at': '2026-08-20T10:00:00Z',
      'updated_at': '2026-08-20T10:08:00Z',
    });

    expect(job.isTerminal, isTrue);
    expect(job.isSuccessful, isTrue);
    expect(job.outputUrl?.host, 'example.test');
    expect(job.startedAt, DateTime.utc(2026, 8, 20, 10, 3));
    expect(job.updatedAt, DateTime.utc(2026, 8, 20, 10, 8));
  });
}
