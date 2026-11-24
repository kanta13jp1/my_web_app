import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_web_app/services/external_markdown_extraction_service.dart';
import 'package:my_web_app/widgets/external_markdown_extractor_panel.dart';

class _FakeExternalMarkdownRepository
    implements ExternalMarkdownExtractionRepository {
  final List<ExternalMarkdownExtractionRecord> _items =
      <ExternalMarkdownExtractionRecord>[
    ExternalMarkdownExtractionRecord(
      id: 'ext-initial-1',
      userId: 'user-1',
      sourceUrl: 'https://docs.example.com/overview',
      sourceTitle: 'Overview Guide',
      markdownContent: '# Overview Guide\n\n- Key takeaway one',
      structuredPayload: const StructuredExtractionPayload(
        title: 'Overview Guide',
        description: 'Official overview document',
        headings: <String>['Overview Guide'],
        links: <ExtractedLinkItem>[
          ExtractedLinkItem(
            text: 'Reference',
            url: 'https://docs.example.com/ref',
          ),
        ],
        keyPoints: <String>['Key takeaway one'],
        wordCount: 6,
        extractorMode: ExternalExtractorMode.stdlibHtml,
        fetchedAt: null,
      ),
      extractorMode: ExternalExtractorMode.stdlibHtml,
      status: ExternalExtractionStatus.completed,
      errorCode: null,
      createdAt: DateTime.utc(2026, 11, 24, 2, 0),
      updatedAt: DateTime.utc(2026, 11, 24, 2, 0),
    ),
  ];

  bool throwOnLoad = false;
  int _seq = 10;

  @override
  Future<List<ExternalMarkdownExtractionRecord>> listExtractions({
    int limit = 30,
  }) async {
    if (throwOnLoad) {
      throw StateError('simulated list error');
    }
    return _items.take(limit).toList(growable: false);
  }

  @override
  Future<ExternalMarkdownExtractionRecord> submitExtraction({
    required String url,
    ExternalExtractorMode mode = ExternalExtractorMode.stdlibHtml,
  }) async {
    final err = validateExternalHttpsUrl(url);
    if (err != null) {
      throw ArgumentError(err);
    }
    _seq += 1;
    final created = ExternalMarkdownExtractionRecord(
      id: 'ext-$_seq',
      userId: 'user-1',
      sourceUrl: url.trim(),
      sourceTitle: 'Extracted Spec',
      markdownContent: '# Extracted Spec\n\n- Structured bullet',
      structuredPayload: StructuredExtractionPayload(
        title: 'Extracted Spec',
        description: 'Structured JSON summary',
        headings: const <String>['Extracted Spec'],
        links: const <ExtractedLinkItem>[
          ExtractedLinkItem(
            text: 'API Docs',
            url: 'https://docs.example.com/api',
          ),
        ],
        keyPoints: const <String>['Structured bullet'],
        wordCount: 5,
        extractorMode: mode,
        fetchedAt: DateTime.utc(2026, 11, 24, 3, 0),
      ),
      extractorMode: mode,
      status: ExternalExtractionStatus.completed,
      errorCode: null,
      createdAt: DateTime.utc(2026, 11, 24, 3, 0),
      updatedAt: DateTime.utc(2026, 11, 24, 3, 0),
    );
    _items.insert(0, created);
    return created;
  }
}

