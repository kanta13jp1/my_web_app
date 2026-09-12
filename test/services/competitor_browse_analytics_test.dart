import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/competitor_browse_analytics.dart';

void main() {
  group('CompetitorBrowseAnalytics', () {
    test('tracks browse view and search events', () {
      final events = <Map<String, dynamic>>[];
      final analytics = CompetitorBrowseAnalytics(
        onTrack: (name, props) {
          events.add(<String, dynamic>{'event': name, ...props});
        },
      );

      analytics.trackBrowseView(
        totalCompetitorsCount: 174,
        initialCategory: 'ai-coding',
      );
      analytics.trackSearchUsed(
        query: 'Claude Code',
        resultsCount: 3,
      );

      expect(events.length, 2);
      expect(events[0]['event'], 'competitor_browse_view');
      expect(events[0]['total_competitors_count'], 174);
      expect(events[0]['category'], 'ai-coding');

      expect(events[1]['event'], 'competitor_search_used');
      expect(events[1]['query_length_bucket'], 15);
      expect(events[1]['results_count'], 3);
      expect(events[1]['is_zero_result'], false);
    });

    test('tracks filter and card clicked events', () {
      final events = <Map<String, dynamic>>[];
      final analytics = CompetitorBrowseAnalytics(
        onTrack: (name, props) {
          events.add(<String, dynamic>{'event': name, ...props});
        },
      );

      analytics.trackFilterChanged(
        filterType: 'japan_presence',
        filterValue: 'high',
        filteredResultsCount: 42,
      );
      analytics.trackCompetitorCardClicked(
        competitorKey: 'notion',
        destinationRoute: '/vs-notion',
      );

      expect(events.length, 2);
      expect(events[0]['event'], 'competitor_filter_changed');
      expect(events[0]['filter_type'], 'japan_presence');
      expect(events[0]['filter_value'], 'high');
      expect(events[0]['filtered_results_count'], 42);

      expect(events[1]['event'], 'competitor_card_clicked');
      expect(events[1]['competitor_key'], 'notion');
      expect(events[1]['destination_route'], '/vs-notion');
    });
  });
}
