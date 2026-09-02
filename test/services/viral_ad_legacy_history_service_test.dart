import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/viral_ad_legacy_history_service.dart';

void main() {
  test('旧動画広告の hub_data metadata を履歴表示へ変換する', () {
    final entries = ViralAdLegacyHistoryService.parseVideoAdResponse({
      'items': [
        {
          'id': 'video-ad-1',
          'created_at': '2026-08-20T10:00:00Z',
          'metadata': {
            'title': '夏の新商品',
            'platform': 'tiktok',
            'status': 'ready',
          },
        },
      ],
    });

    expect(entries, hasLength(1));
    expect(entries.single.id, 'video-ad-1');
    expect(entries.single.title, '夏の新商品');
    expect(entries.single.detail, 'tiktok');
    expect(entries.single.status, 'ready');
    expect(entries.single.sourceLabel, '旧 動画広告');
  });

  test('旧バイラル動画の欠損項目を安全な表示へフォールバックする', () {
    final entries = ViralAdLegacyHistoryService.parseViralVideoResponse({
      'briefs': [
        {
          'id': 'viral-video-1',
          'created_at': '2026-08-19T09:00:00Z',
          'metadata': {'style': 'short_reel'},
        },
      ],
    });

    expect(entries, hasLength(1));
    expect(entries.single.title, 'バイラル動画ブリーフ');
    expect(entries.single.detail, 'short_reel');
    expect(entries.single.status, 'draft');
    expect(entries.single.sourceLabel, '旧 バイラル動画');
  });

  test('想定外レスポンスは空履歴として扱う', () {
    expect(
      ViralAdLegacyHistoryService.parseVideoAdResponse({'items': 'invalid'}),
      isEmpty,
    );
    expect(ViralAdLegacyHistoryService.parseViralVideoResponse(null), isEmpty);
  });
}
