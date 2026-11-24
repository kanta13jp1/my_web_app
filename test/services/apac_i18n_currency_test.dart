import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/apac_i18n_currency_service.dart';
import 'package:my_web_app/widgets/apac_locale_currency_panel.dart';

RegionalDocumentMetadata _createVerifiedJpyDocument() {
  return const RegionalDocumentMetadata(
    id: 'doc-jp-verified-1',
    userId: 'user-apac-1',
    title: '日本本社 確定財務ベースドキュメント',
    targetRegion: 'JP',
    contentLocale: 'ja-JP',
    baseCurrencyCode: 'JPY',
    amountMinorOrDecimal: 1000000,
    fxRequiresVerification: false,
  );
}

RegionalDocumentMetadata _createUnverifiedApacDocument() {
  return const RegionalDocumentMetadata(
    id: 'doc-sg-fx-2',
    userId: 'user-apac-1',
    title: 'ASEAN 子会社買収バリュエーション試算',
    targetRegion: 'SG',
    contentLocale: 'en-SG',
    baseCurrencyCode: 'SGD',
    amountMinorOrDecimal: 250000.50,
    fxRequiresVerification: true,
    verificationNote: 'MAS公式日次仲値で要再照合',
  );
}

void main() {
  group('ApacI18nCurrencyService & RegionalDocumentMetadata (#2594)', () {
    test(
      'formats all supported APAC currencies via intl NumberFormat.currency',
      () {
        final jpy = ApacI18nCurrencyService.formatCurrency(
          amount: 1250000,
          currencyCode: 'JPY',
          localeTag: 'ja-JP',
        ).replaceAll('\u00a0', ' ');
        final sgd = ApacI18nCurrencyService.formatCurrency(
          amount: 1250.5,
          currencyCode: 'SGD',
          localeTag: 'en-SG',
        ).replaceAll('\u00a0', ' ');
        final aud = ApacI18nCurrencyService.formatCurrency(
          amount: 1250.5,
          currencyCode: 'AUD',
          localeTag: 'en-AU',
        ).replaceAll('\u00a0', ' ');
        final usd = ApacI18nCurrencyService.formatCurrency(
          amount: 1250.5,
          currencyCode: 'USD',
          localeTag: 'en-SG',
        ).replaceAll('\u00a0', ' ');
        final idr = ApacI18nCurrencyService.formatCurrency(
          amount: 1250000,
          currencyCode: 'IDR',
          localeTag: 'id-ID',
        ).replaceAll('\u00a0', ' ');
        final vnd = ApacI18nCurrencyService.formatCurrency(
          amount: 1250000,
          currencyCode: 'VND',
          localeTag: 'vi-VN',
        ).replaceAll('\u00a0', ' ');
        final thb = ApacI18nCurrencyService.formatCurrency(
          amount: 1250.5,
          currencyCode: 'THB',
          localeTag: 'th-TH',
        ).replaceAll('\u00a0', ' ');

        expect(jpy, '¥1,250,000');
        expect(sgd, contains('S\$'));
        expect(sgd, contains('1,250.50'));
        expect(aud, contains('A\$'));
        expect(aud, contains('1,250.50'));
        expect(usd, contains('US\$'));
        expect(usd, contains('1,250.50'));
        expect(idr, contains('Rp'));
        expect(idr, contains('1.250.000'));
        expect(vnd, contains('₫'));
        expect(vnd, contains('1.250.000'));
        expect(thb, contains('฿'));
        expect(thb, contains('1,250.50'));
      },
    );

    test(
      'ApacLocaleNotifier switches locales and notifies listeners cleanly',
      () {
        final notifier = ApacLocaleNotifier();
        addTearDown(notifier.dispose);

        var notifications = 0;
        notifier.addListener(() {
          notifications += 1;
        });

        expect(notifier.localeTag, 'ja-JP');
        expect(notifier.targetRegion, 'JP');
        expect(notifier.currencyCode, 'JPY');
        expect(notifier.flutterLocale, const Locale('ja', 'JP'));
        expect(notifier.strings.panelTitle, 'APAC 多言語・多通貨データ基盤');

        notifier.setLocale('en-SG');
        expect(notifications, 1);
        expect(notifier.localeTag, 'en-SG');
        expect(notifier.targetRegion, 'SG');
        expect(notifier.currencyCode, 'SGD');
        expect(notifier.flutterLocale, const Locale('en', 'SG'));
        expect(
          notifier.strings.panelTitle,
          'APAC Multi-Locale & Currency Foundation',
        );

        notifier.setLocale('id-ID');
        expect(notifications, 2);
        expect(notifier.localeTag, 'id-ID');
        expect(notifier.targetRegion, 'ID');
        expect(notifier.currencyCode, 'IDR');
        expect(
          notifier.strings.panelTitle,
          'Fondasi Multi-Bahasa & Multi-Mata Uang APAC',
        );

        // Preserve current currency/region when syncRegionAndCurrency is false
        notifier.setLocale('ja-JP', syncRegionAndCurrency: false);
        expect(notifications, 3);
        expect(notifier.localeTag, 'ja-JP');
        expect(notifier.currencyCode, 'IDR');
        expect(notifier.targetRegion, 'ID');

        notifier.setCurrency('AUD');
        notifier.setTargetRegion('AU');
        notifier.setFinancialEstimate(enabled: true);
        expect(notifications, 6);
        expect(notifier.currencyCode, 'AUD');
        expect(notifier.targetRegion, 'AU');
        expect(notifier.isFinancialEstimate, isTrue);
      },
    );

    test(
      'RegionalDocumentMetadata round-trips JSON and enforces FX checks',
      () {
        final parsed =
            RegionalDocumentMetadata.fromJson(const <String, dynamic>{
          'id': 'doc-42',
          'user_id': 'user-99',
          'title': 'タイ拠点評価レポート',
          'target_region': 'TH',
          'content_locale': 'th-TH',
          'base_currency_code': 'THB',
          'amount_minor_or_decimal': '985000.25',
          'fx_requires_verification': true,
          'verification_note': 'BOT公開レート確認待ち',
          'created_at': '2026-11-24T01:00:00Z',
        });

        expect(parsed.id, 'doc-42');
        expect(parsed.targetRegion, 'TH');
        expect(parsed.contentLocale, 'th-TH');
        expect(parsed.baseCurrencyCode, 'THB');
        expect(parsed.amountMinorOrDecimal, 985000.25);
        expect(parsed.fxRequiresVerification, isTrue);
        expect(parsed.isVerifiedBaseJpy, isFalse);

        final jsonOut = parsed.toJson();
        expect(jsonOut['target_region'], 'TH');
        expect(jsonOut['content_locale'], 'th-TH');
        expect(jsonOut['base_currency_code'], 'THB');
        expect(jsonOut['fx_requires_verification'], isTrue);

        final notePayload = parsed.toNoteMetadataPayload();
        expect(
          notePayload.keys,
          const <String>[
            'target_region',
            'content_locale',
            'base_currency_code',
            'fx_requires_verification',
          ],
        );

        final fallback =
            RegionalDocumentMetadata.fromJson(const <String, dynamic>{
          'id': 'doc-fallback',
          'user_id': 'user-1',
          'title': '未定義地域テスト',
          'target_region': 'UNKNOWN',
          'content_locale': 'zz-ZZ',
          'base_currency_code': 'ZZZ',
        });
        expect(fallback.targetRegion, 'JP');
        expect(fallback.contentLocale, 'ja-JP');
        expect(fallback.baseCurrencyCode, 'JPY');
        expect(fallback.fxRequiresVerification, isTrue);

        expect(
          ApacI18nCurrencyService.evaluateRequiresFxVerification(
            fxRequiresVerification: false,
            baseCurrencyCode: 'JPY',
            displayCurrencyCode: 'JPY',
          ),
          isFalse,
        );
        expect(
          ApacI18nCurrencyService.evaluateRequiresFxVerification(
            fxRequiresVerification: true,
            baseCurrencyCode: 'JPY',
            displayCurrencyCode: 'JPY',
          ),
          isTrue,
        );
        expect(
          ApacI18nCurrencyService.evaluateRequiresFxVerification(
            fxRequiresVerification: false,
            baseCurrencyCode: 'JPY',
            displayCurrencyCode: 'SGD',
          ),
          isTrue,
        );
        expect(
          ApacI18nCurrencyService.evaluateRequiresFxVerification(
            fxRequiresVerification: false,
            baseCurrencyCode: 'JPY',
            displayCurrencyCode: 'JPY',
            isFinancialEstimate: true,
          ),
          isTrue,
        );

        final converted = ApacI18nCurrencyService.convertEstimatedAmount(
          amount: 114000,
          fromCurrencyCode: 'JPY',
          toCurrencyCode: 'SGD',
        );
        expect(converted, closeTo(1000.0, 0.0001));
        expect(
          ApacI18nCurrencyService.convertEstimatedAmount(
            amount: 100,
            fromCurrencyCode: 'JPY',
            toCurrencyCode: 'UNKNOWN',
          ),
          isNull,
        );
      },
    );
  });

  group('ApacLocaleCurrencyPanel widget & accessibility (#2594)', () {
    testWidgets(
      'toggles locale dynamically and shows FX warning only when unverified or FX-converted',
      (WidgetTester tester) async {
        final notifier = ApacLocaleNotifier();
        addTearDown(notifier.dispose);
        final verifiedDoc = _createVerifiedJpyDocument();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ApacLocaleCurrencyPanel(
                  notifier: notifier,
                  document: verifiedDoc,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial verified base JPY state: clear badge visible, FX warning hidden
        expect(find.text('APAC 多言語・多通貨データ基盤'), findsOneWidget);
        expect(find.text('¥1,000,000'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('apac_verified_base_status_badge')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey<String>('apac_fx_verification_warning_banner'),
          ),
          findsNothing,
        );

        // Toggle to en-SG: UI updates immediately & FX warning appears
        final sgButton =
            find.byKey(const ValueKey<String>('apac_locale_button_en-SG'));
        await tester.ensureVisible(sgButton);
        await tester.tap(sgButton);
        await tester.pumpAndSettle();

        expect(
          find.text('APAC Multi-Locale & Currency Foundation'),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey<String>('apac_fx_verification_warning_banner'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey<String>('apac_fx_verification_warning_badge'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('apac_verified_base_status_badge')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('apac_fx_converted_amount_text')),
          findsOneWidget,
        );

        // Toggle to id-ID: Bahasa Indonesia UI & Rupiah formatting appear
        final idButton =
            find.byKey(const ValueKey<String>('apac_locale_button_id-ID'));
        await tester.ensureVisible(idButton);
        await tester.tap(idButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Fondasi Multi-Bahasa & Multi-Mata Uang APAC'),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey<String>('apac_fx_verification_warning_banner'),
          ),
          findsOneWidget,
        );

        // Toggle back to ja-JP: returns cleanly to verified base JPY state
        final jpButton =
            find.byKey(const ValueKey<String>('apac_locale_button_ja-JP'));
        await tester.ensureVisible(jpButton);
        await tester.tap(jpButton);
        await tester.pumpAndSettle();

        expect(find.text('APAC 多言語・多通貨データ基盤'), findsOneWidget);
        expect(find.text('¥1,000,000'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('apac_verified_base_status_badge')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey<String>('apac_fx_verification_warning_banner'),
          ),
          findsNothing,
        );

        // Toggling financial estimate mode surfaces FX warning even on JPY
        final estimateToggle =
            find.byKey(const ValueKey<String>('apac_estimate_toggle_button'));
        await tester.ensureVisible(estimateToggle);
        await tester.tap(estimateToggle);
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('apac_fx_verification_warning_banner'),
          ),
          findsOneWidget,
        );
        expect(notifier.localeTag, 'ja-JP');
        expect(notifier.currencyCode, 'JPY');
        expect(notifier.isFinancialEstimate, isTrue);

        // Unmount widget tree cleanly before notifier disposal
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'displays warning banner and verification note for fxRequiresVerification=true document',
      (WidgetTester tester) async {
        final unverifiedDoc = _createUnverifiedApacDocument();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ApacLocaleCurrencyPanel(document: unverifiedDoc),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('apac_fx_verification_warning_banner'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('apac_verification_note_text')),
          findsOneWidget,
        );
        expect(find.textContaining('MAS公式日次仲値で要再照合'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('apac_verified_base_status_badge')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'passes 390x844 and 1280x800 light/dark 2.0x textScale and WCAG semantics guidelines',
      (WidgetTester tester) async {
        final viewports = <Size>[
          const Size(390, 844),
          const Size(1280, 800),
        ];
        final themes = <ThemeData>[
          ThemeData.light(),
          ThemeData.dark(),
        ];
        final docs = <RegionalDocumentMetadata>[
          _createVerifiedJpyDocument(),
          _createUnverifiedApacDocument(),
        ];

        for (final viewport in viewports) {
          for (final theme in themes) {
            for (final doc in docs) {
              final SemanticsHandle handle = tester.ensureSemantics();
              try {
                tester.view.physicalSize = viewport;
                tester.view.devicePixelRatio = 1.0;

                await tester.pumpWidget(
                  MaterialApp(
                    key: ValueKey<String>(
                      '${viewport.width}_${theme.brightness}_${doc.id}',
                    ),
                    theme: theme,
                    home: MediaQuery(
                      data: MediaQueryData(
                        size: viewport,
                        textScaler: const TextScaler.linear(2.0),
                      ),
                      child: Scaffold(
                        body: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: ApacLocaleCurrencyPanel(document: doc),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                expect(
                  find.byKey(
                    const ValueKey<String>('apac_locale_currency_panel'),
                  ),
                  findsOneWidget,
                );

                await expectLater(
                  tester,
                  meetsGuideline(androidTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(labeledTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(textContrastGuideline),
                );
              } finally {
                handle.dispose();
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
              }
            }
          }
        }
      },
    );
  });
}
