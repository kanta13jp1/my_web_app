import 'package:my_web_app/services/ai_university_video_lesson_service.dart';
import 'package:test/test.dart';

void main() {
  test('supplemental video rows restore every unique published lesson', () {
    Map<String, dynamic> row(String category, {String? title}) => {
          'provider': 'openai',
          'category': category,
          'title': title ?? category,
          'content': 'lesson',
          'source_url': 'https://www.youtube.com/watch?v=-ZxiEPqxKRY',
        };

    final merged =
        AiUniversityVideoLessonService.mergeContentRowsByProviderCategory(
      [
        row('overview'),
        row('video_codex_solution_engineering'),
        row('video_codex_custom_code_review_rules', title: 'stale title'),
      ],
      [
        row('video_codex_record_replay'),
        row('video_codex_customer_demo'),
        row('video_codex_ios_xcodebuildmcp'),
        row('video_codex_solution_engineering'),
        row('video_codex_custom_code_review_rules', title: 'current title'),
      ],
    );

    final videoRows = merged
        .where((item) => (item['category'] as String).startsWith('video_'))
        .toList();

    expect(videoRows, hasLength(5));
    expect(merged, hasLength(6));
    expect(
      videoRows.singleWhere(
        (item) => item['category'] == 'video_codex_custom_code_review_rules',
      )['title'],
      'current title',
    );
  });

  test('topicsFromRows sorts overview before api', () {
    final topics = AiUniversityVideoLessonService.topicsFromRows([
      {
        'provider': 'hedra',
        'category': 'api',
        'title': 'API',
        'content': 'api content',
      },
      {
        'provider': 'hedra',
        'category': 'overview',
        'title': 'Overview',
        'content': 'overview content',
      },
    ]);

    expect(topics.map((topic) => topic.category).toList(), [
      'overview',
      'api',
    ]);
  });

  test('pickInitialTopic prefers overview', () {
    const apiTopic = AiUniversityVideoLessonTopic(
      provider: 'hedra',
      category: 'api',
      title: 'API',
      content: 'api content',
    );
    const overviewTopic = AiUniversityVideoLessonTopic(
      provider: 'hedra',
      category: 'overview',
      title: 'Overview',
      content: 'overview content',
    );

    final selected = AiUniversityVideoLessonService.pickInitialTopic([
      apiTopic,
      overviewTopic,
    ]);

    expect(selected, overviewTopic);
  });

  test('youtubeVideoIdFromUrl supports common YouTube URLs', () {
    const videoId = '-ZxiEPqxKRY';

    expect(
      AiUniversityVideoLessonService.youtubeVideoIdFromUrl(
        'https://www.youtube.com/watch?v=$videoId',
      ),
      videoId,
    );
    expect(
      AiUniversityVideoLessonService.youtubeVideoIdFromUrl(
        'https://youtu.be/$videoId?t=12',
      ),
      videoId,
    );
    expect(
      AiUniversityVideoLessonService.youtubeVideoIdFromUrl(
        'https://www.youtube.com/embed/$videoId',
      ),
      videoId,
    );
    expect(
      AiUniversityVideoLessonService.youtubeVideoIdFromUrl(
        'https://example.com/watch?v=$videoId',
      ),
      isNull,
    );
  });

  test('topic exposes YouTube video id and video category label', () {
    const topic = AiUniversityVideoLessonTopic(
      provider: 'openai',
      category: 'video_codex_record_replay',
      title: 'Codex Record & Replay',
      content: '一度見せた作業を再利用可能なスキルとして保存する方法を学ぶ。',
      sourceUrl: 'https://youtu.be/-ZxiEPqxKRY',
    );

    expect(topic.youtubeVideoId, '-ZxiEPqxKRY');
    expect(
      AiUniversityVideoLessonService.categoryLabel(topic.category),
      '動画レッスン',
    );
  });

  test('buildPrompt includes provider title and clipped source', () {
    final topic = AiUniversityVideoLessonTopic(
      provider: 'hedra',
      category: 'overview',
      title: 'Character-3',
      content: '# Heading\n${'a' * 2200}',
    );

    final prompt = AiUniversityVideoLessonService.buildPrompt(
      providerLabel: 'Hedra AI',
      topic: topic,
    );

    expect(prompt, contains('Hedra AI'));
    expect(prompt, contains('Character-3'));
    expect(prompt, isNot(contains('# Heading')));
    expect(prompt.length, lessThan(2600));
  });

  test('buildHeyGenV3Plan creates five scenes and copy text', () {
    const topic = AiUniversityVideoLessonTopic(
      provider: 'heygen',
      category: 'api',
      title: 'HeyGen API',
      content:
          'HeyGen API can generate avatar videos and translate videos into many languages. It is useful for product education.',
    );

    final plan = AiUniversityVideoLessonService.buildHeyGenV3Plan(
      providerLabel: 'HeyGen',
      topic: topic,
    );

    expect(plan.title, contains('HeyGen AI大学 v3'));
    expect(plan.scenes, hasLength(5));
    expect(plan.heygenBrief, contains('HeyGen Avatar V'));
    expect(plan.localizationNotes, isNotEmpty);
    expect(plan.clipboardText, contains('Learning goal'));
  });

  test('buildHeyGenV3Prompt adds HeyGen video constraints', () {
    const topic = AiUniversityVideoLessonTopic(
      provider: 'openai',
      category: 'overview',
      title: 'Overview',
      content:
          'OpenAI provides models for reasoning, coding, multimodal understanding, and agents.',
    );

    final prompt = AiUniversityVideoLessonService.buildHeyGenV3Prompt(
      providerLabel: 'OpenAI',
      topic: topic,
    );

    expect(prompt, contains('HeyGen Avatar V'));
    expect(prompt, contains('5シーン構成'));
    expect(prompt, contains('OpenAI'));
  });
}
