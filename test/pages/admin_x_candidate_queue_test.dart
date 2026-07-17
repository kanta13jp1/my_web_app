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
      // R27: AIツール動向トラッカー系列(playbook step 4 のラベル登録)。
      expect(xTrackerSeriesLabel('ai_tool_tracker'), 'AIツール定点観測');
      // R28: 両党地力差ランキング系列(playbook step 4)。
      expect(xTrackerSeriesLabel('party_gap_ranking'), '選挙: 両党地力差');
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

    test('actionableCandidates keeps retryable states, drops finished ones',
        () {
      XPostCandidateSummary withStatus(String status) => XPostCandidateSummary(
            id: status,
            status: status,
            candidateType: 't',
            variant: 'household_tracker',
            archetype: 'data_report',
            text: 'x',
            replyTexts: const [],
            generatedAt: null,
          );
      final filtered = actionableCandidates([
        withStatus('pending_approval'),
        withStatus('approved'),
        withStatus('publish_failed'),
        withStatus('posted'),
        withStatus('rejected_duplicate'),
      ]);
      // edge の approve は pending/approved/publish_failed の3状態から可能=
      // 「approve成功→投稿失敗」の候補が再試行面から消えない。
      expect(
        filtered.map((c) => c.status).toList(),
        ['pending_approval', 'approved', 'publish_failed'],
      );
      expect(withStatus('publish_failed').statusLabel, contains('再試行可'));
      expect(withStatus('posted').isActionable, isFalse);
    });
  });

  group('R26 review-fix helpers (F0/F2/F3)', () {
    XPostCandidateSummary make({
      required String id,
      String status = 'pending_approval',
      List<String> replies = const [],
      String? generatedAt,
    }) =>
        XPostCandidateSummary(
          id: id,
          status: status,
          candidateType: 't',
          variant: 'household_tracker',
          archetype: 'data_report',
          text: 'リード本文',
          replyTexts: replies,
          generatedAt:
              generatedAt == null ? null : DateTime.tryParse(generatedAt),
        );

    test('candidateFullReviewText carries EVERY reply body (HITL guarantee)',
        () {
      final full = candidateFullReviewText(
        make(id: 'a', replies: ['リプ1本文', 'リプ2本文']),
      );
      expect(full, contains('リード本文'));
      expect(full, contains('━━ リプライ1/2 ━━'));
      expect(full, contains('リプ1本文'));
      expect(full, contains('━━ リプライ2/2 ━━'));
      expect(full, contains('リプ2本文'));
      // リプ無しはリードのみ(区切りを出さない)。
      expect(candidateFullReviewText(make(id: 'b')), 'リード本文');
    });

    test('mergeCandidateSummaries dedupes by id and sorts newest first', () {
      final merged = mergeCandidateSummaries([
        [make(id: 'old', generatedAt: '2026-07-01T00:00:00Z')],
        [
          make(id: 'new', generatedAt: '2026-07-12T00:00:00Z'),
          make(id: 'old', generatedAt: '2026-07-01T00:00:00Z'),
        ],
      ]);
      expect(merged.map((c) => c.id).toList(), ['new', 'old']);
    });

    test('candidateQueueHeaderLabel separates pending from retry counts', () {
      expect(
        candidateQueueHeaderLabel([
          make(id: 'a'),
          make(id: 'b'),
          make(id: 'c', status: 'publish_failed'),
        ]),
        '承認待ち 2件・再試行 1件',
      );
      expect(
        candidateQueueHeaderLabel([make(id: 'a')]),
        '承認待ち 1件',
      );
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

  group('candidate freshness (stale queue guard)', () {
    final now = DateTime.utc(2026, 7, 17, 0, 0);

    XPostCandidateSummary make({
      String archetype = 'data_report',
      String variant = 'household_tracker',
      DateTime? generatedAt,
    }) =>
        XPostCandidateSummary(
          id: 'id',
          status: 'pending_approval',
          candidateType: 't',
          variant: variant,
          archetype: archetype,
          text: 'x',
          replyTexts: const [],
          generatedAt: generatedAt,
        );

    test('news_briefing expires after 24h', () {
      final fresh = make(
        archetype: 'news_briefing',
        generatedAt: now.subtract(const Duration(hours: 23)),
      );
      final stale = make(
        archetype: 'news_briefing',
        generatedAt: now.subtract(const Duration(hours: 25)),
      );
      expect(isCandidateExpired(fresh, now), isFalse);
      expect(isCandidateExpired(stale, now), isTrue);
    });

    test('data_report expires after 72h', () {
      final fresh = make(
        generatedAt: now.subtract(const Duration(hours: 71)),
      );
      final stale = make(
        generatedAt: now.subtract(const Duration(days: 4)),
      );
      expect(isCandidateExpired(fresh, now), isFalse);
      expect(isCandidateExpired(stale, now), isTrue);
    });

    test('election variants get the 72h window even without archetype', () {
      final stale = make(
        archetype: '',
        variant: 'local_election_schedule_delta',
        generatedAt: now.subtract(const Duration(days: 4)),
      );
      expect(isCandidateExpired(stale, now), isTrue);
      expect(
        candidateFreshnessWindow(stale),
        const Duration(hours: 72),
      );
    });

    test('unknown series falls back to 7 days and null generatedAt never '
        'expires', () {
      final unknown = make(
        archetype: 'product_intro',
        variant: 'brand_new_series',
        generatedAt: now.subtract(const Duration(days: 6)),
      );
      expect(isCandidateExpired(unknown, now), isFalse);
      expect(
        isCandidateExpired(
          make(
            archetype: 'product_intro',
            variant: 'brand_new_series',
            generatedAt: now.subtract(const Duration(days: 8)),
          ),
          now,
        ),
        isTrue,
      );
      expect(isCandidateExpired(make(generatedAt: null), now), isFalse);
    });

    test('rejected status label is defined for the upcoming reject action',
        () {
      const rejected = XPostCandidateSummary(
        id: 'r',
        status: 'rejected',
        candidateType: 't',
        variant: 'household_tracker',
        archetype: 'data_report',
        text: 'x',
        replyTexts: [],
        generatedAt: null,
      );
      expect(rejected.statusLabel, '却下済み');
      expect(rejected.isActionable, isFalse);
    });
  });
}
