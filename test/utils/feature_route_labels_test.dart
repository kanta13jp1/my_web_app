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
      expect(featureLabelForRoute('/release-notes'), 'Release Notes');
    });
  });
}
