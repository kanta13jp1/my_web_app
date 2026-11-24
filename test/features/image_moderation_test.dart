import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/image_moderation/application/image_moderation_controller.dart';
import 'package:my_web_app/features/image_moderation/domain/image_moderation_models.dart';
import 'package:my_web_app/features/image_moderation/image_moderation_container.dart';

class _FakeImageModerationRepository implements ImageModerationRepository {
  _FakeImageModerationRepository({List<ModeratedImageAsset>? initialAssets})
      : _assets = List<ModeratedImageAsset>.from(
          initialAssets ?? <ModeratedImageAsset>[],
        );

  final List<ModeratedImageAsset> _assets;
  bool throwOnLoad = false;
  Completer<List<ModeratedImageAsset>>? pendingLoad;
  int nextId = 1;

  @override
  Future<List<ModeratedImageAsset>> fetchAssets() async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('storage index unavailable');
    }
    return List<ModeratedImageAsset>.unmodifiable(_assets);
  }

  @override
  Future<ModeratedImageAsset> registerUploadedImage(
    ModeratedImageAsset draft,
  ) async {
    final created = draft.copyWith(id: 'img-${nextId++}');
    _assets.insert(0, created);
    return created;
  }
}

List<ModeratedImageAsset> _sampleAssets() {
  final ts = DateTime.utc(2026, 11, 24, 15, 0);
  return <ModeratedImageAsset>[
    ModeratedImageAsset(
      id: 'asset-receipt',
      storageBucket: 'user-uploads',
      storagePath: 'receipt_tax_2026.png',
      tags: const <String>['receipt', 'document'],
      safetyScore: 0.97,
      moderationStatus: ImageModerationStatus.approved,
      isHidden: false,
      externalTransferConsented: false,
      createdAt: ts,
      updatedAt: ts,
    ),
    ModeratedImageAsset(
      id: 'asset-nature',
      storageBucket: 'user-uploads',
      storagePath: 'landscape_fuji.jpg',
      tags: const <String>['landscape'],
      safetyScore: 0.95,
      moderationStatus: ImageModerationStatus.approved,
      isHidden: false,
      externalTransferConsented: false,
      createdAt: ts,
      updatedAt: ts,
    ),
    ModeratedImageAsset(
      id: 'asset-hidden',
      storageBucket: 'user-uploads',
      storagePath: 'flagged_unsafe_upload.png',
      tags: const <String>['policy-review'],
      safetyScore: 0.18,
      moderationStatus: ImageModerationStatus.hidden,
      isHidden: true,
      externalTransferConsented: false,
      createdAt: ts,
      updatedAt: ts,
    ),
  ];
}

void main() {
  group(
    'ImageModerationController & LocalImageModerationAnalyzer (#2644)',
    () {
      test(
        'defaults consent false, hides unsafe items, filters tags, and guards disposal',
        () async {
          final repo = _FakeImageModerationRepository(
            initialAssets: _sampleAssets(),
          );
          final controller = ImageModerationController(repository: repo);
          expect(controller.state.externalTransferConsented, isFalse);

          await controller.loadAssets();
          expect(controller.state.filteredAssets.length, 2);
          expect(controller.state.hiddenOrFlaggedCount, 1);

          controller.selectTag('receipt');
          expect(controller.state.filteredAssets.length, 1);
          expect(controller.state.filteredAssets.first.id, 'asset-receipt');

          controller.selectTag('');
          controller.toggleIncludeRestricted(include: true);
          expect(controller.state.filteredAssets.length, 3);

          controller.dispose();
          expect(controller.isDisposed, isTrue);
          await controller.submitImageForModeration(
            storagePath: 'after_dispose.png',
          );
          expect(controller.state.filteredAssets.length, 3);
        },
      );
    },
  );

  group(
    'ImageModerationContainer Widget & A11y tests (#2644)',
    () {
      testWidgets(
        'filters by auto-tags, reveals masked unsafe items, and respects consent toggle',
        (WidgetTester tester) async {
          final repo = _FakeImageModerationRepository(
            initialAssets: _sampleAssets(),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ImageModerationContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('receipt_tax_2026.png'), findsOneWidget);
          expect(find.text('landscape_fuji.jpg'), findsOneWidget);
          expect(
            find.textContaining('flagged_unsafe_upload.png'),
            findsNothing,
          );

          final receiptChip = find.byKey(
            const ValueKey<String>('tag_filter_receipt'),
          );
          await tester.ensureVisible(receiptChip);
          await tester.tap(receiptChip);
          await tester.pumpAndSettle();

          expect(find.text('receipt_tax_2026.png'), findsOneWidget);
          expect(find.text('landscape_fuji.jpg'), findsNothing);

          final allChip = find.byKey(const ValueKey<String>('tag_filter_all'));
          await tester.ensureVisible(allChip);
          await tester.tap(allChip);
          await tester.pumpAndSettle();

          final showRestricted = find.byKey(
            const ValueKey<String>('toggle_include_restricted'),
          );
          await tester.ensureVisible(showRestricted);
          await tester.tap(showRestricted);
          await tester.pumpAndSettle();

          expect(
            find.textContaining('[安全マスク中] flagged_unsafe_upload.png'),
            findsOneWidget,
          );

          final consentToggle = find.byKey(
            const ValueKey<String>('external_transfer_consent_toggle'),
          );
          await tester.ensureVisible(consentToggle);
          await tester.tap(consentToggle);
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const ValueKey<String>('image_upload_path_input')),
            'food_bento_lunch.png',
          );
          final submitBtn = find.byKey(
            const ValueKey<String>('image_submit_button'),
          );
          await tester.ensureVisible(submitBtn);
          await tester.tap(submitBtn);
          await tester.pumpAndSettle();

          expect(find.text('food_bento_lunch.png'), findsOneWidget);
          expect(
            repo._assets.first.externalTransferConsented,
            isTrue,
          );
        },
      );

      testWidgets(
        'displays error banner and recovers on retry',
        (WidgetTester tester) async {
          final repo = _FakeImageModerationRepository(
            initialAssets: _sampleAssets(),
          )..throwOnLoad = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ImageModerationContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('image_moderation_error_banner')),
            findsOneWidget,
          );

          repo.throwOnLoad = false;
          final retryBtn = find.byKey(
            const ValueKey<String>('image_moderation_retry_button'),
          );
          await tester.ensureVisible(retryBtn);
          await tester.tap(retryBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('image_moderation_error_banner')),
            findsNothing,
          );
          expect(find.text('receipt_tax_2026.png'), findsOneWidget);
        },
      );

      testWidgets(
        'disposes cleanly while initial fetch is pending',
        (WidgetTester tester) async {
          final completer = Completer<List<ModeratedImageAsset>>();
          final repo = _FakeImageModerationRepository()
            ..pendingLoad = completer;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ImageModerationContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          );
          completer.complete(_sampleAssets());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
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
              final semanticsHandle = tester.ensureSemantics();
              tester.view.physicalSize = viewport;
              tester.view.devicePixelRatio = 1.0;
              try {
                final repo = _FakeImageModerationRepository(
                  initialAssets: _sampleAssets(),
                );
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
                              child: ImageModerationContainer(repository: repo),
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
                semanticsHandle.dispose();
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
              }
            },
          );
        }
      }
    },
  );
}
