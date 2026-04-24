import 'package:my_web_app/services/heygen_blog_video_service.dart';
import 'package:test/test.dart';

void main() {
  test('buildPlan creates a five scene HeyGen brief from blog metadata', () {
    final plan = HeyGenBlogVideoService.buildPlan(
      title: 'Flutter WebのCI改善',
      excerpt: 'flutter analyzeを安定させるために、対象ファイルを分けて検証し、CIの失敗原因を早く切り分ける。',
      draftPath: 'docs/blog-drafts/flutter-ci.md',
      targetPlatforms: const ['Qiita', 'Zenn', 'X Article'],
    );

    expect(plan.title, contains('Flutter WebのCI改善'));
    expect(plan.productionBrief, contains('HeyGen Avatar V'));
    expect(plan.scenes, hasLength(5));
    expect(plan.scenes.first.label, 'Hook');
    expect(plan.shortPost, contains('#HeyGen'));
    expect(plan.clipboardText, contains('Reuse checklist'));
  });

  test('buildPlan falls back gracefully when only title exists', () {
    final plan = HeyGenBlogVideoService.buildPlan(title: '短い記事');

    expect(plan.sourceSummary, contains('短い記事'));
    expect(plan.scenes[2].narration, contains('短い記事'));
    expect(plan.reuseChecklist, isNotEmpty);
  });
}
