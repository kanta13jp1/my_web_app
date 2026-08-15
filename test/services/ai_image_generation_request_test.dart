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

  test('builds a structured prompt in a stable labeled order', () {
    final prompt = const AiImageStructuredPrompt(
      sceneAndSubject: 'a small robot arranging notebooks',
      detailsAndStyle: 'flat editorial illustration, teal and coral',
      constraints: 'preserve the desk layout, avoid extra fingers',
      imageText: 'daily reset',
    ).buildPrompt();

    expect(
      prompt,
      'Scene and subject:\n'
      'a small robot arranging notebooks\n\n'
      'Details and style:\n'
      'flat editorial illustration, teal and coral\n\n'
      'Constraints to preserve or avoid:\n'
      'preserve the desk layout, avoid extra fingers\n\n'
      'Image text:\n'
      '"DAILY RESET" in clean, readable typography.',
    );
  });
}
