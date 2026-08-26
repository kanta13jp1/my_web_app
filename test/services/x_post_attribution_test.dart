import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/x_post_attribution.dart';

void main() {
  test('video takes precedence and receives ai_video attribution', () {
    expect(
      buildViralAdXPostAttribution(
        videoUrl: 'https://cdn.example/video.mp4',
        imageUrl: 'https://cdn.example/image.png',
      ),
      <String, String>{
        'variant': 'ai_video',
        'utmContent': 'ai_video',
        'mediaType': 'video',
      },
    );
  });

  test('image fallback receives ai_image attribution', () {
    expect(
      buildViralAdXPostAttribution(
        videoUrl: '  ',
        imageUrl: 'https://cdn.example/image.png',
      ),
      <String, String>{
        'variant': 'ai_image',
        'utmContent': 'ai_image',
        'mediaType': 'image',
      },
    );
  });

  test('text fallback receives ai_text attribution', () {
    expect(buildViralAdXPostAttribution(), <String, String>{
      'variant': 'ai_text',
      'utmContent': 'ai_text',
      'mediaType': 'text',
    });
  });
}