void main() {
  group('ExternalMarkdownExtractionService', () {
    test(
      'validates https URLs and rejects SSRF, userinfo, and private IPs',
      () {
        expect(
          validateExternalHttpsUrl('https://docs.example.com/guide'),
          isNull,
        );
        expect(
          validateExternalHttpsUrl('http://docs.example.com/guide'),
          isNotNull,
        );
        expect(validateExternalHttpsUrl('javascript:alert(1)'), isNotNull);
        expect(
          validateExternalHttpsUrl('https://user:pass@example.com/docs'),
          isNotNull,
        );
        expect(validateExternalHttpsUrl('https://localhost/admin'), isNotNull);
        expect(
          validateExternalHttpsUrl('https://127.0.0.1/internal'),
          isNotNull,
        );
        expect(
          validateExternalHttpsUrl('https://100.64.0.5/cgnat'),
          isNotNull,
        );
      },
    );

    test(
      'parses ExternalMarkdownExtractionRecord and strips unsafe links from payload',
      () {
        final record = ExternalMarkdownExtractionRecord.fromJson(
          const <String, Object?>{
            'id': 'rec-1',
            'user_id': 'user-1',
            'source_url': 'https://docs.example.com/guide',
            'source_title': 'Guide',
            'markdown_content': '# Guide',
            'extractor_mode': 'firecrawl_v1',
            'status': 'completed',
            'structured_payload': <String, Object?>{
              'title': 'Guide',
              'description': 'Desc',
              'headings': <Object?>[
                <String, Object?>{'level': 1, 'text': 'Guide'},
              ],
              'links': <Object?>[
                <String, Object?>{
                  'text': 'Safe',
                  'url': 'https://docs.example.com/safe',
                },
                <String, Object?>{
                  'text': 'Bad',
                  'url': 'javascript:alert(1)',
                },
              ],
              'key_points': <Object?>['Bullet A'],
              'word_count': 12,
              'extractor_mode': 'firecrawl_v1',
            },
          },
        );
        expect(record.extractorMode, ExternalExtractorMode.firecrawlV1);
        expect(record.status, ExternalExtractionStatus.completed);
        expect(record.structuredPayload.links, hasLength(1));
        expect(
          record.structuredPayload.links.single.url,
          'https://docs.example.com/safe',
        );
        expect(record.structuredPayload.keyPoints, const <String>['Bullet A']);
      },
    );
  });

  group('ExternalMarkdownExtractorPanel Widget & A11y', () {
    testWidgets(
      'rejects invalid URLs, submits valid https URL, and renders Markdown + JSON',
      (WidgetTester tester) async {
        final repo = _FakeExternalMarkdownRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExternalMarkdownExtractorPanel(repository: repo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final urlInput = find.byKey(const ValueKey<String>('ext_md_url_input'));
        final submitBtn =
            find.byKey(const ValueKey<String>('ext_md_submit_button'));

        await tester.ensureVisible(urlInput);
        await tester.enterText(urlInput, 'http://127.0.0.1/secret');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('ext_md_error_banner')),
          findsOneWidget,
        );

        await tester.ensureVisible(urlInput);
        await tester.enterText(urlInput, 'https://docs.example.com/spec');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('ext_md_error_banner')),
          findsNothing,
        );
        expect(find.textContaining('Extracted Spec'), findsWidgets);
        expect(find.textContaining('Structured bullet'), findsWidgets);
      },
    );

    testWidgets(
      'recovers from load error and disposes controllers cleanly',
      (WidgetTester tester) async {
        final repo = _FakeExternalMarkdownRepository()..throwOnLoad = true;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExternalMarkdownExtractorPanel(repository: repo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('ext_md_error_banner')),
          findsOneWidget,
        );

        repo.throwOnLoad = false;
        final retryBtn =
            find.byKey(const ValueKey<String>('ext_md_retry_button'));
        await tester.ensureVisible(retryBtn);
        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('Overview Guide'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    for (final viewport in const <Size>[Size(360, 800), Size(1280, 800)]) {
      for (final brightness in const <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        testWidgets(
          'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} $brightness 2.0x textScale',
          (WidgetTester tester) async {
            final a11yHandle = tester.ensureSemantics();
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            try {
              final repo = _FakeExternalMarkdownRepository();
              final theme = brightness == Brightness.dark
                  ? ThemeData.dark()
                  : ThemeData.light();
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>(
                    '${viewport.width.toInt()}_${brightness.name}',
                  ),
                  theme: theme,
                  home: Builder(
                    builder: (BuildContext context) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          size: viewport,
                          textScaler: const TextScaler.linear(2.0),
                        ),
                        child: Scaffold(
                          body: SingleChildScrollView(
                            child: ExternalMarkdownExtractorPanel(
                              repository: repo,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
              await tester.pumpAndSettle();

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
              a11yHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          },
        );
      }
    }
  });
}
