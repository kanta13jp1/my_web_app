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

  test('job parses its durable artifact, review, and improvement lineage', () {
    final job = VideoGenerationJob.fromJson({
      'id': 'job-2',
      'model_key': 'studio-video-v1',
      'prompt': 'improved office scene',
      'duration_seconds': 5,
      'aspect_ratio': '16:9',
      'resolution': '720p',
      'status': 'succeeded',
      'quoted_credits': 300,
      'charged_credits': 300,
      'created_at': '2026-08-20T10:00:00Z',
      'parent_artifact_id': 'artifact-1',
      'applied_review_id': 'review-1',
      'authorization_id': 'authorization-1',
      'artifact': {
        'id': 'artifact-2',
        'job_id': 'job-2',
        'parent_artifact_id': 'artifact-1',
        'title': 'improved office scene',
        'file_size_bytes': 1024,
        'sha256': List.filled(64, 'a').join(),
        'lifecycle_stage': 'original',
        'rights_status': 'confirmed',
        'privacy_status': 'confirmed',
        'commerce_status': 'sale_candidate',
        'intended_for_sale': true,
        'iteration': 2,
        'created_at': '2026-08-20T10:08:00Z',
        'latest_review': {
          'id': 'review-2',
          'artifact_id': 'artifact-2',
          'iteration': 1,
          'quality_score': 4,
          'prompt_alignment_score': 5,
          'motion_quality_score': 4,
          'commercial_value_score': 4,
          'decision': 'keep',
          'strengths': '動きが自然',
          'improvement_request': '',
          'suggested_prompt': '',
          'notes': '',
          'created_at': '2026-08-20T10:09:00Z',
        },
      },
    });

    expect(job.parentArtifactId, 'artifact-1');
    expect(job.appliedReviewId, 'review-1');
    expect(job.authorizationId, 'authorization-1');
    expect(job.artifact?.isSaleCandidate, isTrue);
    expect(job.artifact?.iteration, 2);
    expect(job.artifact?.fileSizeBytes, 1024);
    expect(job.artifact?.latestReview?.decision, 'keep');
    expect(job.artifact?.latestReview?.promptAlignmentScore, 5);
  });

  test('authorization exposes machine-checkable remaining limits', () {
    final authorization = VideoImprovementAuthorization.fromJson({
      'id': 'authorization-1',
      'status': 'active',
      'valid_until':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'total_credit_limit': 600,
      'reserved_credits': 300,
      'consumed_credits': 0,
      'remaining_credits': 300,
      'total_regeneration_limit': 2,
      'consumed_regenerations': 1,
      'remaining_regenerations': 1,
      'root_artifact_id': 'artifact-1',
      'initial_review_id': 'review-1',
      'allow_credit_purchase': false,
    });

    expect(authorization.isActive, isTrue);
    expect(authorization.remainingCredits, 300);
    expect(authorization.remainingRegenerations, 1);
    expect(authorization.allowCreditPurchase, isFalse);
  });

  test('pending authorization remains resumable and exposes blockers', () {
    final authorization = VideoImprovementAuthorization.fromJson({
      'id': 'authorization-pending',
      'status': 'pending_funding',
      'pending_reasons': ['insufficient_credits'],
      'valid_until':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'total_credit_limit': 600,
      'reserved_credits': 0,
      'consumed_credits': 0,
      'remaining_credits': 600,
      'total_regeneration_limit': 2,
      'consumed_regenerations': 0,
      'remaining_regenerations': 2,
      'root_artifact_id': 'artifact-1',
      'initial_review_id': 'review-1',
      'allow_credit_purchase': false,
    });

    expect(authorization.isActive, isTrue);
    expect(authorization.isPending, isTrue);
    expect(authorization.pendingReasons, ['insufficient_credits']);
  });
}
