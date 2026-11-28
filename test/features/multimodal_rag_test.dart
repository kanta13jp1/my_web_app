import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/multimodal_rag/application/multimodal_rag_controller.dart';
import 'package:my_web_app/features/multimodal_rag/domain/multimodal_rag_models.dart';
import 'package:my_web_app/features/multimodal_rag/multimodal_rag_container.dart';

class _InMemoryMultimodalRagRepository implements MultimodalRagRepository {
  _InMemoryMultimodalRagRepository({this.throwOnSearch = false});

  final bool throwOnSearch;
  final List<MultimodalRagItem> _items = <MultimodalRagItem>[
    const MultimodalRagItem(
      id: 'item-diagram',
      sourceKey: 'manual-diagram',
      title: '製品配線マニュアル図',
      modality: MultimodalModality.mixed,
      mimeType: 'image/png',
      storageObjectPath: 'user-1/2026-11-25/manual-diagram.png',
      contentText: 'Gemini Embedding 2 を使った画像とテキストの統合インデックス',
      byteSize: 67,
      chunkCount: 1,
      embeddingModel: 'gemini-embedding-2',
      embeddingMode: MultimodalEmbeddingMode.live,
      updatedAtIso: '2026-11-25T04:10:00Z',
    ),
    const MultimodalRagItem(
      id: 'item-video',
      sourceKey: 'walkthrough-video',
      title: '操作説明動画 250秒',
      modality: MultimodalModality.video,
      mimeType: 'video/mp4',
      storageObjectPath: 'user-1/2026-11-25/walkthrough.mp4',
      contentText: '動画フレームを120秒単位でチャンク化して検索可能にしたデータ',
      byteSize: 4096,
      durationSec: 250,
      chunkCount: 3,
      embeddingModel: 'gemini-embedding-2',
      embeddingMode: MultimodalEmbeddingMode.live,
      updatedAtIso: '2026-11-25T04:05:00Z',
    ),
  ];

  MultimodalQueryRequest? lastSearchRequest;

  @override
  Future<List<MultimodalRagItem>> listItems({int limit = 30}) async {
    return List<MultimodalRagItem>.unmodifiable(_items.take(limit));
  }

  @override
  Future<MultimodalRagItem> ingestItem(MultimodalIngestRequest request) async {
    final int chunks = estimateMultimodalChunkCount(
      contentText: request.contentText,
      mimeType: request.mimeType,
      durationSec: request.durationSec,
      pageCount: request.pageCount,
    );
    final MultimodalRagItem created = MultimodalRagItem(
      id: 'item-${_items.length + 1}',
      sourceKey: request.sourceKey,
      title: request.title,
      modality:
          request.hasMedia ? MultimodalModality.mixed : MultimodalModality.text,
      mimeType: request.mimeType,
      storageObjectPath: request.hasMedia
          ? 'user-1/2026-11-25/${request.sourceKey}.png'
          : null,
      contentText: request.contentText,
      byteSize: request.mediaBytes?.length ?? request.contentText.length,
      durationSec: request.durationSec,
      pageCount: request.pageCount,
      chunkCount: chunks,
      embeddingModel: 'gemini-embedding-2',
      embeddingMode: MultimodalEmbeddingMode.live,
      updatedAtIso: '2026-11-25T04:20:00Z',
    );
    _items.insert(0, created);
    return created;
  }

