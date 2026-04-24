import 'package:my_web_app/services/ai_university_video_lesson_service.dart';
import 'package:test/test.dart';

void main() {
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
