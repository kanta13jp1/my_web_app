import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_image_generation_request.dart';

void main() {
  test('builds image.generate body with selected quality', () {
    final body = buildAiImageGenerateBody(
      prompt: 'watercolor mountain calendar',
      size: '1024x1024',
      style: 'natural',
      quality: AiImageGenerationQuality.high,
    );

    expect(body['action'], 'image.generate');
    expect(body['prompt'], 'watercolor mountain calendar');
    expect(body['size'], '1024x1024');
    expect(body['style'], 'natural');
    expect(body['quality'], 'high');
  });

  test('falls back to medium for unknown stored quality values', () {
    expect(
      AiImageGenerationQuality.fromValue('unexpected'),
      AiImageGenerationQuality.medium,
    );
  });
}