  @override
  Future<MultimodalSearchResult> search(MultimodalQueryRequest request) async {
    lastSearchRequest = request;
    if (throwOnSearch) {
      throw StateError('pgvector search endpoint failed');
    }
    final String needle = request.queryText.trim().toLowerCase();
    final Set<MultimodalModality> filters = request.modalities.toSet();
    final List<MultimodalSearchHit> hits = _items
        .where(
          (MultimodalRagItem item) =>
              filters.isEmpty || filters.contains(item.modality),
        )
        .map((MultimodalRagItem item) {
          final String hay =
              '${item.title} ${item.contentText} ${item.sourceKey}'
                  .toLowerCase();
          double score = 0.35;
          if (request.hasImageQuery && item.hasStorageLink) {
            score += 0.45;
          }
          if (needle.isNotEmpty && hay.contains(needle)) {
            score += 0.19;
          }
          return MultimodalSearchHit(
            itemId: item.id,
            sourceKey: item.sourceKey,
            title: item.title,
            modality: item.modality,
            mimeType: item.mimeType,
            storageObjectPath: item.storageObjectPath,
            matchedExcerpt: item.contentText,
            chunkCount: item.chunkCount,
            embeddingModel: item.embeddingModel,
            embeddingMode: item.embeddingMode,
            similarityScore: score.clamp(0.0, 1.0),
            signedUrl: item.hasStorageLink
                ? 'https://storage.local/signed/${item.id}'
                : null,
            updatedAtIso: item.updatedAtIso,
          );
        })
        .where(
          (MultimodalSearchHit hit) =>
              needle.isEmpty ||
              request.hasImageQuery ||
              hit.similarityScore > 0.4,
        )
        .toList()
      ..sort(
        (MultimodalSearchHit a, MultimodalSearchHit b) =>
            b.similarityScore.compareTo(a.similarityScore),
      );

    return MultimodalSearchResult(
      queryModality: request.hasImageQuery && needle.isNotEmpty
          ? MultimodalModality.mixed
          : (request.hasImageQuery
              ? MultimodalModality.image
              : MultimodalModality.text),
      embeddingModel: 'gemini-embedding-2',
      embeddingMode: MultimodalEmbeddingMode.live,
      hits: hits.take(request.limit).toList(growable: false),
    );
  }

  @override
  Future<String> requestSignedUrl(String itemId) async {
    return 'https://storage.local/signed/$itemId?ttl=300';
  }

  @override
  Future<void> deleteItem(String itemId) async {
    _items.removeWhere((MultimodalRagItem item) => item.id == itemId);
  }
}

