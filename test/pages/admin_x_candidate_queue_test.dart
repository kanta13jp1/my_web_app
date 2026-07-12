import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/admin_x_candidate_queue.dart';

void main() {
  group('R26 xTrackerSeriesLabel', () {
    test('maps known tracker variants to JP series labels', () {
      expect(xTrackerSeriesLabel('local_election_tally'), '選挙集計(全文)');
      expect(
        xTrackerSeriesLabel('member_delta_national_progress'),
        '選挙: 議員数増減',
      );
      expect(xTrackerSeriesLabel('household_tracker'), '家計トラッカー');
      expect(xTrackerSeriesLabel('weekly_data_report'), 'X運用実測');
    });

    test('collapses daily_briefing variants and passes unknown through', () {
      expect(
        xTrackerSeriesLabel('daily_briefing_v2_numbers'),
        'デイリーブリーフィング',
      );
      // 未知 variant は隠さず raw 表示=新系列の追い漏れに気づける。
      expect(xTrackerSeriesLabel('new_series_x'), 'new_series_x');
      expect(xTrackerSeriesLabel(''), '(variant未設定)');
    });
  });

  group('R26 parseXPostCandidates', () {
    List<Map<String, dynamic>> rows() => [
          {
            'id': 'aaa-1',
            'created_at': '2026-07-12T01:00:00Z',
            'metadata': {
              'status': 'pending_approval',
              'candidate_type': 'local_election_delta',
              'variant': 'member_delta_national_progress',
              'content_archetype': 'data_report',
              'text': '【国民民主党・地方議員データ更新】\n公式掲載の地方議員は 378→381人（+3）。',
              'reply_texts': <String>[],
              'generated_at': '2026-07-12T01:00:00Z',
            },
          },
          {
            'id': 'bbb-2',
            'created_at': '2026-07-12T03:00:00Z',
            'metadata': {
              'status': 'pending_approval',
              'candidate_type': 'daily_briefing_thread',
              'variant': 'daily_briefing_v2_deep',
              'content_archetype': 'news_briefing',
              'text': 'デイリーブリーフィング本文',
              'reply_texts': ['r1', 'r2', 'r3'],
              'generated_at': '2026-07-12T03:00:00Z',
            },
          },
          // 壊れた行: text 欠落 → 捨てる。
          {
            'id': 'ccc-3',
            'metadata': {'status': 'pending_approval'},
          },
          // 壊れた行: metadata 型不正 → 捨てる。
          {'id': 'ddd-4', 'metadata': 'nope'},
        ];

    test('parses valid rows, drops broken ones, sorts newest first', () {
      final parsed = parseXPostCandidates(rows());
      expect(parsed.length, 2);
      expect(parsed[0].id, 'bbb-2');
      expect(parsed[0].replyCount, 3);
      expect(parsed[0].seriesLabel, 'デイリーブリーフィング');
      expect(parsed[1].id, 'aaa-1');
      expect(parsed[1].archetype, 'data_report');
      expect(parsed[1].isPendingApproval, isTrue);
      expect(parsed[1].seriesLabel, '選挙: 議員数増減');
    });

    test('non-list input degrades to empty', () {
      expect(parseXPostCandidates(null), isEmpty);
      expect(parseXPostCandidates('x'), isEmpty);
    });
  });

  group('R26 preview and age labels', () {
    test('candidatePreviewText flattens newlines and truncates', () {
      expect(candidatePreviewText('a\n\nb   c'), 'a b c');
      final long = 'あ' * 300;
      final preview = candidatePreviewText(long, maxChars: 10);
      expect(preview.length, 10);
      expect(preview.endsWith('…'), isTrue);
    });

    test('candidateAgeLabel buckets hours and days, hides unparseable', () {
      final now = DateTime.parse('2026-07-12T12:00:00Z');
      expect(
        candidateAgeLabel(DateTime.parse('2026-07-12T11:30:00Z'), now),
        '1時間以内',
      );
      expect(
        candidateAgeLabel(DateTime.parse('2026-07-12T05:00:00Z'), now),
        '7時間前',
      );
      expect(
        candidateAgeLabel(DateTime.parse('2026-07-09T05:00:00Z'), now),
        '3日前',
      );
      expect(candidateAgeLabel(null, now), '');
    });
  });

  group('R26 finalize result and outcome message', () {
    test('buildCandidateFinalizeResult mirrors posted success shape', () {
      final result = buildCandidateFinalizeResult({
        'success': true,
        'posted': true,
        'tweetId': 't1',
        'replyTweetId': 'r1',
        'replyTweetIds': ['r1'],
        'log': {'id': 'log-1'},
      });
      expect(result['posted'], isTrue);
      expect(result['tweetId'], 't1');
      expect(result['logId'], 'log-1');
      expect(result.containsKey('code'), isFalse);
    });

    test('buildCandidateFinalizeResult mirrors duplicate rejection shape', () {
      final result = buildCandidateFinalizeResult({
        'success': false,
        'posted': false,
        'code': 'duplicate_content',
      });
      expect(result['posted'], isFalse);
      expect(result['code'], 'duplicate_content');
      expect(result.containsKey('tweetId'), isFalse);
    });

    test('candidatePublishOutcomeMessage distinguishes 3 outcomes', () {
      expect(
        candidatePublishOutcomeMessage({'posted': true}),
        contains('計測対象'),
      );
      expect(
        candidatePublishOutcomeMessage({
          'posted': false,
          'code': 'duplicate_content',
        }),
        contains('近似重複'),
      );
      expect(
        candidatePublishOutcomeMessage({
          'posted': false,
          'error': 'X API error',
        }),
        contains('X API error'),
      );
    });
  });
}
