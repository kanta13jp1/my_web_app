import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/long_form_summary/application/long_form_summary_controller.dart';
import 'package:my_web_app/features/long_form_summary/data/long_form_summary_repository.dart';
import 'package:my_web_app/features/long_form_summary/domain/long_form_summary_models.dart';
import 'package:my_web_app/features/long_form_summary/long_form_summary_container.dart';

class _FakeLongFormSummaryRepository implements LongFormSummaryRepository {
  final List<LongFormDocumentWithSummary> stored =
      <LongFormDocumentWithSummary>[
    const LongFormDocumentWithSummary(
      documentId: 'doc-initial-1',
      title: 'Attention 機構による長文構造化レポート',
      bodyText:
          '本文全文マーカー_INITIAL: Transformer の Self-Attention は系列長に依存しない注意重み計算を行います。'
          '長文データを分割せずに文脈の核心を抽出できます。',
      charCount: 92,
      summaryText: '要約プレビュー_INITIAL: Self-Attention により長文の核心を先行抽出します。',
      status: LongFormSummaryStatus.completed,
      modelName: 'extractive-local-v1',
    ),
  ];

  bool throwStateError = false;
  bool returnRateLimited = false;

  @override
  Future<List<LongFormDocumentWithSummary>> fetchDocuments() async {
    if (throwStateError) {
      throw StateError('db unavailable');
    }
    return List<LongFormDocumentWithSummary>.from(stored);
  }

  @override
  Future<LongFormDocumentWithSummary> saveDocument({
    required String title,
    required String bodyText,
  }) async {
    if (throwStateError) {
      throw StateError('save failed');
    }
    final LongFormDocumentWithSummary next = LongFormDocumentWithSummary(
      documentId: 'doc-created-${stored.length + 1}',
      title: title,
      bodyText: bodyText,
      charCount: bodyText.length,
      summaryText: returnRateLimited
          ? ''
          : LongFormSummaryBuilder.buildLocalPreviewSummary(bodyText),
      status: returnRateLimited
          ? LongFormSummaryStatus.rateLimited
          : LongFormSummaryStatus.completed,
      retryAfterSeconds: returnRateLimited ? 120 : 0,
      modelName: returnRateLimited ? 'rate-limiter' : 'extractive-local-v1',
    );
    stored.insert(0, next);
    return next;
  }

  @override
  Future<LongFormDocumentWithSummary?> fetchByDocumentId(
    String documentId,
  ) async {
    for (final LongFormDocumentWithSummary item in stored) {
      if (item.documentId == documentId) {
        return item.copyWith(
          summaryText: '更新済み要約プレビュー: ${item.title}',
          status: LongFormSummaryStatus.completed,
        );
      }
    }
    return null;
  }
}

void main() {
  group('LongFormSummaryController', () {
    test(
      'handles StateError fallback, rate-limit metadata, and idempotent dispose',
      () async {
        final _FakeLongFormSummaryRepository repo =
            _FakeLongFormSummaryRepository()..throwStateError = true;
        final LongFormSummaryController controller = LongFormSummaryController(
          repository: repo,
        );
        addTearDown(controller.dispose);

        await controller.loadDocuments();
        expect(controller.items, isNotEmpty);
        expect(controller.errorMessage, contains('ローカル要約プレビュー'));

        repo.throwStateError = false;
        repo.returnRateLimited = true;
        expect(
          await controller.submitDocument(
            title: 'レート制限検証ドキュメント',
            bodyText: '長文データの連続送信によりレート制限待機になるテストケースです。' * 12,
          ),
          isTrue,
        );
        expect(
          controller.items.first.status,
          LongFormSummaryStatus.rateLimited,
        );
        expect(controller.items.first.retryAfterSeconds, 120);

        controller.dispose();
        controller.dispose();
      },
    );
  });

  group('LongFormSummaryContainer', () {
    testWidgets(
      'shows generated summary preview before expanding full long-form text',
      (WidgetTester tester) async {
        final _FakeLongFormSummaryRepository repo =
            _FakeLongFormSummaryRepository();
        final LongFormSummaryController controller = LongFormSummaryController(
          repository: repo,
        );
        addTearDown(controller.dispose);
        await controller.loadDocuments();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1E3A8A),
              ),
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LongFormSummaryContainer(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('summary-preview-doc-initial-1')),
          findsOneWidget,
        );
        expect(
          find.textContaining('要約プレビュー_INITIAL'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('full-text-body-doc-initial-1')),
          findsNothing,
        );

        final Finder toggleBtn = find.byKey(
          const ValueKey<String>('toggle-full-text-doc-initial-1'),
        );
        await tester.ensureVisible(toggleBtn);
        await tester.pumpAndSettle();
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('full-text-body-doc-initial-1')),
          findsOneWidget,
        );
        expect(find.textContaining('本文全文マーカー_INITIAL'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'passes responsive and WCAG accessibility audit at 360x800 and 1280x800 in light/dark modes with 2.0x textScale',
      (WidgetTester tester) async {
        const List<Size> viewports = <Size>[
          Size(360, 800),
          Size(1280, 800),
        ];
        const List<Brightness> modes = <Brightness>[
          Brightness.light,
          Brightness.dark,
        ];

        for (final Size viewport in viewports) {
          for (final Brightness mode in modes) {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;

            final _FakeLongFormSummaryRepository repo =
                _FakeLongFormSummaryRepository();
            final LongFormSummaryController controller =
                LongFormSummaryController(repository: repo);
            await controller.loadDocuments();

            final SemanticsHandle semanticsHandle = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>('${viewport.width}_${mode.name}'),
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: mode,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFF1E3A8A),
                      brightness: mode,
                    ),
                  ),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: viewport,
                      textScaler: const TextScaler.linear(2.0),
                    ),
                    child: Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: LongFormSummaryContainer(controller: controller),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(textContrastGuideline));
            } finally {
              semanticsHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              controller.dispose();
            }
          }
        }
      },
    );
  });
}
