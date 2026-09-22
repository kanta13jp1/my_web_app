import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/feature_route_labels.dart';

void main() {
  group('featureLabelForRoute', () {
    test('system-fixed なルートは日本語ラベルを返す', () {
      // kHomeSystemFixed 由来。Supabase 未初期化でも参照できる。
      expect(featureLabelForRoute('/site-guide-ai'), 'サイト案内AI');
      expect(featureLabelForRoute('/ai-university'), 'AI大学');
      expect(featureLabelForRoute('/ai-university-toeic'), 'AI大学 TOEIC対策');
      expect(featureLabelForRoute('/release-notes'), 'Release Notes');
      expect(featureLabelForRoute('/procrastination-reset'), '先延ばしリセット');
      expect(
        featureLabelForRoute('/proactive-form-check'),
        '入力チェックアシスタント',
      );
      expect(featureLabelForRoute('/custom-task-list'), 'AI カスタムタスクリスト');
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
      expect(featureLabelForRoute('/video-ad-generator'), 'バイラル広告ジェネレーター');
      expect(featureLabelForRoute('/wip-limit'), '消化してから次へ');
      expect(featureLabelForRoute('/habit-gamification'), '毎日の習慣');
      expect(featureLabelForRoute('/goal-tracker'), '人生目標管理');
      expect(featureLabelForRoute('/stats'), '実績・リワード');
      expect(
        featureLabelForRoute('/ai-summarizer'),
        'AI文章・要約アシスタント',
      );
      expect(
        featureLabelForRoute('/local-election-schedule'),
        '2027 統一地方選 700必達管理室',
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
      expect(
        canonicalFeatureRoutePath('/video-ad-generator'),
        '/viral-ad-generator',
      );
      expect(
        canonicalFeatureRoutePath('/viral-video-generator'),
        '/viral-ad-generator',
      );
      expect(canonicalFeatureRoutePath('/wip-limit'), '/digest-queue');
      expect(canonicalFeatureRoutePath('/habit-gamification'), '/daily-habits');
      expect(canonicalFeatureRoutePath('/goal-tracker'), '/life-goals');
      expect(canonicalFeatureRoutePath('/stats'), '/rewards');
      expect(
        canonicalFeatureRoutePath('/ai-summarizer'),
        '/ai-writing-assistant',
      );
      expect(
        canonicalFeatureRoutePath('/local-election-schedule'),
        '/local-election-700',
      );
    });

    test('正規 route と未知 route は変更しない', () {
      expect(canonicalFeatureRoutePath('/focus-timer'), '/focus-timer');
      expect(canonicalFeatureRoutePath('/unknown-feature'), '/unknown-feature');
    });
  });
}
