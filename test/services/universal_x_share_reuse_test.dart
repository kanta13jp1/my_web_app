import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/universal_x_share_service.dart';

Map<String, dynamic> row({
  String status = 'video_ready',
  String lang = 'ja',
  String type = 'presenter_video',
  String? url =
      'https://smmkxxavexumewbfaqpy.supabase.co/storage/v1/object/public/viral-ad-videos/hedra/2026-07-06/abc-ai_secretary_site_tour-ja-captioned.mp4',
  String createdAt = '2026-07-06T12:00:00+00:00',
  String templateKey = 'ai_secretary_site_tour',
  String script = 'ニュースを判断材料に変える視点で整理します。',
  String? videoReason,
}) {
  return <String, dynamic>{
    'status': status,
    'lang': lang,
    'type': type,
    'generated_video_url': url,
    'created_at': createdAt,
    'template_key': templateKey,
    'script': script,
    if (videoReason != null) 'video_reason': videoReason,
  };
}

void main() {
  // 2026-07-07 09:00 JST 相当。
  final nowJst = DateTime.utc(2026, 7, 7, 0, 0).add(const Duration(hours: 9));
  const template = 'ai_secretary_site_tour';

  group('selectReusableVideo', () {
    test('prefers same-day over older captioned videos', () {
      final picked = UniversalXShareService.selectReusableVideo(
        [
          row(
            createdAt: '2026-07-05T10:00:00+00:00',
            url: 'https://x.co/storage/viral-ad-videos/a-captioned.mp4',
          ),
          row(
            createdAt: '2026-07-06T23:00:00+00:00', // 7/7 08:00 JST = 同日
            url: 'https://x.co/storage/viral-ad-videos/b.mp4',
          ),
        ],
        nowJst: nowJst,
        templateKey: template,
      );
      expect(picked, isNotNull);
      expect(picked!.sameDay, isTrue);
      expect(picked.url, contains('/b.mp4'));
    });

    test('prefers captioned within the same day', () {
      final picked = UniversalXShareService.selectReusableVideo(
        [
          row(
            createdAt: '2026-07-06T22:00:00+00:00',
            url: 'https://x.co/storage/viral-ad-videos/plain.mp4',
          ),
          row(
            createdAt: '2026-07-06T21:00:00+00:00',
            url: 'https://x.co/storage/viral-ad-videos/sub-captioned.mp4',
          ),
        ],
        nowJst: nowJst,
        templateKey: template,
      );
      expect(picked!.url, contains('-captioned'));
      expect(picked.captioned, isTrue);
    });

    test('excludes videos older than the freshness cap', () {
      final picked = UniversalXShareService.selectReusableVideo(
        [
          row(
            createdAt: '2026-06-28T12:00:00+00:00', // 9日前
            url: 'https://x.co/storage/viral-ad-videos/old-captioned.mp4',
          ),
        ],
        nowJst: nowJst,
        templateKey: template,
      );
      expect(picked, isNull);
    });

    test('excludes ephemeral (non-durable) and non-ja rows', () {
      final picked = UniversalXShareService.selectReusableVideo(
        [
          row(
            // Hedra 一時URL(永続化失敗) = /viral-ad-videos/ マーカーなし。
            url: 'https://hedra-api-video.s3.amazonaws.com/tmp/x.mp4',
          ),
          row(
            lang: 'en',
            url: 'https://x.co/storage/viral-ad-videos/en-captioned.mp4',
          ),
          row(status: 'processing'),
        ],
        nowJst: nowJst,
        templateKey: template,
      );
      expect(picked, isNull);
    });

    test('deprioritizes scripts that speak an explicit date', () {
      final picked = UniversalXShareService.selectReusableVideo(
        [
          row(
            createdAt: '2026-07-05T10:00:00+00:00',
            url: 'https://x.co/storage/viral-ad-videos/dated.mp4',
            script: '7月5日のニュースです。',
          ),
          row(
            createdAt: '2026-07-05T09:00:00+00:00',
            url: 'https://x.co/storage/viral-ad-videos/undated.mp4',
          ),
        ],
        nowJst: nowJst,
        templateKey: template,
      );
      expect(picked!.url, contains('/undated.mp4'));
    });

    test('returns null for empty or unparsable rows', () {
      expect(
        UniversalXShareService.selectReusableVideo(
          [row(createdAt: 'not-a-date')],
          nowJst: nowJst,
          templateKey: template,
        ),
        isNull,
      );
      expect(
        UniversalXShareService.selectReusableVideo(
          const [],
          nowJst: nowJst,
          templateKey: template,
        ),
        isNull,
      );
    });
  });

  group('shouldSkipVideoGeneration', () {
    final nowUtc = DateTime.utc(2026, 7, 7, 0, 0);
    const billingReason = 'Hedra のクレジットが不足しています（必要 119 / 残り 68）。';

    test('true when a recent billing failure has no later success', () {
      final skip = UniversalXShareService.shouldSkipVideoGeneration(
        [
          row(
            status: 'fallback_text',
            url: null,
            createdAt: '2026-07-06T16:00:00+00:00', // 8時間前
            videoReason: billingReason,
          ),
        ],
        nowUtc: nowUtc,
      );
      expect(skip, isTrue);
    });

    test('false when the billing failure is older than the TTL', () {
      final skip = UniversalXShareService.shouldSkipVideoGeneration(
        [
          row(
            status: 'fallback_text',
            url: null,
            createdAt: '2026-07-05T22:00:00+00:00', // 26時間前
            videoReason: billingReason,
          ),
        ],
        nowUtc: nowUtc,
      );
      expect(skip, isFalse);
    });

    test('false when a success happened after the billing failure', () {
      final skip = UniversalXShareService.shouldSkipVideoGeneration(
        [
          row(
            status: 'fallback_text',
            url: null,
            createdAt: '2026-07-06T16:00:00+00:00',
            videoReason: billingReason,
          ),
          row(createdAt: '2026-07-06T20:00:00+00:00'), // その後の video_ready
        ],
        nowUtc: nowUtc,
      );
      expect(skip, isFalse);
    });

    test('false for non-billing failures or empty history', () {
      expect(
        UniversalXShareService.shouldSkipVideoGeneration(
          [
            row(
              status: 'fallback_text',
              url: null,
              createdAt: '2026-07-06T16:00:00+00:00',
              videoReason: 'Hedra video is not complete yet',
            ),
          ],
          nowUtc: nowUtc,
        ),
        isFalse,
      );
      expect(
        UniversalXShareService.shouldSkipVideoGeneration(
          const [],
          nowUtc: nowUtc,
        ),
        isFalse,
      );
    });
  });

  test('fetchReusableVideo never throws (returns null on fetcher failure)',
      () async {
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async => {'success': true},
      historyFetcher: () async => throw Exception('network down'),
    );
    final reused = await service.fetchReusableVideo(
      context: const UniversalSharePageContext(
        routePath: '/gemini-university',
        title: 'Gemini University',
        url: 'https://my-web-app-b67f4.web.app/gemini-university',
      ),
    );
    expect(reused, isNull);
  });
}
