import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/admin/admin_growth_achievement_summary_card.dart';

void main() {
  group('AdminGrowthAchievementSummaryCard', () {
    testWidgets(
      'shows honest un-connected message when summary lacks metric keys',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminGrowthAchievementSummaryCard(
                  summary: <String, dynamic>{
                    'success': true,
                    'items': <dynamic>[],
                  },
                  loading: false,
                  onRefresh: _noop,
                  onSelectPeriod: _noopSelect,
                ),
              ),
            ),
          ),
        );

        expect(
          find.textContaining('成長サマリーの集計はまだ接続されていません'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders achievement.summary metrics cleanly at 2.0x textScale on 360x800',
      (WidgetTester tester) async {
        String? selectedLabel;
        String? selectedSince;

        final errors = <FlutterErrorDetails>[];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          errors.add(details);
        };

        try {
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: AdminGrowthAchievementSummaryCard(
                      summary: const <String, dynamic>{
                        'success': true,
                        'newUsers': 5,
                        'totalUsersEver': 44,
                        'acquisitionSignals': 12,
                        'referralsCompleted': 2,
                        'importPreviews': 7,
                        'label': '今週',
                      },
                      loading: false,
                      onRefresh: _noop,
                      onSelectPeriod: (String since, String label) {
                        selectedSince = since;
                        selectedLabel = label;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.text('期間: 今週'), findsOneWidget);
          expect(find.text('5人'), findsOneWidget);
          expect(find.text('44人'), findsOneWidget);
          expect(find.text('12件'), findsOneWidget);
          expect(find.text('2件'), findsOneWidget);
          expect(find.text('7件'), findsOneWidget);

          await tester.tap(find.text('今日'));
          await tester.pump();

          expect(selectedLabel, '今日');
          expect(selectedSince, isNotNull);
          expect(selectedSince!.endsWith('Z'), isTrue);
          expect(errors, isEmpty);
        } finally {
          FlutterError.onError = oldOnError;
        }
      },
    );
  });
}

void _noop() {}

void _noopSelect(String since, String label) {}
