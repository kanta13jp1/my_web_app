import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/ai_university_curated_videos.dart';

void main() {
  test('AI University owns the four videos removed from philosophy', () {
    expect(aiUniversityCuratedVideos, hasLength(4));
    expect(
      aiUniversityCuratedVideos.map((video) => video.id).toSet(),
      <String>{
        'anthropic-claude-apps',
        'google-gemini-life',
        'nomic-aec',
        'multi-agent-convergence',
      },
    );
    expect(
      aiUniversityCuratedVideos.where((video) => video.youtubeVideoId != null),
      hasLength(3),
    );
    for (final video in aiUniversityCuratedVideos) {
      expect(video.title, isNotEmpty);
      expect(video.description, isNot(contains('市場シェア')));
      expect(video.description, isNot(contains('評価額')));
      expect(video.description, isNot(contains('コスト削減率')));
    }
  });
}
