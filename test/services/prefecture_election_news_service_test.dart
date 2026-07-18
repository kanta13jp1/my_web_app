import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/prefecture_election_news_service.dart';

void main() {
  group('normalizePrefectureKey', () {
    test('長形式 (都/府/県 付き) を短形式へ正規化する', () {
      expect(
        PrefectureElectionNewsService.normalizePrefectureKey('宮崎県'),
        '宮崎',
      );
      expect(
        PrefectureElectionNewsService.normalizePrefectureKey('東京都'),
        '東京',
      );
      expect(
        PrefectureElectionNewsService.normalizePrefectureKey('大阪府'),
        '大阪',
      );
      expect(
        PrefectureElectionNewsService.normalizePrefectureKey('神奈川県'),
        '神奈川',
      );
    });

    test('DB 格納の短形式はそのまま維持する (京都 を 京 に潰さない)', () {
      expect(
        PrefectureElectionNewsService.normalizePrefectureKey('宮崎'),
        '宮崎',
      );
      expect(
        PrefectureElectionNewsService.normalizePrefectureKey('京都'),
        '京都',
      );
      expect(
        PrefectureElectionNewsService.normalizePrefectureKey('京都府'),
        '京都',
      );
    });

    test('北海道は suffix を落とさない', () {
      expect(
        PrefectureElectionNewsService.normalizePrefectureKey('北海道'),
        '北海道',
      );
    });
  });

  group('groupByPrefecture', () {
    Map<String, dynamic> row(String prefecture, String title) =>
        <String, dynamic>{
          'prefecture': prefecture,
          'news_title': title,
        };

    test('県別に振り分け、announced_at 降順の先頭 3 件のみ保持する', () {
      final grouped = PrefectureElectionNewsService.groupByPrefecture([
        row('宮崎', 'news-1'),
        row('北海道', 'hokkaido-1'),
        row('宮崎', 'news-2'),
        row('宮崎', 'news-3'),
        row('宮崎', 'news-4'),
        row('大阪', 'osaka-1'),
      ]);

      expect(grouped['宮崎']!.map((r) => r['news_title']), [
        'news-1',
        'news-2',
        'news-3',
      ]);
      expect(grouped['北海道']!.single['news_title'], 'hokkaido-1');
      expect(grouped['大阪']!.single['news_title'], 'osaka-1');
    });

    test('prefecture 空の行は捨てる', () {
      final grouped = PrefectureElectionNewsService.groupByPrefecture([
        row('', 'dropped'),
        row('宮崎', 'kept'),
      ]);
      expect(grouped.keys, ['宮崎']);
    });
  });
}
