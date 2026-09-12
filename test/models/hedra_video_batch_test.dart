import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/hedra_video_batch.dart';

void main() {
  test('parses every Hedra batch result and polling id', () {
    final batch = HedraVideoBatch.fromMap({
      'hedraBatchGenerationId': 'batch-123',
      'hedraBatchSize': 2,
      'hedraBatchResults': [
        {
          'id': 'video-a',
          'status': 'completed',
          'videoUrl': 'https://example.test/a.mp4',
        },
        {'id': 'video-b', 'status': 'processing'},
      ],
    });

    expect(batch.isBatch, isTrue);
    expect(batch.isPending, isTrue);
    expect(batch.generationIds, ['video-a', 'video-b']);
    expect(batch.videoUrls, ['https://example.test/a.mp4']);
  });

  test('keeps the legacy single-video response compatible', () {
    final batch = HedraVideoBatch.fromMap({
      'hedraGenerationId': 'legacy-id',
      'generatedVideoUrl': 'https://example.test/legacy.mp4',
      'videoStatus': 'completed',
    });

    expect(batch.isBatch, isFalse);
    expect(batch.requestedSize, 1);
    expect(batch.generationIds, ['legacy-id']);
    expect(batch.videoUrls, ['https://example.test/legacy.mp4']);
  });

  test('parses persisted JSON batch results from history rows', () {
    final batch = HedraVideoBatch.fromMap({
      'batch_generation_id': 'persisted-batch',
      'batch_size': 8,
      'batch_results':
          '[{"id":"video-1","status":"completed","video_url":"https://example.test/1.mp4"}]',
    });

    expect(batch.requestedSize, 8);
    expect(batch.batchGenerationId, 'persisted-batch');
    expect(batch.videoUrls, ['https://example.test/1.mp4']);
  });
}
