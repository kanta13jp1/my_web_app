import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_video_lesson_service.dart';

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
}