void main() {
  group('MultimodalRag models & chunk estimator', () {
    test('estimates chunks for video (120s), audio (180s), pdf (6p), text', () {
      expect(
        estimateMultimodalChunkCount(
          contentText: '',
          mimeType: 'video/mp4',
          durationSec: 250,
        ),
        3,
      );
      expect(
        estimateMultimodalChunkCount(
          contentText: '',
          mimeType: 'audio/mpeg',
          durationSec: 200,
        ),
        2,
      );
      expect(
        estimateMultimodalChunkCount(
          contentText: '',
          mimeType: 'application/pdf',
          pageCount: 13,
        ),
        3,
      );
      expect(
        estimateMultimodalChunkCount(
          contentText: 'x' * 3000,
          mimeType: 'text/plain',
        ),
        3,
      );
    });

    test('validates PNG and JPEG magic bytes strictly', () {
      expect(
        hasSupportedImageMagicBytes(kSampleMultimodalPngBytes, 'image/png'),
        isTrue,
      );
      expect(
        hasSupportedImageMagicBytes(kSampleMultimodalPngBytes, 'image/jpeg'),
        isFalse,
      );
      expect(
        hasSupportedImageMagicBytes(
          Uint8List.fromList(<int>[0x3c, 0x73, 0x76, 0x67]),
          'image/png',
        ),
        isFalse,
      );
    });
  });

  group('MultimodalRagController', () {
    test('rejects empty query and runs text + image queries cleanly', () async {
      final _InMemoryMultimodalRagRepository repo =
          _InMemoryMultimodalRagRepository();
      final MultimodalRagController controller = MultimodalRagController(
        repository: repo,
      );
      addTearDown(controller.dispose);

      await controller.loadDashboard();
      expect(controller.items.length, 2);
      expect(controller.hits.length, 2);

      await controller.runSearch('   ');
      expect(controller.errorMessage, isNotEmpty);

      controller.attachQueryImage(
        bytes: kSampleMultimodalPngBytes,
        mimeType: 'image/png',
        fileName: 'diagram.png',
      );
      expect(controller.hasQueryImage, isTrue);
      await controller.runSearch('配線');
      expect(controller.errorMessage, isEmpty);
      expect(repo.lastSearchRequest?.hasImageQuery, isTrue);
      expect(controller.hits.first.itemId, 'item-diagram');
    });

    test('ingests media item, refreshes signed url, and deletes item',
        () async {
      final _InMemoryMultimodalRagRepository repo =
          _InMemoryMultimodalRagRepository();
      final MultimodalRagController controller = MultimodalRagController(
        repository: repo,
      );
      addTearDown(controller.dispose);

      await controller.loadDashboard();
      final bool ok = await controller.ingestItem(
        sourceKey: 'circuit-sheet',
        title: '基板仕様シート',
        contentText: '電源基板のシルクスクリーンと部品配置図',
        mediaBytes: kSampleMultimodalPngBytes,
        mimeType: 'image/png',
      );
      expect(ok, isTrue);
      expect(controller.items.length, 3);
      expect(controller.items.first.hasStorageLink, isTrue);

      await controller.refreshSignedUrl(controller.items.first.id);
      expect(controller.lastSignedUrl, contains(controller.items.first.id));

      await controller.deleteItem(controller.items.first.id);
      expect(controller.items.length, 2);
    });

    test('surfaces backend search failure cleanly without crashing', () async {
      final _InMemoryMultimodalRagRepository repo =
          _InMemoryMultimodalRagRepository(throwOnSearch: true);
      final MultimodalRagController controller = MultimodalRagController(
        repository: repo,
      );
      addTearDown(controller.dispose);

      await controller.runSearch('マニュアル');
      expect(controller.errorMessage, contains('マルチモーダル検索に失敗'));
    });
  });

  group('MultimodalRagContainer widget & accessibility QA', () {
    testWidgets(
      'supports text + image query, ingest submission, and deletion',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final _InMemoryMultimodalRagRepository repo =
            _InMemoryMultimodalRagRepository();
        final MultimodalRagController controller = MultimodalRagController(
          repository: repo,
        );

        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MultimodalRagContainer(
                    controller: controller,
                    autoLoad: true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('multimodal-mode-badge')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('multimodal-hit-item-diagram')),
            findsOneWidget,
          );

          await tester.enterText(
            find.byKey(const ValueKey<String>('multimodal-query-input')),
            '配線',
          );
          final Finder attachBtn = find.byKey(
            const ValueKey<String>('multimodal-attach-sample-image-btn'),
          );
          await tester.ensureVisible(attachBtn);
          await tester.tap(attachBtn);
          await tester.pumpAndSettle();

          final Finder searchBtn = find.byKey(
            const ValueKey<String>('multimodal-search-submit-btn'),
          );
          await tester.ensureVisible(searchBtn);
          await tester.tap(searchBtn);
          await tester.pumpAndSettle();
          expect(repo.lastSearchRequest?.hasImageQuery, isTrue);

          await tester.enterText(
            find.byKey(const ValueKey<String>('multimodal-ingest-title-input')),
            '新規回路図',
          );
          await tester.enterText(
            find.byKey(
              const ValueKey<String>('multimodal-ingest-content-input'),
            ),
            'Supabase pgvector へ保存する新しい回路図データ',
          );
          final Finder pngChip = find.byKey(
            const ValueKey<String>('multimodal-ingest-attach-png-chip'),
          );
          await tester.ensureVisible(pngChip);
          await tester.tap(pngChip);
          await tester.pumpAndSettle();

          final Finder ingestBtn = find.byKey(
            const ValueKey<String>('multimodal-ingest-submit-btn'),
          );
          await tester.ensureVisible(ingestBtn);
          await tester.tap(ingestBtn);
          await tester.pumpAndSettle();

          expect(controller.items.length, 3);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          controller.dispose();
        }
      },
    );

    testWidgets(
      'passes responsive and WCAG guidelines at 360x800, 390x844, and 1280x800 in light/dark with 2.0x textScale',
      (WidgetTester tester) async {
        const List<Size> viewports = <Size>[
          Size(360, 800),
          Size(390, 844),
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

            final _InMemoryMultimodalRagRepository repo =
                _InMemoryMultimodalRagRepository();
            final MultimodalRagController controller = MultimodalRagController(
              repository: repo,
            );
            final SemanticsHandle semanticsHandle = tester.ensureSemantics();

            try {
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>(
                    '${viewport.width}_${viewport.height}_${mode.name}',
                  ),
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
                        child: MultimodalRagContainer(
                          controller: controller,
                          autoLoad: true,
                        ),
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
              await expectLater(
                tester,
                meetsGuideline(textContrastGuideline),
              );
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
