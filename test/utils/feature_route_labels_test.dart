import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/feature_route_labels.dart';

void main() {
  group('featureLabelForRoute', () {
    test('system-fixed なルートは日本語ラベルを返す', () {
      // kHomeSystemFixed 由来。Supabase 未初期化でも参照できる。
      expect(featureLabelForRoute('/site-guide-ai'), 'サイト案内AI');
      expect(featureLabelForRoute('/ai-university'), 'AI大学');
      expect(featureLabelForRoute('/release-notes'), 'Release Notes');
    });

    test('未知ルートは slug を Title Case に整形してフォールバックする', () {
      expect(
        featureLabelForRoute('/guitar-recording-studio'),
        'Guitar Recording Studio',
      );
      expect(featureLabelForRoute('/personality-test'), 'Personality Test');
    });

    test('クエリ付きでも path 部分のラベルになる', () {
      expect(
        featureLabelForRoute('/release-notes?from=header'),
        'Release Notes',
      );
    });

    test('旧 route は統合後の日本語ラベルになる', () {
      expect(featureLabelForRoute('/mindmap'), 'マインドマップ');
      expect(featureLabelForRoute('/pomodoro-timer'), '集中タイマー');
      expect(
        featureLabelForRoute('/referral-program?from=legacy'),
        '友達招待・紹介プログラム',
      );
    });
  });

  group('canonicalFeatureRoutePath', () {
    test('重複 route を正規機能へ集約する', () {
      expect(canonicalFeatureRoutePath('/mindmap'), '/mind-map');
      expect(canonicalFeatureRoutePath('/pomodoro-timer'), '/focus-timer');
      expect(canonicalFeatureRoutePath('/referral-program'), '/referral');
      expect(
        canonicalFeatureRoutePath('/social-media-scheduler'),
        '/social-scheduler',
      );
      expect(canonicalFeatureRoutePath('/travel-itinerary'), '/travel-planner');
    });

    test('正規 route と未知 route は変更しない', () {
      expect(canonicalFeatureRoutePath('/focus-timer'), '/focus-timer');
      expect(canonicalFeatureRoutePath('/unknown-feature'), '/unknown-feature');
    });
  });
}
