import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/campaign_video.dart';

void main() {
  group('CampaignCategory', () {
    test('exposes 禁酒/禁煙/脱・風俗 labels and hashtags', () {
      expect(CampaignCategory.alcohol.label, '禁酒');
      expect(CampaignCategory.tobacco.label, '禁煙');
      expect(CampaignCategory.fuzoku.label, '脱・風俗');
      expect(CampaignCategory.alcohol.hashtag, '#禁酒チャレンジ');
      expect(CampaignCategory.fuzoku.hashtag, '#脱風俗');
    });
  });

  group('CampaignVideo', () {
    test('seed covers all three campaign categories', () {
      final seed = CampaignVideo.seed();
      expect(seed, isNotEmpty);
      final categories = seed.map((v) => v.category).toSet();
      expect(categories, containsAll(CampaignCategory.values));
    });

    test('shareText includes title, caption, hashtag and url', () {
      const video = CampaignVideo(
        id: 'x',
        category: CampaignCategory.alcohol,
        title: 'タイトル',
        caption: 'ほんぶん',
        creatorName: '作者',
        creatorHandle: '@a',
        videoUrl: 'https://example.com/v',
      );
      final text = video.shareText();
      expect(text, contains('タイトル'));
      expect(text, contains('ほんぶん'));
      expect(text, contains('#禁酒チャレンジ'));
      expect(text, contains('https://example.com/v'));
    });

    test('shareText omits url line when videoUrl is null', () {
      const video = CampaignVideo(
        id: 'y',
        category: CampaignCategory.tobacco,
        title: 'T',
        caption: 'C',
        creatorName: 'N',
        creatorHandle: '@n',
      );
      expect(video.shareText(), isNot(contains('http')));
    });

    test('copyWith overrides only likes and reposts', () {
      const video = CampaignVideo(
        id: 'z',
        category: CampaignCategory.fuzoku,
        title: 'T',
        caption: 'C',
        creatorName: 'N',
        creatorHandle: '@n',
        likes: 10,
        reposts: 2,
      );
      final updated = video.copyWith(likes: 11);
      expect(updated.likes, 11);
      expect(updated.reposts, 2);
      expect(updated.title, 'T');
    });
  });
}
