import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/legislative_facts_service.dart';
import 'package:my_web_app/widgets/legislative_facts_matrix_card.dart';

void main() {
  group('LegislativeFactsService & LegislativeFactsMatrixCard', () {
    test('rejects invalid or missing sourceUrl and builds matrix', () {
      final service = LegislativeFactsService();

      expect(
        () => service.registerFact(
          const LegislativeFactEntry(
            id: 'bad-1',
            topicKey: 'topic-a',
            factionName: '会派A',
            summary: '出典なし',
            sourceUrl: '',
            sourceTitle: 'なし',
            stance: FactStance.contextual,
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => service.registerFact(
          const LegislativeFactEntry(
            id: 'bad-2',
            topicKey: 'topic-a',
            factionName: '会派A',
            summary: '不正スキーム',
            sourceUrl: 'ftp://example.go.jp/doc',
            sourceTitle: 'FTP',
            stance: FactStance.contextual,
          ),
        ),
        throwsArgumentError,
      );

      service.registerFact(
        const LegislativeFactEntry(
          id: 'f1',
          topicKey: '緊急事態条項',
          factionName: '会派B',
          summary: '現行法制での対応実績を整理。',
          sourceUrl: 'https://example.go.jp/statute-b',
          sourceTitle: '法令資料B',
          stance: FactStance.contextual,
        ),
      );
      service.registerFact(
        const LegislativeFactEntry(
          id: 'f2',
          topicKey: '緊急事態条項',
          factionName: '会派A',
          summary: '任期延長要件の明文化論点を整理。',
          sourceUrl: 'https://example.go.jp/report-a',
          sourceTitle: '委員会報告A',
          stance: FactStance.supporting,
        ),
      );

      final matrix = service.buildComparisonMatrix('緊急事態条項');
      expect(matrix.totalFacts, 2);
      expect(matrix.columns.length, 2);
      expect(matrix.columns[0].factionName, '会派A');
      expect(matrix.columns[1].factionName, '会派B');
    });

    testWidgets(
      'renders cleanly at 2.0x textScale on 360x800 and opens source',
      (WidgetTester tester) async {
        final service = LegislativeFactsService();
        service.registerFact(
          const LegislativeFactEntry(
            id: 'f1',
            topicKey: '地方自治と財源',
            factionName: '会派A',
            summary: '地方交付税の推移データ。',
            sourceUrl: 'https://example.go.jp/local-a',
            sourceTitle: '統計資料A',
            stance: FactStance.supporting,
          ),
        );
        service.registerFact(
          const LegislativeFactEntry(
            id: 'f2',
            topicKey: '地方自治と財源',
            factionName: '会派B',
            summary: '自主財源比率の国際比較。',
            sourceUrl: 'https://example.go.jp/local-b',
            sourceTitle: '比較資料B',
            stance: FactStance.disputed,
          ),
        );

        final matrix = service.buildComparisonMatrix('地方自治と財源');
        final openedUrls = <String>[];

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
                    child: LegislativeFactsMatrixCard(
                      matrix: matrix,
                      onOpenSource: openedUrls.add,
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.text('地方自治と財源'), findsOneWidget);
          expect(find.text('会派A'), findsOneWidget);
          expect(find.text('会派B'), findsOneWidget);
          expect(find.text('出典'), findsNWidgets(2));

          await tester.tap(find.text('出典').first);
          await tester.pump();

          expect(openedUrls, <String>['https://example.go.jp/local-a']);
          expect(errors, isEmpty);
        } finally {
          FlutterError.onError = oldOnError;
        }
      },
    );
  });
}
