import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/unified_media_library/application/unified_media_library_controller.dart';
import 'package:my_web_app/features/unified_media_library/domain/unified_media_library_models.dart';
import 'package:my_web_app/features/unified_media_library/unified_media_library_container.dart';

class _InMemoryUnifiedMediaLibraryRepository
    implements UnifiedMediaLibraryRepository {
  _InMemoryUnifiedMediaLibraryRepository({
    required this.throwOnSearch,
    required List<UnifiedMediaAsset> initialAssets,
  }) : _store = List<UnifiedMediaAsset>.from(initialAssets);

  final bool throwOnSearch;
  final List<UnifiedMediaAsset> _store;

  static List<UnifiedMediaAsset> sampleAssets() {
    return const <UnifiedMediaAsset>[
      UnifiedMediaAsset(
        id: 'asset-1',
        assetKind: MediaAssetKind.video,
        mimeType: 'video/mp4',
        title: 'オープニング動画テンプレート',
        description: '全チャンネル共通 4K イントロ素材',
        contentSha256:
            '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff',
        byteSize: 2048,
        durationSec: 12,
        storageObjectPath: 'user-1/video/1111222233334444/intro.bin',
        tags: <String>['intro', 'template'],
        autoTags: <String>['kind:video', 'ai:template'],
        taggingModel: AutoTagModelPreference.claudeSonnet46,
        reuseCount: 2,
        usages: <MediaProjectUsage>[
          MediaProjectUsage(
            id: 'usage-1',
            assetId: 'asset-1',
            projectKey: 'proj-alpha',
            projectTitle: 'メイン動画企画',
            pipelineStage: PipelineReuseStage.videoTimeline,
            notes: '',
            updatedAtIso: '2026-11-24T01:00:00Z',
          ),
          MediaProjectUsage(
            id: 'usage-2',
            assetId: 'asset-1',
            projectKey: 'proj-beta',
            projectTitle: 'ダイジェスト版',
            pipelineStage: PipelineReuseStage.bRoll,
            notes: '',
            updatedAtIso: '2026-11-24T02:00:00Z',
          ),
        ],
        updatedAtIso: '2026-11-24T02:00:00Z',
      ),
      UnifiedMediaAsset(
        id: 'asset-2',
        assetKind: MediaAssetKind.audio,
        mimeType: 'audio/mpeg',
        title: 'ナレーション共通ジングル',
        description: '解説動画用ループBGM',
        contentSha256:
            'ffffeeeeddddccccbbbbaaaa0000999988887777666655554444333322221111',
        byteSize: 512,
        durationSec: 8,
        storageObjectPath: 'user-1/audio/ffffeeeeddddcccc/jingle.bin',
        tags: <String>['bgm', 'audio'],
        autoTags: <String>['kind:audio', 'ai:loop'],
        taggingModel: AutoTagModelPreference.gemini31Pro,
        reuseCount: 1,
        usages: <MediaProjectUsage>[
          MediaProjectUsage(
            id: 'usage-3',
            assetId: 'asset-2',
            projectKey: 'proj-alpha',
            projectTitle: 'メイン動画企画',
            pipelineStage: PipelineReuseStage.audioTrack,
            notes: '',
            updatedAtIso: '2026-11-24T03:00:00Z',
          ),
        ],
        updatedAtIso: '2026-11-24T03:00:00Z',
      ),
    ];
  }

  String _pseudoSha256(String base64Payload) {
    final List<int> bytes = base64Decode(base64Payload);
    var acc = 0x12345678;
    for (final int b in bytes) {
      acc = ((acc * 31) ^ b) & 0x7fffffff;
    }
    return acc.toRadixString(16).padLeft(16, '0').padRight(64, 'a');
  }

  @override
  Future<List<UnifiedMediaAsset>> searchAssets({
    String query = '',
    MediaAssetKind? assetKind,
    String? tag,
    String? projectKey,
  }) async {
    if (throwOnSearch) {
      throw StateError('media library search failed');
    }
    final String q = query.trim().toLowerCase();
    final String cleanTag = (tag ?? '').trim().toLowerCase();
    final String cleanProject = (projectKey ?? '').trim().toLowerCase();
    return _store.where((UnifiedMediaAsset item) {
      if (assetKind != null && item.assetKind != assetKind) {
        return false;
      }
      if (cleanTag.isNotEmpty &&
          !item.allSearchTags.any((String t) => t.toLowerCase() == cleanTag)) {
        return false;
      }
      if (cleanProject.isNotEmpty &&
          !item.usages.any(
            (MediaProjectUsage u) => u.projectKey.toLowerCase() == cleanProject,
          )) {
        return false;
      }
      if (q.isNotEmpty) {
        final String hay =
            '${item.title} ${item.description} ${item.allSearchTags.join(' ')}'
                .toLowerCase();
        if (!hay.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  @override
  Future<MediaUploadResult> uploadOrDeduplicateAsset({
    required String title,
    required MediaAssetKind assetKind,
    required String contentBase64,
    String description = '',
    List<String> tags = const <String>[],
    AutoTagModelPreference aiModel =
        AutoTagModelPreference.deterministicFallback,
    int? durationSec,
    String? projectKey,
    PipelineReuseStage pipelineStage = PipelineReuseStage.videoTimeline,
  }) async {
    final List<int> bytes = base64Decode(contentBase64);
    final String sha = _pseudoSha256(contentBase64);
    final int existingIdx = _store.indexWhere(
      (UnifiedMediaAsset item) => item.contentSha256 == sha,
    );
    if (existingIdx >= 0) {
      final UnifiedMediaAsset existing = _store[existingIdx];
      MediaProjectUsage? createdUsage;
      var updatedUsages = existing.usages;
      var nextReuse = existing.reuseCount;
      final String cleanProj = (projectKey ?? '').trim();
      if (cleanProj.isNotEmpty &&
          !existing.usages.any(
            (MediaProjectUsage u) =>
                u.projectKey == cleanProj && u.pipelineStage == pipelineStage,
          )) {
        createdUsage = MediaProjectUsage(
          id: 'usage-${existing.usages.length + 10}',
          assetId: existing.id,
          projectKey: cleanProj,
          projectTitle: cleanProj,
          pipelineStage: pipelineStage,
          notes: '',
          updatedAtIso: '2026-11-24T05:00:00Z',
        );
        updatedUsages = <MediaProjectUsage>[...existing.usages, createdUsage];
        nextReuse += 1;
      }
      final UnifiedMediaAsset updated = existing.copyWith(
        tags: <String>{...existing.tags, ...tags}.toList(growable: false),
        reuseCount: nextReuse,
        usages: updatedUsages,
      );
      _store[existingIdx] = updated;
      return MediaUploadResult(
        deduplicated: true,
        storageUploadSkipped: true,
        bytesSaved: bytes.length,
        asset: updated,
        usage: createdUsage,
      );
    }

    final String cleanProj = (projectKey ?? '').trim();
    final List<MediaProjectUsage> initialUsages = cleanProj.isEmpty
        ? const <MediaProjectUsage>[]
        : <MediaProjectUsage>[
            MediaProjectUsage(
              id: 'usage-new-${_store.length + 1}',
              assetId: 'asset-${_store.length + 1}',
              projectKey: cleanProj,
              projectTitle: cleanProj,
              pipelineStage: pipelineStage,
              notes: '',
              updatedAtIso: '2026-11-24T05:00:00Z',
            ),
          ];

    final UnifiedMediaAsset created = UnifiedMediaAsset(
      id: 'asset-${_store.length + 1}',
      assetKind: assetKind,
      mimeType: assetKind.defaultMimeType,
      title: title,
      description: description,
      contentSha256: sha,
      byteSize: bytes.length,
      durationSec: durationSec,
      storageObjectPath: 'user-1/${assetKind.wireValue}/$sha/payload.bin',
      tags: tags,
      autoTags: <String>[
        'kind:${assetKind.wireValue}',
        'model:${aiModel.wireValue}',
      ],
      taggingModel: aiModel,
      reuseCount: initialUsages.length,
      usages: initialUsages,
      updatedAtIso: '2026-11-24T05:00:00Z',
    );
    _store.insert(0, created);
    return MediaUploadResult(
      deduplicated: false,
      storageUploadSkipped: false,
      bytesSaved: 0,
      asset: created,
      usage: initialUsages.isEmpty ? null : initialUsages.first,
    );
  }

  @override
  Future<UnifiedMediaAsset> reuseAssetInProject({
    required UnifiedMediaAsset asset,
    required String projectKey,
    String projectTitle = '',
    PipelineReuseStage pipelineStage = PipelineReuseStage.videoTimeline,
    String notes = '',
  }) async {
    final int idx = _store.indexWhere(
      (UnifiedMediaAsset item) => item.id == asset.id,
    );
    if (idx < 0) {
      throw StateError('Asset not found: ${asset.id}');
    }
    final UnifiedMediaAsset current = _store[idx];
    final MediaProjectUsage usage = MediaProjectUsage(
      id: 'usage-${current.usages.length + 20}',
      assetId: current.id,
      projectKey: projectKey,
      projectTitle: projectTitle.isEmpty ? projectKey : projectTitle,
      pipelineStage: pipelineStage,
      notes: notes,
      updatedAtIso: '2026-11-24T06:00:00Z',
    );
    final UnifiedMediaAsset updated = current.copyWith(
      reuseCount: current.reuseCount + 1,
      usages: <MediaProjectUsage>[...current.usages, usage],
    );
    _store[idx] = updated;
    return updated;
  }

  @override
  Future<UnifiedMediaAsset> updateAssetTags({
    required UnifiedMediaAsset asset,
    required List<String> tags,
    bool refreshAutoTags = false,
    AutoTagModelPreference aiModel =
        AutoTagModelPreference.deterministicFallback,
  }) async {
    final int idx = _store.indexWhere(
      (UnifiedMediaAsset item) => item.id == asset.id,
    );
    if (idx < 0) {
      throw StateError('Asset not found: ${asset.id}');
    }
    final UnifiedMediaAsset current = _store[idx];
    final List<String> nextAutoTags = refreshAutoTags
        ? <String>[
            'kind:${current.assetKind.wireValue}',
            'hook:${aiModel.wireValue}',
          ]
        : current.autoTags;
    final UnifiedMediaAsset updated = current.copyWith(
      tags: tags,
      autoTags: nextAutoTags,
      taggingModel: refreshAutoTags ? aiModel : current.taggingModel,
    );
    _store[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteAsset(String assetId) async {
    _store.removeWhere((UnifiedMediaAsset item) => item.id == assetId);
  }
}

void main() {
  group('UnifiedMediaLibraryController', () {
    test(
      'deduplicates identical SHA-256 uploads, tracks project reuse, filters, and handles errors',
      () async {
        final _InMemoryUnifiedMediaLibraryRepository repo =
            _InMemoryUnifiedMediaLibraryRepository(
          throwOnSearch: false,
          initialAssets: _InMemoryUnifiedMediaLibraryRepository.sampleAssets(),
        );
        final UnifiedMediaLibraryController controller =
            UnifiedMediaLibraryController(repository: repo);
        addTearDown(controller.dispose);

        await controller.loadAssets();
        expect(controller.assets.length, 2);
        expect(controller.totalReuseCount, 3);

        controller.selectAiModel(AutoTagModelPreference.claudeSonnet46);
        final MediaUploadResult? firstUpload =
            await controller.uploadOrDeduplicateTextPayload(
          title: '新商品プロモ Bロール',
          assetKind: MediaAssetKind.video,
          rawPayloadText: 'identical-binary-payload-frame-001',
          description: '商品レビュー冒頭クリップ',
          tags: const <String>['promo', 'review'],
          projectKey: 'proj-gamma',
          pipelineStage: PipelineReuseStage.bRoll,
        );
        expect(firstUpload, isNotNull);
        expect(firstUpload!.deduplicated, isFalse);
        expect(controller.assets.length, 3);

        final MediaUploadResult? dupUpload =
            await controller.uploadOrDeduplicateTextPayload(
          title: '別名で再アップロードした同一素材',
          assetKind: MediaAssetKind.video,
          rawPayloadText: 'identical-binary-payload-frame-001',
          tags: const <String>['reused'],
          projectKey: 'proj-delta',
          pipelineStage: PipelineReuseStage.adCreative,
        );
        expect(dupUpload, isNotNull);
        expect(dupUpload!.deduplicated, isTrue);
        expect(dupUpload.storageUploadSkipped, isTrue);
        expect(controller.assets.length, 3);
        expect(controller.totalDeduplicatedBytesSaved, greaterThan(0));

        controller.selectAiModel(AutoTagModelPreference.gemini31Pro);
        final bool tagged = await controller.updateAssetTags(
          asset: controller.assets.first,
          tags: const <String>['promo', 'verified'],
          refreshAutoTags: true,
        );
        expect(tagged, isTrue);
        expect(
          controller.assets.first.taggingModel,
          AutoTagModelPreference.gemini31Pro,
        );
        expect(controller.assets.first.allSearchTags, contains('verified'));

        final bool reused = await controller.reuseAssetInProject(
          asset: controller.assets.first,
          projectKey: 'proj-epsilon',
          projectTitle: '年末年始特集',
          pipelineStage: PipelineReuseStage.thumbnail,
        );
        expect(reused, isTrue);
        expect(
          controller.assets.first.usages
              .any((MediaProjectUsage u) => u.projectKey == 'proj-epsilon'),
          isTrue,
        );

        controller.selectKindFilter(MediaAssetKind.audio);
        expect(controller.filteredAssets.length, 1);
        controller.selectKindFilter(null);
        controller.selectTagFilter('verified');
        expect(controller.filteredAssets.length, 1);
        controller.selectTagFilter('');
        controller.setSearchQuery('ジングル');
        expect(controller.filteredAssets.length, 1);
        controller.setSearchQuery('');

        final bool deleted = await controller.deleteAsset('asset-2');
        expect(deleted, isTrue);
        expect(controller.assets.length, 2);

        final _InMemoryUnifiedMediaLibraryRepository failingRepo =
            _InMemoryUnifiedMediaLibraryRepository(
          throwOnSearch: true,
          initialAssets: const <UnifiedMediaAsset>[],
        );
        final UnifiedMediaLibraryController failingController =
            UnifiedMediaLibraryController(repository: failingRepo);
        addTearDown(failingController.dispose);
        await failingController.loadAssets();
        expect(failingController.errorMessage, contains('失敗'));

        controller.dispose();
        controller.dispose();
      },
    );
  });

  group('UnifiedMediaLibraryContainer', () {
    testWidgets(
      'supports deduplicating upload, multi-project reuse, tag filtering, and clean disposal',
      (WidgetTester tester) async {
        final _InMemoryUnifiedMediaLibraryRepository repo =
            _InMemoryUnifiedMediaLibraryRepository(
          throwOnSearch: false,
          initialAssets: _InMemoryUnifiedMediaLibraryRepository.sampleAssets(),
        );
        final UnifiedMediaLibraryController controller =
            UnifiedMediaLibraryController(repository: repo);
        addTearDown(controller.dispose);

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
                child: UnifiedMediaLibraryContainer(
                  controller: controller,
                  autoLoad: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('media-asset-card-asset-1')),
          findsOneWidget,
        );

        final Finder reuseProjectField = find.byKey(
          const ValueKey<String>('media-reuse-project-key-field'),
        );
        await tester.ensureVisible(reuseProjectField);
        await tester.enterText(reuseProjectField, 'proj-omega');

        final Finder reuseBtn = find.byKey(
          const ValueKey<String>('media-reuse-btn-asset-1'),
        );
        await tester.ensureVisible(reuseBtn);
        await tester.tap(reuseBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('media-status-banner')),
          findsOneWidget,
        );
        expect(find.textContaining('proj-omega'), findsWidgets);

        final Finder titleField = find.byKey(
          const ValueKey<String>('media-upload-title-field'),
        );
        await tester.ensureVisible(titleField);
        await tester.enterText(titleField, '重複検証ビデオ');

        final Finder payloadField = find.byKey(
          const ValueKey<String>('media-upload-payload-field'),
        );
        await tester.ensureVisible(payloadField);
        await tester.enterText(payloadField, 'unique-clip-content-bytes');

        final Finder uploadBtn = find.byKey(
          const ValueKey<String>('media-upload-submit-button'),
        );
        await tester.ensureVisible(uploadBtn);
        await tester.tap(uploadBtn);
        await tester.pumpAndSettle();

        await tester.ensureVisible(titleField);
        await tester.enterText(titleField, '二度目の同一ビデオ');
        await tester.ensureVisible(uploadBtn);
        await tester.tap(uploadBtn);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('重複アップロードをスキップして再利用しました'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'passes responsive layout and WCAG contrast/tap-target guidelines at 360x800 and 1280x800 in light/dark modes with 2.0x textScale',
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

            final _InMemoryUnifiedMediaLibraryRepository repo =
                _InMemoryUnifiedMediaLibraryRepository(
              throwOnSearch: false,
              initialAssets:
                  _InMemoryUnifiedMediaLibraryRepository.sampleAssets(),
            );
            final UnifiedMediaLibraryController controller =
                UnifiedMediaLibraryController(repository: repo);

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
                        child: UnifiedMediaLibraryContainer(
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
