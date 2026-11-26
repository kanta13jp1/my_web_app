import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/foreign_institution_ref_service.dart';
import 'package:my_web_app/widgets/foreign_institution_ref_card.dart';

void main() {
  group('ForeignInstitutionRefService & ForeignInstitutionRefCard', () {
    test('validates officialUrl, filters by country, and reverse-looks up', () {
      final service = ForeignInstitutionRefService();

      expect(
        () => service.registerEntry(
          const ForeignInstitutionEntry(
            id: 'bad',
            countryCode: 'DE',
            countryName: 'ドイツ',
            category: InstitutionCategory.oversight,
            title: 'Invalid',
            summary: 'Invalid URL',
            officialUrl: 'ftp://example.org/doc',
            citedSpeechIds: <String>['s1'],
          ),
        ),
        throwsArgumentError,
      );

      service.registerEntry(
        const ForeignInstitutionEntry(
          id: 'de-1',
          countryCode: 'de',
          countryName: 'ドイツ',
          category: InstitutionCategory.oversight,
          title: '基本法115a条',
          summary: '防衛事態における合同委員会の議会統制。',
          officialUrl: 'https://www.gesetze-im-internet.de/englisch_gg/',
          citedSpeechIds: <String>['speech-1', 'speech-2'],
        ),
      );
      service.registerEntry(
        const ForeignInstitutionEntry(
          id: 'gb-1',
          countryCode: 'GB',
          countryName: 'イギリス',
          category: InstitutionCategory.emergencyDecree,
          title: '2004年民間緊急事態法',
          summary: '緊急規則の時限と議会承認要件。',
          officialUrl: 'https://www.legislation.gov.uk/ukpga/2004/36/contents',
          citedSpeechIds: <String>['speech-2'],
        ),
      );

      expect(service.countries, <String>['DE', 'GB']);
      expect(service.filterByCountry('DE').length, 1);
      expect(service.findBySpeechId('speech-2').length, 2);
      expect(service.findBySpeechId('speech-1').single.id, 'de-1');
    });

    testWidgets(
      'filters by country and renders cleanly at 2.0x textScale on 360x800',
      (WidgetTester tester) async {
        final service = ForeignInstitutionRefService();
        service.registerEntry(
          const ForeignInstitutionEntry(
            id: 'de-1',
            countryCode: 'DE',
            countryName: 'ドイツ',
            category: InstitutionCategory.oversight,
            title: '基本法115a条',
            summary: '防衛事態における議会統制。',
            officialUrl: 'https://www.gesetze-im-internet.de/englisch_gg/',
            citedSpeechIds: <String>['speech-1'],
          ),
        );
        service.registerEntry(
          const ForeignInstitutionEntry(
            id: 'gb-1',
            countryCode: 'GB',
            countryName: 'イギリス',
            category: InstitutionCategory.emergencyDecree,
            title: '2004年民間緊急事態法',
            summary: '緊急規則の時限と議会承認。',
            officialUrl:
                'https://www.legislation.gov.uk/ukpga/2004/36/contents',
            citedSpeechIds: <String>['speech-2'],
          ),
        );

        final opened = <String>[];
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
                    child: ForeignInstitutionRefCard(
                      entries: service.filterByCountry(),
                      onOpenOfficialUrl: opened.add,
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.text('ドイツ (議会統制)'), findsOneWidget);
          expect(find.text('イギリス (緊急政令)'), findsOneWidget);

          await tester.tap(find.text('DE'));
          await tester.pump();

          expect(find.text('ドイツ (議会統制)'), findsOneWidget);
          expect(find.text('イギリス (緊急政令)'), findsNothing);

          await tester.tap(find.text('参照'));
          await tester.pump();

          expect(
            opened,
            <String>['https://www.gesetze-im-internet.de/englisch_gg/'],
          );
          expect(errors, isEmpty);
        } finally {
          FlutterError.onError = oldOnError;
        }
      },
    );
  });
}
